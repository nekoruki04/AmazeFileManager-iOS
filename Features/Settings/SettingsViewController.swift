// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Settings & About"
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "PREFERENCES"
        case 1: return "JAILBREAK & ROOTLESS"
        case 2: return "ABOUT AMAZE"
        default: return nil
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return 2
        case 2: return 3
        default: return 0
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "settingsCell")

        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Show Hidden Files"
                let sw = UISwitch()
                sw.isOn = UserDefaults.standard.bool(forKey: "AmazeShowHidden")
                sw.addAction(UIAction { action in
                    UserDefaults.standard.set(sw.isOn, forKey: "AmazeShowHidden")
                }, for: .valueChanged)
                cell.accessoryView = sw
            } else {
                cell.textLabel?.text = "Default Startup Directory"
                cell.detailTextLabel?.text = "/var/mobile"
                cell.accessoryType = .disclosureIndicator
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Detected Jailbreak"
                cell.detailTextLabel?.text = JailbreakEnvironment.currentFlavor.description
            } else {
                cell.textLabel?.text = "Rootless Prefix"
                cell.detailTextLabel?.text = RootlessPaths.resolvedJailbreakPath ?? "/var/jb (inactive)"
            }
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Amaze File Manager for iOS"
                cell.detailTextLabel?.text = "v1.0.0 (Rootless)"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Port Author"
                cell.detailTextLabel?.text = "nekoruki (@nekoruki04)"
            } else {
                cell.textLabel?.text = "License"
                cell.detailTextLabel?.text = "GNU GPL v3.0+"
                cell.accessoryType = .disclosureIndicator
            }
        }

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 2 && indexPath.row == 2 {
            let licenseVC = TextEditorViewController(filePath: "/var/jb/Applications/Amaze.app/LICENSE")
            licenseVC.title = "GPLv3 License"
            navigationController?.pushViewController(licenseVC, animated: true)
        }
    }
}
