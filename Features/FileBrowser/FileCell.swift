// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class FileCell: UICollectionViewListCell {
    public static let reuseIdentifier = "FileCell"

    public func configure(with item: FileItem) {
        var content = defaultContentConfiguration()
        content.text = item.name
        content.textProperties.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        content.textProperties.numberOfLines = 1

        let dateStr = DateFormatter.localizedString(from: item.modificationDate, dateStyle: .short, timeStyle: .short)
        content.secondaryText = "\(item.formattedSize) • \(dateStr) • \(item.octalPermissions)"
        content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        content.secondaryTextProperties.color = .secondaryLabel

        let itemColor = AmazeTheme.color(for: item)
        var icon = UIImage(systemName: item.systemIconName)
        icon = icon?.withTintColor(itemColor, renderingMode: .alwaysOriginal)

        content.image = icon
        content.imageProperties.maximumSize = CGSize(width: 36, height: 36)
        content.imageProperties.reservedLayoutSize = CGSize(width: 40, height: 40)

        self.contentConfiguration = content

        if item.isDirectory {
            accessories = [.disclosureIndicator()]
        } else {
            accessories = []
        }
    }
}
