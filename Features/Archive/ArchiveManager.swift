// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Darwin

public enum ArchiveFormat: String, CaseIterable, Sendable {
    case zip = "zip"
    case tarGz = "tar.gz"
    case tarBz2 = "tar.bz2"
    case tarXz = "tar.xz"
    case tar = "tar"
    case sevenZip = "7z"

    public var fileExtension: String {
        return rawValue
    }
}

public struct ArchiveEntry: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let uncompressedSize: Int64
    public let isDirectory: Bool
}

public struct ArchiveManager: Sendable {
    /// Executes a binary via posix_spawn with arguments and optional stdout capture.
    public static func runCommand(executable: String, arguments: [String], captureOutput: Bool = false) throws -> (status: Int32, output: String) {
        var pid: pid_t = 0
        var cArgs: [UnsafeMutablePointer<CChar>?] = []
        cArgs.append(strdup(executable))
        for arg in arguments {
            cArgs.append(strdup(arg))
        }
        cArgs.append(nil)
        defer {
            for ptr in cArgs where ptr != nil { free(ptr) }
        }

        var fileActions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        var pipeFds: [Int32] = [0, 0]
        if captureOutput {
            pipe(&pipeFds)
            posix_spawn_file_actions_adddup2(&fileActions, pipeFds[1], STDOUT_FILENO)
            posix_spawn_file_actions_addclose(&fileActions, pipeFds[0])
        }

        let spawnErr = posix_spawnp(&pid, executable, &fileActions, nil, &cArgs, environ)
        if captureOutput {
            close(pipeFds[1])
        }

        if spawnErr != 0 {
            if captureOutput { close(pipeFds[0]) }
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(spawnErr),
                userInfo: [NSLocalizedDescriptionKey: "posix_spawn failed for \(executable): \(String(cString: strerror(spawnErr)))"]
            )
        }

        var outputString = ""
        if captureOutput {
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let bytesRead = read(pipeFds[0], &buffer, buffer.count)
                if bytesRead <= 0 { break }
                if let str = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    outputString += str
                }
            }
            close(pipeFds[0])
        }

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return (status, outputString)
    }

    /// Resolves executable path, checking Procursus rootless paths first.
    public static func resolveBinary(_ name: String) -> String? {
        let candidates = [
            "/var/jb/usr/bin/\(name)",
            "/var/jb/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Validates that an archive entry does not escape destinationDirectory (Zip Slip defense).
    public static func isSafeEntryPath(_ entryPath: String, destinationDirectory: String) -> Bool {
        let destURL = URL(fileURLWithPath: destinationDirectory).standardizedFileURL
        let combinedURL = destURL.appendingPathComponent(entryPath).standardizedFileURL
        return combinedURL.path.hasPrefix(destURL.path)
    }

    /// Extracts an archive safely into destinationDirectory.
    public static func extractArchive(at sourcePath: String, to destinationDirectory: String) throws {
        let destURL = URL(fileURLWithPath: destinationDirectory).standardizedFileURL
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        let lower = sourcePath.lowercased()

        // 7-Zip archives
        if lower.hasSuffix(".7z") {
            guard let sevenZip = resolveBinary("7z") ?? resolveBinary("7za") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "7z tool not found in /var/jb/usr/bin/7z. Please install p7zip from Sileo."])
            }
            let res = try runCommand(executable: sevenZip, arguments: ["x", sourcePath, "-o\(destURL.path)", "-y"])
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "7z extraction failed with status \(res.status)"])
            }
            return
        }

        // RAR archives
        if lower.hasSuffix(".rar") {
            guard let unrar = resolveBinary("unrar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "unrar tool not found. RAR extraction requires unrar package."])
            }
            let res = try runCommand(executable: unrar, arguments: ["x", "-y", sourcePath, destURL.path])
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "RAR extraction failed with status \(res.status)"])
            }
            return
        }

        // Standard tar, gz, bz2, xz, and zip via bsdtar/tar/unzip
        guard let tarBin = resolveBinary("tar") else {
            throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found."])
        }

        var flags = "-x"
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") || lower.hasSuffix(".gz") {
            flags += "z"
        } else if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".bz2") {
            flags += "j"
        } else if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") || lower.hasSuffix(".xz") {
            flags += "J"
        }
        flags += "f"

        // For zip files, try bsdtar first, then fallback to unzip
        if lower.hasSuffix(".zip") {
            if let unzipBin = resolveBinary("unzip") {
                let res = try runCommand(executable: unzipBin, arguments: ["-q", "-o", sourcePath, "-d", destURL.path])
                if res.status == 0 { return }
            }
        }

        _ = chmod((destURL.path as NSString).fileSystemRepresentation, 0o777)

        let args = [flags, sourcePath, "--no-same-owner", "-C", destURL.path]
        let res = try? runCommand(executable: tarBin, arguments: args)
        if let res = res, res.status == 0 {
            return
        }

        if let fallbackRes = try? runCommand(executable: tarBin, arguments: [flags, sourcePath, "-C", destURL.path]), fallbackRes.status == 0 {
            return
        }

        if (try? PrivilegeHelper.extractArchive(source: sourcePath, destination: destURL.path)) != nil {
            return
        }

        let exitCode = res?.status ?? 1
        throw NSError(domain: "ArchiveManager", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: "Archive extraction exited with status \(exitCode)"])
    }

    /// Creates an archive from a list of files or directory.
    public static func createArchive(sources: [String], destinationPath: String, format: ArchiveFormat) throws {
        let destURL = URL(fileURLWithPath: destinationPath).standardizedFileURL
        let parentDir = destURL.deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true, attributes: nil)

        switch format {
        case .zip:
            if let zipBin = resolveBinary("zip") {
                var args = ["-r", "-q", destURL.path]
                for src in sources {
                    args.append((src as NSString).lastPathComponent)
                }
                let firstSrcParent = (sources[0] as NSString).deletingLastPathComponent
                let originalCwd = FileManager.default.currentDirectoryPath
                FileManager.default.changeCurrentDirectoryPath(firstSrcParent)
                defer { FileManager.default.changeCurrentDirectoryPath(originalCwd) }

                let res = try runCommand(executable: zipBin, arguments: args)
                if res.status != 0 {
                    throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "zip creation failed with status \(res.status)"])
                }
                return
            }
            fallthrough // fallback to tar.gz if zip tool is absent

        case .tarGz:
            guard let tarBin = resolveBinary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-czf", destURL.path]
            let firstSrcParent = (sources[0] as NSString).deletingLastPathComponent
            args.append("-C")
            args.append(firstSrcParent)
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try runCommand(executable: tarBin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.gz creation failed with status \(res.status)"])
            }

        case .tarBz2:
            guard let tarBin = resolveBinary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-cjf", destURL.path, "-C", (sources[0] as NSString).deletingLastPathComponent]
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try runCommand(executable: tarBin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.bz2 creation failed with status \(res.status)"])
            }

        case .tarXz:
            guard let tarBin = resolveBinary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-cJf", destURL.path, "-C", (sources[0] as NSString).deletingLastPathComponent]
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try runCommand(executable: tarBin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.xz creation failed with status \(res.status)"])
            }

        case .tar:
            guard let tarBin = resolveBinary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-cf", destURL.path, "-C", (sources[0] as NSString).deletingLastPathComponent]
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try runCommand(executable: tarBin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar creation failed with status \(res.status)"])
            }

        case .sevenZip:
            guard let sevenZip = resolveBinary("7z") ?? resolveBinary("7za") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "7z tool not found. Install p7zip from Sileo."])
            }
            var args = ["a", destURL.path]
            for src in sources {
                args.append(src)
            }
            let res = try runCommand(executable: sevenZip, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "7z creation failed with status \(res.status)"])
            }
        }
    }

    /// Lists archive entries without extracting them.
    public static func listArchiveEntries(at sourcePath: String) throws -> [String] {
        let lower = sourcePath.lowercased()

        if lower.hasSuffix(".7z") {
            guard let sevenZip = resolveBinary("7z") ?? resolveBinary("7za") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "7z tool not found."])
            }
            let res = try runCommand(executable: sevenZip, arguments: ["l", "-slt", sourcePath], captureOutput: true)
            var files: [String] = []
            for line in res.output.split(separator: "\n") {
                if line.hasPrefix("Path = ") && !line.contains(sourcePath) {
                    files.append(String(line.dropFirst(7)))
                }
            }
            return files
        }

        guard let tarBin = resolveBinary("tar") else {
            throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found."])
        }

        var flags = "-t"
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") || lower.hasSuffix(".gz") {
            flags += "z"
        } else if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".bz2") {
            flags += "j"
        } else if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") || lower.hasSuffix(".xz") {
            flags += "J"
        }
        flags += "f"

        let args = [flags, sourcePath]
        let res = try runCommand(executable: tarBin, arguments: args, captureOutput: true)
        return res.output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }
}
