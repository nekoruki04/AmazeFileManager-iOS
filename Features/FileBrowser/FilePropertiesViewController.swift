// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit
import CommonCrypto

public final class FilePropertiesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let item: FileItem
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var rows: [(label: String, value: String)] = []
    private var sha256Checksum: String = "Calculating..."

    public init(item: FileItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        buildProperties()
        calculateChecksumAsync()
    }

    private func setupUI() {
        title = "Properties"
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "propCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(dismissModal)
        )
    }

    @objc private func dismissModal() {
        dismiss(animated: true)
    }

    private func buildProperties() {
        let typeStr: String
        if item.isDirectory {
            typeStr = "Directory / Folder"
        } else if item.isSymlink {
            typeStr = "Symbolic Link -> \(item.symlinkTarget ?? "unknown")"
        } else {
            typeStr = item.fileExtension.isEmpty ? "Generic File" : "\(item.fileExtension.uppercased()) Document"
        }

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium

        rows = [
            ("Name", item.name),
            ("Type", typeStr),
            ("Path", item.path),
            ("Size", "\(item.formattedSize) (\(item.size) bytes)"),
            ("Permissions", "\(item.octalPermissions) (\(item.permissionsString))"),
            ("Owner", "\(item.ownerName) (UID \(item.ownerId))"),
            ("Group", "\(item.groupName) (GID \(item.groupId))"),
            ("Modified", df.string(from: item.modificationDate)),
            ("Created", df.string(from: item.creationDate)),
            ("SHA-256", sha256Checksum)
        ]
        tableView.reloadData()
    }

    private func calculateChecksumAsync() {
        guard !item.isDirectory else {
            self.sha256Checksum = "N/A (Directory)"
            self.buildProperties()
            return
        }

        Task.detached(priority: .utility) {
            guard let handle = FileHandle(forReadingAtPath: self.item.path) else { return }
            var ctx = CC_SHA256_CTX()
            CC_SHA256_Init(&ctx)

            while autoreleasepool(invoking: {
                let chunk = handle.readData(ofLength: 65536)
                if chunk.isEmpty { return false }
                chunk.withUnsafeBytes { ptr in
                    _ = CC_SHA256_Update(&ctx, ptr.baseAddress, CC_LONG(chunk.count))
                }
                return true
            }) {}
            try? handle.close()

            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256_Final(&digest, &ctx)
            let hashStr = digest.map { String(format: "%02x", $0) }.joined()

            await MainActor.run {
                self.sha256Checksum = hashStr
                self.buildProperties()
            }
        }
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "propCell")
        let r = rows[indexPath.row]
        cell.textLabel?.text = r.label
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        cell.textLabel?.textColor = AmazeTheme.primaryDark

        cell.detailTextLabel?.text = r.value
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let r = rows[indexPath.row]
        UIPasteboard.general.string = r.value
        let alert = UIAlertController(title: "Copied", message: "\(r.label) copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
