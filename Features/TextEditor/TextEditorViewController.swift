// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit

public final class TextEditorViewController: UIViewController {
    private let filePath: String
    private let textView = UITextView()
    private var originalContent: String = ""

    public init(filePath: String) {
        self.filePath = filePath
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFileContent()
    }

    private func setupUI() {
        title = (filePath as NSString).lastPathComponent
        view.backgroundColor = .systemBackground

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Enable native find interaction on iOS 16+
        if #available(iOS 16.0, *) {
            textView.isFindInteractionEnabled = true
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveFile)
        )
    }

    private func loadFileContent() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            self.originalContent = text
            self.textView.text = text
        } catch {
            let alert = UIAlertController(title: "Read Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func saveFile() {
        guard let data = textView.text.data(using: .utf8) else { return }
        do {
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            originalContent = textView.text
            let banner = UIAlertController(title: "Saved", message: "File saved successfully.", preferredStyle: .alert)
            banner.addAction(UIAlertAction(title: "OK", style: .default))
            present(banner, animated: true)
        } catch {
            let alert = UIAlertController(title: "Save Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
