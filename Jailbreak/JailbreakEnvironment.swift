// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Darwin

public enum JailbreakFlavor: String, CustomStringConvertible, Sendable {
    case dopamine2 = "Dopamine 2"
    case dopamine3 = "Dopamine 3"
    case dopamineRootHide = "Dopamine RootHide"
    case genericRootless = "Rootless Environment"
    case jailed = "Standard (Sandboxed)"

    public var description: String { rawValue }
}

public struct ProcessCredentials: Sendable {
    public let uid: uid_t
    public let euid: uid_t
    public let gid: gid_t
    public let egid: gid_t
    public let isRoot: Bool
    public let isUnsandboxed: Bool

    public var summary: String {
        "UID: \(uid), EUID: \(euid), GID: \(gid), EGID: \(egid) [\(isUnsandboxed ? "Unsandboxed" : "Sandboxed")]"
    }
}

public struct JailbreakEnvironment: Sendable {
    public static var currentFlavor: JailbreakFlavor {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/basebin/libroothider.dylib") {
            return .dopamineRootHide
        }
        if fm.fileExists(atPath: "/var/jb/basebin/hookd") {
            return .dopamine3
        }
        if fm.fileExists(atPath: "/var/jb/basebin/jbctl") {
            return .dopamine2
        }
        if fm.fileExists(atPath: "/var/jb") {
            return .genericRootless
        }
        return .jailed
    }

    public static var isRootless: Bool {
        FileManager.default.fileExists(atPath: "/var/jb")
    }

    public static var credentials: ProcessCredentials {
        let u = getuid()
        let eu = geteuid()
        let g = getgid()
        let eg = getegid()
        let unsandboxed = isUnsandboxed
        return ProcessCredentials(
            uid: u,
            euid: eu,
            gid: g,
            egid: eg,
            isRoot: eu == 0,
            isUnsandboxed: unsandboxed
        )
    }

    public static var isUnsandboxed: Bool {
        // True unsandboxed check: can read /var/mobile and /var/jb without sandbox containment
        let canReadMobile = access("/var/mobile", R_OK) == 0
        let canReadJb = access("/var/jb", R_OK) == 0
        return canReadMobile || canReadJb
    }

    public static var jbctlPath: String? {
        let paths = ["/var/jb/basebin/jbctl", "/var/jb/usr/bin/jbctl"]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
