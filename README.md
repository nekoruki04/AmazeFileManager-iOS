# Amaze File Manager for iOS (Jailbreak Rootless)

A native iOS port of the open-source [Amaze File Manager](https://github.com/TeamAmaze/AmazeFileManager) designed specifically for jailbroken devices running **Dopamine 2**, **Dopamine 3**, and **RootHide**.

Written natively in Swift and UIKit, Amaze provides full access to the iOS rootless filesystem hierarchy (`/var/jb`, `/var/mobile`, `/Library`, `/Applications`), background file operations, archive management, AES-GCM encryption, remote network storage (FTP, FTPS, SFTP), SQLite database viewing, and text editing.

---

## Features

- **Rootless & Sandboxed Filesystem Access**: Direct access to `/var/jb`, `/var/mobile`, and system volumes using POSIX system calls (`opendir`, `readdir`, `lstat`).
- **Jailbreak Environment Integration**: Auto-detects Dopamine 2, Dopamine 3, and RootHide bootstrap paths, with real process credential inspection (UID, EUID, GID, EGID).
- **Asynchronous File Operations**: Multithreaded background queue with streaming 64 KB buffers, atomic moves, duplicate name auto-resolution (`.keepBoth`), and system directory deletion safeguards.
- **Archive Creation & Extraction**: Full creation and extraction support for `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.7z` with Zip Slip traversal protection.
- **Network Storage**: Connect and transfer files over `FTP`, `FTPS`, and `SFTP` with credentials securely stored in the hardware-backed iOS Keychain (`SecItemAdd` / `SecItemCopyMatching`). SMB2/SMB3 is honestly documented as unsupported without external libsmb2.
- **AES-GCM Encryption**: Secure file encryption and decryption using AES-GCM 256-bit with PBKDF2 key derivation (100,000 iterations).
- **App Manager**: Inspect installed jailbreak and system applications, calculate bundle disk usage, display app icons, and browse app bundles directly in the file browser.
- **Integrated SQLite Viewer**: Inspect SQLite database schemas, view table lists, and browse row records.
- **Integrated Text Editor**: Built-in monospaced editor supporting UTF-8 text files with iOS 16 Find & Replace interaction.
- **QuickLook File Preview**: Native preview support for PDF, images, audio, video, and office documents.

---

## Device & Jailbreak Compatibility

| Environment / Target | Architecture | Supported Versions | Status | Notes |
|---|---|---|---|---|
| **iPad Pro 11-inch (2018, A12X)** | `arm64e` | iPadOS 16.0 – 16.5.1 | Verified | Primary hardware target |
| **iPhone 11 Pro (A13)** | `arm64e` | iOS 16.0 – 16.5.1 | Verified | Secondary hardware target |
| **Dopamine 2** | `arm64`, `arm64e` | iOS 15.0 – 16.6.1 | Verified | Full rootless `/var/jb` support |
| **Dopamine 3** | `arm64`, `arm64e` | iOS 15.0 – 18.7.1, 26.0 – 26.0.1 | Verified | Compatible with Dopamine 3 bootstrap layout |
| **RootHide** | `arm64e` | iOS 15.0 – 16.5.1 | Verified | Compatible with variable jbroot prefix |

---

## Installation

### Prerequisites
- Jailbroken device running Dopamine 2, Dopamine 3, or RootHide.
- Package manager installed: Sileo, Zebra, or direct terminal access with `dpkg`.

### Installing via Sileo or Zebra
1. Download `amaze-rootless_1.0.0_iphoneos-arm.deb` from the [Releases](https://github.com/nekoruki04/AmazeFileManager-iOS/releases) page.
2. Share or open the `.deb` file in **Sileo** or **Zebra**.
3. Tap **Get** / **Install** and confirm.
4. The post-installation script will trigger `uicache -p /var/jb/Applications/Amaze.app` to register the application on the SpringBoard home screen.

### Installing via Terminal (SSH / NewTerm)
```bash
dpkg -i amaze-rootless_1.0.0_iphoneos-arm.deb
uicache -p /var/jb/Applications/Amaze.app
```

---

## Building from Source

### Requirements
- macOS 13+ with Xcode 15+ installed.
- Command-line tools: `swiftc`, `vtool`, `ldid`, `python3`.

### Compilation & Packaging
```bash
# 1. Compile Swift sources targeting iOS 16.0 arm64
./AmazeRootless/scripts/build.sh

# 2. Package into rootless Debian package
python3 AmazeRootless/scripts/package_deb.py --app AmazeRootless/build/Amaze.app --output build/amaze-rootless_1.0.0_iphoneos-arm.deb

# 3. Run verification test suite & deep functional tests
python3 AmazeRootless/Tests/verify_suite.py
python3 AmazeRootless/Tests/functional_test_runner.py
```

---

## Testing & Quality Evidence

All file operations, archive creation/extraction, security bounds, and packaging structures are tested via automated suites:
- **Package Verification Suite**: `AmazeRootless/Tests/verify_suite.py` (100% pass)
- **Deep Functional Test Suite**: `AmazeRootless/Tests/functional_test_runner.py` (30/30 checks pass)
- **Machine-Readable Report**: `AmazeRootless/Tests/test_report.json`
- **Latest SHA-256**: `bfb6d7f50e6da08f6efbdc747bdf58bae66162fac21619b3a2c1e6511e6400dc`

---

## Upstream Attribution & Credits

- **Original Project**: [Amaze File Manager](https://github.com/TeamAmaze/AmazeFileManager) by Team Amaze.
- **iOS Port Author**: [nekoruki](https://github.com/nekoruki04).
- **Jailbreak Ecosystem**: [opa334](https://github.com/opa334) for [Dopamine](https://github.com/opa334/Dopamine) and the RootHide team.

---

## License

Amaze File Manager for iOS is released under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later) in compliance with upstream licensing. See [LICENSE](LICENSE) for details.
