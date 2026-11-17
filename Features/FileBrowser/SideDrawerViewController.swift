// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public protocol SideDrawerDelegate: AnyObject {
    func sideDrawerDidSelectPath(_ path: String)
    func sideDrawerDidSelectTool(_ tool: SideDrawerTool)
}

public enum SideDrawerTool: String, CaseIterable, Sendable {
    case appManager = "App Manager"
    case networkStorage = "Network Storage"
    case bookmarks = "Bookmarks"
    case storageAnalysis = "Storage Analysis"
    case settings = "Settings & About"

    public var systemIcon: String {
        switch self {
        case .appManager: return "app.badge.checkmark"
        case .networkStorage: return "server.rack"
        case .bookmarks: return "bookmark.fill"
        case .storageAnalysis: return "chart.pie.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public final class SideDrawerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    public weak var delegate: SideDrawerDelegate?

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var quickLocations: [(name: String, path: String, icon: String)] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "drawerCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupHeader()
    }

    private func setupHeader() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 160))
        headerView.backgroundColor = AmazeTheme.primaryBlue

        let iconView = UIImageView(image: UIImage(systemName: "folder.badge.gearshape.fill"))
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = "Amaze File Manager"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Jailbreak Rootless Edition (v1.0.0)"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)

        // Storage usage progress bar
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.progressTintColor = AmazeTheme.folderAmber
        progressView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(progressView)

        let storageLabel = UILabel()
        storageLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        storageLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        storageLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(storageLabel)

        if let info = RootlessPaths.volumeInfo(for: "/var/mobile") {
            let usedGB = Double(info.usedBytes) / (1024 * 1024 * 1024)
            let totalGB = Double(info.totalBytes) / (1024 * 1024 * 1024)
            progressView.progress = Float(Double(info.usedBytes) / Double(info.totalBytes))
            storageLabel.text = String(format: "Storage: %.1f GB / %.1f GB (%.0f%% used)", usedGB, totalGB, (100 - info.freePercentage))
        } else {
            storageLabel.text = "Storage: Active"
        }

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: headerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),

            progressView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            storageLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 6),
            storageLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16)
        ])

        tableView.tableHeaderView = headerView
    }

    private func loadData() {
        quickLocations = RootlessPaths.defaultLocations
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource
    public func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "STORAGE & DRIVES" : "TOOLS & PLUGINS"
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? quickLocations.count : SideDrawerTool.allCases.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "drawerCell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            let loc = quickLocations[indexPath.row]
            content.text = loc.name
            content.image = UIImage(systemName: loc.icon)?.withTintColor(AmazeTheme.primaryBlue, renderingMode: .alwaysOriginal)
        } else {
            let tool = SideDrawerTool.allCases[indexPath.row]
            content.text = tool.rawValue
            content.image = UIImage(systemName: tool.systemIcon)?.withTintColor(AmazeTheme.fabPink, renderingMode: .alwaysOriginal)
        }

        content.textProperties.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if indexPath.section == 0 {
                self.delegate?.sideDrawerDidSelectPath(self.quickLocations[indexPath.row].path)
            } else {
                self.delegate?.sideDrawerDidSelectTool(SideDrawerTool.allCases[indexPath.row])
            }
        }
    }
}
