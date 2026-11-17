# Architecture & Technical Design

This document details the software architecture, memory management, and filesystem models of Amaze File Manager for iOS.

## 1. Architectural Overview

Amaze is structured into modular layers adhering to modern Swift concurrency (`async`/`await`, `actor`) and UIKit standards:

```
[UI Layer]
BrowserViewController  <-->  BreadcrumbBar / FileCell
      |
      v
[Features Layer]
ArchiveManager | TextEditor | DatabaseViewer | AppManager | BookmarkStore | NetworkStorageViewController
      |
      v
[Core Operations Layer]
FileOperationsQueue (actor)  <-->  ConflictResolver
      |
      v
[Network & Storage Layer]
NetworkStorageClient (actor) <--> KeychainHelper (Security.framework)
      |
      v
[Filesystem & Security Layer]
FileSystemProvider (POSIX) | RootlessPaths | CryptEngine (AES-GCM 256)
      |
      v
[Jailbreak Layer]
JailbreakEnvironment (Dopamine 2 / Dopamine 3 / RootHide detection + ProcessCredentials)
```

## 2. Low-Overhead Filesystem Provider

On iOS, high-level Foundation APIs (`FileManager.contentsOfDirectory`) allocate substantial Objective-C objects per entry, which degrades performance when navigating directories containing thousands of files (e.g. `/var/jb/usr/lib`).

`FileSystemProvider` implements direct POSIX traversal:
1. `opendir(path)` initiates a raw directory handle.
2. `readdir(dir)` iterates raw directory entries without Objective-C bridge overhead.
3. `lstat(fullPath)` collects file size, mode, permissions, creation, and modification timestamps.
4. Returns strongly-typed `FileItem` structs to the UI collection view diffable data source.

## 3. Asynchronous File Operations & Safety Bounds

File copy, move, and delete operations execute inside a dedicated Swift `actor` (`FileOperationsQueue`):
- **Streaming Buffers**: Large files are copied in 64 KB streaming chunks, maintaining a flat memory footprint and avoiding memory pressure termination under Jetsam limits.
- **Cross-Device Move**: When moving across different filesystem mount points (e.g., from `/private/var` to `/private/preboot`), the queue transparently falls back from atomic `rename()` to a streaming copy followed by source unlink.
- **System Directory Protection**: A hardcoded guard prevents destructive delete operations on root paths (`/`, `/var`, `/usr`, `/System`, `/Library`, `/etc`, `/bin`, `/sbin`, `/var/jb`).

## 4. Archive Creation & Extraction

The archive subsystem (`ArchiveManager`) interfaces with native Procursus command-line tools via `posix_spawn` / `posix_spawnp`:
- **Extraction**: Supports `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.7z`.
- **Creation**: Supports `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.7z`.
- **Zip Slip Defense**: Path traversal prevention verifies that all entry targets resolve strictly within the destination directory boundaries.

## 5. Network Storage & Keychain Security

- **Protocols Supported**: `FTP`, `FTPS` (implicit and explicit TLS), and `SFTP` over SSH.
- **Credential Storage**: Passwords and connection secrets are saved in the hardware-backed iOS Keychain (`kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). Plaintext password storage is strictly forbidden.
- **SMB Support Status**: SMB2/SMB3 is explicitly designated as unsupported in this release because it requires linking against an external C library (`libsmb2`).

## 6. Cryptographic Engine

Amaze implements file encryption using Apple CryptoKit and CommonCrypto:
- **Algorithm**: AES-GCM (Galois/Counter Mode) with 256-bit symmetric keys.
- **Key Derivation**: PBKDF2 (HMAC-SHA256) with 100,000 rounds and a cryptographic 16-byte random salt (`SecRandomCopyBytes`).
- **Payload Structure**: Salt (16 bytes) + Nonce (12 bytes) + Ciphertext + Tag (16 bytes).

## 7. Mach-O & Entitlements

The application executable is linked against the iOS 16.0 SDK and signed with:
- `com.apple.private.security.no-sandbox`: Bypasses sandbox restrictions to access all filesystem paths.
- `platform-application`: Grants platform privileges under the jailbreak trust cache.
- `com.apple.developer.kernel.increased-memory-limit`: Allows the app to utilize extended memory for archive unpacking and SQLite operations.
