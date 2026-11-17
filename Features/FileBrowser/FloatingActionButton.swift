// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class FloatingActionButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AmazeTheme.fabPink
        tintColor = .white
        setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)), for: .normal)

        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.35

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 56).isActive = true
        heightAnchor.constraint(equalToConstant: 56).isActive = true
    }
}
