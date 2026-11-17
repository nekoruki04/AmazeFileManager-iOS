// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class NetworkStorageViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var servers: [NetworkServerConfig] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let serversKey = "AmazeSavedNetworkServers"

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedServers()
    }

    private func setupUI() {
        title = "Network Storage"
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "serverCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(promptAddServer)
        )
    }

    private func loadSavedServers() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let list = try? JSONDecoder().decode([NetworkServerConfig].self, from: data) {
            servers = list
        }
        tableView.reloadData()
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
    }

    @objc private func promptAddServer() {
        let alert = UIAlertController(title: "Add Network Storage", message: "Select connection protocol:", preferredStyle: .actionSheet)

        for proto in NetworkProtocolType.allCases {
            alert.addAction(UIAlertAction(title: proto.rawValue, style: proto.isSupported ? .default : .destructive, handler: { [weak self] _ in
                if !proto.isSupported {
                    let unsupportedAlert = UIAlertController(
                        title: "Protocol Unsupported",
                        message: "SMB2/SMB3 is not supported in this release as it requires an external libsmb2 library.",
                        preferredStyle: .alert
                    )
                    unsupportedAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(unsupportedAlert, animated: true)
                } else {
                    self?.promptServerDetails(for: proto)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptServerDetails(for proto: NetworkProtocolType) {
        let alert = UIAlertController(title: "New \(proto.rawValue) Server", message: "Enter connection parameters:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Server Display Name (e.g. My FTP)" }
        alert.addTextField { $0.placeholder = "Host / IP (e.g. 192.168.1.100)" }
        alert.addTextField {
            $0.placeholder = "Port (default: \(proto == .ftp ? "21" : proto == .ftps ? "990" : "22"))"
            $0.keyboardType = .numberPad
        }
        alert.addTextField { $0.placeholder = "Username" }
        alert.addTextField {
            $0.placeholder = "Password"
            $0.isSecureTextEntry = true
        }
        alert.addTextField { $0.placeholder = "Remote Path (default: /)" }

        alert.addAction(UIAlertAction(title: "Save & Connect", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?[0].text, !name.isEmpty,
                  let host = alert.textFields?[1].text, !host.isEmpty,
                  let username = alert.textFields?[3].text, !username.isEmpty else { return }

            let portStr = alert.textFields?[2].text
            let port = Int(portStr ?? "")
            let password = alert.textFields?[4].text ?? ""
            let remotePath = alert.textFields?[5].text?.isEmpty == false ? alert.textFields![5].text! : "/"

            let config = NetworkServerConfig(
                name: name,
                protocolType: proto,
                host: host,
                port: port,
                username: username,
                remoteBasePath: remotePath
            )

            // Save credentials to Keychain securely
            KeychainHelper.shared.savePassword(password, for: config.keychainAccountKey)

            self.servers.append(config)
            self.saveServers()
            self.tableView.reloadData()

            // Verify connection
            self.testAndOpen(config: config)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func testAndOpen(config: NetworkServerConfig) {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = view.center
        view.addSubview(spinner)
        spinner.startAnimating()

        Task {
            do {
                _ = try await NetworkStorageClient.shared.testConnection(config: config)
                await MainActor.run {
                    spinner.stopAnimating()
                    spinner.removeFromSuperview()
                    let alert = UIAlertController(title: "Connected", message: "Successfully connected to \(config.name).", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            } catch {
                await MainActor.run {
                    spinner.stopAnimating()
                    spinner.removeFromSuperview()
                    let alert = UIAlertController(title: "Connection Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        servers.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "serverCell", for: indexPath)
        let s = servers[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "\(s.name) (\(s.protocolType.rawValue))"
        content.secondaryText = "\(s.username)@\(s.host):\(s.port)\(s.remoteBasePath)"
        content.image = UIImage(systemName: "server.rack")
        cell.contentConfiguration = content
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        testAndOpen(config: servers[indexPath.row])
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let s = servers[indexPath.row]
            KeychainHelper.shared.deletePassword(for: s.keychainAccountKey)
            servers.remove(at: indexPath.row)
            saveServers()
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
