#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/Amaze.app"
ENTITLEMENTS="$PROJECT_ROOT/Packaging/Amaze.entitlements"

echo "[*] Project root: $PROJECT_ROOT"
echo "[*] App bundle: $APP_DIR"

mkdir -p "$APP_DIR"

SWIFT_SOURCES=(
    "$PROJECT_ROOT/App/AppDelegate.swift"
    "$PROJECT_ROOT/App/SceneDelegate.swift"
    "$PROJECT_ROOT/Core/Theme/AmazeTheme.swift"
    "$PROJECT_ROOT/Core/Privilege/PrivilegeHelper.swift"
    "$PROJECT_ROOT/Core/FileSystem/FileItem.swift"
    "$PROJECT_ROOT/Core/FileSystem/FileSystemProvider.swift"
    "$PROJECT_ROOT/Core/FileSystem/RootlessPaths.swift"
    "$PROJECT_ROOT/Core/FileOperations/FileOperation.swift"
    "$PROJECT_ROOT/Core/FileOperations/ConflictResolver.swift"
    "$PROJECT_ROOT/Core/FileOperations/FileOperationsQueue.swift"
    "$PROJECT_ROOT/Core/Search/FileSearchEngine.swift"
    "$PROJECT_ROOT/Core/Security/CryptEngine.swift"
    "$PROJECT_ROOT/Core/Network/KeychainHelper.swift"
    "$PROJECT_ROOT/Core/Network/NetworkStorageItem.swift"
    "$PROJECT_ROOT/Core/Network/NetworkStorageClient.swift"
    "$PROJECT_ROOT/Jailbreak/JailbreakEnvironment.swift"
    "$PROJECT_ROOT/Features/Archive/ArchiveManager.swift"
    "$PROJECT_ROOT/Features/Bookmarks/BookmarkStore.swift"
    "$PROJECT_ROOT/Features/TextEditor/TextEditorViewController.swift"
    "$PROJECT_ROOT/Features/DatabaseViewer/DatabaseViewerViewController.swift"
    "$PROJECT_ROOT/Features/AppManager/AppManagerViewController.swift"
    "$PROJECT_ROOT/Features/Network/NetworkStorageViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/SideDrawerViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FloatingActionButton.swift"
    "$PROJECT_ROOT/Features/FileBrowser/TabBarHeaderView.swift"
    "$PROJECT_ROOT/Features/FileBrowser/BreadcrumbBar.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FileCell.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FileGridCell.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FilePropertiesViewController.swift"
    "$PROJECT_ROOT/Features/Settings/SettingsViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/BrowserViewController.swift"
)

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "[*] Using iPhoneOS SDK: $SDK_PATH"

echo "[*] Compiling Swift sources for arm64 iOS 16.0..."
swiftc \
    -target arm64-apple-ios16.0 \
    -sdk "$SDK_PATH" \
    -module-name Amaze \
    -O \
    -whole-module-optimization \
    -parse-as-library \
    -emit-executable \
    -o "$APP_DIR/Amaze" \
    "${SWIFT_SOURCES[@]}"

echo "[*] Compiling amazeRootHelper binary..."
xcrun --sdk iphoneos clang \
    -target arm64-apple-ios16.0 \
    -isysroot "$SDK_PATH" \
    -O2 \
    "$PROJECT_ROOT/Core/Privilege/amazeRootHelper.c" \
    -o "$APP_DIR/amazeRootHelper"

xcrun vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_DIR/amazeRootHelper" "$APP_DIR/amazeRootHelper"
ldid -S"$ENTITLEMENTS" "$APP_DIR/amazeRootHelper"

echo "[*] Copying bundle resources..."
cp "$PROJECT_ROOT/App/Info.plist" "$APP_DIR/Info.plist"
if [ -f "$APP_DIR/icon.png" ]; then
    cp "$APP_DIR/icon.png" "$APP_DIR/AppIcon60x60@2x.png"
    cp "$APP_DIR/icon.png" "$APP_DIR/AppIcon76x76@2x~ipad.png"
fi

echo "[*] Retargeting Mach-O platform version to iOS 16.0..."
xcrun vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_DIR/Amaze" "$APP_DIR/Amaze"

echo "[*] Signing executable with entitlements..."
ldid -S"$ENTITLEMENTS" "$APP_DIR/Amaze"

echo "[+] Amaze.app compiled and signed successfully."
file "$APP_DIR/Amaze"
