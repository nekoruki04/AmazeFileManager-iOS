// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public struct SearchQuery: Sendable {
    public let text: String
    public let startingPath: String
    public let isRegex: Bool
    public let matchCase: Bool
    public let maxResults: Int

    public init(
        text: String,
        startingPath: String,
        isRegex: Bool = false,
        matchCase: Bool = false,
        maxResults: Int = 500
    ) {
        self.text = text
        self.startingPath = startingPath
        self.isRegex = isRegex
        self.matchCase = matchCase
        self.maxResults = maxResults
    }
}

public actor FileSearchEngine {
    public static let shared = FileSearchEngine()

    private var activeSearchTask: Task<[FileItem], Error>?

    private init() {}

    public func search(query: SearchQuery, onMatch: (@Sendable (FileItem) -> Void)? = nil) async throws -> [FileItem] {
        activeSearchTask?.cancel()

        let task = Task.detached(priority: .userInitiated) { () -> [FileItem] in
            var matches: [FileItem] = []
            let regex: NSRegularExpression?
            if query.isRegex {
                let options: NSRegularExpression.Options = query.matchCase ? [] : [.caseInsensitive]
                regex = try? NSRegularExpression(pattern: query.text, options: options)
            } else {
                regex = nil
            }

            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: query.startingPath),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants]
            ) else {
                return []
            }

            while let fileURL = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                if matches.count >= query.maxResults { break }

                let filename = fileURL.lastPathComponent
                var isMatch = false

                if let regex = regex {
                    let range = NSRange(location: 0, length: filename.utf16.count)
                    isMatch = regex.firstMatch(in: filename, options: [], range: range) != nil
                } else if query.matchCase {
                    isMatch = filename.contains(query.text)
                } else {
                    isMatch = filename.localizedCaseInsensitiveContains(query.text)
                }

                if isMatch {
                    if let item = FileSystemProvider.shared.statItem(at: fileURL.path, name: filename) {
                        matches.append(item)
                        onMatch?(item)
                    }
                }
            }
            return matches
        }

        activeSearchTask = task
        return try await task.value
    }

    public func cancel() {
        activeSearchTask?.cancel()
        activeSearchTask = nil
    }
}
