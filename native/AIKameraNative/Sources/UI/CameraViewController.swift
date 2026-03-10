#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif
import Contacts
@preconcurrency import ContactsUI
import EventKit
@preconcurrency import EventKitUI
import UIKit

@MainActor
final class CameraViewController: UIViewController, UIGestureRecognizerDelegate {
    private enum TuningControl {
        case exposure
        case shutter
        case iso
        case focus
    }

    private enum ToolsSection {
        case quick
        case detect
        case pro
    }

    private let cameraService = CameraService()
    private let settingsStore = AppSettingsStore()
    private let vaultStore = ScanVaultStore()
    private let aiService = OpenAIVisionService()
    private let contactStore = CNContactStore()
    private let eventStore = EKEventStore()
#if canImport(CoreImage)
    private let ciContext = CIContext()
#endif
#if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
#endif

    private var settings = AppSettings.default
    private var latestImageData: Data?
    private var latestRenderedImage: UIImage?
    private var latestVideoURL: URL?
    private var latestScannedCode: ScannedCode?
    private var capturedRecognizedText: String?
    private var scanHistory: [ScannedCode] = []
    private var vaultEntries: [ScanVaultEntry] = []
    private var latestAnalysis: CameraAnalysis?
    private var isCapturing = false
    private var isAnalyzing = false
    private var isRecordingVideo = false
    private var isFlashEnabled = false
    private var zoomFactor: CGFloat = 1.0
    private var pinchStartZoomFactor: CGFloat = 1.0
    private var preferredFPS = 30
    private var isNightBoostEnabled = false
    private var isScannerEnabled = false
    private var isTorchEnabled = false
    private var lastScannerMetadataRect: CGRect?
    private var isToolsPanelExpanded = false
    private var activeTuningControl: TuningControl = .exposure
    private var tuningPanBaselineX: CGFloat = 0
    private var isGridVisible = true
    private var isLevelVisible = true
    private var isHistogramVisible = true
    private var isZebraVisible = false
    private var isLiveOCREnabled = false
    private var isDocumentModeEnabled = false
    private var isLiveMLEnabled = false
    private var isObjectDetectionEnabled = false
    private var isFocusExposureLocked = false
    private var isPreparingMLModel = false
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?
    private var activeToolsSection: ToolsSection = .quick

    private let previewView = PreviewView()
    private let imageView = UIImageView()
    private let topFadeView = OverlayGradientView(direction: .top)
    private let bottomFadeView = OverlayGradientView(direction: .bottom)
    private let focusIndicatorView = FocusIndicatorView()
    private let scannerFrameView = ScannerFrameView()
    private let gridOverlayView = GridOverlayView()
    private let levelView = HorizonLevelView()
    private let zebraOverlayView = ZebraOverlayView()
    private let ocrOverlayView = OCRTextOverlayView()
    private let documentOverlayView = DocumentQuadOverlayView()
    private let objectOverlayView = ObjectDetectionOverlayView()

    private let statusCard = CameraGlassCard()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()
    private let tuningHUDCard = CameraGlassCard()
    private let tuningHUDLabel = UILabel()
    private let recordingHUDCard = CameraGlassCard()
    private let recordingDotView = UIView()
    private let recordingTimeLabel = UILabel()
    private let histogramCard = CameraGlassCard()
    private let histogramView = HistogramOverlayView()
    private let lumaLabel = UILabel()

    private let modeCard = CameraGlassCard()
    private let modeControl = UISegmentedControl(items: AnalysisMode.allCases.map(AppStrings.modeLabel))

    private let toolsPanelCard = CameraGlassCard()
    private let toolsSectionStack = UIStackView()
    private let toolsScrollView = UIScrollView()
    private let toolsToggleButton = UIButton(type: .system)
    private let quickSectionButton = UIButton(type: .system)
    private let detectSectionButton = UIButton(type: .system)
    private let proSectionButton = UIButton(type: .system)
    private let rightButtonStack = UIStackView()
    private let flipButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let zoomBadgeButton = UIButton(type: .system)
    private let fpsButton = UIButton(type: .system)
    private let nightButton = UIButton(type: .system)
    private let scannerButton = UIButton(type: .system)
    private let vaultButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let exposureTuneButton = UIButton(type: .system)
    private let shutterTuneButton = UIButton(type: .system)
    private let isoTuneButton = UIButton(type: .system)
    private let focusTuneButton = UIButton(type: .system)
    private let autofocusButton = UIButton(type: .system)
    private let lockButton = UIButton(type: .system)
    private let whiteBalanceButton = UIButton(type: .system)
    private let gridButton = UIButton(type: .system)
    private let levelButton = UIButton(type: .system)
    private let histogramButton = UIButton(type: .system)
    private let zebraButton = UIButton(type: .system)
    private let ocrButton = UIButton(type: .system)
    private let documentButton = UIButton(type: .system)
    private let mlButton = UIButton(type: .system)
    private let objectButton = UIButton(type: .system)
    private let brandLinkButton = UIButton(type: .system)
    private let askAIButton = UIButton(type: .system)
    private let speakButton = UIButton(type: .system)

    private let captureButton = UIButton(type: .system)
    private let captureInnerView = UIView()
    private let analyzeButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)

    private let resultCard = CameraGlassCard()
    private let resultTitleLabel = UILabel()
    private let resultLabel = UILabel()
    private let historyLabel = UILabel()
    private let errorLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let openButton = UIButton(type: .system)

    private let permissionCard = CameraGlassCard()
    private let permissionTitleLabel = UILabel()
    private let permissionBodyLabel = UILabel()
    private let permissionButton = UIButton(type: .system)
    private let systemSettingsButton = UIButton(type: .system)

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var focusIndicatorCenterXConstraint: NSLayoutConstraint?
    private var focusIndicatorCenterYConstraint: NSLayoutConstraint?
    private var isSpeakingResult = false
    private var liveOCRBlocks: [RecognizedTextBlock] = []
    private var liveOCRDisplayBlocks: [OCRTextOverlayView.DisplayBlock] = []
    private var selectedOCRText: String?
    private var latestDocumentQuad: DetectedDocumentQuad?
    private var liveClassification: ImageClassificationSample?
    private var capturedClassification: ImageClassificationSample?
    private var liveObjectDetection: ObjectDetectionSample?
    private var capturedObjectDetection: ObjectDetectionSample?

    override func viewDidLoad() {
        super.viewDidLoad()
        settings = settingsStore.load()
        vaultEntries = vaultStore.loadEntries()
        view.backgroundColor = .black
        previewView.previewLayer.session = cameraService.session
        speechSynthesizer.delegate = self
        cameraService.onCodeScanned = { [weak self] code in
            self?.handleScannedCode(code)
        }
        cameraService.onMonitoringSample = { [weak self] sample in
            self?.handleMonitoringSample(sample)
        }
        cameraService.onRecognizedText = { [weak self] sample in
            self?.handleRecognizedTextSample(sample)
        }
        cameraService.onDetectedDocument = { [weak self] quad in
            self?.handleDetectedDocument(quad)
        }
        cameraService.onImageClassification = { [weak self] sample in
            self?.handleImageClassificationSample(sample)
        }
        cameraService.onDetectedObjects = { [weak self] sample in
            self?.handleObjectDetectionSample(sample)
        }

        configureViews()
        layoutUI()
        refreshUI()

        Task { await prepareCamera() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        cameraService.startSession()
        startMotionUpdatesIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraService.stopSession()
        stopRecordingTimer()
        speechSynthesizer.stopSpeaking(at: .immediate)
        stopMotionUpdates()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScannerRectOfInterest()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureViews() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.previewLayer.videoGravity = .resizeAspectFill
        previewView.backgroundColor = .black
        previewView.isUserInteractionEnabled = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true

        topFadeView.translatesAutoresizingMaskIntoConstraints = false
        bottomFadeView.translatesAutoresizingMaskIntoConstraints = false
        focusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        focusIndicatorView.alpha = 0
        scannerFrameView.translatesAutoresizingMaskIntoConstraints = false
        scannerFrameView.isHidden = true
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false
        levelView.translatesAutoresizingMaskIntoConstraints = false
        levelView.isHidden = false
        zebraOverlayView.translatesAutoresizingMaskIntoConstraints = false
        zebraOverlayView.isHidden = true
        ocrOverlayView.translatesAutoresizingMaskIntoConstraints = false
        ocrOverlayView.isHidden = true
        documentOverlayView.translatesAutoresizingMaskIntoConstraints = false
        documentOverlayView.isHidden = true
        objectOverlayView.translatesAutoresizingMaskIntoConstraints = false
        objectOverlayView.isHidden = true

        tuningHUDCard.alpha = 0
        tuningHUDCard.isHidden = true
        tuningHUDLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        tuningHUDLabel.textColor = .white
        tuningHUDLabel.textAlignment = .center
        tuningHUDLabel.numberOfLines = 2

        recordingHUDCard.alpha = 0
        recordingHUDCard.isHidden = true
        recordingDotView.translatesAutoresizingMaskIntoConstraints = false
        recordingDotView.backgroundColor = UIColor.systemRed
        recordingDotView.layer.cornerRadius = 5
        recordingDotView.layer.cornerCurve = .continuous
        recordingTimeLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        recordingTimeLabel.textColor = .white
        recordingTimeLabel.textAlignment = .center

        histogramCard.alpha = 0.9
        histogramCard.isHidden = false
        histogramView.translatesAutoresizingMaskIntoConstraints = false
        lumaLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        lumaLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        lumaLabel.textAlignment = .center
        lumaLabel.text = "\(AppStrings.luma) 0%"

        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.numberOfLines = 1
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.8
        statusLabel.textAlignment = .center

        hintLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.numberOfLines = 1
        hintLabel.adjustsFontSizeToFitWidth = true
        hintLabel.minimumScaleFactor = 0.8
        hintLabel.textAlignment = .center
        statusCard.contentView.backgroundColor = UIColor.clear
        modeCard.contentView.backgroundColor = UIColor.clear

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.selectedSegmentIndex = AnalysisMode.allCases.firstIndex(of: settings.analysisMode) ?? 0
        modeControl.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.2)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 10, weight: .semibold)], for: .selected)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.75), .font: UIFont.systemFont(ofSize: 10, weight: .medium)], for: .normal)
        modeControl.backgroundColor = UIColor.clear
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        toolsPanelCard.alpha = 0
        toolsPanelCard.isHidden = true
        toolsSectionStack.translatesAutoresizingMaskIntoConstraints = false
        toolsSectionStack.axis = .horizontal
        toolsSectionStack.spacing = 8
        toolsSectionStack.distribution = .fillEqually
        toolsScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolsScrollView.showsVerticalScrollIndicator = false
        toolsScrollView.alwaysBounceVertical = true
        toolsScrollView.delaysContentTouches = false

        configureToolsToggleButton()
        configureSectionButton(quickSectionButton, symbolName: "bolt.fill", action: #selector(quickSectionTapped), label: AppStrings.toolsQuick)
        configureSectionButton(detectSectionButton, symbolName: "viewfinder", action: #selector(detectSectionTapped), label: AppStrings.toolsDetect)
        configureSectionButton(proSectionButton, symbolName: "dial.medium.fill", action: #selector(proSectionTapped), label: AppStrings.toolsPro)

        rightButtonStack.translatesAutoresizingMaskIntoConstraints = false
        rightButtonStack.axis = .vertical
        rightButtonStack.spacing = 10

        configureOverlayButton(flipButton, symbolName: "camera.rotate", action: #selector(flipTapped), label: AppStrings.flipCamera)
        configureOverlayButton(flashButton, symbolName: "bolt.slash.fill", action: #selector(flashTapped), label: AppStrings.flashOff)
        configureZoomBadge()
        configureFPSButton()
        configureOverlayButton(nightButton, symbolName: "moon.fill", action: #selector(nightModeTapped), label: AppStrings.nightModeOff)
        configureOverlayButton(scannerButton, symbolName: "qrcode.viewfinder", action: #selector(scannerTapped), label: AppStrings.scannerOff)
        configureOverlayButton(vaultButton, symbolName: "archivebox.fill", action: #selector(vaultTapped), label: AppStrings.scanVault)
        configureOverlayButton(settingsButton, symbolName: "gearshape.fill", action: #selector(settingsTapped), label: AppStrings.settings)
        configureTuningButton(exposureTuneButton, title: "EXP", action: #selector(exposureTuneTapped))
        configureTuningButton(shutterTuneButton, title: "SHR", action: #selector(shutterTuneTapped))
        configureTuningButton(isoTuneButton, title: "ISO", action: #selector(isoTuneTapped))
        configureTuningButton(focusTuneButton, title: "FOC", action: #selector(focusTuneTapped))
        configureAutoFocusButton()
        configureOverlayButton(lockButton, symbolName: "lock.open", action: #selector(lockTapped), label: AppStrings.focusExposureLock)
        configureWhiteBalanceButton()
        configureOverlayButton(gridButton, symbolName: "grid", action: #selector(gridTapped), label: AppStrings.grid)
        configureOverlayButton(levelButton, symbolName: "level", action: #selector(levelTapped), label: AppStrings.level)
        configureTuningButton(histogramButton, title: "HST", action: #selector(histogramTapped))
        configureTuningButton(zebraButton, title: "ZBR", action: #selector(zebraTapped))
        configureTuningButton(ocrButton, title: "OCR", action: #selector(ocrTapped))
        configureTuningButton(documentButton, title: "DOC", action: #selector(documentTapped))
        configureTuningButton(mlButton, title: "ML", action: #selector(mlTapped))
        configureTuningButton(objectButton, title: "OBJ", action: #selector(objectTapped))
        configureBrandLinkButton()

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .clear
        captureButton.layer.cornerRadius = 29
        captureButton.layer.cornerCurve = .continuous
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        installPressAnimation(on: captureButton, pressedScale: 0.95)

        captureInnerView.translatesAutoresizingMaskIntoConstraints = false
        captureInnerView.backgroundColor = .white
        captureInnerView.layer.cornerRadius = 20
        captureInnerView.layer.cornerCurve = .continuous
        captureInnerView.isUserInteractionEnabled = false
        captureButton.addSubview(captureInnerView)

        configurePillButton(analyzeButton, title: AppStrings.analyze, symbolName: "sparkles", action: #selector(analyzeTapped))
        configurePillButton(shareButton, title: AppStrings.shareResult, symbolName: "square.and.arrow.up", action: #selector(shareTapped))
        configurePillButton(copyButton, title: AppStrings.copyResult, symbolName: "doc.on.doc", action: #selector(copyTapped))
        configurePillButton(openButton, title: AppStrings.openLink, symbolName: "safari", action: #selector(openScannedLinkTapped))
        configurePillButton(askAIButton, title: AppStrings.askAI, symbolName: "text.bubble", action: #selector(askAITapped))
        configurePillButton(speakButton, title: AppStrings.speakResult, symbolName: "speaker.wave.2", action: #selector(speakTapped))

        resultTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        resultTitleLabel.textColor = .white
        resultTitleLabel.text = AppStrings.resultTitle

        resultLabel.font = .systemFont(ofSize: 15, weight: .medium)
        resultLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        resultLabel.numberOfLines = 8

        historyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        historyLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        historyLabel.numberOfLines = 4

        errorLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        errorLabel.textColor = UIColor.systemRed.withAlphaComponent(0.95)
        errorLabel.numberOfLines = 3

        permissionTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        permissionTitleLabel.textColor = .white
        permissionTitleLabel.numberOfLines = 2
        permissionTitleLabel.text = AppStrings.permissionTitle

        permissionBodyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        permissionBodyLabel.textColor = UIColor.white.withAlphaComponent(0.84)
        permissionBodyLabel.numberOfLines = 0
        permissionBodyLabel.text = AppStrings.permissionBody

        configurePillButton(permissionButton, title: AppStrings.allowCamera, symbolName: "camera.fill", action: #selector(permissionTapped), emphasized: true)
        configurePillButton(systemSettingsButton, title: AppStrings.openSystemSettings, symbolName: "gearshape", action: #selector(openSystemSettingsTapped))

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(pinchRecognizer)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.delegate = self
        tapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapRecognizer)

        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handlePreviewDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.delegate = self
        doubleTapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(doubleTapRecognizer)
        tapRecognizer.require(toFail: doubleTapRecognizer)

        let twoFingerDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerDoubleTapReset(_:)))
        twoFingerDoubleTapRecognizer.numberOfTapsRequired = 2
        twoFingerDoubleTapRecognizer.numberOfTouchesRequired = 2
        twoFingerDoubleTapRecognizer.delegate = self
        twoFingerDoubleTapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(twoFingerDoubleTapRecognizer)
        tapRecognizer.require(toFail: twoFingerDoubleTapRecognizer)
        doubleTapRecognizer.require(toFail: twoFingerDoubleTapRecognizer)

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleCaptureLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.22
        longPressRecognizer.allowableMovement = 40
        captureButton.addGestureRecognizer(longPressRecognizer)

        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePreviewPan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        panRecognizer.delegate = self
        panRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(panRecognizer)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handlePreviewVerticalSwipe(_:)))
        swipeUpRecognizer.direction = .up
        swipeUpRecognizer.delegate = self
        swipeUpRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeUpRecognizer)

        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handlePreviewVerticalSwipe(_:)))
        swipeDownRecognizer.direction = .down
        swipeDownRecognizer.delegate = self
        swipeDownRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeDownRecognizer)
    }

    private func layoutUI() {
        [previewView, imageView, zebraOverlayView, ocrOverlayView, documentOverlayView, objectOverlayView, gridOverlayView, topFadeView, bottomFadeView, statusCard, modeCard, toolsPanelCard, toolsToggleButton, resultCard, analyzeButton, shareButton, captureButton, permissionCard, activityIndicator, focusIndicatorView, scannerFrameView, tuningHUDCard, recordingHUDCard, histogramCard, levelView, brandLinkButton].forEach {
            view.addSubview($0)
        }

        toolsSectionStack.addArrangedSubview(quickSectionButton)
        toolsSectionStack.addArrangedSubview(detectSectionButton)
        toolsSectionStack.addArrangedSubview(proSectionButton)
        renderActiveToolsSection()

        toolsPanelCard.contentView.addSubview(toolsSectionStack)
        toolsPanelCard.contentView.addSubview(toolsScrollView)
        toolsScrollView.addSubview(rightButtonStack)
        embed(tuningHUDLabel, in: tuningHUDCard, inset: 10)
        let recordingHUDStack = UIStackView(arrangedSubviews: [recordingDotView, recordingTimeLabel])
        recordingHUDStack.axis = .horizontal
        recordingHUDStack.alignment = .center
        recordingHUDStack.spacing = 8
        embed(recordingHUDStack, in: recordingHUDCard, inset: 10)
        let histogramStack = UIStackView(arrangedSubviews: [histogramView, lumaLabel])
        histogramStack.axis = .vertical
        histogramStack.spacing = 6
        embed(histogramStack, in: histogramCard, inset: 10)
        histogramView.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let statusStack = UIStackView(arrangedSubviews: [statusLabel, hintLabel])
        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 2
        embed(statusStack, in: statusCard, inset: 8)

        embed(modeControl, in: modeCard, inset: 6)

        let resultActions = UIStackView(arrangedSubviews: [copyButton, openButton])
        resultActions.axis = .horizontal
        resultActions.alignment = .fill
        resultActions.distribution = .fillEqually

        let secondaryResultActions = UIStackView(arrangedSubviews: [askAIButton, speakButton])
        secondaryResultActions.axis = .horizontal
        secondaryResultActions.alignment = .fill
        secondaryResultActions.distribution = .fillEqually

        let resultStack = UIStackView(arrangedSubviews: [resultTitleLabel, errorLabel, resultLabel, historyLabel, resultActions, secondaryResultActions])
        resultStack.axis = .vertical
        resultStack.spacing = 10
        embed(resultStack, in: resultCard)

        let permissionActions = UIStackView(arrangedSubviews: [permissionButton, systemSettingsButton])
        permissionActions.axis = .vertical
        permissionActions.spacing = 10

        let permissionStack = UIStackView(arrangedSubviews: [permissionTitleLabel, permissionBodyLabel, permissionActions])
        permissionStack.axis = .vertical
        permissionStack.spacing = 16
        embed(permissionStack, in: permissionCard)

        focusIndicatorCenterXConstraint = focusIndicatorView.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: view.bounds.midX)
        focusIndicatorCenterYConstraint = focusIndicatorView.centerYAnchor.constraint(equalTo: view.topAnchor, constant: view.bounds.midY)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            zebraOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            zebraOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zebraOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zebraOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            ocrOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            ocrOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ocrOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ocrOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            documentOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            documentOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            documentOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            objectOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            objectOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            objectOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            objectOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            gridOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            gridOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topFadeView.topAnchor.constraint(equalTo: view.topAnchor),
            topFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFadeView.heightAnchor.constraint(equalToConstant: 220),

            bottomFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeView.heightAnchor.constraint(equalToConstant: 280),

            statusCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statusCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusCard.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            statusCard.trailingAnchor.constraint(lessThanOrEqualTo: toolsToggleButton.leadingAnchor, constant: -12),
            statusCard.widthAnchor.constraint(lessThanOrEqualToConstant: 184),

            modeCard.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 6),
            modeCard.centerXAnchor.constraint(equalTo: statusCard.centerXAnchor),
            modeCard.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            modeCard.trailingAnchor.constraint(lessThanOrEqualTo: toolsToggleButton.leadingAnchor, constant: -12),
            modeCard.widthAnchor.constraint(lessThanOrEqualToConstant: 188),

            toolsToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolsToggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),

            toolsPanelCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolsPanelCard.topAnchor.constraint(equalTo: toolsToggleButton.bottomAnchor, constant: 10),
            toolsPanelCard.widthAnchor.constraint(equalToConstant: 82),
            toolsPanelCard.heightAnchor.constraint(equalToConstant: 420),
            toolsPanelCard.bottomAnchor.constraint(lessThanOrEqualTo: captureButton.topAnchor, constant: -16),

            toolsSectionStack.topAnchor.constraint(equalTo: toolsPanelCard.contentView.topAnchor, constant: 8),
            toolsSectionStack.leadingAnchor.constraint(equalTo: toolsPanelCard.contentView.leadingAnchor, constant: 6),
            toolsSectionStack.trailingAnchor.constraint(equalTo: toolsPanelCard.contentView.trailingAnchor, constant: -6),
            toolsSectionStack.heightAnchor.constraint(equalToConstant: 32),

            toolsScrollView.topAnchor.constraint(equalTo: toolsSectionStack.bottomAnchor, constant: 8),
            toolsScrollView.leadingAnchor.constraint(equalTo: toolsPanelCard.contentView.leadingAnchor, constant: 4),
            toolsScrollView.trailingAnchor.constraint(equalTo: toolsPanelCard.contentView.trailingAnchor, constant: -4),
            toolsScrollView.bottomAnchor.constraint(equalTo: toolsPanelCard.contentView.bottomAnchor, constant: -8),

            rightButtonStack.topAnchor.constraint(equalTo: toolsScrollView.contentLayoutGuide.topAnchor),
            rightButtonStack.leadingAnchor.constraint(equalTo: toolsScrollView.contentLayoutGuide.leadingAnchor),
            rightButtonStack.trailingAnchor.constraint(equalTo: toolsScrollView.contentLayoutGuide.trailingAnchor),
            rightButtonStack.bottomAnchor.constraint(equalTo: toolsScrollView.contentLayoutGuide.bottomAnchor),
            rightButtonStack.widthAnchor.constraint(equalTo: toolsScrollView.frameLayoutGuide.widthAnchor),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            captureButton.widthAnchor.constraint(equalToConstant: 58),
            captureButton.heightAnchor.constraint(equalToConstant: 58),

            captureInnerView.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            captureInnerView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            captureInnerView.widthAnchor.constraint(equalToConstant: 40),
            captureInnerView.heightAnchor.constraint(equalToConstant: 40),

            analyzeButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            analyzeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            shareButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            brandLinkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            brandLinkButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            resultCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultCard.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -16),

            tuningHUDCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tuningHUDCard.bottomAnchor.constraint(equalTo: resultCard.topAnchor, constant: -12),
            tuningHUDCard.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            recordingHUDCard.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 12),
            recordingHUDCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            recordingHUDCard.widthAnchor.constraint(lessThanOrEqualToConstant: 160),

            histogramCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            histogramCard.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -22),
            histogramCard.widthAnchor.constraint(equalToConstant: 134),
            histogramCard.heightAnchor.constraint(equalToConstant: 92),

            permissionCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            permissionCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            permissionCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            focusIndicatorView.widthAnchor.constraint(equalToConstant: 92),
            focusIndicatorView.heightAnchor.constraint(equalToConstant: 92),
            focusIndicatorCenterXConstraint!,
            focusIndicatorCenterYConstraint!,

            scannerFrameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scannerFrameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -28),
            scannerFrameView.widthAnchor.constraint(equalToConstant: 240),
            scannerFrameView.heightAnchor.constraint(equalToConstant: 240),

            levelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            levelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            levelView.widthAnchor.constraint(equalToConstant: 170),
            levelView.heightAnchor.constraint(equalToConstant: 36),

            recordingDotView.widthAnchor.constraint(equalToConstant: 10),
            recordingDotView.heightAnchor.constraint(equalToConstant: 10),
        ])
    }

    private func refreshUI() {
        let isAuthorized = cameraService.authorizationStatus == .authorized
        let hasImage = latestImageData != nil
        let hasVideo = latestVideoURL != nil
        let hasScan = latestScannedCode != nil
        let hasCapturedOCR = !(capturedRecognizedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasOCR = currentLiveOCRText() != nil
        let hasLiveML = !(liveClassification?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasCapturedML = !(capturedClassification?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasLiveObjects = !(liveObjectDetection?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasCapturedObjects = !(capturedObjectDetection?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasAnalysis = latestAnalysis != nil
        let hasError = !(cameraService.lastError ?? "").isEmpty
        let showScannerOverlay = isAuthorized && isScannerEnabled && !hasImage && !hasVideo
        let showLiveAssists = isAuthorized && !hasImage && !hasVideo
        let hasPrimaryScanAction = latestScannedCode?.hasPrimaryAction == true

        previewView.isHidden = !isAuthorized || hasImage
        imageView.isHidden = !hasImage
        permissionCard.isHidden = isAuthorized
        zebraOverlayView.isHidden = !(showLiveAssists && isZebraVisible)
        ocrOverlayView.isHidden = !(showLiveAssists && isLiveOCREnabled)
        documentOverlayView.isHidden = !(showLiveAssists && isDocumentModeEnabled)
        objectOverlayView.isHidden = !(showLiveAssists && isObjectDetectionEnabled)
        gridOverlayView.isHidden = !(showLiveAssists && isGridVisible)
        levelView.isHidden = !(showLiveAssists && isLevelVisible)
        histogramCard.isHidden = !(showLiveAssists && isHistogramVisible)
        scannerFrameView.isHidden = !showScannerOverlay
        scannerFrameView.setActive(showScannerOverlay)
        scannerFrameView.setDetected(hasScan)

        statusLabel.text = currentStatusText(hasImage: hasImage, hasVideo: hasVideo, hasScan: hasScan)
        hintLabel.text = secondaryStatusText(hasImage: hasImage, hasVideo: hasVideo, hasScan: hasScan, hasAnalysis: hasAnalysis)
        modeControl.selectedSegmentIndex = AnalysisMode.allCases.firstIndex(of: settings.analysisMode) ?? 0
        modeControl.isEnabled = !isCapturing && !isAnalyzing && !isRecordingVideo
        modeCard.alpha = isAuthorized ? 1.0 : 0.55
        brandLinkButton.isHidden = !isAuthorized
        brandLinkButton.alpha = hasImage || hasVideo || hasScan ? 0.58 : 0.78

        let canInteractWithCamera = isAuthorized && !isCapturing && !isAnalyzing && !isPreparingMLModel && !isRecordingVideo
        captureButton.isEnabled = canInteractWithCamera
        analyzeButton.isEnabled = (hasImage || hasScan || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects) && !isAnalyzing
        analyzeButton.isHidden = !(hasImage || hasScan || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        shareButton.isEnabled = hasAnalysis || hasVideo || hasScan || hasImage || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects
        shareButton.isHidden = !(hasAnalysis || hasVideo || hasScan || hasImage || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        copyButton.isHidden = !(hasAnalysis || hasScan || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        askAIButton.isHidden = !(hasImage || hasScan || hasAnalysis || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        askAIButton.isEnabled = !isAnalyzing && (hasImage || hasScan || hasAnalysis || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        speakButton.isHidden = !(hasAnalysis || hasScan || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)
        speakButton.isEnabled = hasAnalysis || hasScan || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects
        openButton.isHidden = !hasPrimaryScanAction
        flipButton.isEnabled = canInteractWithCamera
        flipButton.alpha = (hasImage || hasVideo) ? 0.45 : 1.0
        flashButton.isEnabled = canInteractWithCamera && (isScannerEnabled ? cameraService.hasTorch : cameraService.hasFlash)
        flashButton.alpha = (isScannerEnabled ? cameraService.hasTorch : cameraService.hasFlash) && !hasImage && !hasVideo ? 1.0 : 0.45
        zoomBadgeButton.alpha = isAuthorized && !hasImage && !hasVideo ? 1.0 : 0.45
        fpsButton.isEnabled = canInteractWithCamera && cameraService.supports60FPS
        fpsButton.alpha = cameraService.supports60FPS && !hasImage && !hasVideo ? 1.0 : 0.45
        nightButton.isEnabled = canInteractWithCamera && cameraService.supportsLowLightBoost
        nightButton.alpha = cameraService.supportsLowLightBoost && !hasImage && !hasVideo ? 1.0 : 0.45
        whiteBalanceButton.isEnabled = canInteractWithCamera
        whiteBalanceButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        autofocusButton.isEnabled = canInteractWithCamera && cameraService.supportsManualFocus
        autofocusButton.alpha = cameraService.supportsManualFocus && !hasImage && !hasVideo ? 1.0 : 0.45
        lockButton.isEnabled = canInteractWithCamera
        lockButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        focusTuneButton.isEnabled = canInteractWithCamera && cameraService.supportsManualFocus
        focusTuneButton.alpha = cameraService.supportsManualFocus && !hasImage && !hasVideo ? 1.0 : 0.45
        scannerButton.isEnabled = canInteractWithCamera
        scannerButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        gridButton.isEnabled = canInteractWithCamera
        levelButton.isEnabled = canInteractWithCamera
        histogramButton.isEnabled = canInteractWithCamera
        histogramButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        zebraButton.isEnabled = canInteractWithCamera
        zebraButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        ocrButton.isEnabled = canInteractWithCamera
        ocrButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        documentButton.isEnabled = canInteractWithCamera
        documentButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        mlButton.isEnabled = canInteractWithCamera
        mlButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        objectButton.isEnabled = canInteractWithCamera
        objectButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        vaultButton.isEnabled = !vaultEntries.isEmpty
        vaultButton.alpha = vaultEntries.isEmpty ? 0.45 : 1.0
        shutterTuneButton.isEnabled = canInteractWithCamera
        shutterTuneButton.alpha = !hasImage && !hasVideo ? 1.0 : 0.45
        toolsToggleButton.isEnabled = true

        updateFlashButton()
        updateCaptureButton(hasImage: hasImage, hasVideo: hasVideo, hasScan: hasScan)
        updateZoomBadge()
        updateFPSButton()
        updateNightButton()
        updateWhiteBalanceButton()
        updateAutofocusButton()
        updateLockButton()
        updateScannerButton()
        updateGridButton()
        updateLevelButton()
        updateHistogramButton()
        updateZebraButton()
        updateOCRButton()
        updateDocumentButton()
        updateMLButton()
        updateObjectButton()
        updateVaultButton()
        updatePrimaryActionButton()
        updateAnalyzeButton()
        updateSpeakButton()
        updateToolsToggleButton()
        updateToolsSectionButtons()
        updateTuningButtons()
        updateToolsPanel(animated: false)
        updateTuningHUD(text: tuningHUDText(), animated: false)
        updateRecordingHUD(animated: false)

        errorLabel.text = cameraService.lastError
        errorLabel.isHidden = !hasError
        historyLabel.text = formattedScanHistory()
        historyLabel.isHidden = scanHistory.count < 2

        if hasAnalysis {
            resultTitleLabel.text = AppStrings.resultTitle
        } else if hasImage, hasCapturedObjects {
            resultTitleLabel.text = AppStrings.capturedObjectText
        } else if hasImage, hasCapturedML {
            resultTitleLabel.text = AppStrings.capturedMLText
        } else if hasImage {
            resultTitleLabel.text = hasCapturedOCR ? AppStrings.capturedOCRText : AppStrings.latestShot
        } else if hasScan {
            resultTitleLabel.text = AppStrings.scannedCode
        } else if hasLiveObjects {
            resultTitleLabel.text = AppStrings.objectDetectText
        } else if hasLiveML {
            resultTitleLabel.text = AppStrings.liveMLText
        } else if hasOCR {
            resultTitleLabel.text = AppStrings.liveOCRText
        } else if hasVideo {
            resultTitleLabel.text = AppStrings.latestVideo
        } else {
            resultTitleLabel.text = AppStrings.resultTitle
        }

        if let analysis = latestAnalysis {
            resultLabel.text = formatted(analysis: analysis)
        } else if hasImage, let capturedObjectDetection {
            resultLabel.text = capturedObjectDetection.combinedText
        } else if hasImage, let capturedClassification {
            resultLabel.text = capturedClassification.combinedText
        } else if hasImage, let capturedRecognizedText, !capturedRecognizedText.isEmpty {
            resultLabel.text = capturedRecognizedText
        } else if hasImage {
            resultLabel.text = AppStrings.askAIMessage
        } else if hasLiveObjects {
            resultLabel.text = liveObjectDetection?.combinedText ?? AppStrings.objectDetectNoResult
        } else if hasLiveML {
            resultLabel.text = liveClassification?.combinedText ?? AppStrings.liveMLNoResult
        } else if hasOCR {
            resultLabel.text = currentLiveOCRText() ?? AppStrings.liveOCRNoText
        } else if hasVideo {
            resultLabel.text = "\(AppStrings.latestVideo) • \(preferredFPS) \(AppStrings.fps)"
        } else if let latestScannedCode {
            resultLabel.text = formatted(scannedCode: latestScannedCode)
        } else if hasError {
            resultLabel.text = AppStrings.noResultBody
        } else {
            resultLabel.text = nil
        }

        resultCard.isHidden = !(hasAnalysis || hasError || hasVideo || hasScan || hasImage || hasOCR || hasCapturedOCR || hasLiveML || hasCapturedML || hasLiveObjects || hasCapturedObjects)

        if isCapturing || isAnalyzing || isPreparingMLModel {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func updateFlashButton() {
        let scannerTorchMode = isScannerEnabled && latestImageData == nil && latestVideoURL == nil
        let symbol = scannerTorchMode
            ? (isTorchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
            : (isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
        flashButton.configuration?.image = UIImage(systemName: symbol)
        flashButton.accessibilityLabel = scannerTorchMode
            ? (isTorchEnabled ? AppStrings.torchOn : AppStrings.torchOff)
            : (isFlashEnabled ? AppStrings.flashOn : AppStrings.flashOff)
        flashButton.tintColor = (scannerTorchMode ? isTorchEnabled : isFlashEnabled) ? UIColor.systemYellow : .white
    }

    private func updateZoomBadge() {
        zoomBadgeButton.configuration?.title = String(format: "%.1fx", zoomFactor)
        zoomBadgeButton.accessibilityLabel = "\(AppStrings.zoom) \(String(format: "%.1fx", zoomFactor))"
    }

    private func updateFPSButton() {
        fpsButton.configuration?.title = "\(preferredFPS)"
        fpsButton.accessibilityLabel = "\(preferredFPS) \(AppStrings.fps)"
    }

    private func updateNightButton() {
        let symbol = isNightBoostEnabled ? "moon.stars.fill" : "moon.fill"
        nightButton.configuration?.image = UIImage(systemName: symbol)
        nightButton.accessibilityLabel = isNightBoostEnabled ? AppStrings.nightModeOn : AppStrings.nightModeOff
        nightButton.tintColor = isNightBoostEnabled ? UIColor.systemTeal : .white
    }

    private func updateWhiteBalanceButton() {
        whiteBalanceButton.configuration?.subtitle = AppStrings.whiteBalanceLabel(settings.whiteBalancePreset)
        whiteBalanceButton.tintColor = settings.whiteBalancePreset == .auto ? .white : UIColor.systemCyan
    }

    private func updateAutofocusButton() {
        autofocusButton.configuration?.subtitle = AppStrings.focusModeLabel(settings.focusMode)
        autofocusButton.tintColor = settings.focusMode == .auto ? UIColor.systemGreen : UIColor.systemOrange
    }

    private func updateLockButton() {
        let locked = isFocusExposureLocked
        lockButton.configuration?.image = UIImage(systemName: locked ? "lock.fill" : "lock.open")
        lockButton.configuration?.subtitle = locked ? "AE/AF" : nil
        lockButton.accessibilityLabel = locked ? AppStrings.focusExposureLocked : AppStrings.focusExposureLock
        lockButton.tintColor = locked ? UIColor.systemRed : .white
    }

    private func updateScannerButton() {
        let symbol = isScannerEnabled ? "viewfinder.circle.fill" : "qrcode.viewfinder"
        scannerButton.configuration?.image = UIImage(systemName: symbol)
        scannerButton.accessibilityLabel = isScannerEnabled ? AppStrings.scannerOn : AppStrings.scannerOff
        scannerButton.tintColor = isScannerEnabled ? UIColor.systemGreen : .white
    }

    private func updateGridButton() {
        gridButton.configuration?.image = UIImage(systemName: isGridVisible ? "grid.circle.fill" : "grid")
        gridButton.tintColor = isGridVisible ? UIColor.systemBlue : .white
    }

    private func updateLevelButton() {
        levelButton.configuration?.image = UIImage(systemName: isLevelVisible ? "level.fill" : "level")
        levelButton.tintColor = isLevelVisible ? UIColor.systemMint : .white
    }

    private func updateHistogramButton() {
        histogramButton.backgroundColor = isHistogramVisible ? UIColor.systemBlue.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        histogramButton.tintColor = .white
        histogramButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.histogram, active: isHistogramVisible)
    }

    private func updateZebraButton() {
        zebraButton.backgroundColor = isZebraVisible ? UIColor.systemPink.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        zebraButton.tintColor = .white
        zebraButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.zebras, active: isZebraVisible)
    }

    private func updateOCRButton() {
        ocrButton.backgroundColor = isLiveOCREnabled ? UIColor.systemGreen.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        ocrButton.tintColor = .white
        ocrButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.liveOCR, active: isLiveOCREnabled)
    }

    private func updateDocumentButton() {
        documentButton.backgroundColor = isDocumentModeEnabled ? UIColor.systemYellow.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        documentButton.tintColor = isDocumentModeEnabled ? .black : .white
        documentButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.documentMode, active: isDocumentModeEnabled)
    }

    private func updateMLButton() {
        mlButton.backgroundColor = isLiveMLEnabled ? UIColor.systemPurple.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        mlButton.tintColor = .white
        mlButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.liveML, active: isLiveMLEnabled)
    }

    private func updateObjectButton() {
        objectButton.backgroundColor = isObjectDetectionEnabled ? UIColor.systemIndigo.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        objectButton.tintColor = .white
        objectButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.objectDetect, active: isObjectDetectionEnabled)
    }

    private func updateVaultButton() {
        vaultButton.configuration?.subtitle = vaultEntries.isEmpty ? nil : "\(vaultEntries.count)"
        vaultButton.tintColor = vaultEntries.isEmpty ? .white : UIColor.systemOrange
    }

    private func updateToolsToggleButton() {
        toolsToggleButton.configuration?.image = UIImage(systemName: isToolsPanelExpanded ? "xmark" : "slider.horizontal.3")
        toolsToggleButton.accessibilityLabel = isToolsPanelExpanded ? AppStrings.toolsClose : AppStrings.toolsOpen
        toolsToggleButton.tintColor = isToolsPanelExpanded ? UIColor.systemOrange : .white
    }

    private func updateToolsSectionButtons() {
        updateSectionButton(quickSectionButton, active: activeToolsSection == .quick)
        updateSectionButton(detectSectionButton, active: activeToolsSection == .detect)
        updateSectionButton(proSectionButton, active: activeToolsSection == .pro)
    }

    private func updateTuningButtons() {
        let exposureActive = activeTuningControl == .exposure
        let shutterActive = activeTuningControl == .shutter
        let isoActive = activeTuningControl == .iso
        let focusActive = activeTuningControl == .focus

        exposureTuneButton.backgroundColor = exposureActive ? UIColor.systemOrange.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        shutterTuneButton.backgroundColor = shutterActive ? UIColor.systemOrange.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        isoTuneButton.backgroundColor = isoActive ? UIColor.systemOrange.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        focusTuneButton.backgroundColor = focusActive ? UIColor.systemOrange.withAlphaComponent(0.88) : UIColor.black.withAlphaComponent(0.28)
        exposureTuneButton.tintColor = .white
        shutterTuneButton.tintColor = .white
        isoTuneButton.tintColor = .white
        focusTuneButton.tintColor = .white
        exposureTuneButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.exposure, active: exposureActive)
        shutterTuneButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.shutter, active: shutterActive)
        isoTuneButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.iso, active: isoActive)
        focusTuneButton.accessibilityLabel = AppStrings.tuningLabel(AppStrings.focus, active: focusActive)
    }

    private func updateRecordingHUD(animated: Bool) {
        let shouldShow = isRecordingVideo
        recordingTimeLabel.text = shouldShow ? formattedRecordingDuration() : AppStrings.recordingTimer

        let applyState = {
            self.recordingHUDCard.alpha = shouldShow ? 1 : 0
            self.recordingHUDCard.transform = shouldShow ? .identity : CGAffineTransform(scaleX: 0.96, y: 0.96)
        }

        if animated {
            if shouldShow {
                recordingHUDCard.isHidden = false
            }
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
                applyState()
            } completion: { _ in
                self.recordingHUDCard.isHidden = !shouldShow
            }
        } else {
            applyState()
            recordingHUDCard.isHidden = !shouldShow
        }
    }

    private func updateToolsPanel(animated: Bool) {
        let applyState = {
            self.toolsPanelCard.alpha = self.isToolsPanelExpanded ? 1 : 0
            self.toolsPanelCard.transform = self.isToolsPanelExpanded
                ? .identity
                : CGAffineTransform(translationX: 22, y: 0).scaledBy(x: 0.96, y: 0.96)
        }

        if animated {
            if isToolsPanelExpanded {
                toolsPanelCard.isHidden = false
            }
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.22, options: [.curveEaseInOut]) {
                applyState()
            } completion: { _ in
                self.toolsPanelCard.isHidden = !self.isToolsPanelExpanded
            }
        } else {
            applyState()
            toolsPanelCard.isHidden = !isToolsPanelExpanded
        }

        let isInteractive = isToolsPanelExpanded
        rightButtonStack.arrangedSubviews.forEach {
            $0.isUserInteractionEnabled = isInteractive
        }
        toolsSectionStack.arrangedSubviews.forEach {
            $0.isUserInteractionEnabled = isInteractive
        }
    }

    private func toolButtons(for section: ToolsSection) -> [UIButton] {
        switch section {
        case .quick:
            return [flipButton, flashButton, zoomBadgeButton, fpsButton, nightButton, vaultButton, settingsButton]
        case .detect:
            return [scannerButton, ocrButton, documentButton, mlButton, objectButton]
        case .pro:
            return [whiteBalanceButton, autofocusButton, lockButton, exposureTuneButton, shutterTuneButton, isoTuneButton, focusTuneButton, gridButton, levelButton, histogramButton, zebraButton]
        }
    }

    private func renderActiveToolsSection() {
        rightButtonStack.arrangedSubviews.forEach { row in
            rightButtonStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        toolButtons(for: activeToolsSection).forEach { button in
            button.removeFromSuperview()
            rightButtonStack.addArrangedSubview(button)
        }
        updateToolsSectionButtons()
    }

    private func updateAnalyzeButton() {
        let title = latestScannedCode != nil && latestImageData == nil ? AppStrings.analyzeScan : AppStrings.analyze
        analyzeButton.configuration?.title = title
    }

    private func updateSpeakButton() {
        let isSpeaking = isSpeakingResult
        let title = isSpeaking ? AppStrings.stopSpeaking : AppStrings.speakResult
        let symbol = isSpeaking ? "speaker.slash" : "speaker.wave.2"
        speakButton.configuration?.title = title
        speakButton.configuration?.image = UIImage(systemName: symbol)
    }

    private func updatePrimaryActionButton() {
        openButton.configuration?.title = latestScannedCode?.primaryActionTitle ?? AppStrings.openLink
    }

    private func updateCaptureButton(hasImage: Bool, hasVideo: Bool, hasScan: Bool) {
        let innerColor: UIColor
        if isRecordingVideo {
            innerColor = .systemRed
        } else if isAnalyzing {
            innerColor = .systemYellow
        } else if hasScan && !hasImage && !hasVideo {
            innerColor = .systemGreen
        } else if hasImage || hasVideo {
            innerColor = .systemOrange
        } else {
            innerColor = .white
        }

        captureInnerView.backgroundColor = innerColor
        captureInnerView.layer.cornerRadius = isRecordingVideo ? 11 : 20
        captureInnerView.transform = (isCapturing || isRecordingVideo) ? CGAffineTransform(scaleX: 0.74, y: 0.74) : .identity
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(captureButton.isEnabled ? 1.0 : 0.45).cgColor
    }

    private func currentStatusText(hasImage: Bool, hasVideo: Bool, hasScan: Bool) -> String {
        if isRecordingVideo { return AppStrings.recording }
        if isAnalyzing { return AppStrings.analyzing }
        if isPreparingMLModel { return AppStrings.coreMLPreparing }
        if isCapturing { return AppStrings.capturing }
        if let latestAnalysis {
            return latestAnalysis.title
        }
        if hasImage {
            return AppStrings.latestShot
        }
        if hasVideo {
            return AppStrings.videoReady
        }
        if hasScan {
            return AppStrings.codeDetected
        }
        if isDocumentModeEnabled, latestDocumentQuad != nil {
            return AppStrings.documentReady
        }
        if isObjectDetectionEnabled {
            return AppStrings.objectDetectReady
        }
        if isLiveMLEnabled {
            return AppStrings.liveMLReady
        }
        if isLiveOCREnabled {
            return AppStrings.liveOCRReady
        }
        if isScannerEnabled {
            return AppStrings.scannerReady
        }
        return AppStrings.livePreview
    }

    private func secondaryStatusText(hasImage: Bool, hasVideo: Bool, hasScan: Bool, hasAnalysis: Bool) -> String {
        if !cameraService.authorizationStatus.isAuthorizedForCamera {
            return AppStrings.permissionBody
        }
        if isPreparingMLModel {
            return AppStrings.coreMLHint
        }
        if isRecordingVideo {
            return "\(preferredFPS) \(AppStrings.fps) • \(String(format: "%.1fx", zoomFactor))"
        }
        if hasAnalysis, let latestAnalysis {
            return "\(latestAnalysis.confidenceLabel) • \(AppStrings.usingModel): \(settings.model)"
        }
        if isFocusExposureLocked {
            return "\(AppStrings.focusExposureLocked) • \(compactPreviewSummary())"
        }
        if hasVideo {
            return "\(AppStrings.shareResult) • \(preferredFPS) \(AppStrings.fps)"
        }
        if hasScan, let latestScannedCode {
            return "\(latestScannedCode.type) • \(latestScannedCode.payload.prefix(40))"
        }
        if hasImage {
            if let capturedObjectDetection, !capturedObjectDetection.combinedText.isEmpty {
                return "\(AppStrings.capturedObjectHint) • \(capturedObjectDetection.compactSummary)"
            }
            if let capturedClassification, !capturedClassification.combinedText.isEmpty {
                return "\(AppStrings.capturedMLHint) • \(capturedClassification.compactSummary)"
            }
            if let capturedRecognizedText, !capturedRecognizedText.isEmpty {
                return "\(AppStrings.capturedOCRHint) • \(capturedRecognizedText.prefix(40))"
            }
            return "\(AppStrings.modeLabel(settings.analysisMode)) • \(AppStrings.captureEffectLabel(settings.captureEffect)) • \(String(format: "%+.1f", settings.exposureBias))"
        }
        if isDocumentModeEnabled {
            return "\(AppStrings.documentHint) • \(preferredFPS) \(AppStrings.fps)"
        }
        if isObjectDetectionEnabled {
            let summary = liveObjectDetection?.compactSummary ?? AppStrings.objectDetectHint
            return "\(summary) • \(preferredFPS) \(AppStrings.fps)"
        }
        if isLiveMLEnabled {
            let summary = liveClassification?.compactSummary ?? AppStrings.liveMLHint
            return "\(summary) • \(preferredFPS) \(AppStrings.fps)"
        }
        if isLiveOCREnabled {
            return "\(AppStrings.liveOCRHint) • \(preferredFPS) \(AppStrings.fps)"
        }
        if isScannerEnabled {
            return "\(AppStrings.scannerAimHint) • \(preferredFPS) \(AppStrings.fps)"
        }
        let swipeHint = isToolsPanelExpanded ? " • \(AppStrings.swipeTuningCompactHint)" : ""
        return "\(compactPreviewSummary())\(swipeHint)"
    }

    private func formatted(analysis: CameraAnalysis) -> String {
        var lines: [String] = []
        lines.append(analysis.summary)

        if !analysis.findings.isEmpty {
            lines.append("")
            lines.append("\(AppStrings.findings):")
            lines.append(contentsOf: analysis.findings.prefix(3).map { "• \($0)" })
        }
        if !analysis.recommendations.isEmpty {
            lines.append("")
            lines.append("\(AppStrings.recommendations):")
            lines.append(contentsOf: analysis.recommendations.prefix(2).map { "• \($0)" })
        }
        if !analysis.detectedText.isEmpty {
            lines.append("")
            lines.append("\(AppStrings.detectedText):")
            lines.append(contentsOf: analysis.detectedText.prefix(2).map { "• \($0)" })
        }

        return lines.joined(separator: "\n")
    }

    private func formatted(scannedCode: ScannedCode) -> String {
        var lines = ["\(scannedCode.type)", scannedCode.formattedDetails]
        if scannedCode.primaryActionURL != nil {
            lines.append("")
            lines.append(scannedCode.primaryActionTitle ?? AppStrings.openLink)
        } else if scannedCode.hasPrimaryAction {
            lines.append("")
            lines.append(scannedCode.primaryActionTitle ?? AppStrings.openLink)
        }
        return lines.joined(separator: "\n")
    }

    private func currentLiveOCRText() -> String? {
        let selected = selectedOCRText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selected, !selected.isEmpty {
            return selected
        }
        let combined = liveOCRBlocks.prefix(8).map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    private func currentLiveOCRScannedCode() -> ScannedCode? {
        guard let text = currentLiveOCRText() else { return nil }
        return ScannedCode(payload: text, type: "live-ocr")
    }

    private func currentLiveMLText() -> String? {
        let text = liveClassification?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private func currentLiveMLScannedCode() -> ScannedCode? {
        guard let text = currentLiveMLText() else { return nil }
        return ScannedCode(payload: text, type: "live-ml")
    }

    private func currentLiveObjectText() -> String? {
        let text = liveObjectDetection?.combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private func currentLiveObjectScannedCode() -> ScannedCode? {
        guard let text = currentLiveObjectText() else { return nil }
        return ScannedCode(payload: text, type: "live-objects")
    }

    private func nearestShutterPresetIndex(for value: Double) -> Int {
        AppSettings.shutterPresets.enumerated().min(by: { abs($0.element - value) < abs($1.element - value) })?.offset ?? 0
    }

    private func formattedShutterValue(_ seconds: Double) -> String {
        if seconds <= 0 {
            return AppStrings.shutterAuto
        }
        if seconds >= 1 {
            return seconds.rounded() == seconds ? String(format: "%.0fs", seconds) : String(format: "%.1fs", seconds)
        }
        let reciprocal = max(1, Int((1.0 / seconds).rounded()))
        return "1/\(reciprocal)s"
    }

    private func updateSettings(_ next: AppSettings) {
        settings = next
        do {
            try settingsStore.save(next)
        } catch {
            cameraService.lastError = error.localizedDescription
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task { [weak self] in
            guard let self else { return }
            await self.applySavedCameraTuning(persistIfAdjusted: true)
            self.refreshRenderedImagePreviewIfNeeded()
            self.refreshUI()
        }
        refreshUI()
    }

    private func prepareCamera() async {
        await cameraService.requestAccessIfNeeded()
        await applySavedCameraTuning(persistIfAdjusted: true)
        previewView.previewLayer.session = cameraService.session
        zoomFactor = cameraService.zoomFactor
        preferredFPS = cameraService.currentFPS
        isNightBoostEnabled = cameraService.isLowLightBoostEnabled
        isScannerEnabled = cameraService.isScannerEnabled
        isLiveOCREnabled = cameraService.isTextRecognitionEnabled
        isDocumentModeEnabled = cameraService.isDocumentDetectionEnabled
        isLiveMLEnabled = cameraService.isMLClassificationEnabled
        isObjectDetectionEnabled = cameraService.isObjectDetectionEnabled
        isTorchEnabled = cameraService.isTorchEnabled
        isFocusExposureLocked = cameraService.isFocusExposureLocked
        settings.exposureBias = Double(cameraService.currentExposureBias)
        settings.shutterDurationSeconds = cameraService.currentShutterDurationSeconds
        settings.whiteBalancePreset = cameraService.currentWhiteBalancePreset
        settings.focusMode = cameraService.currentFocusModePreset
        settings.manualFocusPosition = Double(cameraService.currentManualFocusPosition)
        updateScannerRectOfInterest()
        refreshUI()
    }

    private func presentSettings() {
        let isoUpperBound = max(cameraService.maxISOValue, Float(1600))
        let controller = UINavigationController(rootViewController: SettingsViewController(current: settings, isoRange: 0 ... isoUpperBound) { [weak self] next in
            self?.updateSettings(next)
        })
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }

    @objc
    private func settingsTapped() {
        presentSettings()
    }

    @objc
    private func toolsToggleTapped() {
        isToolsPanelExpanded.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshUI()
        updateToolsPanel(animated: true)
    }

    @objc
    private func quickSectionTapped() {
        activeToolsSection = .quick
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        renderActiveToolsSection()
        refreshUI()
    }

    @objc
    private func detectSectionTapped() {
        activeToolsSection = .detect
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        renderActiveToolsSection()
        refreshUI()
    }

    @objc
    private func proSectionTapped() {
        activeToolsSection = .pro
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        renderActiveToolsSection()
        refreshUI()
    }

    @objc
    private func permissionTapped() {
        Task { await prepareCamera() }
    }

    @objc
    private func openSystemSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc
    private func modeChanged() {
        settings.analysisMode = AnalysisMode.allCases[safe: modeControl.selectedSegmentIndex] ?? .scene
        updateSettings(settings)
    }

    @objc
    private func exposureTuneTapped() {
        selectActiveTuningControl(.exposure, showHUD: true)
    }

    @objc
    private func shutterTuneTapped() {
        selectActiveTuningControl(.shutter, showHUD: true)
    }

    @objc
    private func isoTuneTapped() {
        selectActiveTuningControl(.iso, showHUD: true)
    }

    @objc
    private func focusTuneTapped() {
        selectActiveTuningControl(.focus, showHUD: true)
    }

    @objc
    private func autofocusTapped() {
        let next: FocusModePreset = settings.focusMode == .auto ? .manual : .auto
        settings.focusMode = next
        try? settingsStore.save(settings)
        Task { [weak self] in
            guard let self else { return }
            self.settings.focusMode = await self.cameraService.setFocusModePreset(next)
            self.settings.manualFocusPosition = Double(self.cameraService.currentManualFocusPosition)
            try? self.settingsStore.save(self.settings)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
            self.refreshUI()
        }
    }

    @objc
    private func whiteBalanceTapped() {
        let all = WhiteBalancePreset.allCases
        guard let index = all.firstIndex(of: settings.whiteBalancePreset) else { return }
        let next = all[(index + 1) % all.count]
        settings.whiteBalancePreset = next
        try? settingsStore.save(settings)
        Task { [weak self] in
            guard let self else { return }
            self.settings.whiteBalancePreset = await self.cameraService.setWhiteBalancePreset(next)
            try? self.settingsStore.save(self.settings)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
            self.refreshUI()
        }
    }

    @objc
    private func gridTapped() {
        isGridVisible.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshUI()
    }

    @objc
    private func levelTapped() {
        isLevelVisible.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshUI()
    }

    @objc
    private func histogramTapped() {
        isHistogramVisible.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshUI()
    }

    @objc
    private func zebraTapped() {
        isZebraVisible.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshUI()
    }

    @objc
    private func ocrTapped() {
        let requested = !isLiveOCREnabled
        Task { [weak self] in
            guard let self else { return }
            self.isLiveOCREnabled = await self.cameraService.setTextRecognitionEnabled(requested)
            if self.isLiveOCREnabled {
                self.isScannerEnabled = false
                self.isDocumentModeEnabled = false
                self.isLiveMLEnabled = false
                self.isObjectDetectionEnabled = false
                self.latestDocumentQuad = nil
                self.documentOverlayView.update(quad: nil)
                self.liveClassification = nil
                self.liveObjectDetection = nil
                self.objectOverlayView.update(objects: [])
            } else {
                self.liveOCRBlocks.removeAll()
                self.liveOCRDisplayBlocks.removeAll()
                self.selectedOCRText = nil
                self.ocrOverlayView.update(blocks: [], selectedText: nil)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.refreshUI()
        }
    }

    @objc
    private func documentTapped() {
        let requested = !isDocumentModeEnabled
        Task { [weak self] in
            guard let self else { return }
            self.isDocumentModeEnabled = await self.cameraService.setDocumentDetectionEnabled(requested)
            if self.isDocumentModeEnabled {
                self.isScannerEnabled = false
                self.isLiveOCREnabled = false
                self.isLiveMLEnabled = false
                self.isObjectDetectionEnabled = false
                self.liveOCRBlocks.removeAll()
                self.liveOCRDisplayBlocks.removeAll()
                self.selectedOCRText = nil
                self.ocrOverlayView.update(blocks: [], selectedText: nil)
                self.liveClassification = nil
                self.liveObjectDetection = nil
                self.objectOverlayView.update(objects: [])
            }
            if !self.isDocumentModeEnabled {
                self.latestDocumentQuad = nil
                self.documentOverlayView.update(quad: nil)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.refreshUI()
        }
    }

    @objc
    private func mlTapped() {
        let requested = !isLiveMLEnabled
        Task { [weak self] in
            guard let self else { return }
            if requested {
                self.isPreparingMLModel = true
                self.cameraService.lastError = nil
                self.refreshUI()
            }
            self.isLiveMLEnabled = await self.cameraService.setMLClassificationEnabled(requested)
            self.isPreparingMLModel = false
            if self.isLiveMLEnabled {
                self.isScannerEnabled = false
                self.isLiveOCREnabled = false
                self.isDocumentModeEnabled = false
                self.isObjectDetectionEnabled = false
                self.liveOCRBlocks.removeAll()
                self.liveOCRDisplayBlocks.removeAll()
                self.selectedOCRText = nil
                self.ocrOverlayView.update(blocks: [], selectedText: nil)
                self.latestDocumentQuad = nil
                self.documentOverlayView.update(quad: nil)
                self.liveObjectDetection = nil
                self.objectOverlayView.update(objects: [])
                self.updateTuningHUD(text: AppStrings.coreMLReady, animated: true)
            } else {
                self.liveClassification = nil
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.refreshUI()
        }
    }

    @objc
    private func objectTapped() {
        let requested = !isObjectDetectionEnabled
        Task { [weak self] in
            guard let self else { return }
            if requested {
                self.isPreparingMLModel = true
                self.cameraService.lastError = nil
                self.refreshUI()
            }
            self.isObjectDetectionEnabled = await self.cameraService.setObjectDetectionEnabled(requested)
            self.isPreparingMLModel = false
            if self.isObjectDetectionEnabled {
                self.isScannerEnabled = false
                self.isLiveOCREnabled = false
                self.isDocumentModeEnabled = false
                self.isLiveMLEnabled = false
                self.liveOCRBlocks.removeAll()
                self.liveOCRDisplayBlocks.removeAll()
                self.selectedOCRText = nil
                self.ocrOverlayView.update(blocks: [], selectedText: nil)
                self.latestDocumentQuad = nil
                self.documentOverlayView.update(quad: nil)
                self.liveClassification = nil
                self.updateTuningHUD(text: AppStrings.coreMLReady, animated: true)
            } else {
                self.liveObjectDetection = nil
                self.objectOverlayView.update(objects: [])
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.refreshUI()
        }
    }

    @objc
    private func lockTapped() {
        let requested = !isFocusExposureLocked
        Task { [weak self] in
            guard let self else { return }
            self.isFocusExposureLocked = await self.cameraService.setFocusExposureLock(requested)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.updateTuningHUD(
                text: self.isFocusExposureLocked ? AppStrings.focusExposureLocked : AppStrings.focusExposureUnlocked,
                animated: true
            )
            self.refreshUI()
        }
    }

    @objc
    private func flashTapped() {
        if isScannerEnabled && latestImageData == nil && latestVideoURL == nil {
            Task {
                isTorchEnabled = await cameraService.setTorchEnabled(!isTorchEnabled)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                refreshUI()
            }
        } else {
            isFlashEnabled.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            refreshUI()
        }
    }

    @objc
    private func fpsTapped() {
        let next = preferredFPS == 30 ? 60 : 30
        Task {
            preferredFPS = await cameraService.setPreferredFPS(next)
            zoomFactor = cameraService.zoomFactor
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            refreshUI()
        }
    }

    @objc
    private func nightModeTapped() {
        let requested = !isNightBoostEnabled
        Task {
            isNightBoostEnabled = await cameraService.setLowLightBoost(enabled: requested)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            refreshUI()
        }
    }

    @objc
    private func scannerTapped() {
        let requested = !isScannerEnabled
        Task {
            isScannerEnabled = await cameraService.setScannerEnabled(requested)
            if requested {
                isLiveOCREnabled = false
                isDocumentModeEnabled = false
                isLiveMLEnabled = false
                isObjectDetectionEnabled = false
                liveOCRBlocks.removeAll()
                liveOCRDisplayBlocks.removeAll()
                selectedOCRText = nil
                ocrOverlayView.update(blocks: [], selectedText: nil)
                latestDocumentQuad = nil
                documentOverlayView.update(quad: nil)
                liveClassification = nil
                liveObjectDetection = nil
                objectOverlayView.update(objects: [])
            }
            if !requested, isTorchEnabled {
                isTorchEnabled = await cameraService.setTorchEnabled(false)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            refreshUI()
        }
    }

    @objc
    private func vaultTapped() {
        guard !vaultEntries.isEmpty else { return }
        let controller = UINavigationController(
            rootViewController: ScanVaultViewController(
                entries: vaultEntries,
                onRestore: { [weak self] entry in
                    self?.restoreVaultEntry(entry)
                },
                onDelete: { [weak self] entry in
                    self?.deleteVaultEntry(entry)
                },
                onToggleFavorite: { [weak self] entry in
                    self?.toggleFavorite(entry)
                }
            )
        )
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard latestImageData == nil,
              cameraService.authorizationStatus.isAuthorizedForCamera else { return }

        switch recognizer.state {
        case .began:
            pinchStartZoomFactor = zoomFactor
        case .changed, .ended:
            let raw = pinchStartZoomFactor * recognizer.scale
            let bounded = max(cameraService.minZoomFactor, min(raw, cameraService.maxZoomFactor))
            zoomFactor = bounded
            Task { await cameraService.setZoomFactor(bounded) }
            refreshUI()
        default:
            break
        }
    }

    @objc
    private func handlePreviewTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: previewView)
        if latestImageData == nil,
           latestVideoURL == nil,
           isLiveOCREnabled,
           let matched = liveOCRDisplayBlocks.first(where: { $0.rect.insetBy(dx: -12, dy: -12).contains(point) }) {
            selectedOCRText = matched.text
            ocrOverlayView.update(blocks: liveOCRDisplayBlocks, selectedText: selectedOCRText)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            updateTuningHUD(text: "\(AppStrings.liveOCR) • \(matched.text.prefix(42))", animated: true)
            refreshUI()
            return
        }

        guard latestImageData == nil,
              latestVideoURL == nil,
              cameraService.authorizationStatus.isAuthorizedForCamera,
              cameraService.canFocus else { return }

        let devicePoint = previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        showFocusIndicator(at: point)
        Task {
            await cameraService.focus(at: devicePoint)
            let hint = isFocusExposureLocked
                ? AppStrings.focusExposureLocked
                : (settings.focusMode == .manual ? AppStrings.focusLockedHint : "\(AppStrings.autofocus) • \(cameraTuningSummary())")
            updateTuningHUD(text: hint, animated: true)
        }
    }

    @objc
    private func handlePreviewDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard latestImageData == nil, latestVideoURL == nil else { return }
        flipTapped()
    }

    @objc
    private func handleTwoFingerDoubleTapReset(_ recognizer: UITapGestureRecognizer) {
        guard latestImageData == nil,
              latestVideoURL == nil,
              cameraService.authorizationStatus.isAuthorizedForCamera else { return }
        resetProTuningToAuto()
    }

    @objc
    private func handlePreviewVerticalSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard latestImageData == nil,
              latestVideoURL == nil,
              cameraService.authorizationStatus.isAuthorizedForCamera else { return }

        switch recognizer.direction {
        case .up:
            cycleActiveTuningControl(by: 1)
        case .down:
            cycleActiveTuningControl(by: -1)
        default:
            break
        }
    }

    @objc
    private func handleCaptureLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard latestImageData == nil, latestVideoURL == nil else { return }

        switch recognizer.state {
        case .began:
            Task { await startVideoRecording() }
        case .ended, .cancelled, .failed:
            Task { await stopVideoRecording() }
        default:
            break
        }
    }

    @objc
    private func handlePreviewPan(_ recognizer: UIPanGestureRecognizer) {
        guard latestImageData == nil,
              latestVideoURL == nil,
              cameraService.authorizationStatus.isAuthorizedForCamera else { return }

        let translationX = recognizer.translation(in: previewView).x
        let threshold: CGFloat = 28

        switch recognizer.state {
        case .began:
            tuningPanBaselineX = translationX
            updateTuningHUD(text: tuningHUDText(), animated: true)
        case .changed:
            var delta = translationX - tuningPanBaselineX
            while delta >= threshold {
                adjustActiveTuning(by: 1)
                tuningPanBaselineX += threshold
                delta = translationX - tuningPanBaselineX
            }
            while delta <= -threshold {
                adjustActiveTuning(by: -1)
                tuningPanBaselineX -= threshold
                delta = translationX - tuningPanBaselineX
            }
        default:
            tuningPanBaselineX = 0
        }
    }

    @objc
    private func flipTapped() {
        guard latestImageData == nil, latestVideoURL == nil else { return }
        Task {
            do {
                try await cameraService.toggleCamera()
                if !cameraService.hasFlash {
                    isFlashEnabled = false
                }
                isTorchEnabled = cameraService.isTorchEnabled
                refreshUI()
            } catch {
                cameraService.lastError = error.localizedDescription
                refreshUI()
            }
        }
    }

    @objc
    private func captureTapped() {
        Task {
            if latestImageData == nil, latestVideoURL == nil, latestScannedCode == nil, latestAnalysis == nil {
                await captureImage()
            } else {
                clearCapture()
            }
        }
    }

    @objc
    private func analyzeTapped() {
        Task {
            if latestImageData != nil {
                await analyzeImage()
            } else if latestScannedCode != nil {
                await analyzeScannedCode()
            } else if currentLiveObjectText() != nil {
                await analyzeLiveObjectText()
            } else if currentLiveOCRText() != nil {
                await analyzeLiveOCRText()
            } else if currentLiveMLText() != nil {
                await analyzeLiveMLText()
            }
        }
    }

    @objc
    private func askAITapped() {
        let alert = UIAlertController(title: AppStrings.askAITitle, message: AppStrings.askAIMessage, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = AppStrings.askAIPlaceholder
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .send
        }
        alert.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: AppStrings.askAISend, style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let question = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !question.isEmpty else { return }
            Task { await self.askAI(question: question) }
        })
        present(alert, animated: true)
    }

    @objc
    private func speakTapped() {
        if isSpeakingResult {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeakingResult = false
            refreshUI()
            return
        }

        let text: String
        if let latestAnalysis {
            text = formatted(analysis: latestAnalysis)
        } else if let latestScannedCode {
            text = formatted(scannedCode: latestScannedCode)
        } else if let capturedObjectDetection, !capturedObjectDetection.combinedText.isEmpty {
            text = capturedObjectDetection.combinedText
        } else if let capturedClassification, !capturedClassification.combinedText.isEmpty {
            text = capturedClassification.combinedText
        } else if let capturedRecognizedText, !capturedRecognizedText.isEmpty {
            text = capturedRecognizedText
        } else if let liveObjectText = currentLiveObjectText() {
            text = liveObjectText
        } else if let liveMLText = currentLiveMLText() {
            text = liveMLText
        } else if let liveOCRText = currentLiveOCRText() {
            text = liveOCRText
        } else {
            return
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AppStrings.isCzech ? "cs-CZ" : "en-US")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.prefersAssistiveTechnologySettings = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
        isSpeakingResult = true
        refreshUI()
    }

    @objc
    private func copyTapped() {
        let value: String
        if let latestAnalysis {
            value = formatted(analysis: latestAnalysis)
        } else if let latestScannedCode {
            value = latestScannedCode.payload
        } else if let capturedObjectDetection, !capturedObjectDetection.combinedText.isEmpty {
            value = capturedObjectDetection.combinedText
        } else if let capturedClassification, !capturedClassification.combinedText.isEmpty {
            value = capturedClassification.combinedText
        } else if let capturedRecognizedText, !capturedRecognizedText.isEmpty {
            value = capturedRecognizedText
        } else if let liveObjectText = currentLiveObjectText() {
            value = liveObjectText
        } else if let liveMLText = currentLiveMLText() {
            value = liveMLText
        } else if let liveOCRText = currentLiveOCRText() {
            value = liveOCRText
        } else {
            return
        }

        UIPasteboard.general.string = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let alert = UIAlertController(title: AppStrings.brand, message: AppStrings.copiedResult, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak alert] in
            alert?.dismiss(animated: true)
        }
    }

    @objc
    private func openScannedLinkTapped() {
        guard let latestScannedCode else { return }

        switch latestScannedCode.kind {
        case .contact:
            presentContactAction(for: latestScannedCode)
        case .event:
            presentEventAction(for: latestScannedCode)
        default:
            guard let url = latestScannedCode.primaryActionURL else { return }
            UIApplication.shared.open(url)
        }
    }

    @objc
    private func shareTapped() {
        let items: [Any]
        if let latestVideoURL {
            items = [latestVideoURL]
        } else if let latestAnalysis {
            items = [formatted(analysis: latestAnalysis)]
        } else if let capturedObjectDetection, !capturedObjectDetection.combinedText.isEmpty {
            items = [capturedObjectDetection.combinedText]
        } else if let capturedClassification, !capturedClassification.combinedText.isEmpty {
            items = [capturedClassification.combinedText]
        } else if let capturedRecognizedText, !capturedRecognizedText.isEmpty {
            items = [capturedRecognizedText]
        } else if let latestRenderedImage {
            items = [latestRenderedImage]
        } else if let latestScannedCode {
            items = [latestScannedCode.payload]
        } else if let liveObjectText = currentLiveObjectText() {
            items = [liveObjectText]
        } else if let liveMLText = currentLiveMLText() {
            items = [liveMLText]
        } else if let liveOCRText = currentLiveOCRText() {
            items = [liveOCRText]
        } else {
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(controller, animated: true)
    }

    @objc
    private func appDidBecomeActive() {
        Task { await prepareCamera() }
    }

    private func showFocusIndicator(at point: CGPoint) {
        focusIndicatorCenterXConstraint?.constant = point.x
        focusIndicatorCenterYConstraint?.constant = point.y
        view.layoutIfNeeded()
        focusIndicatorView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        UIView.animate(withDuration: 0.15) {
            self.focusIndicatorView.alpha = 1
            self.focusIndicatorView.transform = .identity
        }
        UIView.animate(withDuration: 0.25, delay: 0.7, options: [.curveEaseInOut]) {
            self.focusIndicatorView.alpha = 0
        }
    }

    private func clearCapture() {
        latestImageData = nil
        latestRenderedImage = nil
        latestVideoURL = nil
        latestScannedCode = nil
        capturedRecognizedText = nil
        capturedClassification = nil
        capturedObjectDetection = nil
        latestAnalysis = nil
        isSpeakingResult = false
        speechSynthesizer.stopSpeaking(at: .immediate)
        selectedOCRText = nil
        if !isLiveMLEnabled {
            liveClassification = nil
        }
        if !isObjectDetectionEnabled {
            liveObjectDetection = nil
            objectOverlayView.update(objects: [])
        }
        recordingStartedAt = nil
        stopRecordingTimer()
        imageView.image = nil
        previewView.isHidden = false
        imageView.isHidden = true
        cameraService.lastError = nil
        if !isDocumentModeEnabled {
            latestDocumentQuad = nil
            documentOverlayView.update(quad: nil)
        }
        cameraService.startSession()
        refreshUI()
    }

    private func captureImage() async {
        guard !isCapturing else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        cameraService.lastError = nil
        latestVideoURL = nil
        latestScannedCode = nil
        capturedRecognizedText = nil
        capturedClassification = nil
        capturedObjectDetection = nil
        latestRenderedImage = nil
        refreshUI()

        do {
            let data = try await cameraService.capturePhoto(flashEnabled: isFlashEnabled)
            latestImageData = applyDocumentCorrectionIfNeeded(to: data) ?? data
            latestAnalysis = nil
            refreshRenderedImagePreviewIfNeeded()
            if (settings.analysisMode == .text || isDocumentModeEnabled),
               let latestImageData,
               let ocrSample = await cameraService.recognizeText(in: latestImageData),
               !ocrSample.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                capturedRecognizedText = ocrSample.combinedText
            }
            if (settings.analysisMode == .scene || settings.analysisMode == .shopping || isLiveMLEnabled),
               let latestImageData,
               let classification = await cameraService.classifyImage(in: latestImageData),
               !classification.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                capturedClassification = classification
            }
            if (settings.analysisMode == .shopping || isObjectDetectionEnabled),
               let latestImageData,
               let objectSample = await cameraService.detectObjects(in: latestImageData),
               !objectSample.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                capturedObjectDetection = objectSample
            }
            imageView.isHidden = false
            previewView.isHidden = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if settings.autoAnalyze {
                await analyzeImage()
            }
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isCapturing = false
        refreshUI()
    }

    private func startVideoRecording() async {
        guard !isRecordingVideo, !isCapturing, !isAnalyzing else { return }

        isRecordingVideo = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        recordingStartedAt = nil
        stopRecordingTimer()
        latestImageData = nil
        latestVideoURL = nil
        latestScannedCode = nil
        capturedRecognizedText = nil
        capturedClassification = nil
        capturedObjectDetection = nil
        latestAnalysis = nil
        imageView.image = nil
        cameraService.lastError = nil
        refreshUI()

        do {
            try await cameraService.startRecording(flashEnabled: isFlashEnabled)
            recordingStartedAt = Date()
            startRecordingTimer()
            refreshUI()
        } catch {
            isRecordingVideo = false
            recordingStartedAt = nil
            stopRecordingTimer()
            cameraService.lastError = error.localizedDescription
            refreshUI()
        }
    }

    private func stopVideoRecording() async {
        guard isRecordingVideo else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        do {
            latestVideoURL = try await cameraService.stopRecording()
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isRecordingVideo = false
        recordingStartedAt = nil
        stopRecordingTimer()
        refreshUI()
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        updateRecordingHUD(animated: true)
        recordingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(recordingTimerFired), userInfo: nil, repeats: true)
        if let recordingTimer {
            RunLoop.main.add(recordingTimer, forMode: .common)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        updateRecordingHUD(animated: true)
    }

    private func formattedRecordingDuration() -> String {
        guard let recordingStartedAt else { return "00:00" }
        let elapsed = max(0, Int(Date().timeIntervalSince(recordingStartedAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @objc
    private func recordingTimerFired() {
        recordingTimeLabel.text = formattedRecordingDuration()
    }

    private func analyzeImage() async {
        guard !isAnalyzing else { return }
        guard let latestImageData else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            latestAnalysis = try await aiService.analyze(imageData: latestImageData, settings: settings)
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func analyzeScannedCode() async {
        guard !isAnalyzing else { return }
        guard let latestScannedCode else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            latestAnalysis = try await aiService.analyze(scannedCode: latestScannedCode, settings: settings)
            persistVault(scannedCode: latestScannedCode, analysis: latestAnalysis)
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func analyzeLiveOCRText() async {
        guard !isAnalyzing else { return }
        guard let liveOCRCode = currentLiveOCRScannedCode() else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            latestAnalysis = try await aiService.analyze(scannedCode: liveOCRCode, settings: settings)
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func analyzeLiveMLText() async {
        guard !isAnalyzing else { return }
        guard let liveMLCode = currentLiveMLScannedCode() else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            latestAnalysis = try await aiService.analyze(scannedCode: liveMLCode, settings: settings)
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func analyzeLiveObjectText() async {
        guard !isAnalyzing else { return }
        guard let liveObjectCode = currentLiveObjectScannedCode() else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            latestAnalysis = try await aiService.analyze(scannedCode: liveObjectCode, settings: settings)
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func askAI(question: String) async {
        guard !isAnalyzing else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cameraService.lastError = AppStrings.missingAPIKey
            refreshUI()
            presentSettings()
            return
        }

        isAnalyzing = true
        cameraService.lastError = nil
        refreshUI()

        do {
            if let latestImageData {
                latestAnalysis = try await aiService.analyze(imageData: latestImageData, settings: settings, question: question)
            } else if let latestScannedCode {
                latestAnalysis = try await aiService.analyze(scannedCode: latestScannedCode, settings: settings, question: question)
                persistVault(scannedCode: latestScannedCode, analysis: latestAnalysis)
            } else if let liveObjectCode = currentLiveObjectScannedCode() {
                latestAnalysis = try await aiService.analyze(scannedCode: liveObjectCode, settings: settings, question: question)
            } else if let liveMLCode = currentLiveMLScannedCode() {
                latestAnalysis = try await aiService.analyze(scannedCode: liveMLCode, settings: settings, question: question)
            } else if let liveOCRCode = currentLiveOCRScannedCode() {
                latestAnalysis = try await aiService.analyze(scannedCode: liveOCRCode, settings: settings, question: question)
            }
        } catch {
            cameraService.lastError = error.localizedDescription
        }

        isAnalyzing = false
        refreshUI()
    }

    private func handleScannedCode(_ scannedCode: ScannedCode) {
        guard latestImageData == nil, latestVideoURL == nil else { return }
        latestScannedCode = scannedCode
        capturedRecognizedText = nil
        capturedClassification = nil
        capturedObjectDetection = nil
        scanHistory.removeAll { $0.payload == scannedCode.payload }
        scanHistory.insert(scannedCode, at: 0)
        scanHistory = Array(scanHistory.prefix(4))
        latestAnalysis = nil
        persistVault(scannedCode: scannedCode, analysis: nil)
        cameraService.lastError = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scannerFrameView.flashDetected()
        refreshUI()
    }

    private func handleMonitoringSample(_ sample: FrameMonitoringSample) {
        let lumaPercent = Int((sample.averageLuma / 255.0 * 100.0).rounded())
        histogramView.update(bins: sample.histogram)
        lumaLabel.text = "\(AppStrings.luma) \(lumaPercent)%"

        let mappedRects = sample.overexposedRects.map { previewView.previewLayer.layerRectConverted(fromMetadataOutputRect: $0) }
        zebraOverlayView.update(rects: mappedRects)
    }

    private func handleRecognizedTextSample(_ sample: TextRecognitionSample) {
        guard latestImageData == nil, latestVideoURL == nil else { return }

        liveOCRBlocks = sample.blocks
        liveOCRDisplayBlocks = sample.blocks.map { block in
            let rect = previewView.previewLayer.layerRectConverted(fromMetadataOutputRect: block.boundingBox)
            return OCRTextOverlayView.DisplayBlock(text: block.text, rect: rect, confidence: block.confidence)
        }

        if let selectedOCRText,
           !liveOCRDisplayBlocks.contains(where: { $0.text == selectedOCRText }) {
            self.selectedOCRText = nil
        }

        if currentLiveOCRText() == nil, let first = liveOCRBlocks.first?.text {
            selectedOCRText = first
        }

        ocrOverlayView.update(blocks: liveOCRDisplayBlocks, selectedText: selectedOCRText)
        if isLiveOCREnabled {
            refreshUI()
        }
    }

    private func handleDetectedDocument(_ quad: DetectedDocumentQuad?) {
        latestDocumentQuad = quad
        documentOverlayView.update(quad: quad.map { quad in
            DocumentQuadOverlayView.DisplayQuad(
                topLeft: previewView.previewLayer.layerPointConverted(fromCaptureDevicePoint: quad.topLeft),
                topRight: previewView.previewLayer.layerPointConverted(fromCaptureDevicePoint: quad.topRight),
                bottomRight: previewView.previewLayer.layerPointConverted(fromCaptureDevicePoint: quad.bottomRight),
                bottomLeft: previewView.previewLayer.layerPointConverted(fromCaptureDevicePoint: quad.bottomLeft)
            )
        })
        if isDocumentModeEnabled {
            refreshUI()
        }
    }

    private func handleImageClassificationSample(_ sample: ImageClassificationSample?) {
        guard latestImageData == nil, latestVideoURL == nil else { return }
        liveClassification = sample
        if isLiveMLEnabled {
            refreshUI()
        }
    }

    private func handleObjectDetectionSample(_ sample: ObjectDetectionSample?) {
        guard latestImageData == nil, latestVideoURL == nil else { return }
        liveObjectDetection = sample

        let displayObjects = sample?.objects.map { object in
            ObjectDetectionOverlayView.DisplayObject(
                label: object.label,
                confidence: object.confidence,
                rect: previewView.previewLayer.layerRectConverted(fromMetadataOutputRect: object.boundingBox)
            )
        } ?? []
        objectOverlayView.update(objects: displayObjects)

        if isObjectDetectionEnabled {
            refreshUI()
        }
    }

    private func persistVault(scannedCode: ScannedCode, analysis: CameraAnalysis?) {
        do {
            vaultEntries = try vaultStore.upsert(scannedCode: scannedCode, analysis: analysis)
        } catch {
            cameraService.lastError = error.localizedDescription
        }
    }

    private func restoreVaultEntry(_ entry: ScanVaultEntry) {
        latestImageData = nil
        latestRenderedImage = nil
        latestVideoURL = nil
        latestScannedCode = entry.scannedCode
        capturedRecognizedText = nil
        capturedClassification = nil
        capturedObjectDetection = nil
        latestAnalysis = entry.analysis?.analysis
        cameraService.lastError = nil
        refreshUI()
    }

    private func applySavedCameraTuning(persistIfAdjusted: Bool) async {
        let appliedBias = await cameraService.setExposureBias(Float(settings.exposureBias))
        if abs(Double(appliedBias) - settings.exposureBias) > 0.01 {
            settings.exposureBias = Double(appliedBias)
        }
        let appliedShutter = await cameraService.setManualShutterDuration(settings.shutterDurationSeconds)
        settings.shutterDurationSeconds = appliedShutter
        let appliedISO = await cameraService.setManualISO(Float(settings.isoValue))
        settings.isoValue = Double(appliedISO)
        settings.whiteBalancePreset = await cameraService.setWhiteBalancePreset(settings.whiteBalancePreset)
        settings.focusMode = await cameraService.setFocusModePreset(settings.focusMode)
        if settings.focusMode == .manual {
            settings.manualFocusPosition = Double(await cameraService.setManualFocusPosition(Float(settings.manualFocusPosition)))
        }
        if persistIfAdjusted {
            try? settingsStore.save(settings)
        }
    }

    private func refreshRenderedImagePreviewIfNeeded() {
        guard let latestImageData,
              let sourceImage = UIImage(data: latestImageData) else {
            latestRenderedImage = nil
            imageView.image = nil
            return
        }

        let rendered = renderedImage(from: sourceImage, effect: settings.captureEffect) ?? sourceImage
        latestRenderedImage = rendered
        imageView.image = rendered
    }

    private func renderedImage(from image: UIImage, effect: CaptureEffect) -> UIImage? {
#if canImport(CoreImage)
        guard effect != .natural,
              let inputImage = CIImage(image: image) else {
            return image
        }

        let outputImage: CIImage?
        switch effect {
        case .natural:
            outputImage = inputImage
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = inputImage
            filter.saturation = 1.28
            filter.contrast = 1.14
            filter.brightness = 0.04
            outputImage = filter.outputImage
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = inputImage
            outputImage = filter.outputImage
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = inputImage
            outputImage = filter.outputImage
        }

        guard let outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
#else
        return image
#endif
    }

    private func applyDocumentCorrectionIfNeeded(to imageData: Data) -> Data? {
#if canImport(CoreImage)
        guard isDocumentModeEnabled,
              let quad = latestDocumentQuad,
              let image = UIImage(data: imageData),
              let inputImage = CIImage(image: image) else {
            return nil
        }

        let corrected = correctedDocumentImage(from: inputImage, quad: quad)
        guard let corrected,
              let cgImage = ciContext.createCGImage(corrected, from: corrected.extent) else {
            return nil
        }
        let output = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        return output.jpegData(compressionQuality: 0.96)
#else
        return nil
#endif
    }

#if canImport(CoreImage)
    private func correctedDocumentImage(from image: CIImage, quad: DetectedDocumentQuad) -> CIImage? {
        let extent = image.extent

        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.minX + normalized.x * extent.width,
                y: extent.minY + (1 - normalized.y) * extent.height
            )
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = point(quad.topLeft)
        filter.topRight = point(quad.topRight)
        filter.bottomRight = point(quad.bottomRight)
        filter.bottomLeft = point(quad.bottomLeft)
        return filter.outputImage
    }
#endif

    private func cameraTuningSummary() -> String {
        let exposureValue = String(format: "%+.1f", settings.exposureBias)
        let shutterValue = formattedShutterValue(settings.shutterDurationSeconds)
        let isoValue: String
        if settings.isoValue > Double(cameraService.minISOValue) {
            isoValue = "ISO \(Int(settings.isoValue.rounded()))"
        } else {
            isoValue = AppStrings.isoAuto
        }
        let whiteBalance = AppStrings.whiteBalanceLabel(settings.whiteBalancePreset)
        let focusValue = settings.focusMode == .auto
            ? AppStrings.autofocus
            : "\(AppStrings.manualFocus) \(String(format: "%.2f", settings.manualFocusPosition))"
        return "\(AppStrings.captureEffectLabel(settings.captureEffect)) • \(AppStrings.exposure) \(exposureValue) • \(AppStrings.shutter) \(shutterValue) • \(isoValue) • \(whiteBalance) • \(focusValue)"
    }

    private func compactPreviewSummary() -> String {
        "\(AppStrings.modeLabel(settings.analysisMode)) • \(preferredFPS) \(AppStrings.fps) • \(String(format: "%.1fx", zoomFactor))"
    }

    private func deleteVaultEntry(_ entry: ScanVaultEntry) {
        do {
            vaultEntries = try vaultStore.delete(entryID: entry.id)
            if latestScannedCode?.payload == entry.payload, latestScannedCode?.type == entry.type {
                latestScannedCode = nil
                latestAnalysis = nil
            }
            refreshUI()
        } catch {
            cameraService.lastError = error.localizedDescription
            refreshUI()
        }
    }

    private func toggleFavorite(_ entry: ScanVaultEntry) -> ScanVaultEntry? {
        do {
            vaultEntries = try vaultStore.toggleFavorite(entryID: entry.id)
            refreshUI()
            return vaultEntries.first(where: { $0.id == entry.id })
        } catch {
            cameraService.lastError = error.localizedDescription
            refreshUI()
            return nil
        }
    }

    private func tuningControlLabel(_ control: TuningControl) -> String {
        switch control {
        case .exposure:
            return AppStrings.exposure
        case .shutter:
            return AppStrings.shutter
        case .iso:
            return AppStrings.iso
        case .focus:
            return AppStrings.focus
        }
    }

    private func selectActiveTuningControl(_ control: TuningControl, showHUD: Bool) {
        activeTuningControl = control
        updateTuningButtons()
        if showHUD {
            updateTuningHUD(text: "\(AppStrings.activeTuningPrefix): \(tuningControlLabel(control))", animated: true)
        }
        refreshUI()
    }

    private func cycleActiveTuningControl(by step: Int) {
        let all: [TuningControl] = [.exposure, .shutter, .iso, .focus]
        guard let currentIndex = all.firstIndex(of: activeTuningControl) else { return }
        let count = all.count
        let nextIndex = (currentIndex + step + count) % count
        let nextControl = all[nextIndex]
        guard nextControl != activeTuningControl else { return }
        selectActiveTuningControl(nextControl, showHUD: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func resetProTuningToAuto() {
        settings.exposureBias = AppSettings.default.exposureBias
        settings.shutterDurationSeconds = AppSettings.default.shutterDurationSeconds
        settings.isoValue = AppSettings.default.isoValue
        settings.whiteBalancePreset = .auto
        settings.focusMode = .auto
        settings.manualFocusPosition = AppSettings.default.manualFocusPosition
        try? settingsStore.save(settings)
        selectActiveTuningControl(.exposure, showHUD: false)
        updateTuningHUD(text: AppStrings.tuningResetHint, animated: true)

        Task { [weak self] in
            guard let self else { return }
            self.settings.exposureBias = Double(await self.cameraService.setExposureBias(Float(AppSettings.default.exposureBias)))
            self.settings.shutterDurationSeconds = await self.cameraService.setManualShutterDuration(AppSettings.default.shutterDurationSeconds)
            self.settings.isoValue = Double(await self.cameraService.setManualISO(Float(AppSettings.default.isoValue)))
            self.settings.whiteBalancePreset = await self.cameraService.setWhiteBalancePreset(.auto)
            self.settings.focusMode = await self.cameraService.setFocusModePreset(.auto)
            self.settings.manualFocusPosition = Double(self.cameraService.currentManualFocusPosition)
            self.isNightBoostEnabled = self.cameraService.isLowLightBoostEnabled
            try? self.settingsStore.save(self.settings)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.refreshUI()
        }
    }

    private func adjustActiveTuning(by step: Int) {
        switch activeTuningControl {
        case .exposure:
            let nextBias = max(-2.0, min(settings.exposureBias + (0.2 * Double(step)), 2.0))
            guard abs(nextBias - settings.exposureBias) > 0.001 else { return }
            settings.exposureBias = nextBias
            settings.shutterDurationSeconds = 0
            settings.isoValue = 0
            try? settingsStore.save(settings)
            Task { [weak self] in
                guard let self else { return }
                let appliedBias = await self.cameraService.setExposureBias(Float(nextBias))
                self.settings.exposureBias = Double(appliedBias)
                self.settings.shutterDurationSeconds = 0
                self.settings.isoValue = 0
                try? self.settingsStore.save(self.settings)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
                self.refreshUI()
            }
        case .shutter:
            let currentIndex = nearestShutterPresetIndex(for: settings.shutterDurationSeconds)
            let nextIndex = max(0, min(currentIndex + step, AppSettings.shutterPresets.count - 1))
            let nextShutter = AppSettings.shutterPresets[nextIndex]
            guard abs(nextShutter - settings.shutterDurationSeconds) > 0.0001 else { return }
            settings.shutterDurationSeconds = nextShutter
            try? settingsStore.save(settings)
            Task { [weak self] in
                guard let self else { return }
                let applied = await self.cameraService.setManualShutterDuration(nextShutter)
                self.settings.shutterDurationSeconds = applied
                self.isNightBoostEnabled = self.cameraService.isLowLightBoostEnabled
                try? self.settingsStore.save(self.settings)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
                self.refreshUI()
            }
        case .iso:
            let minISO = Double(max(cameraService.minISOValue, 1))
            let maxISO = Double(max(cameraService.maxISOValue, Float(minISO)))
            var nextISO = settings.isoValue > minISO ? settings.isoValue : minISO
            nextISO += Double(step * 24)
            if nextISO < (minISO + 12) {
                nextISO = 0
            }
            nextISO = max(0, min(nextISO, maxISO))
            guard abs(nextISO - settings.isoValue) > 0.001 else { return }
            settings.isoValue = nextISO
            try? settingsStore.save(settings)
            Task { [weak self] in
                guard let self else { return }
                let appliedISO = await self.cameraService.setManualISO(Float(nextISO))
                self.settings.isoValue = Double(appliedISO)
                self.isNightBoostEnabled = self.cameraService.isLowLightBoostEnabled
                try? self.settingsStore.save(self.settings)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
                self.refreshUI()
            }
        case .focus:
            let nextFocus = max(0, min(settings.manualFocusPosition + (0.06 * Double(step)), 1))
            guard abs(nextFocus - settings.manualFocusPosition) > 0.001 else { return }
            settings.focusMode = .manual
            settings.manualFocusPosition = nextFocus
            try? settingsStore.save(settings)
            Task { [weak self] in
                guard let self else { return }
                _ = await self.cameraService.setFocusModePreset(.manual)
                let applied = await self.cameraService.setManualFocusPosition(Float(nextFocus))
                self.settings.focusMode = .manual
                self.settings.manualFocusPosition = Double(applied)
                try? self.settingsStore.save(self.settings)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.updateTuningHUD(text: self.tuningHUDText(), animated: true)
                self.refreshUI()
            }
        }
    }

    private func updateScannerRectOfInterest() {
        guard !previewView.bounds.isEmpty, !scannerFrameView.bounds.isEmpty else { return }
        let frameInPreview = previewView.convert(scannerFrameView.frame, from: view)
        let metadataRect = previewView.previewLayer.metadataOutputRectConverted(fromLayerRect: frameInPreview)
        guard lastScannerMetadataRect != metadataRect else { return }
        lastScannerMetadataRect = metadataRect
        Task { await cameraService.setScannerRectOfInterest(metadataRect) }
    }

    private func presentContactAction(for scannedCode: ScannedCode) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            showContactView(for: scannedCode)
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.showContactView(for: scannedCode)
                }
            }
        default:
            cameraService.lastError = AppStrings.permissionBody
            refreshUI()
        }
    }

    private func showContactView(for scannedCode: ScannedCode) {
        guard let data = scannedCode.payload.data(using: .utf8),
              let contact = try? CNContactVCardSerialization.contacts(with: data).first else {
            if case .contact(let payload) = scannedCode.kind {
                let contact = CNMutableContact()
                contact.givenName = payload.fullName
                if let phone = payload.phone {
                    contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
                }
                if let email = payload.email {
                    contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
                }
                if let organization = payload.organization {
                    contact.organizationName = organization
                }
                presentContactViewController(contact)
            }
            return
        }

        let mutable = contact.mutableCopy() as? CNMutableContact ?? CNMutableContact()
        presentContactViewController(mutable)
    }

    private func presentContactViewController(_ contact: CNMutableContact) {
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = contactStore
        controller.delegate = self
        let navigation = UINavigationController(rootViewController: controller)
        present(navigation, animated: true)
    }

    private func presentEventAction(for scannedCode: ScannedCode) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                guard let self, granted else { return }
                DispatchQueue.main.async {
                    self.showEventView(for: scannedCode)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                guard let self, granted else { return }
                DispatchQueue.main.async {
                    self.showEventView(for: scannedCode)
                }
            }
        }
    }

    private func showEventView(for scannedCode: ScannedCode) {
        guard case .event(let payload) = scannedCode.kind else { return }
        let event = EKEvent(eventStore: eventStore)
        event.title = payload.title
        event.startDate = payload.startDate ?? Date()
        event.endDate = payload.endDate ?? payload.startDate?.addingTimeInterval(3600) ?? Date().addingTimeInterval(3600)
        event.location = payload.location
        event.notes = payload.notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = self
        present(controller, animated: true)
    }

    private func formattedScanHistory() -> String? {
        guard scanHistory.count > 1 else { return nil }
        let entries = scanHistory.dropFirst().prefix(3).map { code in
            let truncated = code.payload.count > 28 ? "\(code.payload.prefix(28))…" : code.payload
            return "• \(code.type) • \(truncated)"
        }
        guard !entries.isEmpty else { return nil }
        return "\(AppStrings.recentScans):\n" + entries.joined(separator: "\n")
    }

    private func tuningHUDText() -> String {
        let exposure = String(format: "%+.1f", settings.exposureBias)
        let shutter = formattedShutterValue(settings.shutterDurationSeconds)
        let iso: String
        if settings.isoValue > Double(cameraService.minISOValue) {
            iso = "ISO \(Int(settings.isoValue.rounded()))"
        } else {
            iso = AppStrings.isoAuto
        }
        let focus = settings.focusMode == .auto
            ? AppStrings.autofocus
            : "\(AppStrings.manualFocus) \(String(format: "%.2f", settings.manualFocusPosition))"
        return "\(AppStrings.exposure) \(exposure) • \(AppStrings.shutter) \(shutter) • \(iso)\n\(AppStrings.whiteBalance) \(AppStrings.whiteBalanceLabel(settings.whiteBalancePreset)) • \(focus)"
    }

    private func updateTuningHUD(text: String, animated: Bool) {
        tuningHUDLabel.text = text
        if animated {
            tuningHUDCard.isHidden = false
            UIView.animate(withDuration: 0.18) {
                self.tuningHUDCard.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.25, delay: 1.0, options: [.curveEaseInOut]) {
                    self.tuningHUDCard.alpha = self.isToolsPanelExpanded ? 0.88 : 0
                } completion: { _ in
                    self.tuningHUDCard.isHidden = !self.isToolsPanelExpanded
                }
            }
        } else {
            tuningHUDCard.alpha = isToolsPanelExpanded ? 0.88 : 0
            tuningHUDCard.isHidden = !isToolsPanelExpanded
        }
    }

    private func startMotionUpdatesIfNeeded() {
#if canImport(CoreMotion)
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 0.12
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let degrees = motion.attitude.roll * 180 / .pi
            self.levelView.update(rollDegrees: degrees)
        }
#endif
    }

    private func stopMotionUpdates() {
#if canImport(CoreMotion)
        motionManager.stopDeviceMotionUpdates()
#endif
    }

    private func configureToolsToggleButton() {
        toolsToggleButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "slider.horizontal.3")
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        toolsToggleButton.configuration = configuration
        toolsToggleButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        toolsToggleButton.layer.cornerRadius = 26
        toolsToggleButton.layer.cornerCurve = .continuous
        toolsToggleButton.clipsToBounds = true
        toolsToggleButton.addTarget(self, action: #selector(toolsToggleTapped), for: .touchUpInside)
        toolsToggleButton.accessibilityLabel = AppStrings.toolsOpen
        installPressAnimation(on: toolsToggleButton)

        NSLayoutConstraint.activate([
            toolsToggleButton.widthAnchor.constraint(equalToConstant: 52),
            toolsToggleButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureSectionButton(_ button: UIButton, symbolName: String, action: Selector, label: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7)
        button.configuration = configuration
        button.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = label
        installPressAnimation(on: button, pressedScale: 0.95)

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func updateSectionButton(_ button: UIButton, active: Bool) {
        button.backgroundColor = active ? UIColor.systemOrange.withAlphaComponent(0.9) : UIColor.black.withAlphaComponent(0.24)
        button.tintColor = .white
    }

    private func configureWhiteBalanceButton() {
        whiteBalanceButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "WB"
        configuration.subtitle = AppStrings.whiteBalanceLabel(settings.whiteBalancePreset)
        configuration.baseForegroundColor = .white
        whiteBalanceButton.configuration = configuration
        whiteBalanceButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        whiteBalanceButton.layer.cornerRadius = 26
        whiteBalanceButton.layer.cornerCurve = .continuous
        whiteBalanceButton.clipsToBounds = true
        whiteBalanceButton.addTarget(self, action: #selector(whiteBalanceTapped), for: .touchUpInside)
        installPressAnimation(on: whiteBalanceButton)

        NSLayoutConstraint.activate([
            whiteBalanceButton.widthAnchor.constraint(equalToConstant: 52),
            whiteBalanceButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureAutoFocusButton() {
        autofocusButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "AF"
        configuration.subtitle = AppStrings.focusModeLabel(settings.focusMode)
        configuration.baseForegroundColor = .white
        autofocusButton.configuration = configuration
        autofocusButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        autofocusButton.layer.cornerRadius = 26
        autofocusButton.layer.cornerCurve = .continuous
        autofocusButton.clipsToBounds = true
        autofocusButton.addTarget(self, action: #selector(autofocusTapped), for: .touchUpInside)
        installPressAnimation(on: autofocusButton)

        NSLayoutConstraint.activate([
            autofocusButton.widthAnchor.constraint(equalToConstant: 52),
            autofocusButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureOverlayButton(_ button: UIButton, symbolName: String, action: Selector, label: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        button.configuration = configuration
        button.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        button.layer.cornerRadius = 26
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = label
        installPressAnimation(on: button)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 52),
            button.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureTuningButton(_ button: UIButton, title: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = .white
        button.configuration = configuration
        button.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        button.layer.cornerRadius = 26
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        installPressAnimation(on: button)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 52),
            button.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureZoomBadge() {
        zoomBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "1.0x"
        configuration.baseForegroundColor = .white
        zoomBadgeButton.configuration = configuration
        zoomBadgeButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        zoomBadgeButton.layer.cornerRadius = 26
        zoomBadgeButton.layer.cornerCurve = .continuous
        zoomBadgeButton.clipsToBounds = true
        zoomBadgeButton.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            zoomBadgeButton.widthAnchor.constraint(equalToConstant: 52),
            zoomBadgeButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureFPSButton() {
        fpsButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "30"
        configuration.subtitle = AppStrings.fps
        configuration.baseForegroundColor = .white
        fpsButton.configuration = configuration
        fpsButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        fpsButton.layer.cornerRadius = 26
        fpsButton.layer.cornerCurve = .continuous
        fpsButton.clipsToBounds = true
        fpsButton.addTarget(self, action: #selector(fpsTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            fpsButton.widthAnchor.constraint(equalToConstant: 52),
            fpsButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func configureBrandLinkButton() {
        brandLinkButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = AppStrings.brand
        configuration.baseForegroundColor = UIColor.white.withAlphaComponent(0.72)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        brandLinkButton.configuration = configuration
        brandLinkButton.titleLabel?.font = .systemFont(ofSize: 9, weight: .semibold)
        brandLinkButton.backgroundColor = UIColor.clear
        brandLinkButton.addTarget(self, action: #selector(brandLinkTapped), for: .touchUpInside)
        installPressAnimation(on: brandLinkButton, pressedScale: 0.96)
    }

    private func installPressAnimation(on button: UIButton, pressedScale: CGFloat = 0.92) {
        button.addTarget(self, action: #selector(buttonPressedDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(buttonPressedUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        button.layer.setValue(pressedScale, forKey: "pressScale")
    }

    @objc
    private func buttonPressedDown(_ sender: UIButton) {
        let scale = sender.layer.value(forKey: "pressScale") as? CGFloat ?? 0.92
        UIView.animate(withDuration: 0.14, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            sender.transform = CGAffineTransform(scaleX: scale, y: scale)
            sender.alpha = 0.9
        }
    }

    @objc
    private func buttonPressedUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.2, options: [.curveEaseOut, .beginFromCurrentState]) {
            sender.transform = .identity
            sender.alpha = 1
        }
    }

    private func shouldHandlePreviewGesture(at point: CGPoint) -> Bool {
        let blockedViews: [UIView] = [
            statusCard,
            modeCard,
            toolsToggleButton,
            toolsPanelCard,
            resultCard,
            histogramCard,
            captureButton,
            analyzeButton,
            shareButton,
            brandLinkButton,
            permissionCard,
        ]

        return !blockedViews.contains { !$0.isHidden && $0.alpha > 0.01 && $0.frame.insetBy(dx: -10, dy: -10).contains(point) }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: view)
        return shouldHandlePreviewGesture(at: point)
    }

    @objc
    private func brandLinkTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let url = URL(string: "https://github.com/iPwn666/topwnz-native-ai-cam") else { return }
        UIApplication.shared.open(url)
    }

    private func configurePillButton(_ button: UIButton, title: String, symbolName: String, action: Selector, emphasized: Bool = false) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = emphasized ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: symbolName)
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = emphasized ? UIColor.systemOrange : UIColor.black.withAlphaComponent(0.26)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        installPressAnimation(on: button, pressedScale: 0.96)
    }

    private func embed(_ content: UIView, in card: CameraGlassCard, inset: CGFloat = 14) {
        card.contentView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: inset),
            content.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -inset),
            content.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -inset),
        ])
    }
}

private final class CameraGlassCard: UIVisualEffectView {
    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        clipsToBounds = true
        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.12)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class OverlayGradientView: UIView {
    enum Direction {
        case top
        case bottom
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private let direction: Direction

    init(direction: Direction) {
        self.direction = direction
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        configureGradient()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureGradient() {
        guard let layer = layer as? CAGradientLayer else { return }
        switch direction {
        case .top:
            layer.colors = [
                UIColor.black.withAlphaComponent(0.62).cgColor,
                UIColor.black.withAlphaComponent(0.16).cgColor,
                UIColor.clear.cgColor,
            ]
        case .bottom:
            layer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.18).cgColor,
                UIColor.black.withAlphaComponent(0.72).cgColor,
            ]
        }
        layer.locations = [0, 0.48, 1]
    }
}

private final class FocusIndicatorView: UIView {
    private let horizontal = UIView()
    private let vertical = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 2
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderColor = UIColor.systemYellow.cgColor
        backgroundColor = .clear
        isUserInteractionEnabled = false

        [horizontal, vertical].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            horizontal.centerXAnchor.constraint(equalTo: centerXAnchor),
            horizontal.centerYAnchor.constraint(equalTo: centerYAnchor),
            horizontal.widthAnchor.constraint(equalToConstant: 36),
            horizontal.heightAnchor.constraint(equalToConstant: 2),

            vertical.centerXAnchor.constraint(equalTo: centerXAnchor),
            vertical.centerYAnchor.constraint(equalTo: centerYAnchor),
            vertical.widthAnchor.constraint(equalToConstant: 2),
            vertical.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

private extension AVAuthorizationStatus {
    var isAuthorizedForCamera: Bool {
        self == .authorized
    }
}

private final class ScannerFrameView: UIView {
    private let cornersLayer = CAShapeLayer()
    private let scanLine = UIView()
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.clear

        cornersLayer.strokeColor = UIColor.white.withAlphaComponent(0.92).cgColor
        cornersLayer.fillColor = UIColor.clear.cgColor
        cornersLayer.lineWidth = 5
        cornersLayer.lineCap = .round
        layer.addSublayer(cornersLayer)

        scanLine.translatesAutoresizingMaskIntoConstraints = false
        scanLine.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.92)
        scanLine.layer.cornerRadius = 2
        scanLine.layer.cornerCurve = .continuous
        addSubview(scanLine)

        NSLayoutConstraint.activate([
            scanLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            scanLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            scanLine.heightAnchor.constraint(equalToConstant: 4),
            scanLine.topAnchor.constraint(equalTo: topAnchor, constant: 42),
        ])

        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cornersLayer.frame = bounds
        cornersLayer.path = scannerPath(in: bounds.insetBy(dx: 6, dy: 6)).cgPath
    }

    func setActive(_ active: Bool) {
        if active {
            if !isAnimating {
                startAnimating()
            }
            if alpha < 1 {
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 1
                }
            }
        } else {
            stopAnimating()
            if alpha > 0 {
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 0
                }
            }
        }
    }

    func setDetected(_ detected: Bool) {
        cornersLayer.strokeColor = (detected ? UIColor.systemGreen : UIColor.white.withAlphaComponent(0.92)).cgColor
        scanLine.backgroundColor = (detected ? UIColor.systemGreen : UIColor.systemGreen.withAlphaComponent(0.92))
    }

    func flashDetected() {
        let previous = backgroundColor
        backgroundColor = UIColor.systemGreen.withAlphaComponent(0.16)
        UIView.animate(withDuration: 0.22, delay: 0.08, options: [.curveEaseOut]) {
            self.backgroundColor = previous
        }
    }

    private func startAnimating() {
        isAnimating = true
        scanLine.layer.removeAllAnimations()
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = 42
        animation.toValue = bounds.height - 42
        animation.duration = 1.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scanLine.layer.add(animation, forKey: "scanLineMove")
    }

    private func stopAnimating() {
        isAnimating = false
        scanLine.layer.removeAnimation(forKey: "scanLineMove")
    }

    private func scannerPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let corner: CGFloat = 28

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))

        return path
    }
}

private final class HistogramOverlayView: UIView {
    private let barsLayer = CAShapeLayer()
    private let baselineLayer = CAShapeLayer()
    private var bins: [Double] = Array(repeating: 0, count: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        baselineLayer.strokeColor = UIColor.white.withAlphaComponent(0.12).cgColor
        baselineLayer.fillColor = UIColor.clear.cgColor
        baselineLayer.lineWidth = 1
        layer.addSublayer(baselineLayer)

        barsLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.96).cgColor
        barsLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.22).cgColor
        barsLayer.lineWidth = 1
        layer.addSublayer(barsLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    func update(bins: [Double]) {
        self.bins = bins
        redraw()
    }

    private func redraw() {
        baselineLayer.frame = bounds
        barsLayer.frame = bounds

        let baselinePath = UIBezierPath()
        baselinePath.move(to: CGPoint(x: 0, y: bounds.maxY - 1))
        baselinePath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - 1))
        baselineLayer.path = baselinePath.cgPath

        guard !bins.isEmpty, bounds.width > 0, bounds.height > 0 else {
            barsLayer.path = nil
            return
        }

        let barWidth = bounds.width / CGFloat(bins.count)
        let path = UIBezierPath()
        for (index, value) in bins.enumerated() {
            let x = CGFloat(index) * barWidth
            let insetRect = CGRect(x: x + 1, y: 0, width: max(2, barWidth - 2), height: bounds.height)
            let height = max(2, CGFloat(value) * (bounds.height - 2))
            let rect = CGRect(x: insetRect.minX, y: bounds.maxY - height, width: insetRect.width, height: height)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: min(3, rect.width / 2)))
        }
        barsLayer.path = path.cgPath
    }
}

private final class ZebraOverlayView: UIView {
    private let stripesLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        stripesLayer.strokeColor = UIColor.systemPink.withAlphaComponent(0.8).cgColor
        stripesLayer.fillColor = UIColor.clear.cgColor
        stripesLayer.lineWidth = 1.2
        layer.addSublayer(stripesLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stripesLayer.frame = bounds
    }

    func update(rects: [CGRect]) {
        let path = UIBezierPath()
        for rect in rects where rect.width > 4 && rect.height > 4 {
            let clipped = rect.intersection(bounds)
            guard !clipped.isNull, !clipped.isEmpty else { continue }
            let spacing: CGFloat = 8
            var x = clipped.minX - clipped.height
            while x < clipped.maxX {
                path.move(to: CGPoint(x: x, y: clipped.maxY))
                path.addLine(to: CGPoint(x: x + clipped.height, y: clipped.minY))
                x += spacing
            }
        }
        stripesLayer.path = path.cgPath
    }
}

private final class OCRTextOverlayView: UIView {
    struct DisplayBlock {
        let text: String
        let rect: CGRect
        let confidence: Float
    }

    private let boxesLayer = CAShapeLayer()
    private var blocks: [DisplayBlock] = []
    private var selectedText: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        boxesLayer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.92).cgColor
        boxesLayer.fillColor = UIColor.systemGreen.withAlphaComponent(0.08).cgColor
        boxesLayer.lineWidth = 1.5
        layer.addSublayer(boxesLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        boxesLayer.frame = bounds
        redraw()
    }

    func update(blocks: [DisplayBlock], selectedText: String?) {
        self.blocks = blocks
        self.selectedText = selectedText
        redraw()
    }

    private func redraw() {
        let path = UIBezierPath()
        for block in blocks {
            let rect = block.rect.intersection(bounds).insetBy(dx: -2, dy: -2)
            guard !rect.isNull, !rect.isEmpty else { continue }
            let isSelected = selectedText == block.text
            let box = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            path.append(box)
            if isSelected {
                let marker = CGRect(x: rect.minX, y: rect.minY - 4, width: min(36, rect.width), height: 4)
                path.append(UIBezierPath(roundedRect: marker, cornerRadius: 2))
            }
        }
        boxesLayer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.92).cgColor
        boxesLayer.fillColor = UIColor.systemGreen.withAlphaComponent(0.08).cgColor
        boxesLayer.path = path.cgPath
    }
}

private final class DocumentQuadOverlayView: UIView {
    struct DisplayQuad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint
    }

    private let quadLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        fillLayer.fillColor = UIColor.systemYellow.withAlphaComponent(0.08).cgColor
        layer.addSublayer(fillLayer)

        quadLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.96).cgColor
        quadLayer.fillColor = UIColor.clear.cgColor
        quadLayer.lineWidth = 2.2
        quadLayer.lineJoin = .round
        quadLayer.lineCap = .round
        layer.addSublayer(quadLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(quad: DisplayQuad?) {
        guard let quad else {
            quadLayer.path = nil
            fillLayer.path = nil
            return
        }

        let path = UIBezierPath()
        path.move(to: quad.topLeft)
        path.addLine(to: quad.topRight)
        path.addLine(to: quad.bottomRight)
        path.addLine(to: quad.bottomLeft)
        path.close()
        quadLayer.path = path.cgPath
        fillLayer.path = path.cgPath
    }
}

private final class ObjectDetectionOverlayView: UIView {
    struct DisplayObject {
        let label: String
        let confidence: Float
        let rect: CGRect
    }

    private let boxesLayer = CAShapeLayer()
    private var labelViews: [UILabel] = []
    private var objects: [DisplayObject] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        boxesLayer.strokeColor = UIColor.systemIndigo.withAlphaComponent(0.96).cgColor
        boxesLayer.fillColor = UIColor.systemIndigo.withAlphaComponent(0.08).cgColor
        boxesLayer.lineWidth = 2
        layer.addSublayer(boxesLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        boxesLayer.frame = bounds
        redraw()
    }

    func update(objects: [DisplayObject]) {
        self.objects = objects
        redraw()
    }

    private func redraw() {
        labelViews.forEach { $0.removeFromSuperview() }
        labelViews.removeAll()

        let path = UIBezierPath()
        for object in objects {
            let rect = object.rect.intersection(bounds).insetBy(dx: -1, dy: -1)
            guard !rect.isNull, !rect.isEmpty else { continue }

            path.append(UIBezierPath(roundedRect: rect, cornerRadius: 10))

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 10, weight: .bold)
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.92)
            label.layer.cornerRadius = 7
            label.layer.cornerCurve = .continuous
            label.clipsToBounds = true
            label.text = "\(object.label) \(Int((object.confidence * 100).rounded()))%"
            addSubview(label)
            labelViews.append(label)

            let width = min(max(label.intrinsicContentSize.width + 12, 70), max(70, rect.width))
            let height: CGFloat = 20
            let x = max(bounds.minX + 4, min(rect.minX, bounds.maxX - width - 4))
            let y = max(bounds.minY + 4, rect.minY - height - 4)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
                label.topAnchor.constraint(equalTo: topAnchor, constant: y),
                label.widthAnchor.constraint(equalToConstant: width),
                label.heightAnchor.constraint(equalToConstant: height),
            ])
        }
        boxesLayer.path = path.cgPath
    }
}

private final class GridOverlayView: UIView {
    private let linesLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        linesLayer.strokeColor = UIColor.white.withAlphaComponent(0.18).cgColor
        linesLayer.fillColor = UIColor.clear.cgColor
        linesLayer.lineWidth = 1
        layer.addSublayer(linesLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        linesLayer.frame = bounds
        let path = UIBezierPath()
        let thirdWidth = bounds.width / 3
        let thirdHeight = bounds.height / 3

        for index in 1 ... 2 {
            let x = thirdWidth * CGFloat(index)
            path.move(to: CGPoint(x: x, y: bounds.minY))
            path.addLine(to: CGPoint(x: x, y: bounds.maxY))

            let y = thirdHeight * CGFloat(index)
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        linesLayer.path = path.cgPath
    }
}

private final class HorizonLevelView: UIView {
    private let centerMark = UIView()
    private let liveMark = UIView()
    private let angleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.18)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        centerMark.translatesAutoresizingMaskIntoConstraints = false
        centerMark.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        centerMark.layer.cornerRadius = 1
        addSubview(centerMark)

        liveMark.translatesAutoresizingMaskIntoConstraints = false
        liveMark.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.92)
        liveMark.layer.cornerRadius = 1.5
        addSubview(liveMark)

        angleLabel.translatesAutoresizingMaskIntoConstraints = false
        angleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        angleLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        angleLabel.textAlignment = .center
        angleLabel.text = "0.0°"
        addSubview(angleLabel)

        NSLayoutConstraint.activate([
            centerMark.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerMark.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerMark.widthAnchor.constraint(equalToConstant: 62),
            centerMark.heightAnchor.constraint(equalToConstant: 2),

            liveMark.centerXAnchor.constraint(equalTo: centerXAnchor),
            liveMark.centerYAnchor.constraint(equalTo: centerYAnchor),
            liveMark.widthAnchor.constraint(equalToConstant: 50),
            liveMark.heightAnchor.constraint(equalToConstant: 3),

            angleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            angleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rollDegrees: Double) {
        let clamped = max(-45, min(rollDegrees, 45))
        let offset = CGFloat(clamped / 45.0) * 46
        liveMark.transform = CGAffineTransform(translationX: offset, y: 0).rotated(by: CGFloat(rollDegrees * .pi / 180))
        angleLabel.text = String(format: "%.1f°", rollDegrees)
        let leveled = abs(rollDegrees) < 1.5
        liveMark.backgroundColor = leveled ? UIColor.systemGreen.withAlphaComponent(0.92) : UIColor.systemOrange.withAlphaComponent(0.92)
    }
}

extension CameraViewController: CNContactViewControllerDelegate, EKEventEditViewDelegate {
    nonisolated func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        Task { @MainActor in
            viewController.presentingViewController?.dismiss(animated: true)
        }
    }

    nonisolated func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        Task { @MainActor in
            controller.dismiss(animated: true)
        }
    }
}

extension CameraViewController: @preconcurrency AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeakingResult = false
            self.refreshUI()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeakingResult = false
            self.refreshUI()
        }
    }
}
#endif
