// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Darwin

public final class FileSystemProvider: Sendable {
    public static let shared = FileSystemProvider()

    public init() {}

    /// Lists entries in a directory using POSIX lstat for high performance and accurate symlink handling.
    public func contentsOfDirectory(at path: String, showHidden: Bool = true) async throws -> [FileItem] {
        return try await Task.detached(priority: .userInitiated) {
            var items: [FileItem] = []
            guard let dir = opendir((path as NSString).fileSystemRepresentation) else {
                let err = errno
                throw NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(err),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open directory \(path): \(String(cString: strerror(err)))"]
                )
            }
            defer { closedir(dir) }

            while let entry = readdir(dir) {
                let name = withUnsafeBytes(of: entry.pointee.d_name) { rawPtr -> String in
                    guard let baseAddress = rawPtr.baseAddress else { return "" }
                    return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
                }

                if name == "." || name == ".." { continue }
                if !showHidden && name.hasPrefix(".") { continue }

                let fullPath = (path as NSString).appendingPathComponent(name)
                if let item = self.statItem(at: fullPath, name: name) {
                    items.append(item)
                }
            }

            return items.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }.value
    }

    /// Obtains detailed file attributes using lstat to accurately inspect symlinks.
    public func statItem(at fullPath: String, name: String? = nil) -> FileItem? {
        var statInfo = stat()
        let cPath = (fullPath as NSString).fileSystemRepresentation
        guard lstat(cPath, &statInfo) == 0 else {
            return nil
        }

        let itemName = name ?? (fullPath as NSString).lastPathComponent
        let mode = statInfo.st_mode
        let isDir = (mode & S_IFMT) == S_IFDIR
        let isSym = (mode & S_IFMT) == S_IFLNK

        var symlinkTarget: String? = nil
        if isSym {
            var buffer = [CChar](repeating: 0, count: 1024)
            let len = readlink(cPath, &buffer, 1023)
            if len > 0 {
                buffer[len] = 0
                symlinkTarget = String(cString: buffer)
            }
        }

        let size: Int64 = isDir ? 0 : Int64(statInfo.st_size)
        let ownerId = statInfo.st_uid
        let groupId = statInfo.st_gid
        let ownerName = getpwuid(ownerId).map { String(cString: $0.pointee.pw_name) } ?? "\(ownerId)"
        let groupName = getgrgid(groupId).map { String(cString: $0.pointee.gr_name) } ?? "\(groupId)"

        let modDate = Date(timeIntervalSince1970: TimeInterval(statInfo.st_mtimespec.tv_sec))
        let birthDate = Date(timeIntervalSince1970: TimeInterval(statInfo.st_birthtimespec.tv_sec))

        let isReadable = access(cPath, R_OK) == 0
        let isWritable = access(cPath, W_OK) == 0

        return FileItem(
            path: fullPath,
            name: itemName,
            fileExtension: (itemName as NSString).pathExtension.lowercased(),
            isDirectory: isDir,
            isSymlink: isSym,
            symlinkTarget: symlinkTarget,
            size: size,
            permissions: mode,
            ownerId: ownerId,
            groupId: groupId,
            ownerName: ownerName,
            groupName: groupName,
            modificationDate: modDate,
            creationDate: birthDate,
            isHidden: itemName.hasPrefix("."),
            isReadable: isReadable,
            isWritable: isWritable
        )
    }

    /// Creates a directory recursively.
    public func createDirectory(at path: String) throws {
        try PrivilegeHelper.createDirectory(at: path)
    }

    /// Creates an empty file.
    public func createFile(at path: String, contents: Data? = nil) throws {
        let parent = (path as NSString).deletingLastPathComponent
        try createDirectory(at: parent)
        if !FileManager.default.createFile(atPath: path, contents: contents ?? Data(), attributes: nil) {
            if let _ = PrivilegeHelper.helperPath {
                try PrivilegeHelper.runHelper(action: "touch", arguments: [path])
                if let data = contents, !data.isEmpty {
                    try data.write(to: URL(fileURLWithPath: path))
                }
                return
            }
            throw NSError(domain: "FileSystemProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file at \(path)"])
        }
    }

    /// Changes POSIX permissions (chmod).
    public func setPermissions(_ mode: mode_t, at path: String) throws {
        try PrivilegeHelper.setPermissions(mode, at: path)
    }
}
