// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public protocol BreadcrumbBarDelegate: AnyObject {
    func breadcrumbBarDidSelectPath(_ path: String)
}

public final class BreadcrumbBar: UIView {
    public weak var delegate: BreadcrumbBarDelegate?
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    public func configure(with currentPath: String) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Root button
        let rootBtn = createCrumbButton(title: "/", path: "/")
        stackView.addArrangedSubview(rootBtn)

        let components = currentPath.split(separator: "/").map { String($0) }
        var cumulativePath = ""

        for comp in components {
            let sep = UILabel()
            sep.text = "›"
            sep.textColor = .tertiaryLabel
            sep.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            stackView.addArrangedSubview(sep)

            cumulativePath += "/" + comp
            let btn = createCrumbButton(title: comp, path: cumulativePath)
            stackView.addArrangedSubview(btn)
        }

        layoutIfNeeded()
        let rightOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        scrollView.setContentOffset(CGPoint(x: rightOffset, y: 0), animated: true)
    }

    private func createCrumbButton(title: String, path: String) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        config.cornerStyle = .small

        let btn = UIButton(configuration: config)
        btn.addAction(UIAction { [weak self] _ in
            self?.delegate?.breadcrumbBarDidSelectPath(path)
        }, for: .touchUpInside)
        return btn
    }
}
