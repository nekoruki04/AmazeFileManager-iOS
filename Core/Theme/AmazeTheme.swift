// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public struct AmazeTheme: Sendable {
    // Official Amaze Material Design Palette
    public static let primaryBlue = UIColor(red: 33/255, green: 150/255, blue: 243/255, alpha: 1.0) // #2196F3
    public static let primaryDark = UIColor(red: 25/255, green: 118/255, blue: 210/255, alpha: 1.0) // #1976D2
    public static let fabPink = UIColor(red: 255/255, green: 64/255, blue: 129/255, alpha: 1.0)     // #FF4081
    public static let folderAmber = UIColor(red: 255/255, green: 160/255, blue: 0/255, alpha: 1.0)  // #FFA000
    public static let archivePurple = UIColor(red: 156/255, green: 39/255, blue: 176/255, alpha: 1.0) // #9C27B0
    public static let imageGreen = UIColor(red: 76/255, green: 175/255, blue: 80/255, alpha: 1.0)   // #4CAF50
    public static let audioOrange = UIColor(red: 255/255, green: 152/255, blue: 0/255, alpha: 1.0)  // #FF9800
    public static let videoRed = UIColor(red: 244/255, green: 67/255, blue: 54/255, alpha: 1.0)     // #F44336
    public static let codeCyan = UIColor(red: 3/255, green: 169/255, blue: 244/255, alpha: 1.0)     // #03A9F4
    public static let databaseTeal = UIColor(red: 0/255, green: 150/255, blue: 136/255, alpha: 1.0) // #009688

    public static func color(for item: FileItem) -> UIColor {
        if item.isDirectory {
            return folderAmber
        }
        let ext = item.fileExtension
        switch ext {
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "deb":
            return archivePurple
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return imageGreen
        case "mp3", "m4a", "wav", "flac", "aac", "ogg":
            return audioOrange
        case "mp4", "mov", "mkv", "avi", "webm":
            return videoRed
        case "sqlite", "sqlite3", "db":
            return databaseTeal
        case "swift", "c", "cpp", "h", "rs", "py", "sh", "json", "xml", "plist", "yml", "yaml":
            return codeCyan
        default:
            return .secondaryLabel
        }
    }
}
