#if canImport(UIKit)
import UIKit

final class SettingsViewController: UIViewController {
    private var draft: AppSettings
    private let isoRange: ClosedRange<Float>
    private let onSave: (AppSettings) -> Void

    private let apiKeyField = UITextField()
    private let modelField = UITextField()
    private let autoAnalyzeSwitch = UISwitch()
    private let modeControl = UISegmentedControl(items: AnalysisMode.allCases.map(AppStrings.modeLabel))
    private let exposureSlider = UISlider()
    private let exposureValueLabel = UILabel()
    private let shutterSlider = UISlider()
    private let shutterValueLabel = UILabel()
    private let isoSlider = UISlider()
    private let isoValueLabel = UILabel()
    private let focusModeControl = UISegmentedControl(items: FocusModePreset.allCases.map(AppStrings.focusModeLabel))
    private let focusSlider = UISlider()
    private let focusValueLabel = UILabel()
    private let effectControl = UISegmentedControl(items: CaptureEffect.allCases.map(AppStrings.captureEffectLabel))
    private let requestHintLabel = UILabel()

    init(current: AppSettings, isoRange: ClosedRange<Float>, onSave: @escaping (AppSettings) -> Void) {
        self.draft = current
        self.isoRange = isoRange
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AppStrings.settings
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: AppStrings.cancel,
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: AppStrings.save,
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )

        configureFields()
        layoutUI()
    }

    private func configureFields() {
        apiKeyField.borderStyle = .roundedRect
        apiKeyField.placeholder = "sk-proj-..."
        apiKeyField.text = draft.apiKey
        apiKeyField.autocapitalizationType = .none
        apiKeyField.autocorrectionType = .no
        apiKeyField.isSecureTextEntry = true

        modelField.borderStyle = .roundedRect
        modelField.placeholder = "gpt-5.4"
        modelField.text = draft.model
        modelField.autocapitalizationType = .none
        modelField.autocorrectionType = .no

        autoAnalyzeSwitch.isOn = draft.autoAnalyze
        modeControl.selectedSegmentIndex = AnalysisMode.allCases.firstIndex(of: draft.analysisMode) ?? 0
        exposureSlider.minimumValue = -2
        exposureSlider.maximumValue = 2
        exposureSlider.value = Float(draft.exposureBias)
        exposureSlider.addTarget(self, action: #selector(exposureChanged), for: .valueChanged)
        exposureValueLabel.font = .preferredFont(forTextStyle: .footnote)
        exposureValueLabel.textColor = .secondaryLabel
        exposureValueLabel.text = formattedExposureValue()
        shutterSlider.minimumValue = 0
        shutterSlider.maximumValue = Float(max(AppSettings.shutterPresets.count - 1, 0))
        shutterSlider.value = Float(nearestShutterPresetIndex(for: draft.shutterDurationSeconds))
        shutterSlider.addTarget(self, action: #selector(shutterChanged), for: .valueChanged)
        shutterValueLabel.font = .preferredFont(forTextStyle: .footnote)
        shutterValueLabel.textColor = .secondaryLabel
        shutterValueLabel.text = formattedShutterValue()
        isoSlider.minimumValue = isoRange.lowerBound
        isoSlider.maximumValue = isoRange.upperBound
        isoSlider.value = draft.isoValue > 0 ? Float(draft.isoValue) : isoRange.lowerBound
        isoSlider.addTarget(self, action: #selector(isoChanged), for: .valueChanged)
        isoValueLabel.font = .preferredFont(forTextStyle: .footnote)
        isoValueLabel.textColor = .secondaryLabel
        isoValueLabel.text = formattedISOValue()
        focusModeControl.selectedSegmentIndex = FocusModePreset.allCases.firstIndex(of: draft.focusMode) ?? 0
        focusModeControl.addTarget(self, action: #selector(focusModeChanged), for: .valueChanged)
        focusSlider.minimumValue = 0
        focusSlider.maximumValue = 1
        focusSlider.value = Float(draft.manualFocusPosition)
        focusSlider.addTarget(self, action: #selector(focusChanged), for: .valueChanged)
        focusValueLabel.font = .preferredFont(forTextStyle: .footnote)
        focusValueLabel.textColor = .secondaryLabel
        focusValueLabel.text = formattedFocusValue()
        effectControl.selectedSegmentIndex = CaptureEffect.allCases.firstIndex(of: draft.captureEffect) ?? 0

        requestHintLabel.text = AppStrings.apiRequestHint
        requestHintLabel.numberOfLines = 0
        requestHintLabel.font = .preferredFont(forTextStyle: .footnote)
        requestHintLabel.textColor = .secondaryLabel
        updateFocusControls()
    }

    private func layoutUI() {
        let scrollView = UIScrollView()
        let stack = UIStackView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill

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

        stack.addArrangedSubview(makeHeaderCard())
        stack.addArrangedSubview(makeFieldCard(title: AppStrings.apiKey, field: apiKeyField))
        stack.addArrangedSubview(makeFieldCard(title: AppStrings.model, field: modelField))
        stack.addArrangedSubview(wrapInCard(requestHintLabel))
        stack.addArrangedSubview(makeSwitchCard())
        stack.addArrangedSubview(makeModeCard())
        stack.addArrangedSubview(makeCameraTuningCard())
    }

    private func makeHeaderCard() -> UIView {
        let titleLabel = UILabel()
        let bodyLabel = UILabel()
        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])

        titleLabel.text = AppStrings.settingsTitle
        titleLabel.font = .preferredFont(forTextStyle: .title2).bold()
        bodyLabel.text = AppStrings.settingsBody
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel

        stack.axis = .vertical
        stack.spacing = 10

        return wrapInCard(stack)
    }

    private func makeFieldCard(title: String, field: UITextField) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)

        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 10
        return wrapInCard(stack)
    }

    private func makeSwitchCard() -> UIView {
        let label = UILabel()
        label.text = AppStrings.autoAnalyze
        label.font = .preferredFont(forTextStyle: .headline)

        let body = UILabel()
        body.text = AppStrings.analyzingHint
        body.numberOfLines = 0
        body.textColor = .secondaryLabel

        let leftStack = UIStackView(arrangedSubviews: [label, body])
        leftStack.axis = .vertical
        leftStack.spacing = 6

        let row = UIStackView(arrangedSubviews: [leftStack, autoAnalyzeSwitch])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        return wrapInCard(row)
    }

    private func makeModeCard() -> UIView {
        let label = UILabel()
        label.text = AppStrings.mode
        label.font = .preferredFont(forTextStyle: .headline)

        let stack = UIStackView(arrangedSubviews: [label, modeControl])
        stack.axis = .vertical
        stack.spacing = 10

        return wrapInCard(stack)
    }

    private func makeCameraTuningCard() -> UIView {
        let title = UILabel()
        title.text = AppStrings.cameraTuning
        title.font = .preferredFont(forTextStyle: .headline)

        let exposureLabel = UILabel()
        exposureLabel.text = AppStrings.exposure
        exposureLabel.font = .preferredFont(forTextStyle: .subheadline)

        let effectLabel = UILabel()
        effectLabel.text = AppStrings.captureEffect
        effectLabel.font = .preferredFont(forTextStyle: .subheadline)

        let shutterLabel = UILabel()
        shutterLabel.text = AppStrings.shutter
        shutterLabel.font = .preferredFont(forTextStyle: .subheadline)

        let isoLabel = UILabel()
        isoLabel.text = AppStrings.iso
        isoLabel.font = .preferredFont(forTextStyle: .subheadline)

        let focusLabel = UILabel()
        focusLabel.text = AppStrings.focus
        focusLabel.font = .preferredFont(forTextStyle: .subheadline)

        let exposureStack = UIStackView(arrangedSubviews: [exposureLabel, exposureValueLabel, exposureSlider])
        exposureStack.axis = .vertical
        exposureStack.spacing = 8

        let shutterStack = UIStackView(arrangedSubviews: [shutterLabel, shutterValueLabel, shutterSlider])
        shutterStack.axis = .vertical
        shutterStack.spacing = 8

        let isoStack = UIStackView(arrangedSubviews: [isoLabel, isoValueLabel, isoSlider])
        isoStack.axis = .vertical
        isoStack.spacing = 8

        let focusStack = UIStackView(arrangedSubviews: [focusLabel, focusModeControl, focusValueLabel, focusSlider])
        focusStack.axis = .vertical
        focusStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [title, exposureStack, shutterStack, isoStack, focusStack, effectLabel, effectControl])
        stack.axis = .vertical
        stack.spacing = 12
        return wrapInCard(stack)
    }

    private func wrapInCard(_ content: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 18
        container.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])

        return container
    }

    @objc
    private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc
    private func exposureChanged() {
        exposureValueLabel.text = formattedExposureValue()
    }

    @objc
    private func isoChanged() {
        isoValueLabel.text = formattedISOValue()
    }

    @objc
    private func shutterChanged() {
        let index = Int(shutterSlider.value.rounded())
        shutterSlider.value = Float(index)
        shutterValueLabel.text = formattedShutterValue()
    }

    @objc
    private func focusModeChanged() {
        updateFocusControls()
    }

    @objc
    private func focusChanged() {
        focusValueLabel.text = formattedFocusValue()
    }

    @objc
    private func saveTapped() {
        draft.apiKey = apiKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        draft.model = modelField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? AppSettings.default.model
        draft.autoAnalyze = autoAnalyzeSwitch.isOn
        draft.analysisMode = AnalysisMode.allCases[safe: modeControl.selectedSegmentIndex] ?? .scene
        draft.exposureBias = Double(exposureSlider.value)
        draft.shutterDurationSeconds = currentShutterPreset(at: Int(shutterSlider.value.rounded()))
        draft.isoValue = Double(isoSlider.value.rounded())
        draft.focusMode = FocusModePreset.allCases[safe: focusModeControl.selectedSegmentIndex] ?? .auto
        draft.manualFocusPosition = Double(focusSlider.value)
        draft.captureEffect = CaptureEffect.allCases[safe: effectControl.selectedSegmentIndex] ?? .natural
        onSave(draft)
        dismiss(animated: true)
    }

    private func formattedExposureValue() -> String {
        String(format: "%+.1f", exposureSlider.value)
    }

    private func formattedShutterValue() -> String {
        let seconds = currentShutterPreset(at: Int(shutterSlider.value.rounded()))
        if seconds <= 0 {
            return AppStrings.shutterAuto
        }
        if seconds >= 1 {
            return seconds.rounded() == seconds ? String(format: "%.0fs", seconds) : String(format: "%.1fs", seconds)
        }
        let reciprocal = max(1, Int((1.0 / seconds).rounded()))
        return "1/\(reciprocal)s"
    }

    private func formattedISOValue() -> String {
        let rounded = Int(isoSlider.value.rounded())
        if rounded <= Int(isoRange.lowerBound) {
            return AppStrings.isoAuto
        }
        return "ISO \(rounded)"
    }

    private func nearestShutterPresetIndex(for value: Double) -> Int {
        AppSettings.shutterPresets.enumerated().min(by: { abs($0.element - value) < abs($1.element - value) })?.offset ?? 0
    }

    private func currentShutterPreset(at index: Int) -> Double {
        let boundedIndex = max(0, min(index, AppSettings.shutterPresets.count - 1))
        return AppSettings.shutterPresets[boundedIndex]
    }

    private func formattedFocusValue() -> String {
        String(format: "%.2f", focusSlider.value)
    }

    private func updateFocusControls() {
        let isManual = (FocusModePreset.allCases[safe: focusModeControl.selectedSegmentIndex] ?? .auto) == .manual
        focusSlider.isEnabled = isManual
        focusSlider.alpha = isManual ? 1.0 : 0.45
        focusValueLabel.text = isManual ? formattedFocusValue() : AppStrings.autofocus
    }
}

private extension UIFont {
    func bold() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
