// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public struct StorageVolumeInfo: Sendable {
    public let path: String
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let usedBytes: Int64
    public let fileSystemType: String

    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes) * 100.0
    }
}

public struct RootlessPaths: Sendable {
    public static let root = "/"
    public static let mobileRoot = "/var/mobile"
    public static let media = "/var/mobile/Media"
    public static let downloads = "/var/mobile/Downloads"
    public static let documents = "/var/mobile/Documents"
    public static let library = "/var/mobile/Library"
    
    // Dopamine rootless base prefix
    public static let rootlessPrefix = "/var/jb"
    public static let rootlessApplications = "/var/jb/Applications"
    public static let rootlessBin = "/var/jb/usr/bin"
    public static let rootlessLibrary = "/var/jb/Library"
    public static let rootlessBaseBin = "/var/jb/basebin"

    /// Dynamically resolves the active jailbreak root directory across Dopamine and RootHide.
    /// Handles randomized RootHide jbroot prefixes and broken symlinks safely.
    public static var resolvedJailbreakPath: String? {
        let fm = FileManager.default

        // 1. Check standard /var/jb and test if readable directory
        if fm.fileExists(atPath: rootlessPrefix) {
            if let dir = opendir((rootlessPrefix as NSString).fileSystemRepresentation) {
                closedir(dir)
                return rootlessPrefix
            }
        }

        // 2. Scan /private/preboot for RootHide randomized jbroot-* or direct Dopamine mounts
        if let prebootContents = try? fm.contentsOfDirectory(atPath: "/private/preboot") {
            for uuid in prebootContents where !uuid.hasPrefix(".") {
                let uuidPath = "/private/preboot/\(uuid)"
                if let sub = try? fm.contentsOfDirectory(atPath: uuidPath) {
                    for item in sub where item.hasPrefix("jbroot-") || item.hasPrefix("dopamine-") || item == "procursus" {
                        let candidate = (uuidPath as NSString).appendingPathComponent(item)
                        let procursusSub = (candidate as NSString).appendingPathComponent("procursus")
                        if fm.fileExists(atPath: procursusSub) {
                            return procursusSub
                        }
                        if fm.fileExists(atPath: candidate) {
                            return candidate
                        }
                    }
                }
            }
        }

        return nil
    }
    
    // Standard application containers
    public static let appDataContainers = "/var/mobile/Containers/Data/Application"
    public static let appBundleContainers = "/var/mobile/Containers/Bundle/Application"

    public static var defaultLocations: [(name: String, path: String, icon: String)] {
        var list: [(name: String, path: String, icon: String)] = [
            ("Mobile Home", mobileRoot, "house.fill"),
            ("Media Storage", media, "photo.on.rectangle.angled"),
            ("Documents", documents, "folder.fill"),
            ("System Root (/)", root, "internaldrive.fill"),
        ]

        if let jbPath = resolvedJailbreakPath {
            list.append(("Jailbreak Root (\(jbPath))", jbPath, "wrench.and.screwdriver.fill"))
            let jbApps = (jbPath as NSString).appendingPathComponent("Applications")
            if FileManager.default.fileExists(atPath: jbApps) {
                list.append(("Jailbreak Apps", jbApps, "app.badge.checkmark"))
            }
        }

        if FileManager.default.fileExists(atPath: appDataContainers) {
            list.append(("App Containers", appDataContainers, "square.grid.2x2.fill"))
        }

        return list
    }

    public static func volumeInfo(for path: String = "/") -> StorageVolumeInfo? {
        var stat = statvfs()
        guard statvfs((path as NSString).fileSystemRepresentation, &stat) == 0 else {
            return nil
        }
        let total = Int64(stat.f_blocks) * Int64(stat.f_frsize)
        let free = Int64(stat.f_bavail) * Int64(stat.f_frsize)
        let used = total - free
        return StorageVolumeInfo(
            path: path,
            totalBytes: total,
            freeBytes: free,
            usedBytes: used,
            fileSystemType: "APFS"
        )
    }
}
