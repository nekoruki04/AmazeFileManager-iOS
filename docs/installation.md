# Installation & Deployment Guide

This guide describes how to install, configure, and troubleshoot Amaze File Manager on jailbroken iOS and iPadOS devices.

---

## 1. Installation Methods

### Method A: Sileo / Zebra Package Manager (Recommended)

1. Open your jailbreak web browser or AirDrop the release `.deb` file: `build/amaze-rootless_1.0.0_iphoneos-arm.deb`.
2. Tap **Share** -> **Open in Sileo** (or Zebra).
3. Tap **Get** and then **Queue**.
4. Confirm installation. Sileo will unpack the archive to `/var/jb/Applications/Amaze.app/` and run the `postinst` script to update the SpringBoard icon cache (`uicache`).
5. Return to the home screen; Amaze will appear with its official icon.

---

### Method B: Terminal (NewTerm, Filza, or SSH)

1. Transfer the `.deb` file to your device (e.g. `/var/mobile/amaze-rootless_1.0.0_iphoneos-arm.deb`).
2. Open a terminal session as root or mobile:
   ```bash
   dpkg -i /var/mobile/amaze-rootless_1.0.0_iphoneos-arm.deb
   ```
3. If the app icon does not immediately appear, refresh icon cache:
   ```bash
   uicache -p /var/jb/Applications/Amaze.app
   ```

---

## 2. Uninstallation

### Method A: Sileo / Zebra
1. Navigate to **Packages** -> **Amaze File Manager**.
2. Tap **Modify** -> **Uninstall** -> **Confirm**.
3. Sileo will execute the `prerm` script (`uicache -u /var/jb/Applications/Amaze.app`) and cleanly remove all app files.

### Method B: Terminal
```bash
dpkg -r xyz.teamamaze.amazefilemanager
uicache -u /var/jb/Applications/Amaze.app
```

---

## 3. Post-Install Verification

Once launched, check the title bar or settings:
- **Jailbreak Detection Badge**: Confirms `Dopamine 2`, `Dopamine 3`, or `RootHide`.
- **Rootless Path Access**: Navigate to `/var/jb` to ensure Procursus binaries and packages are visible.
- **Storage Statistics**: Displays total, free, and used capacity of the primary storage partition.
