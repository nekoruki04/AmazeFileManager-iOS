// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class FileGridCell: UICollectionViewCell {
    public static let reuseIdentifier = "FileGridCell"

    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let sizeLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = .secondaryLabel
        sizeLabel.textAlignment = .center

        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),

            sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            sizeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            sizeLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    public func configure(with item: FileItem) {
        nameLabel.text = item.name
        sizeLabel.text = item.isDirectory ? "\(item.formattedSize)" : item.formattedSize

        let itemColor = AmazeTheme.color(for: item)
        let icon = UIImage(systemName: item.systemIconName)?.withTintColor(itemColor, renderingMode: .alwaysOriginal)
        iconImageView.image = icon
    }
}
