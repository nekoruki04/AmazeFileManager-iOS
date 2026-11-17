// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit
import SQLite3

public final class DatabaseViewerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let dbPath: String
    private var db: OpaquePointer?
    private var tables: [String] = []
    private var currentTable: String?
    private var tableColumns: [String] = []
    private var tableRows: [[String]] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    public init(dbPath: String) {
        self.dbPath = dbPath
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        openDatabase()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func setupUI() {
        title = (dbPath as NSString).lastPathComponent
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Tables",
            style: .plain,
            target: self,
            action: #selector(showTablePicker)
        )
    }

    private func openDatabase() {
        let rc = sqlite3_open_v2((dbPath as NSString).fileSystemRepresentation, &db, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, db != nil else {
            let alert = UIAlertController(title: "Database Error", message: "Failed to open SQLite database (code: \(rc)).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        loadTables()
    }

    private func loadTables() {
        tables.removeAll()
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 0) {
                    tables.append(String(cString: nameC))
                }
            }
        }
        sqlite3_finalize(stmt)

        if let first = tables.first {
            loadTableData(tableName: first)
        } else {
            tableView.reloadData()
        }
    }

    private func loadTableData(tableName: String) {
        currentTable = tableName
        tableColumns.removeAll()
        tableRows.removeAll()

        let query = "SELECT * FROM \"\(tableName)\" LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            let colCount = sqlite3_column_count(stmt)
            for i in 0..<colCount {
                if let colNameC = sqlite3_column_name(stmt, i) {
                    tableColumns.append(String(cString: colNameC))
                } else {
                    tableColumns.append("col_\(i)")
                }
            }

            while sqlite3_step(stmt) == SQLITE_ROW {
                var row: [String] = []
                for i in 0..<colCount {
                    if let textC = sqlite3_column_text(stmt, i) {
                        row.append(String(cString: textC))
                    } else {
                        row.append("NULL")
                    }
                }
                tableRows.append(row)
            }
        }
        sqlite3_finalize(stmt)
        tableView.reloadData()
    }

    @objc private func showTablePicker() {
        let alert = UIAlertController(title: "Select Table", message: nil, preferredStyle: .actionSheet)
        for tbl in tables {
            alert.addAction(UIAlertAction(title: tbl, style: .default, handler: { [weak self] _ in
                self?.loadTableData(tableName: tbl)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource
    public func numberOfSections(in tableView: UITableView) -> Int { 1 }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableRows.count
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let tbl = currentTable else { return "No Tables" }
        return "Table: \(tbl) (\(tableRows.count) rows shown) - Columns: \(tableColumns.joined(separator: ", "))"
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = tableRows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.joined(separator: "  |  ")
        content.textProperties.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.contentConfiguration = content
        return cell
    }
}
