// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public protocol TabBarHeaderViewDelegate: AnyObject {
    func tabBarDidSelectTab(index: Int)
}

public final class TabBarHeaderView: UIView {
    public weak var delegate: TabBarHeaderViewDelegate?

    private let segmentedControl = UISegmentedControl(items: ["Tab 1", "Tab 2"])

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AmazeTheme.primaryDark

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = AmazeTheme.primaryBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.7), .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            segmentedControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            segmentedControl.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func tabChanged() {
        delegate?.tabBarDidSelectTab(index: segmentedControl.selectedSegmentIndex)
    }

    public func setTabTitle(_ title: String, for index: Int) {
        guard index < segmentedControl.numberOfSegments else { return }
        segmentedControl.setTitle(title, forSegmentAt: index)
    }
}
