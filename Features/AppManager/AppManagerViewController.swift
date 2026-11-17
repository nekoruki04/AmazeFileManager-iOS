// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public struct InstalledAppInfo: Identifiable, Sendable {
    public var id: String { bundlePath }
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let bundlePath: String
    public let executableName: String
    public let iconPath: String?
    public let bundleSizeBytes: Int64
}

public final class AppManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var apps: [InstalledAppInfo] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        scanInstalledApplications()
    }

    private func setupUI() {
        title = "Installed Applications"
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "appCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(scanInstalledApplications)
        )
    }

    @objc private func scanInstalledApplications() {
        apps.removeAll()
        let searchDirectories = [
            "/var/jb/Applications",
            "/Applications",
            "/var/mobile/Containers/Bundle/Application"
        ]

        let fm = FileManager.default
        for dir in searchDirectories {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                let fullItem = (dir as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    parseAppBundle(appPath: fullItem)
                } else if dir.contains("Containers/Bundle") {
                    // Inside container folder, search for .app
                    if let subItems = try? fm.contentsOfDirectory(atPath: fullItem) {
                        for sub in subItems where sub.hasSuffix(".app") {
                            parseAppBundle(appPath: (fullItem as NSString).appendingPathComponent(sub))
                        }
                    }
                }
            }
        }

        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        tableView.reloadData()
    }

    private func parseAppBundle(appPath: String) {
        let plistPath = (appPath as NSString).appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }

        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleId = (plist["CFBundleIdentifier"] as? String) ?? "unknown"
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "1.0"
        let exec = (plist["CFBundleExecutable"] as? String) ?? ""

        // Locate icon
        var iconPath: String? = nil
        let candidateIcons = [
            "AppIcon60x60@2x.png",
            "AppIcon76x76@2x~ipad.png",
            "icon.png",
            "Icon.png",
            "Icon@2x.png"
        ]
        for iconName in candidateIcons {
            let candidate = (appPath as NSString).appendingPathComponent(iconName)
            if FileManager.default.fileExists(atPath: candidate) {
                iconPath = candidate
                break
            }
        }

        // Calculate size
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(atPath: appPath) {
            while let file = enumerator.nextObject() as? String {
                let p = (appPath as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
                   let s = attrs[.size] as? Int64 {
                    size += s
                }
            }
        }

        apps.append(InstalledAppInfo(
            name: name,
            bundleIdentifier: bundleId,
            version: version,
            bundlePath: appPath,
            executableName: exec,
            iconPath: iconPath,
            bundleSizeBytes: size
        ))
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        apps.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "appCell", for: indexPath)
        let app = apps[indexPath.row]
        var content = cell.defaultContentConfiguration()

        let sizeFormatted = ByteCountFormatter.string(fromByteCount: app.bundleSizeBytes, countStyle: .file)
        content.text = "\(app.name) (\(app.version))"
        content.secondaryText = "\(app.bundleIdentifier) • \(sizeFormatted)\n\(app.bundlePath)"

        if let iconP = app.iconPath, let img = UIImage(contentsOfFile: iconP) {
            content.image = img
            content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
            content.imageProperties.cornerRadius = 8
        } else {
            content.image = UIImage(systemName: "app.fill")
        }

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let app = apps[indexPath.row]

        let sheet = UIAlertController(title: app.name, message: "Bundle ID: \(app.bundleIdentifier)\nVersion: \(app.version)", preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Browse App Bundle in Files", style: .default, handler: { [weak self] _ in
            NotificationCenter.default.post(name: NSNotification.Name("AmazeNavigateToPath"), object: app.bundlePath)
            self?.navigationController?.popViewController(animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "Inspect Info.plist", style: .default, handler: { [weak self] _ in
            let plist = (app.bundlePath as NSString).appendingPathComponent("Info.plist")
            let editor = TextEditorViewController(filePath: plist)
            self?.navigationController?.pushViewController(editor, animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "Copy Bundle Identifier", style: .default, handler: { _ in
            UIPasteboard.general.string = app.bundleIdentifier
        }))

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}
