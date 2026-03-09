#if canImport(UIKit)
import UIKit

final class ScanVaultViewController: UITableViewController, UISearchResultsUpdating {
    private enum FilterMode: Int, CaseIterable {
        case all
        case favorites
        case withAI
    }

    private var entries: [ScanVaultEntry]
    private var filterMode: FilterMode = .all
    private let onRestore: (ScanVaultEntry) -> Void
    private let onDelete: (ScanVaultEntry) -> Void
    private let onToggleFavorite: (ScanVaultEntry) -> ScanVaultEntry?

    private let filterControl = UISegmentedControl(items: [AppStrings.vaultAll, AppStrings.vaultFavorites, AppStrings.vaultWithAI])
    private let searchController = UISearchController(searchResultsController: nil)

    init(
        entries: [ScanVaultEntry],
        onRestore: @escaping (ScanVaultEntry) -> Void,
        onDelete: @escaping (ScanVaultEntry) -> Void,
        onToggleFavorite: @escaping (ScanVaultEntry) -> ScanVaultEntry?
    ) {
        self.entries = entries
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var filteredEntries: [ScanVaultEntry] {
        let base: [ScanVaultEntry]
        switch filterMode {
        case .all:
            base = entries
        case .favorites:
            base = entries.filter(\.isFavorite)
        case .withAI:
            base = entries.filter { $0.analysis != nil }
        }

        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.lowercased().contains(query) ||
            $0.payload.lowercased().contains(query) ||
            $0.type.lowercased().contains(query)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AppStrings.scanVault
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 80

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: AppStrings.cancel,
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: AppStrings.export,
            style: .plain,
            target: self,
            action: #selector(exportTapped)
        )

        filterControl.selectedSegmentIndex = FilterMode.all.rawValue
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        tableView.tableHeaderView = headerView()

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        definesPresentationContext = true

        refreshEmptyState()
    }

    private func headerView() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(filterControl)
        NSLayoutConstraint.activate([
            filterControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            filterControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            filterControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            filterControl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        return container
    }

    private func refreshEmptyState() {
        if filteredEntries.isEmpty {
            let label = UILabel()
            label.text = AppStrings.vaultEmpty
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredEntries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = filteredEntries[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        var content = cell.defaultContentConfiguration()
        content.text = entry.isFavorite ? "★ \(entry.displayTitle)" : entry.displayTitle

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        let time = formatter.localizedString(for: entry.updatedAt, relativeTo: Date())
        content.secondaryText = "\(entry.type) • \(time)\n\(entry.displaySubtitle)"
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = filteredEntries[indexPath.row]
        navigationController?.pushViewController(
            ScanVaultDetailViewController(
                entry: entry,
                onRestore: { [weak self] restored in
                    self?.dismiss(animated: true) {
                        self?.onRestore(restored)
                    }
                },
                onToggleFavorite: { [weak self] entry in
                    self?.toggleFavorite(entry)
                }
            ),
            animated: true
        )
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = filteredEntries[indexPath.row]
        let favoriteAction = UIContextualAction(style: .normal, title: entry.isFavorite ? AppStrings.unfavorite : AppStrings.favorite) { [weak self] _, _, completion in
            _ = self?.toggleFavorite(entry)
            completion(true)
        }
        favoriteAction.backgroundColor = .systemOrange

        let deleteAction = UIContextualAction(style: .destructive, title: AppStrings.delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            self.entries.removeAll { $0.id == entry.id }
            self.onDelete(entry)
            tableView.reloadData()
            self.refreshEmptyState()
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, favoriteAction])
    }

    func updateSearchResults(for searchController: UISearchController) {
        tableView.reloadData()
        refreshEmptyState()
    }

    private func toggleFavorite(_ entry: ScanVaultEntry) -> ScanVaultEntry? {
        guard let updated = onToggleFavorite(entry),
              let index = entries.firstIndex(where: { $0.id == updated.id }) else {
            return nil
        }
        entries[index] = updated
        tableView.reloadData()
        refreshEmptyState()
        return updated
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }

    @objc
    private func filterChanged() {
        filterMode = FilterMode(rawValue: filterControl.selectedSegmentIndex) ?? .all
        tableView.reloadData()
        refreshEmptyState()
    }

    @objc
    private func exportTapped() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = (try? encoder.encode(entries)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let controller = UIActivityViewController(activityItems: [payload], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(controller, animated: true)
    }
}
#endif
