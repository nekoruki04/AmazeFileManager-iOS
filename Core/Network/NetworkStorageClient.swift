// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Darwin

public actor NetworkStorageClient {
    public static let shared = NetworkStorageClient()

    private init() {}

    /// Resolves curl binary path.
    private nonisolated func curlBinary() -> String? {
        ArchiveManager.resolveBinary("curl")
    }

    /// Constructs the base URL string for curl.
    private nonisolated func buildURL(config: NetworkServerConfig, path: String) -> String {
        let scheme: String
        switch config.protocolType {
        case .ftp: scheme = "ftp"
        case .ftps: scheme = "ftps"
        case .sftp: scheme = "sftp"
        case .smb: scheme = "smb"
        }

        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return "\(scheme)://\(config.host):\(config.port)/\(cleanPath)"
    }

    /// Tests connection and credentials against remote server.
    public func testConnection(config: NetworkServerConfig) async throws -> Bool {
        guard config.protocolType.isSupported else {
            throw NSError(
                domain: "NetworkStorageClient",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "SMB2/SMB3 is unsupported. It requires an external libsmb2 library which is not included in this release."]
            )
        }

        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found in /var/jb/usr/bin/curl"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        let targetURL = buildURL(config: config, path: config.remoteBasePath)

        var args = [
            "-s", "-S",
            "--connect-timeout", "10",
            "--max-time", "15",
            "-u", userAuth,
            "-l", targetURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args, captureOutput: true)
        if res.status != 0 {
            throw NSError(
                domain: "NetworkStorageClient",
                code: Int(res.status),
                userInfo: [NSLocalizedDescriptionKey: "Connection failed: \(res.output.isEmpty ? "Exit status \(res.status)" : res.output)"]
            )
        }
        return true
    }

    /// Lists directory contents on remote server.
    public func listDirectory(config: NetworkServerConfig, remotePath: String) async throws -> [RemoteFileItem] {
        guard config.protocolType.isSupported else {
            throw NSError(domain: "NetworkStorageClient", code: 501, userInfo: [NSLocalizedDescriptionKey: "Protocol unsupported."])
        }
        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        var targetURL = buildURL(config: config, path: remotePath)
        if !targetURL.hasSuffix("/") { targetURL += "/" }

        var args = [
            "-s", "-S",
            "--connect-timeout", "10",
            "-u", userAuth,
            "-l", targetURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args, captureOutput: true)
        guard res.status == 0 else {
            throw NSError(domain: "NetworkStorageClient", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Remote directory listing failed (status \(res.status))"])
        }

        let lines = res.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var remoteItems: [RemoteFileItem] = []

        for line in lines {
            let isDir = line.hasSuffix("/")
            let cleanName = isDir ? String(line.dropLast()) : line
            let fullPath = (remotePath as NSString).appendingPathComponent(cleanName)
            remoteItems.append(RemoteFileItem(
                name: cleanName,
                remotePath: fullPath,
                isDirectory: isDir,
                size: 0,
                modificationDate: nil
            ))
        }

        return remoteItems.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Downloads remote file to local destination path.
    public func downloadFile(config: NetworkServerConfig, remotePath: String, localDestinationPath: String) async throws {
        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        let targetURL = buildURL(config: config, path: remotePath)

        var args = [
            "-s", "-S",
            "--connect-timeout", "10",
            "-u", userAuth,
            "-o", localDestinationPath,
            targetURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args)
        if res.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Download failed (status \(res.status))"])
        }
    }

    /// Uploads local file to remote destination path.
    public func uploadFile(config: NetworkServerConfig, localSourcePath: String, remoteDestinationPath: String) async throws {
        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        let targetURL = buildURL(config: config, path: remoteDestinationPath)

        var args = [
            "-s", "-S",
            "--connect-timeout", "10",
            "-u", userAuth,
            "-T", localSourcePath,
            targetURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args)
        if res.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Upload failed (status \(res.status))"])
        }
    }

    /// Deletes a file on remote server.
    public func deleteRemoteFile(config: NetworkServerConfig, remotePath: String) async throws {
        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        let baseURL = buildURL(config: config, path: "")

        var args = [
            "-s", "-S",
            "-u", userAuth,
            "-Q", "DELE \(remotePath)",
            baseURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args)
        if res.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Remote deletion failed (status \(res.status))"])
        }
    }

    /// Renames a file on remote server.
    public func renameRemoteFile(config: NetworkServerConfig, oldPath: String, newPath: String) async throws {
        guard let curl = curlBinary() else {
            throw NSError(domain: "NetworkStorageClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "curl tool not found"])
        }

        let password = KeychainHelper.shared.getPassword(for: config.keychainAccountKey) ?? ""
        let userAuth = "\(config.username):\(password)"
        let baseURL = buildURL(config: config, path: "")

        var args = [
            "-s", "-S",
            "-u", userAuth,
            "-Q", "RNFR \(oldPath)",
            "-Q", "RNTO \(newPath)",
            baseURL
        ]
        if config.protocolType == .ftps {
            args.append("--ssl")
            args.append("-k")
        }

        let res = try ArchiveManager.runCommand(executable: curl, arguments: args)
        if res.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Remote rename failed (status \(res.status))"])
        }
    }
}
