import Foundation

enum AnalysisMode: String, CaseIterable, Identifiable, Codable {
    case scene
    case text
    case shopping
    case creative

    var id: String { rawValue }
}

enum CaptureEffect: String, CaseIterable, Identifiable, Codable {
    case natural
    case vivid
    case mono
    case noir

    var id: String { rawValue }
}

enum WhiteBalancePreset: String, CaseIterable, Identifiable, Codable {
    case auto
    case warm
    case cool

    var id: String { rawValue }
}

enum FocusModePreset: String, CaseIterable, Identifiable, Codable {
    case auto
    case manual

    var id: String { rawValue }
}

enum FrameProcessorProfile: String, CaseIterable, Identifiable, Codable {
    case off
    case balanced
    case documents
    case detection
    case full
    case custom

    var id: String { rawValue }
}

struct AppSettings: Equatable, Codable {
    static let shutterPresets: [Double] = [0, 1.0 / 1000.0, 1.0 / 500.0, 1.0 / 250.0, 1.0 / 125.0, 1.0 / 60.0, 1.0 / 30.0, 1.0 / 15.0, 1.0 / 8.0, 1.0 / 4.0, 1.0 / 2.0, 1.0]

    var apiKey: String
    var model: String
    var autoAnalyze: Bool
    var locationMetadataEnabled: Bool
    var frameProcessorProfile: FrameProcessorProfile
    var frameProcessorTargetFPS: Int
    var analysisMode: AnalysisMode
    var exposureBias: Double
    var shutterDurationSeconds: Double
    var isoValue: Double
    var whiteBalancePreset: WhiteBalancePreset
    var focusMode: FocusModePreset
    var manualFocusPosition: Double
    var captureEffect: CaptureEffect

    enum CodingKeys: String, CodingKey {
        case apiKey
        case model
        case autoAnalyze
        case locationMetadataEnabled
        case frameProcessorProfile
        case frameProcessorTargetFPS
        case analysisMode
        case exposureBias
        case shutterDurationSeconds
        case isoValue
        case whiteBalancePreset
        case focusMode
        case manualFocusPosition
        case captureEffect
    }

    init(
        apiKey: String,
        model: String,
        autoAnalyze: Bool,
        locationMetadataEnabled: Bool,
        frameProcessorProfile: FrameProcessorProfile,
        frameProcessorTargetFPS: Int,
        analysisMode: AnalysisMode,
        exposureBias: Double,
        shutterDurationSeconds: Double,
        isoValue: Double,
        whiteBalancePreset: WhiteBalancePreset,
        focusMode: FocusModePreset,
        manualFocusPosition: Double,
        captureEffect: CaptureEffect
    ) {
        self.apiKey = apiKey
        self.model = model
        self.autoAnalyze = autoAnalyze
        self.locationMetadataEnabled = locationMetadataEnabled
        self.frameProcessorProfile = frameProcessorProfile
        self.frameProcessorTargetFPS = frameProcessorTargetFPS
        self.analysisMode = analysisMode
        self.exposureBias = exposureBias
        self.shutterDurationSeconds = shutterDurationSeconds
        self.isoValue = isoValue
        self.whiteBalancePreset = whiteBalancePreset
        self.focusMode = focusMode
        self.manualFocusPosition = manualFocusPosition
        self.captureEffect = captureEffect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "gpt-5.4"
        autoAnalyze = try container.decodeIfPresent(Bool.self, forKey: .autoAnalyze) ?? false
        locationMetadataEnabled = try container.decodeIfPresent(Bool.self, forKey: .locationMetadataEnabled) ?? false
        frameProcessorProfile = try container.decodeIfPresent(FrameProcessorProfile.self, forKey: .frameProcessorProfile) ?? .off
        frameProcessorTargetFPS = try container.decodeIfPresent(Int.self, forKey: .frameProcessorTargetFPS) ?? 10
        analysisMode = try container.decodeIfPresent(AnalysisMode.self, forKey: .analysisMode) ?? .scene
        exposureBias = try container.decodeIfPresent(Double.self, forKey: .exposureBias) ?? 0
        shutterDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .shutterDurationSeconds) ?? 0
        isoValue = try container.decodeIfPresent(Double.self, forKey: .isoValue) ?? 0
        whiteBalancePreset = try container.decodeIfPresent(WhiteBalancePreset.self, forKey: .whiteBalancePreset) ?? .auto
        focusMode = try container.decodeIfPresent(FocusModePreset.self, forKey: .focusMode) ?? .auto
        manualFocusPosition = try container.decodeIfPresent(Double.self, forKey: .manualFocusPosition) ?? 0.5
        captureEffect = try container.decodeIfPresent(CaptureEffect.self, forKey: .captureEffect) ?? .natural
    }

    static let `default` = AppSettings(
        apiKey: "",
        model: "gpt-5.4",
        autoAnalyze: false,
        locationMetadataEnabled: false,
        frameProcessorProfile: .off,
        frameProcessorTargetFPS: 10,
        analysisMode: .scene,
        exposureBias: 0,
        shutterDurationSeconds: 0,
        isoValue: 0,
        whiteBalancePreset: .auto,
        focusMode: .auto,
        manualFocusPosition: 0.5,
        captureEffect: .natural
    )
}
