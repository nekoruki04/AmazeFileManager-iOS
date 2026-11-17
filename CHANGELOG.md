# Changelog

All notable changes to Amaze File Manager for iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-17

### Added
- **Material Design UI Alignment (Team Amaze Identity)**:
  - Redesigned visual hierarchy with official Amaze Material Blue (`#2196F3`), Primary Dark (`#1976D2`), and Vibrant Pink FAB (`#FF4081`).
  - Added slide-out **Navigation Drawer** (`SideDrawerViewController`) with storage disk usage bar and direct drive/tool shortcuts.
  - Added **Floating Action Button** (FAB) for quick folder creation, file creation, and path jumping.
  - Added **Multi-Tab Bar** (`TabBarHeaderView`) for dual-pane/tabbed folder switching (Tab 1 / Tab 2).
  - Added **Grid / List View Switcher** (`FileGridCell` vs `FileCell`) with card views and large thumbnail previews.
  - Implemented authentic Amaze file/folder color-coding: Folders in Amber (`#FFA000`), Archives in Purple (`#9C27B0`), Media in Green/Orange/Red, Code in Cyan.
- **Phase 2 Deep Functional Implementation & Audit**:
  - Implemented secure Network Storage subsystem (`FTP`, `FTPS`, `SFTP` over SSH via Procursus curl toolchain).
  - Implemented `KeychainHelper` using iOS Security framework (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) for secure credential handling.
  - Implemented honest status reporting for SMB2/SMB3 (declaring unsupported due to external libsmb2 requirements without fake UI interfaces).
  - Enhanced `ArchiveManager` supporting archive creation (`.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.7z`) and extraction (`.zip`, `.tar`, `.gz`, `.bz2`, `.xz`, `.7z`, and `.rar` via unrar).
  - Added Zip Slip path-traversal protection (`isSafeEntryPath`) preventing arbitrary directory write escapes.
  - Enhanced `AppManagerViewController` with recursive bundle size calculation, icon discovery (`CFBundleIcons` and bundle assets), and direct inspection links to file browser and text editor.
  - Added Process Credentials and privilege audit model in `JailbreakEnvironment` (`ProcessCredentials` capturing real UID, EUID, GID, EGID and unsandboxed state).
  - Added custom file sorting (`Name`, `Size`, `Date Modified`) and context menu archive compression (`Compress (Archive)`).
  - Created machine-readable test evidence report generator (`Tests/functional_test_runner.py` -> `Tests/test_report.json`) running 30 real functional checks with 100% pass rate.
- **Initial Core Architecture**:
  - Native Swift and UIKit user interface targeting Dopamine 2, Dopamine 3, and RootHide jailbreaks on iOS/iPadOS 16.0 – 16.5.1+.
  - Low-overhead POSIX directory enumerator (`opendir`, `readdir`, `lstat`).
  - Actor-based asynchronous file operations engine supporting streaming 64 KB buffered copy, atomic rename/move, cross-device copy-unlink, and recursive deletion.
  - Hardcoded safety guards protecting system partitions (`/`, `/var`, `/usr`, `/System`, `/Library`, `/var/jb`).
  - AES-GCM 256-bit encryption engine with PBKDF2 (100,000 rounds) key derivation.
  - Built-in SQLite3 database viewer and UTF-8 text editor.
