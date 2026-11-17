# Building from Source

This guide explains how to compile and package Amaze File Manager for iOS from source.

## 1. Prerequisites

You will need a macOS system with the following tools installed:
- macOS 13 (Ventura) or later
- Xcode 15 or later with iOS 16+ SDK
- `ldid` (installed via Homebrew or Procursus build tools)
- `python3` (3.8+)

Verify prerequisites:
```bash
xcrun --sdk iphoneos --show-sdk-path
which ldid
python3 --version
```

## 2. Compilation

Run the provided build script:
```bash
cd AmazeRootless
chmod +x scripts/build.sh
./scripts/build.sh
```

This compiles all Swift source modules into an ARM64 Mach-O binary (`AmazeRootless/build/Amaze.app/Amaze`), retargets platform version to iOS 16.0 using `vtool`, and codesigns the bundle with `Packaging/Amaze.entitlements` using `ldid`.

## 3. Debian Packaging

To create the final rootless Debian archive:
```bash
python3 AmazeRootless/scripts/package_deb.py \
  --app AmazeRootless/build/Amaze.app \
  --output build/amaze-rootless_1.0.0_iphoneos-arm.deb
```

## 4. Running the Test Suite

Execute the automated acceptance suite to ensure all package constraints are satisfied:
```bash
python3 AmazeRootless/Tests/verify_suite.py
```
