// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation

public struct BookmarkItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let iconName: String

    public init(name: String, path: String, iconName: String = "bookmark.fill") {
        self.name = name
        self.path = path
        self.iconName = iconName
    }
}

public final class BookmarkStore: @unchecked Sendable {
    public static let shared = BookmarkStore()
    private let key = "amaze_user_bookmarks"

    public private(set) var bookmarks: [BookmarkItem] = []

    private init() {
        load()
        if bookmarks.isEmpty {
            for loc in RootlessPaths.defaultLocations {
                bookmarks.append(BookmarkItem(name: loc.name, path: loc.path, iconName: loc.icon))
            }
            save()
        }
    }

    public func add(name: String, path: String) {
        if !bookmarks.contains(where: { $0.path == path }) {
            bookmarks.append(BookmarkItem(name: name, path: path))
            save()
        }
    }

    public func remove(path: String) {
        bookmarks.removeAll { $0.path == path }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            self.bookmarks = list
        }
    }
}
