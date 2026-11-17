// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import UIKit
import QuickLook

public final class BrowserViewController: UIViewController, UICollectionViewDelegate, BreadcrumbBarDelegate, UISearchResultsUpdating, QLPreviewControllerDataSource, SideDrawerDelegate, TabBarHeaderViewDelegate {
    private var currentPath: String
    private var historyStack: [String] = []
    private var items: [FileItem] = []
    private var filteredItems: [FileItem] = []
    private var showHiddenFiles: Bool = true
    private var isGridView: Bool = false
    private var clipboardPaths: [String] = []
    private var isCutOperation: Bool = false

    // Selection & Batch Mode
    private var isSelectionMode: Bool = false
    private var selectedItems: Set<FileItem> = []

    // Multi-tab state (Tab 1 and Tab 2)
    private var activeTabIndex: Int = 0
    private var tabPaths: [String] = [
        RootlessPaths.mobileRoot,
        RootlessPaths.resolvedJailbreakPath ?? RootlessPaths.media
    ]

    // UI Components
    private let tabBarHeader = TabBarHeaderView()
    private let breadcrumbBar = BreadcrumbBar()
    private var collectionView: UICollectionView!
    private var listLayout: UICollectionViewLayout!
    private var gridLayout: UICollectionViewLayout!
    private var dataSource: UICollectionViewDiffableDataSource<Int, FileItem>!
    private let searchController = UISearchController(searchResultsController: nil)
    private let fabButton = FloatingActionButton()

    // QuickLook state
    private var previewURL: URL?

    public init(initialPath: String = RootlessPaths.mobileRoot) {
        let validPath = FileManager.default.fileExists(atPath: initialPath) ? initialPath : RootlessPaths.root
        self.currentPath = validPath
        let tab2Default = RootlessPaths.resolvedJailbreakPath ?? (FileManager.default.fileExists(atPath: RootlessPaths.media) ? RootlessPaths.media : RootlessPaths.documents)
        self.tabPaths = [validPath, tab2Default]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupThemeAndNavigation()
        setupLayouts()
        setupCollectionView()
        configureDataSource()
        let tab1Title = (tabPaths[0] as NSString).lastPathComponent
        let tab2Title = (tabPaths[1] as NSString).lastPathComponent
        tabBarHeader.setTabTitle(tab1Title.isEmpty ? "Root" : tab1Title, for: 0)
        tabBarHeader.setTabTitle(tab2Title.isEmpty ? "Root" : tab2Title, for: 1)

        setupFAB()
        loadDirectory(path: currentPath)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateNotification(_:)),
            name: NSNotification.Name("AmazeNavigateToPath"),
            object: nil
        )
    }

    @objc private func handleNavigateNotification(_ notification: Notification) {
        if let targetPath = notification.object as? String {
            navigateTo(path: targetPath)
        }
    }

    private func setupThemeAndNavigation() {
        title = "Amaze"
        view.backgroundColor = .systemBackground

        // Configure Amaze Material Blue Navigation Bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AmazeTheme.primaryBlue
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 18, weight: .bold)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 28, weight: .bold)]

        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.compactAppearance = navAppearance
        navigationController?.navigationBar.tintColor = .white

        // Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search files..."
        searchController.searchBar.tintColor = .white
        searchController.searchBar.searchTextField.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        searchController.searchBar.searchTextField.textColor = .white
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Left Bar Button Item: Hamburger Drawer
        let drawerBtn = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(openSideDrawer)
        )
        navigationItem.leftBarButtonItem = drawerBtn

        // Setup TabBar & Breadcrumb
        tabBarHeader.translatesAutoresizingMaskIntoConstraints = false
        tabBarHeader.delegate = self
        view.addSubview(tabBarHeader)

        breadcrumbBar.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbBar.delegate = self
        view.addSubview(breadcrumbBar)

        NSLayoutConstraint.activate([
            tabBarHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBarHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarHeader.heightAnchor.constraint(equalToConstant: 36),

            breadcrumbBar.topAnchor.constraint(equalTo: tabBarHeader.bottomAnchor),
            breadcrumbBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            breadcrumbBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            breadcrumbBar.heightAnchor.constraint(equalToConstant: 40)
        ])

        setupRightNavigationItems()
    }

    private func setupRightNavigationItems() {
        if isSelectionMode {
            title = selectedItems.isEmpty ? "Select Items" : "\(selectedItems.count) Selected"

            let closeBtn = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(exitSelectionMode))
            navigationItem.leftBarButtonItem = closeBtn

            let selectAllBtn = UIBarButtonItem(image: UIImage(systemName: "checklist"), style: .plain, target: self, action: #selector(selectAllItems))
            let batchCopyBtn = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(batchCopy))
            let batchCutBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.right.doc.on.clipboard"), style: .plain, target: self, action: #selector(batchCut))
            let batchDeleteBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(batchDelete))
            let batchShareBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(batchShare))

            navigationItem.rightBarButtonItems = [batchDeleteBtn, batchShareBtn, batchCutBtn, batchCopyBtn, selectAllBtn]
            return
        }

        title = "Amaze"
        let drawerBtn = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), style: .plain, target: self, action: #selector(openSideDrawer))
        navigationItem.leftBarButtonItem = drawerBtn

        let gridListImage = UIImage(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
        let toggleLayoutBtn = UIBarButtonItem(image: gridListImage, style: .plain, target: self, action: #selector(toggleLayout))
        let selectBtn = UIBarButtonItem(image: UIImage(systemName: "checkmark.circle"), style: .plain, target: self, action: #selector(enterSelectionMode))
        let pasteBtn = UIBarButtonItem(image: UIImage(systemName: "doc.on.clipboard"), style: .plain, target: self, action: #selector(pasteClipboard))

        let moreMenu = UIMenu(title: "Amaze Actions", children: [
            UIAction(title: "New Folder", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
                self?.promptCreateItem(isDirectory: true)
            },
            UIAction(title: "New File", image: UIImage(systemName: "doc.badge.plus")) { [weak self] _ in
                self?.promptCreateItem(isDirectory: false)
            },
            UIAction(title: "Jump to Path", image: UIImage(systemName: "arrow.right.circle")) { [weak self] _ in
                self?.promptJumpToPath()
            },
            UIAction(title: "Sort Items", image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
                self?.promptSort()
            },
            UIAction(title: "Toggle Hidden Files", image: UIImage(systemName: "eye")) { [weak self] _ in
                self?.toggleHidden()
            },
            UIAction(title: "Network Storage", image: UIImage(systemName: "server.rack")) { [weak self] _ in
                self?.navigationController?.pushViewController(NetworkStorageViewController(), animated: true)
            },
            UIAction(title: "App Manager", image: UIImage(systemName: "app.badge.checkmark")) { [weak self] _ in
                self?.navigationController?.pushViewController(AppManagerViewController(), animated: true)
            },
            UIAction(title: "Settings & About", image: UIImage(systemName: "gearshape.fill")) { [weak self] _ in
                self?.navigationController?.pushViewController(SettingsViewController(), animated: true)
            },
            UIAction(title: "Storage & System Info", image: UIImage(systemName: "chart.pie.fill")) { [weak self] _ in
                self?.showStorageInfo()
            },
            UIAction(title: "Refresh", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
                self?.refresh()
            }
        ])

        let moreBtn = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: moreMenu)
        navigationItem.rightBarButtonItems = [moreBtn, selectBtn, toggleLayoutBtn, pasteBtn]
    }

    @objc private func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
        setupRightNavigationItems()
    }

    @objc private func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
        setupRightNavigationItems()
    }

    @objc private func selectAllItems() {
        if selectedItems.count == items.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(items)
        }
        setupRightNavigationItems()
    }

    @objc private func batchCopy() {
        guard !selectedItems.isEmpty else { return }
        clipboardPaths = selectedItems.map { $0.path }
        isCutOperation = false
        exitSelectionMode()
        let alert = UIAlertController(title: "Copied to Clipboard", message: "\(clipboardPaths.count) items ready to paste.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func batchCut() {
        guard !selectedItems.isEmpty else { return }
        clipboardPaths = selectedItems.map { $0.path }
        isCutOperation = true
        exitSelectionMode()
        let alert = UIAlertController(title: "Cut to Clipboard", message: "\(clipboardPaths.count) items ready to move.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func batchDelete() {
        guard !selectedItems.isEmpty else { return }
        promptDelete(items: Array(selectedItems))
        exitSelectionMode()
    }

    @objc private func batchShare() {
        guard !selectedItems.isEmpty else { return }
        let urls = selectedItems.map { URL(fileURLWithPath: $0.path) }
        let avc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        present(avc, animated: true)
        exitSelectionMode()
    }

    private func setupLayouts() {
        // 1. List Layout
        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfig.showsSeparators = true
        listConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            self?.trailingSwipeActions(for: indexPath)
        }
        listLayout = UICollectionViewCompositionalLayout.list(using: listConfig)

        // 2. Grid Layout (2 columns on iPhone, 4 on iPad)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let columns = isPad ? 4 : 2
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columns)), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(110))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: Array(repeating: item, count: columns))

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        gridLayout = UICollectionViewCompositionalLayout(section: section)
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: listLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: breadcrumbBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupFAB() {
        fabButton.addTarget(self, action: #selector(fabTapped), for: .touchUpInside)
        view.addSubview(fabButton)

        NSLayoutConstraint.activate([
            fabButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            fabButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func configureDataSource() {
        let listRegistration = UICollectionView.CellRegistration<FileCell, FileItem> { cell, _, item in
            cell.configure(with: item)
        }

        let gridRegistration = UICollectionView.CellRegistration<FileGridCell, FileItem> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, FileItem>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            if self?.isGridView == true {
                return collectionView.dequeueConfiguredReusableCell(using: gridRegistration, for: indexPath, item: item)
            } else {
                return collectionView.dequeueConfiguredReusableCell(using: listRegistration, for: indexPath, item: item)
            }
        }
    }

    @objc private func openSideDrawer() {
        let drawer = SideDrawerViewController()
        drawer.delegate = self
        let nav = UINavigationController(rootViewController: drawer)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func toggleLayout() {
        isGridView.toggle()
        setupRightNavigationItems()
        collectionView.setCollectionViewLayout(isGridView ? gridLayout : listLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.applySnapshot(items: self.items)
        }
    }

    @objc private func fabTapped() {
        let sheet = UIAlertController(title: "Quick Action", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Folder", style: .default, handler: { [weak self] _ in
            self?.promptCreateItem(isDirectory: true)
        }))
        sheet.addAction(UIAlertAction(title: "New File", style: .default, handler: { [weak self] _ in
            self?.promptCreateItem(isDirectory: false)
        }))
        sheet.addAction(UIAlertAction(title: "Jump to Path", style: .default, handler: { [weak self] _ in
            self?.promptJumpToPath()
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = fabButton
            popover.sourceRect = fabButton.bounds
        }
        present(sheet, animated: true)
    }

    public func loadDirectory(path: String) {
        let cleanPath = (path as NSString).standardizingPath

        // Verify directory existence
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir)

        if !exists || !isDir.boolValue {
            let isJb = cleanPath == "/var/jb" || cleanPath.contains("jb")
            let title = isJb ? "Jailbreak Root Not Found" : "Directory Unavailable"
            let msg = isJb
                ? "The directory '/var/jb' does not exist or is inactive on this device. If using Dopamine or RootHide, please verify the jailbreak is currently active."
                : "The requested directory '\(cleanPath)' does not exist."

            let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            if let jbResolved = RootlessPaths.resolvedJailbreakPath, jbResolved != cleanPath {
                alert.addAction(UIAlertAction(title: "Open Detected JB (\((jbResolved as NSString).lastPathComponent))", style: .default, handler: { [weak self] _ in
                    self?.navigateTo(path: jbResolved)
                }))
            }
            alert.addAction(UIAlertAction(title: "Go to Mobile Home", style: .default, handler: { [weak self] _ in
                self?.navigateTo(path: RootlessPaths.mobileRoot)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }

        self.currentPath = cleanPath
        tabPaths[activeTabIndex] = self.currentPath
        let folderName = (self.currentPath as NSString).lastPathComponent
        tabBarHeader.setTabTitle(folderName.isEmpty ? "Root" : folderName, for: activeTabIndex)
        breadcrumbBar.configure(with: currentPath)

        Task {
            do {
                let fetched = try await FileSystemProvider.shared.contentsOfDirectory(at: currentPath, showHidden: showHiddenFiles)
                await MainActor.run {
                    self.items = fetched
                    self.applySnapshot(items: fetched)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "Access Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func applySnapshot(items: [FileItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, FileItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(items, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func navigateTo(path: String) {
        historyStack.append(currentPath)
        loadDirectory(path: path)
    }

    public func refresh() {
        loadDirectory(path: currentPath)
    }

    private func toggleHidden() {
        showHiddenFiles.toggle()
        loadDirectory(path: currentPath)
    }

    // MARK: - TabBarHeaderViewDelegate
    public func tabBarDidSelectTab(index: Int) {
        activeTabIndex = index
        let target = tabPaths[index]
        loadDirectory(path: target)
    }

    // MARK: - SideDrawerDelegate
    public func sideDrawerDidSelectPath(_ path: String) {
        navigateTo(path: path)
    }

    public func sideDrawerDidSelectTool(_ tool: SideDrawerTool) {
        switch tool {
        case .appManager:
            navigationController?.pushViewController(AppManagerViewController(), animated: true)
        case .networkStorage:
            navigationController?.pushViewController(NetworkStorageViewController(), animated: true)
        case .bookmarks:
            showBookmarks()
        case .storageAnalysis:
            showStorageInfo()
        case .settings:
            navigationController?.pushViewController(SettingsViewController(), animated: true)
        }
    }

    // MARK: - BreadcrumbBarDelegate
    public func breadcrumbBarDidSelectPath(_ path: String) {
        navigateTo(path: path)
    }

    // MARK: - UISearchResultsUpdating
    public func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text, !text.isEmpty else {
            applySnapshot(items: items)
            return
        }
        filteredItems = items.filter { $0.name.localizedCaseInsensitiveContains(text) }
        applySnapshot(items: filteredItems)
    }

    // MARK: - UICollectionViewDelegate
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        if isSelectionMode {
            if selectedItems.contains(item) {
                selectedItems.remove(item)
            } else {
                selectedItems.insert(item)
            }
            title = "\(selectedItems.count) Selected"
            return
        }

        if item.isDirectory {
            navigateTo(path: item.path)
        } else {
            openFile(item: item)
        }
    }

    private func openFile(item: FileItem) {
        let ext = item.fileExtension

        // Text files
        if ["txt", "log", "md", "json", "xml", "plist", "yml", "yaml", "sh", "swift", "c", "h", "rs", "py", "conf"].contains(ext) {
            let vc = TextEditorViewController(filePath: item.path)
            navigationController?.pushViewController(vc, animated: true)
            return
        }

        // SQLite databases
        if ["sqlite", "sqlite3", "db"].contains(ext) {
            let vc = DatabaseViewerViewController(dbPath: item.path)
            navigationController?.pushViewController(vc, animated: true)
            return
        }

        // Archives
        if ["tar", "gz", "tgz", "bz2", "xz", "zip", "7z"].contains(ext) {
            promptExtractArchive(item: item)
            return
        }

        // QuickLook preview fallback
        previewURL = URL(fileURLWithPath: item.path)
        let ql = QLPreviewController()
        ql.dataSource = self
        present(ql, animated: true)
    }

    // MARK: - Context & Swipe Actions
    public func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                self?.clipboardPaths = [item.path]
                self?.isCutOperation = false
            }
            let cutAction = UIAction(title: "Cut (Move)", image: UIImage(systemName: "arrow.right.doc.on.clipboard")) { _ in
                self?.clipboardPaths = [item.path]
                self?.isCutOperation = true
            }
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self?.promptRename(item: item)
            }
            let chmodAction = UIAction(title: "Permissions", image: UIImage(systemName: "lock.shield")) { _ in
                self?.promptChmod(item: item)
            }
            let compressAction = UIAction(title: "Compress (Archive)", image: UIImage(systemName: "archivebox")) { _ in
                self?.promptCompress(item: item)
            }
            let encryptAction = UIAction(title: "Encrypt (AES)", image: UIImage(systemName: "lock.fill")) { _ in
                self?.promptEncrypt(item: item)
            }
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let avc = UIActivityViewController(activityItems: [URL(fileURLWithPath: item.path)], applicationActivities: nil)
                self?.present(avc, animated: true)
            }
            let propsAction = UIAction(title: "Properties", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                let propVC = FilePropertiesViewController(item: item)
                let nav = UINavigationController(rootViewController: propVC)
                self?.present(nav, animated: true)
            }
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.promptDelete(items: [item])
            }

            return UIMenu(title: item.name, children: [
                copyAction, cutAction, renameAction, chmodAction, compressAction, encryptAction, shareAction, propsAction, deleteAction
            ])
        }
    }

    private func trailingSwipeActions(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.promptDelete(items: [item])
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    // MARK: - Prompts & Operations
    private func promptCreateItem(isDirectory: Bool) {
        let typeName = isDirectory ? "Folder" : "File"
        let alert = UIAlertController(title: "New \(typeName)", message: "Enter name for new \(typeName.lowercased()):", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = isDirectory ? "New Folder" : "NewFile.txt" }
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let target = (self.currentPath as NSString).appendingPathComponent(name)
            do {
                if isDirectory {
                    try FileSystemProvider.shared.createDirectory(at: target)
                } else {
                    try FileSystemProvider.shared.createFile(at: target)
                }
                self.refresh()
            } catch {
                self.showError(error)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptRename(item: FileItem) {
        let alert = UIAlertController(title: "Rename", message: "Enter new name:", preferredStyle: .alert)
        alert.addTextField { $0.text = item.name }
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
            guard let self = self, let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            Task {
                do {
                    try await FileOperationsQueue.shared.renameItem(at: item.path, to: newName)
                    await MainActor.run { self.refresh() }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptDelete(items: [FileItem]) {
        let count = items.count
        let msg = count == 1 ? "Are you sure you want to delete '\(items[0].name)'?" : "Delete \(count) items?"
        let alert = UIAlertController(title: "Confirm Deletion", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            let paths = items.map { $0.path }
            Task {
                do {
                    _ = try await FileOperationsQueue.shared.delete(paths: paths)
                    await MainActor.run { self.refresh() }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptChmod(item: FileItem) {
        let alert = UIAlertController(title: "Change Permissions", message: "Enter octal permissions (e.g. 0755, 0644):", preferredStyle: .alert)
        alert.addTextField { $0.text = item.octalPermissions }
        alert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { [weak self] _ in
            guard let text = alert.textFields?.first?.text, let octal = UInt16(text, radix: 8) else { return }
            do {
                try FileSystemProvider.shared.setPermissions(mode_t(octal), at: item.path)
                self?.refresh()
            } catch {
                self?.showError(error)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptCompress(item: FileItem) {
        let alert = UIAlertController(title: "Compress '\(item.name)'", message: "Select target archive format:", preferredStyle: .actionSheet)
        for fmt in ArchiveFormat.allCases {
            alert.addAction(UIAlertAction(title: fmt.rawValue.uppercased(), style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let dest = "\(item.path).\(fmt.fileExtension)"
                Task {
                    do {
                        try ArchiveManager.createArchive(sources: [item.path], destinationPath: dest, format: fmt)
                        await MainActor.run { self.refresh() }
                    } catch {
                        await MainActor.run { self.showError(error) }
                    }
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptEncrypt(item: FileItem) {
        let isDecrypt = item.fileExtension == "enc"
        let actionTitle = isDecrypt ? "Decrypt" : "Encrypt"
        let alert = UIAlertController(title: "\(actionTitle) File", message: "Enter AES password:", preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Password"
            $0.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            guard let self = self, let pwd = alert.textFields?.first?.text, !pwd.isEmpty else { return }
            let outPath = isDecrypt ? (item.path as NSString).deletingPathExtension : "\(item.path).enc"
            Task {
                do {
                    if isDecrypt {
                        try CryptEngine.decryptFile(at: item.path, to: outPath, password: pwd)
                    } else {
                        try CryptEngine.encryptFile(at: item.path, to: outPath, password: pwd)
                    }
                    await MainActor.run { self.refresh() }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptExtractArchive(item: FileItem) {
        let alert = UIAlertController(title: "Extract Archive", message: "Extract archive into current folder?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Extract", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try ArchiveManager.extractArchive(at: item.path, to: self.currentPath)
                    await MainActor.run { self.refresh() }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptSort() {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.items.sort { $0.isDirectory == $1.isDirectory ? ($0.name.localizedStandardCompare($1.name) == .orderedAscending) : $0.isDirectory }
            self.applySnapshot(items: self.items)
        }))
        alert.addAction(UIAlertAction(title: "Size (Largest First)", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.items.sort { $0.isDirectory == $1.isDirectory ? ($0.size > $1.size) : $0.isDirectory }
            self.applySnapshot(items: self.items)
        }))
        alert.addAction(UIAlertAction(title: "Date Modified (Newest First)", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.items.sort { $0.isDirectory == $1.isDirectory ? ($0.modificationDate > $1.modificationDate) : $0.isDirectory }
            self.applySnapshot(items: self.items)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func pasteClipboard() {
        guard !clipboardPaths.isEmpty else {
            let alert = UIAlertController(title: "Clipboard Empty", message: "Copy or Cut an item first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let paths = clipboardPaths
        let isCut = isCutOperation
        Task {
            do {
                if isCut {
                    _ = try await FileOperationsQueue.shared.move(sources: paths, destinationDirectory: self.currentPath)
                    self.clipboardPaths.removeAll()
                } else {
                    _ = try await FileOperationsQueue.shared.copy(sources: paths, destinationDirectory: self.currentPath)
                }
                await MainActor.run { self.refresh() }
            } catch {
                await MainActor.run { self.showError(error) }
            }
        }
    }

    private func promptJumpToPath() {
        let alert = UIAlertController(title: "Jump to Path", message: "Enter absolute directory path:", preferredStyle: .alert)
        alert.addTextField { $0.text = self.currentPath }
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler: { [weak self] _ in
            guard let target = alert.textFields?.first?.text, !target.isEmpty else { return }
            if FileManager.default.fileExists(atPath: target) {
                self?.navigateTo(path: target)
            } else {
                self?.showError(NSError(domain: "Amaze", code: 404, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist: \(target)"]))
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showBookmarks() {
        let bookmarks = BookmarkStore.shared.bookmarks
        let sheet = UIAlertController(title: "Bookmarks", message: nil, preferredStyle: .actionSheet)
        for b in bookmarks {
            sheet.addAction(UIAlertAction(title: b.name, style: .default, handler: { [weak self] _ in
                self?.navigateTo(path: b.path)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Bookmark Current Folder", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let name = (self.currentPath as NSString).lastPathComponent
            BookmarkStore.shared.add(name: name.isEmpty ? "Root" : name, path: self.currentPath)
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func showStorageInfo() {
        guard let info = RootlessPaths.volumeInfo(for: currentPath) else { return }
        let total = ByteCountFormatter.string(fromByteCount: info.totalBytes, countStyle: .file)
        let free = ByteCountFormatter.string(fromByteCount: info.freeBytes, countStyle: .file)
        let used = ByteCountFormatter.string(fromByteCount: info.usedBytes, countStyle: .file)
        let creds = JailbreakEnvironment.credentials
        let msg = """
        Environment: \(JailbreakEnvironment.currentFlavor)
        Process: \(creds.summary)

        Storage Path: \(info.path)
        Total Space: \(total)
        Used Space: \(used)
        Free Space: \(free) (\(String(format: "%.1f", info.freePercentage))%)
        """
        let alert = UIAlertController(title: "Storage & System Info", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - QLPreviewControllerDataSource
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewURL != nil ? 1 : 0
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURL! as NSURL
    }
}
