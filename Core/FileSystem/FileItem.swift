// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import UIKit

public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let name: String
    public let fileExtension: String
    public let isDirectory: Bool
    public let isSymlink: Bool
    public let symlinkTarget: String?
    public let size: Int64
    public let permissions: mode_t
    public let ownerId: uid_t
    public let groupId: gid_t
    public let ownerName: String
    public let groupName: String
    public let modificationDate: Date
    public let creationDate: Date
    public let isHidden: Bool
    public let isReadable: Bool
    public let isWritable: Bool

    public init(
        path: String,
        name: String,
        fileExtension: String = "",
        isDirectory: Bool = false,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil,
        size: Int64 = 0,
        permissions: mode_t = 0o644,
        ownerId: uid_t = 0,
        groupId: gid_t = 0,
        ownerName: String = "root",
        groupName: String = "wheel",
        modificationDate: Date = Date(),
        creationDate: Date = Date(),
        isHidden: Bool = false,
        isReadable: Bool = true,
        isWritable: Bool = true
    ) {
        self.id = path
        self.path = path
        self.name = name
        self.fileExtension = fileExtension.isEmpty ? (path as NSString).pathExtension.lowercased() : fileExtension
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.size = size
        self.permissions = permissions
        self.ownerId = ownerId
        self.groupId = groupId
        self.ownerName = ownerName
        self.groupName = groupName
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.isHidden = isHidden
        self.isReadable = isReadable
        self.isWritable = isWritable
    }

    public var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var permissionsString: String {
        var str = ""
        str += isDirectory ? "d" : (isSymlink ? "l" : "-")
        str += (permissions & S_IRUSR) != 0 ? "r" : "-"
        str += (permissions & S_IWUSR) != 0 ? "w" : "-"
        str += (permissions & S_IXUSR) != 0 ? "x" : "-"
        str += (permissions & S_IRGRP) != 0 ? "r" : "-"
        str += (permissions & S_IWGRP) != 0 ? "w" : "-"
        str += (permissions & S_IXGRP) != 0 ? "x" : "-"
        str += (permissions & S_IROTH) != 0 ? "r" : "-"
        str += (permissions & S_IWOTH) != 0 ? "w" : "-"
        str += (permissions & S_IXOTH) != 0 ? "x" : "-"
        return str
    }

    public var octalPermissions: String {
        String(format: "%04o", permissions & 0o7777)
    }

    public var systemIconName: String {
        if isDirectory {
            if isSymlink { return "folder.badge.gearshape" }
            return "folder.fill"
        }
        if isSymlink { return "arrow.uturn.forward.circle.fill" }

        switch fileExtension {
        case "deb": return "shippingbox.fill"
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "xz": return "doc.zipper"
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "bmp", "svg": return "photo.fill"
        case "mp4", "mov", "m4v", "mkv", "avi": return "film.fill"
        case "mp3", "m4a", "flac", "wav", "aac", "ogg": return "music.note"
        case "pdf": return "doc.richtext.fill"
        case "txt", "log", "md", "markdown": return "doc.text.fill"
        case "json", "xml", "plist", "yml", "yaml", "conf", "cfg", "ini": return "gearshape.fill"
        case "sqlite", "sqlite3", "db": return "cylinder.split.1x2.fill"
        case "swift", "c", "cpp", "h", "hpp", "m", "mm", "rs", "py", "sh", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "dylib", "so", "framework": return "puzzlepiece.fill"
        case "app": return "app.fill"
        default: return "doc.fill"
        }
    }
}
