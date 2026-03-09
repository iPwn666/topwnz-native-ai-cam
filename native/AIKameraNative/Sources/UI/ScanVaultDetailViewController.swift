#if canImport(UIKit)
import UIKit

final class ScanVaultDetailViewController: UIViewController {
    private var entry: ScanVaultEntry
    private let onRestore: (ScanVaultEntry) -> Void
    private let onToggleFavorite: (ScanVaultEntry) -> ScanVaultEntry?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let analysisLabel = UILabel()
    private let restoreButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)

    init(
        entry: ScanVaultEntry,
        onRestore: @escaping (ScanVaultEntry) -> Void,
        onToggleFavorite: @escaping (ScanVaultEntry) -> ScanVaultEntry?
    ) {
        self.entry = entry
        self.onRestore = onRestore
        self.onToggleFavorite = onToggleFavorite
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AppStrings.vaultDetail
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: AppStrings.export, style: .plain, target: self, action: #selector(exportTapped)),
            UIBarButtonItem(image: UIImage(systemName: entry.isFavorite ? "star.fill" : "star"), style: .plain, target: self, action: #selector(favoriteTapped)),
        ]

        configureViews()
        layoutUI()
        refreshUI()
    }

    private func configureViews() {
        titleLabel.font = .preferredFont(forTextStyle: .title2).bold()
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        detailsLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        detailsLabel.numberOfLines = 0

        analysisLabel.font = .preferredFont(forTextStyle: .body)
        analysisLabel.numberOfLines = 0

        configureButton(restoreButton, title: AppStrings.restore, symbol: "arrow.uturn.backward.circle.fill", action: #selector(restoreTapped), emphasized: true)
        configureButton(shareButton, title: AppStrings.shareResult, symbol: "square.and.arrow.up", action: #selector(exportTapped), emphasized: false)
    }

    private func layoutUI() {
        let scrollView = UIScrollView()
        let stack = UIStackView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        let actions = UIStackView(arrangedSubviews: [restoreButton, shareButton])
        actions.axis = .horizontal
        actions.spacing = 12
        actions.distribution = .fillEqually

        stack.addArrangedSubview(wrapInCard(titleLabel, subtitleLabel))
        stack.addArrangedSubview(wrapInCard(detailsLabel))
        stack.addArrangedSubview(wrapInCard(analysisLabel))
        stack.addArrangedSubview(actions)
    }

    private func refreshUI() {
        titleLabel.text = entry.displayTitle
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        subtitleLabel.text = "\(entry.type) • \(formatter.string(from: entry.updatedAt))"
        detailsLabel.text = entry.scannedCode.formattedDetails
        analysisLabel.text = entry.analysis?.analysis.summary ?? AppStrings.noResultBody
        navigationItem.rightBarButtonItems?.last?.image = UIImage(systemName: entry.isFavorite ? "star.fill" : "star")
    }

    private func configureButton(_ button: UIButton, title: String, symbol: String, action: Selector, emphasized: Bool) {
        var configuration = emphasized ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func wrapInCard(_ views: UIView...) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 12

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    @objc
    private func restoreTapped() {
        dismiss(animated: true) {
            self.onRestore(self.entry)
        }
    }

    @objc
    private func favoriteTapped() {
        guard let updated = onToggleFavorite(entry) else { return }
        entry = updated
        refreshUI()
    }

    @objc
    private func exportTapped() {
        let lines = [
            entry.displayTitle,
            entry.type,
            "",
            entry.scannedCode.formattedDetails,
            "",
            entry.analysis?.analysis.rawText ?? "",
        ]
        let controller = UIActivityViewController(activityItems: [lines.joined(separator: "\n")], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(controller, animated: true)
    }
}

private extension UIFont {
    func bold() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif
