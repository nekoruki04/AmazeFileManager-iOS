// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public struct ConflictResolver: Sendable {
    /// Generates a non-conflicting path by appending ' (1)', ' (2)', etc.
    public static func nonConflictingPath(for destinationPath: String) -> String {
        guard FileManager.default.fileExists(atPath: destinationPath) else {
            return destinationPath
        }

        let dir = (destinationPath as NSString).deletingLastPathComponent
        let baseFilename = (destinationPath as NSString).lastPathComponent
        let ext = (baseFilename as NSString).pathExtension
        let nameWithoutExt = (baseFilename as NSString).deletingPathExtension

        var index = 1
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(nameWithoutExt) (\(index))"
            } else {
                candidateName = "\(nameWithoutExt) (\(index)).\(ext)"
            }
            let candidatePath = (dir as NSString).appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidatePath) {
                return candidatePath
            }
            index += 1
        }
    }
}
