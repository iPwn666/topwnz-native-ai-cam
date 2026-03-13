#if canImport(AVFoundation) && canImport(UIKit)
@preconcurrency import AVFoundation
#if canImport(CoreML)
import CoreML
#endif
import Foundation
import ImageIO
import Vision
import UIKit

enum CameraServiceError: LocalizedError {
    case unauthorized
    case cameraUnavailable
    case captureInProgress
    case captureUnavailable
    case imageDataUnavailable
    case recordingUnavailable
    case notRecording

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return AppStrings.permissionBody
        case .cameraUnavailable:
            return AppStrings.cameraUnavailable
        case .captureInProgress:
            return AppStrings.isCzech ? "Zpracovává se předchozí snímek." : "The previous capture is still in progress."
        case .captureUnavailable:
            return AppStrings.isCzech ? "Kamera ještě není připravená na pořízení fotky." : "The camera is not ready to capture a photo yet."
        case .imageDataUnavailable:
            return AppStrings.isCzech ? "Nepodařilo se vytvořit obrazová data." : "Failed to produce image data."
        case .recordingUnavailable:
            return AppStrings.isCzech ? "Video záznam teď není k dispozici." : "Video recording is unavailable right now."
        case .notRecording:
            return AppStrings.isCzech ? "Žádný video záznam právě neběží." : "No video recording is currently active."
        }
    }
}

struct ScannedCode: Equatable, Sendable {
    struct WiFiPayload: Equatable, Sendable {
        let ssid: String
        let password: String
        let security: String
        let isHidden: Bool
    }

    struct ContactPayload: Equatable, Sendable {
        let fullName: String
        let phone: String?
        let email: String?
        let organization: String?
    }

    struct EventPayload: Equatable, Sendable {
        let title: String
        let startDate: Date?
        let endDate: Date?
        let location: String?
        let notes: String?
    }

    struct LocationPayload: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        let label: String?
    }

    enum Kind: Equatable, Sendable {
        case url(URL)
        case email(String)
        case phone(String)
        case sms(String)
        case wifi(WiFiPayload)
        case location(LocationPayload)
        case contact(ContactPayload)
        case event(EventPayload)
        case faceTime(String)
        case text
    }

    let payload: String
    let type: String

    var kind: Kind {
        if let wifi = parseWiFiPayload(payload) {
            return .wifi(wifi)
        }
        if let contact = parseVCardPayload(payload) ?? parseMeCardPayload(payload) {
            return .contact(contact)
        }
        if let event = parseEventPayload(payload) {
            return .event(event)
        }
        if let location = parseGeoPayload(payload) {
            return .location(location)
        }

        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("facetime:") {
            let value = String(trimmed.dropFirst("facetime:".count))
            return .faceTime(value)
        }
        if let email = parseMATMSGEmail(trimmed) {
            return .email(email)
        }
        if let sms = parseSMSPayload(trimmed) {
            return .sms(sms)
        }
        if let url = URL(string: trimmed),
           ["http", "https"].contains(url.scheme?.lowercased()) {
            return .url(url)
        }
        if trimmed.lowercased().hasPrefix("mailto:") {
            let value = String(trimmed.dropFirst("mailto:".count))
            return .email(value)
        }
        if trimmed.lowercased().hasPrefix("tel:") {
            let value = String(trimmed.dropFirst("tel:".count))
            return .phone(value)
        }
        if trimmed.lowercased().hasPrefix("sms:") {
            let value = String(trimmed.dropFirst("sms:".count))
            return .sms(value)
        }
        if trimmed.contains("@"), !trimmed.contains(" "), trimmed.contains(".") {
            return .email(trimmed)
        }

        let digits = trimmed.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if digits.count >= 7, digits.first?.isNumber == true || digits.first == "+" {
            return .phone(digits)
        }

        return .text
    }

    var primaryActionURL: URL? {
        switch kind {
        case .url(let url):
            return url
        case .email(let value):
            return URL(string: "mailto:\(value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value)")
        case .phone(let value):
            return URL(string: "tel:\(value)")
        case .sms(let value):
            return URL(string: "sms:\(value)")
        case .wifi:
            return URL(string: "App-Prefs:root=WIFI")
        case .location(let value):
            let label = value.label?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "http://maps.apple.com/?ll=\(value.latitude),\(value.longitude)&q=\(label)")
        case .faceTime(let value):
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
            return URL(string: "facetime://\(encoded)")
        case .contact, .event:
            return nil
        case .text:
            return nil
        }
    }

    var primaryActionTitle: String? {
        switch kind {
        case .url:
            return AppStrings.openLink
        case .email:
            return AppStrings.openMail
        case .phone:
            return AppStrings.openPhone
        case .sms:
            return AppStrings.openMessage
        case .wifi:
            return AppStrings.openWiFiSettings
        case .location:
            return AppStrings.openMaps
        case .faceTime:
            return AppStrings.openFaceTime
        case .contact:
            return AppStrings.addContact
        case .event:
            return AppStrings.addEvent
        case .text:
            return nil
        }
    }

    var hasPrimaryAction: Bool {
        switch kind {
        case .text:
            return false
        default:
            return true
        }
    }

    var isURL: Bool {
        if case .url = kind { return true }
        return false
    }

    var formattedDetails: String {
        switch kind {
        case .wifi(let wifi):
            var lines = [
                "\(AppStrings.wifiSSID): \(wifi.ssid)",
                "\(AppStrings.wifiSecurity): \(wifi.security.isEmpty ? "-" : wifi.security)",
            ]
            if !wifi.password.isEmpty {
                lines.append("\(AppStrings.wifiPassword): \(wifi.password)")
            }
            if wifi.isHidden {
                lines.append("\(AppStrings.wifiHidden): ano")
            }
            return lines.joined(separator: "\n")
        case .contact(let contact):
            var lines: [String] = []
            lines.append("\(AppStrings.contactName): \(contact.fullName)")
            if let phone = contact.phone, !phone.isEmpty {
                lines.append("\(AppStrings.contactPhone): \(phone)")
            }
            if let email = contact.email, !email.isEmpty {
                lines.append("\(AppStrings.contactEmail): \(email)")
            }
            if let organization = contact.organization, !organization.isEmpty {
                lines.append("\(AppStrings.contactOrganization): \(organization)")
            }
            return lines.joined(separator: "\n")
        case .event(let event):
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            var lines = ["\(AppStrings.eventTitle): \(event.title)"]
            if let startDate = event.startDate {
                lines.append("\(AppStrings.eventStart): \(formatter.string(from: startDate))")
            }
            if let endDate = event.endDate {
                lines.append("\(AppStrings.eventEnd): \(formatter.string(from: endDate))")
            }
            if let location = event.location, !location.isEmpty {
                lines.append("\(AppStrings.eventLocation): \(location)")
            }
            if let notes = event.notes, !notes.isEmpty {
                lines.append("\(AppStrings.eventNotes): \(notes)")
            }
            return lines.joined(separator: "\n")
        case .location(let location):
            var lines = ["\(AppStrings.locationCoordinates): \(location.latitude), \(location.longitude)"]
            if let label = location.label, !label.isEmpty {
                lines.append(label)
            }
            return lines.joined(separator: "\n")
        default:
            return payload
        }
    }

    private func parseWiFiPayload(_ value: String) -> WiFiPayload? {
        guard value.uppercased().hasPrefix("WIFI:") else { return nil }
        let rawBody = String(value.dropFirst(5))
        let segments = splitEscapedSegments(rawBody)
        var parsed: [String: String] = [:]
        for segment in segments {
            guard let separator = segment.firstIndex(of: ":") else { continue }
            let key = String(segment[..<separator]).uppercased()
            let content = String(segment[segment.index(after: separator)...])
            parsed[key] = unescapeWiFi(content)
        }

        guard let ssid = parsed["S"], !ssid.isEmpty else { return nil }
        let password = parsed["P"] ?? ""
        let security = parsed["T"] ?? ""
        let isHidden = ["true", "1", "yes"].contains((parsed["H"] ?? "").lowercased())
        return WiFiPayload(ssid: ssid, password: password, security: security, isHidden: isHidden)
    }

    private func splitEscapedSegments(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var isEscaped = false

        for character in input {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == ";" {
                if !current.isEmpty {
                    parts.append(current)
                }
                current = ""
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func unescapeWiFi(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\:", with: ":")
    }

    private func parseVCardPayload(_ value: String) -> ContactPayload? {
        guard value.uppercased().contains("BEGIN:VCARD") else { return nil }
        let fields = parseStructuredLines(value)
        let fullName = fields["FN"] ?? composeName(from: fields["N"]) ?? ""
        guard !fullName.isEmpty || fields["TEL"] != nil || fields["EMAIL"] != nil else { return nil }
        return ContactPayload(
            fullName: fullName.isEmpty ? "Kontakt" : fullName,
            phone: fields["TEL"],
            email: fields["EMAIL"],
            organization: fields["ORG"]
        )
    }

    private func parseMeCardPayload(_ value: String) -> ContactPayload? {
        guard value.uppercased().hasPrefix("MECARD:") else { return nil }
        let body = String(value.dropFirst("MECARD:".count))
        let parts = splitEscapedSegments(body)
        var parsed: [String: String] = [:]
        for part in parts {
            guard let separator = part.firstIndex(of: ":") else { continue }
            let key = String(part[..<separator]).uppercased()
            let content = String(part[part.index(after: separator)...])
            parsed[key] = unescapeWiFi(content)
        }
        guard let rawName = parsed["N"] ?? parsed["SOUND"] ?? parsed["ORG"] else { return nil }
        let nameComponents = rawName.split(separator: ",")
        let fullName = nameComponents.reversed().joined(separator: " ")
        return ContactPayload(
            fullName: fullName.isEmpty ? rawName : fullName,
            phone: parsed["TEL"],
            email: parsed["EMAIL"],
            organization: parsed["ORG"]
        )
    }

    private func parseEventPayload(_ value: String) -> EventPayload? {
        guard value.uppercased().contains("BEGIN:VEVENT") else { return nil }
        let fields = parseStructuredLines(value)
        guard let title = fields["SUMMARY"] ?? fields["DESCRIPTION"] else { return nil }
        return EventPayload(
            title: title,
            startDate: parseICSDate(fields["DTSTART"]),
            endDate: parseICSDate(fields["DTEND"]),
            location: fields["LOCATION"],
            notes: fields["DESCRIPTION"]
        )
    }

    private func parseGeoPayload(_ value: String) -> LocationPayload? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("geo:") else { return nil }
        let body = String(trimmed.dropFirst(4))
        let parts = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let coordinates = parts.first?.split(separator: ",").map(String.init) ?? []
        guard coordinates.count >= 2,
              let latitude = Double(coordinates[0]),
              let longitude = Double(coordinates[1]) else { return nil }

        var label: String?
        if parts.count == 2 {
            let query = String(parts[1])
            if let range = query.range(of: "q=") {
                label = String(query[range.upperBound...]).removingPercentEncoding
            }
        }
        return LocationPayload(latitude: latitude, longitude: longitude, label: label)
    }

    private func parseMATMSGEmail(_ value: String) -> String? {
        guard value.uppercased().hasPrefix("MATMSG:") else { return nil }
        let body = String(value.dropFirst("MATMSG:".count))
        let parts = splitEscapedSegments(body)
        for part in parts {
            guard let separator = part.firstIndex(of: ":") else { continue }
            let key = String(part[..<separator]).uppercased()
            if key == "TO" {
                return String(part[part.index(after: separator)...])
            }
        }
        return nil
    }

    private func parseSMSPayload(_ value: String) -> String? {
        let upper = value.uppercased()
        if upper.hasPrefix("SMSTO:") {
            let body = String(value.dropFirst("SMSTO:".count))
            return body.split(separator: ":").first.map(String.init)
        }
        if upper.hasPrefix("SMS:") {
            return String(value.dropFirst("SMS:".count))
        }
        return nil
    }

    private func parseStructuredLines(_ value: String) -> [String: String] {
        let normalized = value
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var result: [String: String] = [:]
        for line in normalized.split(separator: "\n").map(String.init) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let rawKey = String(line[..<separator])
            let key = rawKey.split(separator: ";").first.map(String.init)?.uppercased() ?? rawKey.uppercased()
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, result[key] == nil {
                result[key] = value
            }
        }
        return result
    }

    private func composeName(from value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        if parts.count >= 2 {
            return [parts[1], parts[0]].joined(separator: " ")
        }
        return parts.joined(separator: " ")
    }

    private func parseICSDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatters: [(String, TimeZone?)] = [
            ("yyyyMMdd'T'HHmmss'Z'", TimeZone(secondsFromGMT: 0)),
            ("yyyyMMdd'T'HHmmss", TimeZone.current),
            ("yyyyMMdd", TimeZone.current),
        ]
        for (format, timeZone) in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            formatter.timeZone = timeZone
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

struct FrameMonitoringSample {
    let histogram: [Double]
    let overexposedRects: [CGRect]
    let averageLuma: Double
    let focusScore: Double
    let focusPeakingRects: [CGRect]
}

struct RecognizedTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

struct TextRecognitionSample {
    let blocks: [RecognizedTextBlock]
    let combinedText: String
}

struct DetectedDocumentQuad {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
    let confidence: VNConfidence
}

struct ImageClassificationLabel: Equatable, Sendable {
    let title: String
    let confidence: Float
}

struct ImageClassificationSample: Equatable, Sendable {
    let labels: [ImageClassificationLabel]

    var combinedText: String {
        labels
            .prefix(4)
            .map { "\($0.title) (\(Int(($0.confidence * 100).rounded()))%)" }
            .joined(separator: "\n")
    }

    var compactSummary: String {
        labels
            .prefix(3)
            .map { "\($0.title) \(Int(($0.confidence * 100).rounded()))%" }
            .joined(separator: " • ")
    }
}

struct DetectedObject: Equatable, Sendable {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}

struct ObjectDetectionSample: Equatable, Sendable {
    let objects: [DetectedObject]

    var combinedText: String {
        objects
            .prefix(5)
            .map { "\($0.label) (\(Int(($0.confidence * 100).rounded()))%)" }
            .joined(separator: "\n")
    }

    var compactSummary: String {
        objects
            .prefix(4)
            .map { "\($0.label) \(Int(($0.confidence * 100).rounded()))%" }
            .joined(separator: " • ")
    }
}

final class CameraService: NSObject, @unchecked Sendable {
    private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    var hasFlash: Bool { videoInput?.device.hasFlash == true }
    var hasTorch: Bool { videoInput?.device.hasTorch == true }
    var canFocus: Bool { videoInput?.device.isFocusPointOfInterestSupported == true }
    var minZoomFactor: CGFloat { 1.0 }
    var maxZoomFactor: CGFloat { min(videoInput?.device.maxAvailableVideoZoomFactor ?? 1.0, 6.0) }
    var zoomFactor: CGFloat { videoInput?.device.videoZoomFactor ?? 1.0 }
    var supports60FPS: Bool {
        supportedFrameRates(for: videoInput?.device).contains(60)
    }
    var supportsLowLightBoost: Bool {
        videoInput?.device != nil
    }
    var lastError: String?

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "AIKameraNative.CameraSession")
#if canImport(CoreML)
    private let coreMLInstaller = CoreMLModelInstaller()
#endif

    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<Data, Error>?
    private var recordingStopContinuation: CheckedContinuation<URL, Error>?
    private var recordingOutputURL: URL?
    private var preferredFPS = 30
    private var lowLightBoostEnabled = false
    private var exposureBias: Float = 0
    private var manualShutterDuration: Double = 0
    private var manualISO: Float = 0
    private var whiteBalancePreset: WhiteBalancePreset = .auto
    private var focusModePreset: FocusModePreset = .auto
    private var manualFocusPosition: Float = 0.5
    private var focusExposureLockEnabled = false
    private var torchEnabled = false
    private var scannerEnabled = false
    private var textRecognitionEnabled = false
    private var documentDetectionEnabled = false
    private var mlClassificationEnabled = false
    private var objectDetectionEnabled = false
    private var isProcessingTextRecognition = false
    private var isProcessingDocumentDetection = false
    private var isProcessingMLClassification = false
    private var isProcessingObjectDetection = false
#if canImport(CoreML)
    private var downloadedCoreMLVisionModel: VNCoreMLModel?
    private var downloadedObjectDetectorVisionModel: VNCoreMLModel?
#endif
    private var scannerRectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var lastScannedCode: String?
    private var lastScannedAt = Date.distantPast
    private var lastMonitoringSampleUptime: TimeInterval = 0
    private var lastTextRecognitionUptime: TimeInterval = 0
    private var lastDocumentDetectionUptime: TimeInterval = 0
    private var lastMLClassificationUptime: TimeInterval = 0
    private var lastObjectDetectionUptime: TimeInterval = 0
    private var classificationHistory: [ImageClassificationSample] = []
    private var objectDetectionHistory: [ObjectDetectionSample] = []

    var onCodeScanned: ((ScannedCode) -> Void)?
    var onMonitoringSample: ((FrameMonitoringSample) -> Void)?
    var onRecognizedText: ((TextRecognitionSample) -> Void)?
    var onDetectedDocument: ((DetectedDocumentQuad?) -> Void)?
    var onImageClassification: ((ImageClassificationSample?) -> Void)?
    var onDetectedObjects: ((ObjectDetectionSample?) -> Void)?

    var currentFPS: Int { preferredFPS }
    var isLowLightBoostEnabled: Bool { lowLightBoostEnabled }
    var currentExposureBias: Float { exposureBias }
    var currentShutterDurationSeconds: Double { manualShutterDuration }
    var currentISO: Float { manualISO > 0 ? manualISO : (videoInput?.device.iso ?? 0) }
    var minISOValue: Float { videoInput?.device.activeFormat.minISO ?? 0 }
    var maxISOValue: Float { videoInput?.device.activeFormat.maxISO ?? 1600 }
    var currentWhiteBalancePreset: WhiteBalancePreset { whiteBalancePreset }
    var currentFocusModePreset: FocusModePreset { focusModePreset }
    var currentManualFocusPosition: Float { manualFocusPosition }
    var isFocusExposureLocked: Bool { focusExposureLockEnabled }
    var supportsManualFocus: Bool { videoInput?.device.isLockingFocusWithCustomLensPositionSupported == true }
    var isTorchEnabled: Bool { torchEnabled }
    var isRecordingVideo: Bool { movieOutput.isRecording }
    var isScannerEnabled: Bool { scannerEnabled }
    var isTextRecognitionEnabled: Bool { textRecognitionEnabled }
    var isDocumentDetectionEnabled: Bool { documentDetectionEnabled }
    var isMLClassificationEnabled: Bool { mlClassificationEnabled }
    var isObjectDetectionEnabled: Bool { objectDetectionEnabled }
    private func supportedFrameRates(for device: AVCaptureDevice?) -> [Int] {
        guard let device else { return [30] }
        let rates = device.formats.flatMap { format in
            format.videoSupportedFrameRateRanges.flatMap { range -> [Int] in
                var values: [Int] = []
                if range.maxFrameRate >= 30 { values.append(30) }
                if range.maxFrameRate >= 60 { values.append(60) }
                return values
            }
        }
        return Array(Set(rates)).sorted()
    }

    private var supportedFrameRates: [Int] {
        let rates = videoInput?.device.activeFormat.videoSupportedFrameRateRanges.flatMap { range -> [Int] in
            var values: [Int] = []
            if range.maxFrameRate >= 30 { values.append(30) }
            if range.maxFrameRate >= 60 { values.append(60) }
            return values
        } ?? [30]
        return Array(Set(rates)).sorted()
    }

    func requestAccessIfNeeded() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status

        switch status {
        case .authorized:
            try? await prepareSession()
            startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            let updated = AVCaptureDevice.authorizationStatus(for: .video)
            authorizationStatus = updated
            if granted {
                try? await prepareSession()
                startSession()
            }
        default:
            break
        }
    }

    func prepareSession() async throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraServiceError.unauthorized
        }

        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                if self.isConfigured, self.videoInput != nil {
                    continuation.resume()
                    return
                }
                do {
                    try self.configureSession(for: self.currentPosition)
                    self.lastError = nil
                    continuation.resume()
                } catch {
                    self.lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleCamera() async throws {
        let nextPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try self.configureSession(for: nextPosition)
                    self.currentPosition = nextPosition
                    continuation.resume()
                } catch {
                    self.lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func capturePhoto(flashEnabled: Bool) async throws -> Data {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraServiceError.unauthorized
        }

        try await prepareSession()
        startSession()

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.captureContinuation == nil else {
                    continuation.resume(throwing: CameraServiceError.captureInProgress)
                    return
                }

                guard self.session.isRunning,
                      let connection = self.photoOutput.connection(with: .video),
                      connection.isEnabled else {
                    continuation.resume(throwing: CameraServiceError.captureUnavailable)
                    return
                }

                self.captureContinuation = continuation
                let settings = AVCapturePhotoSettings()
                settings.flashMode = flashEnabled && (self.videoInput?.device.hasFlash == true) ? .on : .off
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func startRecording(flashEnabled: Bool) async throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraServiceError.unauthorized
        }

        try await prepareSession()
        startSession()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                guard !self.movieOutput.isRecording,
                      self.session.isRunning else {
                    continuation.resume(throwing: CameraServiceError.recordingUnavailable)
                    return
                }

                let outputURL = self.recordingsDirectory()
                    .appendingPathComponent("AIKameraNative-\(UUID().uuidString)")
                    .appendingPathExtension("mov")

                try? FileManager.default.removeItem(at: outputURL)

                guard let connection = self.movieOutput.connection(with: .video) else {
                    continuation.resume(throwing: CameraServiceError.recordingUnavailable)
                    return
                }

                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if self.currentPosition == .front, connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }

                if let audioConnection = self.movieOutput.connection(with: .audio), audioConnection.isEnabled == false {
                    audioConnection.isEnabled = false
                }

                self.recordingOutputURL = outputURL
                self.lastError = nil
                self.movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                continuation.resume()
            }
        }
    }

    func stopRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.movieOutput.isRecording else {
                    continuation.resume(throwing: CameraServiceError.notRecording)
                    return
                }

                self.recordingStopContinuation = continuation
                self.movieOutput.stopRecording()
            }
        }
    }

    func setZoomFactor(_ factor: CGFloat) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume()
                    return
                }

                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = max(self.minZoomFactor, min(factor, self.maxZoomFactor))
                    device.unlockForConfiguration()
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume()
            }
        }
    }

    func setPreferredFPS(_ fps: Int) async -> Int {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.preferredFPS)
                    return
                }

                let supported = self.supportedFrameRates(for: device).contains(fps)
                guard supported else {
                    self.lastError = "\(fps) FPS unsupported."
                    continuation.resume(returning: self.preferredFPS)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    if let format = self.bestFormat(for: device, preferredFPS: fps) {
                        device.activeFormat = format
                    }
                    let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                    device.unlockForConfiguration()
                    self.preferredFPS = fps
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.preferredFPS)
            }
        }
    }

    func setLowLightBoost(enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.lowLightBoostEnabled)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    self.manualISO = 0
                    self.manualShutterDuration = 0
                    if device.isLowLightBoostSupported {
                        device.automaticallyEnablesLowLightBoostWhenAvailable = enabled
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    let preferredBias = enabled ? min(device.maxExposureTargetBias, max(self.exposureBias, 1.5)) : self.exposureBias
                    let boundedBias = max(device.minExposureTargetBias, preferredBias)
                    device.setExposureTargetBias(boundedBias, completionHandler: nil)
                    device.unlockForConfiguration()
                    self.lowLightBoostEnabled = enabled
                    self.exposureBias = boundedBias
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.lowLightBoostEnabled)
            }
        }
    }

    func setExposureBias(_ value: Float) async -> Float {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.exposureBias)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    self.manualISO = 0
                    self.manualShutterDuration = 0
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    let bounded = max(device.minExposureTargetBias, min(value, device.maxExposureTargetBias))
                    device.setExposureTargetBias(bounded, completionHandler: nil)
                    device.unlockForConfiguration()
                    self.exposureBias = bounded
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.exposureBias)
            }
        }
    }

    func setManualISO(_ value: Float) async -> Float {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.manualISO)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    let minISO = device.activeFormat.minISO
                    let maxISO = device.activeFormat.maxISO

                    if value <= minISO {
                        self.manualISO = 0
                        if self.manualShutterDuration > 0 {
                            let duration = self.clampedExposureDuration(seconds: self.manualShutterDuration, for: device)
                            let currentISO = max(minISO, min(device.iso, maxISO))
                            device.setExposureModeCustom(duration: duration, iso: currentISO, completionHandler: nil)
                        } else if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                        }
                        if self.manualShutterDuration == 0 {
                            let boundedBias = max(device.minExposureTargetBias, min(self.exposureBias, device.maxExposureTargetBias))
                            device.setExposureTargetBias(boundedBias, completionHandler: nil)
                        }
                    } else {
                        let boundedISO = max(minISO, min(value, maxISO))
                        let duration = self.manualShutterDuration > 0
                            ? self.clampedExposureDuration(seconds: self.manualShutterDuration, for: device)
                            : (device.exposureDuration.isValid ? device.exposureDuration : CMTime(value: 1, timescale: 60))
                        device.setExposureModeCustom(duration: duration, iso: boundedISO, completionHandler: nil)
                        self.manualISO = boundedISO
                        self.lowLightBoostEnabled = false
                    }
                    device.unlockForConfiguration()
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.manualISO)
            }
        }
    }

    func setManualShutterDuration(_ seconds: Double) async -> Double {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.manualShutterDuration)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    if seconds <= 0 {
                        self.manualShutterDuration = 0
                        if self.manualISO > 0 {
                            let boundedISO = max(device.activeFormat.minISO, min(self.manualISO, device.activeFormat.maxISO))
                            let duration = device.exposureDuration.isValid ? device.exposureDuration : CMTime(value: 1, timescale: 60)
                            device.setExposureModeCustom(duration: duration, iso: boundedISO, completionHandler: nil)
                        } else if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                            let boundedBias = max(device.minExposureTargetBias, min(self.exposureBias, device.maxExposureTargetBias))
                            device.setExposureTargetBias(boundedBias, completionHandler: nil)
                        }
                    } else {
                        let duration = self.clampedExposureDuration(seconds: seconds, for: device)
                        let boundedSeconds = CMTimeGetSeconds(duration)
                        let iso = self.manualISO > 0
                            ? max(device.activeFormat.minISO, min(self.manualISO, device.activeFormat.maxISO))
                            : max(device.activeFormat.minISO, min(device.iso, device.activeFormat.maxISO))
                        device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
                        self.manualShutterDuration = boundedSeconds
                        self.lowLightBoostEnabled = false
                    }
                    device.unlockForConfiguration()
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.manualShutterDuration)
            }
        }
    }

    func setWhiteBalancePreset(_ preset: WhiteBalancePreset) async -> WhiteBalancePreset {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.whiteBalancePreset)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    switch preset {
                    case .auto:
                        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                            device.whiteBalanceMode = .continuousAutoWhiteBalance
                        }
                    case .warm, .cool:
                        if device.isWhiteBalanceModeSupported(.locked) {
                            let target = self.whiteBalanceGains(for: preset, device: device)
                            device.setWhiteBalanceModeLocked(with: target, completionHandler: nil)
                        }
                    }
                    device.unlockForConfiguration()
                    self.whiteBalancePreset = preset
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.whiteBalancePreset)
            }
        }
    }

    func setFocusModePreset(_ preset: FocusModePreset) async -> FocusModePreset {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.focusModePreset)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    switch preset {
                    case .auto:
                        if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        } else if device.isFocusModeSupported(.autoFocus) {
                            device.focusMode = .autoFocus
                        }
                        self.focusModePreset = .auto
                    case .manual:
                        if device.isLockingFocusWithCustomLensPositionSupported {
                            let bounded = max(0, min(device.lensPosition, 1))
                            device.setFocusModeLocked(lensPosition: bounded, completionHandler: nil)
                            self.manualFocusPosition = bounded
                            self.focusModePreset = .manual
                        } else if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                            self.focusModePreset = .auto
                        }
                    }
                    device.unlockForConfiguration()
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.focusModePreset)
            }
        }
    }

    func setManualFocusPosition(_ value: Float) async -> Float {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.manualFocusPosition)
                    return
                }

                guard device.isLockingFocusWithCustomLensPositionSupported else {
                    continuation.resume(returning: self.manualFocusPosition)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    let bounded = max(0, min(value, 1))
                    device.setFocusModeLocked(lensPosition: bounded, completionHandler: nil)
                    device.unlockForConfiguration()
                    self.manualFocusPosition = bounded
                    self.focusModePreset = .manual
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.manualFocusPosition)
            }
        }
    }

    func setFocusExposureLock(_ enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume(returning: self.focusExposureLockEnabled)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    if enabled {
                        if self.focusModePreset == .manual, device.isLockingFocusWithCustomLensPositionSupported {
                            let bounded = max(0, min(self.manualFocusPosition, 1))
                            device.setFocusModeLocked(lensPosition: bounded, completionHandler: nil)
                        } else if device.isLockingFocusWithCustomLensPositionSupported {
                            let currentLens = max(0, min(device.lensPosition, 1))
                            device.setFocusModeLocked(lensPosition: currentLens, completionHandler: nil)
                        } else if device.isFocusModeSupported(.locked) {
                            device.focusMode = .locked
                        }

                        if device.isExposureModeSupported(.locked) {
                            device.exposureMode = .locked
                        }
                    } else {
                        if self.focusModePreset == .manual, device.isLockingFocusWithCustomLensPositionSupported {
                            let bounded = max(0, min(self.manualFocusPosition, 1))
                            device.setFocusModeLocked(lensPosition: bounded, completionHandler: nil)
                        } else if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        } else if device.isFocusModeSupported(.autoFocus) {
                            device.focusMode = .autoFocus
                        }

                        if self.manualShutterDuration > 0 {
                            let duration = self.clampedExposureDuration(seconds: self.manualShutterDuration, for: device)
                            let iso = self.manualISO > 0
                                ? max(device.activeFormat.minISO, min(self.manualISO, device.activeFormat.maxISO))
                                : max(device.activeFormat.minISO, min(device.iso, device.activeFormat.maxISO))
                            device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
                        } else if self.manualISO > 0 {
                            let boundedISO = max(device.activeFormat.minISO, min(self.manualISO, device.activeFormat.maxISO))
                            let duration = device.exposureDuration.isValid ? device.exposureDuration : CMTime(value: 1, timescale: 60)
                            device.setExposureModeCustom(duration: duration, iso: boundedISO, completionHandler: nil)
                        } else if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                            let boundedBias = max(device.minExposureTargetBias, min(self.exposureBias, device.maxExposureTargetBias))
                            device.setExposureTargetBias(boundedBias, completionHandler: nil)
                        }
                    }

                    device.unlockForConfiguration()
                    self.focusExposureLockEnabled = enabled
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.focusExposureLockEnabled)
            }
        }
    }

    func focus(at devicePoint: CGPoint) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device else {
                    continuation.resume()
                    return
                }

                do {
                    try device.lockForConfiguration()

                    if !self.focusExposureLockEnabled, self.focusModePreset == .auto, device.isFocusPointOfInterestSupported {
                        device.focusPointOfInterest = devicePoint
                        device.focusMode = device.isFocusModeSupported(.continuousAutoFocus) ? .continuousAutoFocus : .autoFocus
                    }

                    if !self.focusExposureLockEnabled, device.isExposurePointOfInterestSupported {
                        device.exposurePointOfInterest = devicePoint
                        device.exposureMode = device.isExposureModeSupported(.continuousAutoExposure) ? .continuousAutoExposure : .autoExpose
                    }

                    device.unlockForConfiguration()
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume()
            }
        }
    }

    func setScannerEnabled(_ enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.scannerEnabled = enabled
                if enabled {
                    self.textRecognitionEnabled = false
                    self.documentDetectionEnabled = false
                    self.mlClassificationEnabled = false
                    self.objectDetectionEnabled = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecognizedText?(TextRecognitionSample(blocks: [], combinedText: ""))
                        self?.onDetectedDocument?(nil)
                        self?.onImageClassification?(nil)
                        self?.onDetectedObjects?(nil)
                    }
                }
                self.configureMetadataTypes()
                self.lastError = nil
                continuation.resume(returning: self.scannerEnabled)
            }
        }
    }

    func setTextRecognitionEnabled(_ enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.textRecognitionEnabled = enabled
                self.isProcessingTextRecognition = false
                self.lastTextRecognitionUptime = 0
                if enabled {
                    self.scannerEnabled = false
                    self.documentDetectionEnabled = false
                    self.mlClassificationEnabled = false
                    self.objectDetectionEnabled = false
                    self.configureMetadataTypes()
                    DispatchQueue.main.async { [weak self] in
                        self?.onDetectedDocument?(nil)
                        self?.onImageClassification?(nil)
                        self?.onDetectedObjects?(nil)
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecognizedText?(TextRecognitionSample(blocks: [], combinedText: ""))
                    }
                }
                self.lastError = nil
                continuation.resume(returning: self.textRecognitionEnabled)
            }
        }
    }

    func setDocumentDetectionEnabled(_ enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.documentDetectionEnabled = enabled
                self.isProcessingDocumentDetection = false
                self.lastDocumentDetectionUptime = 0
                if enabled {
                    self.scannerEnabled = false
                    self.textRecognitionEnabled = false
                    self.mlClassificationEnabled = false
                    self.objectDetectionEnabled = false
                    self.configureMetadataTypes()
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecognizedText?(TextRecognitionSample(blocks: [], combinedText: ""))
                        self?.onImageClassification?(nil)
                        self?.onDetectedObjects?(nil)
                    }
                }
                if !enabled {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDetectedDocument?(nil)
                    }
                }
                self.lastError = nil
                continuation.resume(returning: self.documentDetectionEnabled)
            }
        }
    }

    func setMLClassificationEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
#if canImport(CoreML)
            do {
                try await prepareDownloadedMLClassifierIfNeeded()
                Task(priority: .utility) { [weak self] in
                    guard let self else { return }
                    try? await self.prepareDownloadedObjectDetectorIfNeeded()
                }
            } catch {
                lastError = error.localizedDescription
                return false
            }
#endif
        }

        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.mlClassificationEnabled = enabled
                self.isProcessingMLClassification = false
                self.lastMLClassificationUptime = 0
                self.classificationHistory.removeAll()
                if enabled {
                    self.scannerEnabled = false
                    self.textRecognitionEnabled = false
                    self.documentDetectionEnabled = false
                    self.objectDetectionEnabled = false
                    self.objectDetectionHistory.removeAll()
                    self.configureMetadataTypes()
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecognizedText?(TextRecognitionSample(blocks: [], combinedText: ""))
                        self?.onDetectedDocument?(nil)
                        self?.onDetectedObjects?(nil)
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.onImageClassification?(nil)
                    }
                }
                self.lastError = nil
                continuation.resume(returning: self.mlClassificationEnabled)
            }
        }
    }

    func setObjectDetectionEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
#if canImport(CoreML)
            do {
                try await prepareDownloadedObjectDetectorIfNeeded()
                Task(priority: .utility) { [weak self] in
                    guard let self else { return }
                    try? await self.prepareDownloadedMLClassifierIfNeeded()
                }
            } catch {
                lastError = error.localizedDescription
                return false
            }
#endif
        }

        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.objectDetectionEnabled = enabled
                self.isProcessingObjectDetection = false
                self.lastObjectDetectionUptime = 0
                self.objectDetectionHistory.removeAll()
                if enabled {
                    self.scannerEnabled = false
                    self.textRecognitionEnabled = false
                    self.documentDetectionEnabled = false
                    self.mlClassificationEnabled = false
                    self.classificationHistory.removeAll()
                    self.configureMetadataTypes()
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecognizedText?(TextRecognitionSample(blocks: [], combinedText: ""))
                        self?.onDetectedDocument?(nil)
                        self?.onImageClassification?(nil)
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDetectedObjects?(nil)
                    }
                }
                self.lastError = nil
                continuation.resume(returning: self.objectDetectionEnabled)
            }
        }
    }

    func recognizeText(in imageData: Data) async -> TextRecognitionSample? {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                let request = VNRecognizeTextRequest { request, _ in
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return nil }
                        return RecognizedTextBlock(
                            text: text,
                            boundingBox: CGRect(
                                x: observation.boundingBox.minX,
                                y: 1 - observation.boundingBox.maxY,
                                width: observation.boundingBox.width,
                                height: observation.boundingBox.height
                            ),
                            confidence: candidate.confidence
                        )
                    }
                    .sorted {
                        if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.025 {
                            return $0.boundingBox.minY < $1.boundingBox.minY
                        }
                        return $0.boundingBox.minX < $1.boundingBox.minX
                    }

                    let combinedText = blocks.map(\.text).joined(separator: "\n")
                    continuation.resume(returning: TextRecognitionSample(blocks: blocks, combinedText: combinedText))
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["cs-CZ", "en-US"]

                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func classifyImage(in imageData: Data) async -> ImageClassificationSample? {
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let request = self.makeClassificationRequest(resultHandler: { observations in
                    continuation.resume(returning: Self.classificationSample(from: observations))
                }) else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func detectObjects(in imageData: Data) async -> ObjectDetectionSample? {
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let request = self.makeObjectDetectionRequest(resultHandler: { observations in
                    continuation.resume(returning: Self.objectDetectionSample(from: observations))
                }) else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

#if canImport(CoreML)
    private func prepareDownloadedMLClassifierIfNeeded() async throws {
        if downloadedCoreMLVisionModel != nil {
            return
        }

        let compiledModelURL = try await coreMLInstaller.prepareClassifierModel()
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    let configuration = MLModelConfiguration()
                    configuration.computeUnits = .all
                    let mlModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
                    self.downloadedCoreMLVisionModel = try VNCoreMLModel(for: mlModel)
                    self.lastError = nil
                    continuation.resume()
                } catch {
                    self.lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func prepareDownloadedObjectDetectorIfNeeded() async throws {
        if downloadedObjectDetectorVisionModel != nil {
            return
        }

        let compiledModelURL = try await coreMLInstaller.prepareObjectDetectorModel()
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    let configuration = MLModelConfiguration()
                    configuration.computeUnits = .all
                    let mlModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
                    self.downloadedObjectDetectorVisionModel = try VNCoreMLModel(for: mlModel)
                    self.lastError = nil
                    continuation.resume()
                } catch {
                    self.lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                }
            }
        }
    }
#endif

    func setTorchEnabled(_ enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.videoInput?.device, device.hasTorch else {
                    self.torchEnabled = false
                    continuation.resume(returning: false)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    if enabled {
                        try device.setTorchModeOn(level: min(1.0, AVCaptureDevice.maxAvailableTorchLevel))
                    } else {
                        device.torchMode = .off
                    }
                    device.unlockForConfiguration()
                    self.torchEnabled = enabled
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }

                continuation.resume(returning: self.torchEnabled)
            }
        }
    }

    func setScannerRectOfInterest(_ rect: CGRect?) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.scannerRectOfInterest = rect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                if self.scannerEnabled {
                    self.metadataOutput.rectOfInterest = self.scannerRectOfInterest
                }
                continuation.resume()
            }
        }
    }

    private func configureSession(for position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        if let currentInput = videoInput {
            session.removeInput(currentInput)
        }

        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else {
                throw CameraServiceError.cameraUnavailable
            }
            session.addOutput(photoOutput)
        }

        if !session.outputs.contains(movieOutput) {
            guard session.canAddOutput(movieOutput) else {
                throw CameraServiceError.cameraUnavailable
            }
            session.addOutput(movieOutput)
        }

        if !session.outputs.contains(metadataOutput) {
            guard session.canAddOutput(metadataOutput) else {
                throw CameraServiceError.cameraUnavailable
            }
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
        }

        if !session.outputs.contains(videoDataOutput) {
            guard session.canAddOutput(videoDataOutput) else {
                throw CameraServiceError.cameraUnavailable
            }
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            session.addOutput(videoDataOutput)
        }

        guard let device = bestDevice(for: position) else {
            throw CameraServiceError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraServiceError.cameraUnavailable
        }

        session.addInput(input)
        videoInput = input
        if device.activeFormat.videoMaxZoomFactor > 1 {
            do {
                try device.lockForConfiguration()
                if let format = bestFormat(for: device, preferredFPS: preferredFPS) {
                    device.activeFormat = format
                } else {
                    preferredFPS = 30
                }
                device.videoZoomFactor = 1.0
                if supportedFrameRates.contains(preferredFPS) {
                    let duration = CMTime(value: 1, timescale: CMTimeScale(preferredFPS))
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                }
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = lowLightBoostEnabled
                }
                switch whiteBalancePreset {
                case .auto:
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                case .warm, .cool:
                    if device.isWhiteBalanceModeSupported(.locked) {
                        let targetGains = whiteBalanceGains(for: whiteBalancePreset, device: device)
                        device.setWhiteBalanceModeLocked(with: targetGains, completionHandler: nil)
                    }
                }
                if focusModePreset == .manual, device.isLockingFocusWithCustomLensPositionSupported {
                    let boundedFocus = max(0, min(manualFocusPosition, 1))
                    device.setFocusModeLocked(lensPosition: boundedFocus, completionHandler: nil)
                    manualFocusPosition = boundedFocus
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                if manualShutterDuration > 0 {
                    let duration = clampedExposureDuration(seconds: manualShutterDuration, for: device)
                    let iso = manualISO > 0
                        ? max(device.activeFormat.minISO, min(manualISO, device.activeFormat.maxISO))
                        : max(device.activeFormat.minISO, min(device.iso, device.activeFormat.maxISO))
                    device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
                    manualShutterDuration = CMTimeGetSeconds(duration)
                    if manualISO > 0 {
                        manualISO = iso
                    }
                } else if manualISO > 0 {
                    let boundedISO = max(device.activeFormat.minISO, min(manualISO, device.activeFormat.maxISO))
                    let duration = device.exposureDuration.isValid ? device.exposureDuration : CMTime(value: 1, timescale: 60)
                    device.setExposureModeCustom(duration: duration, iso: boundedISO, completionHandler: nil)
                    manualISO = boundedISO
                } else if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    let boundedBias = max(device.minExposureTargetBias, min(exposureBias, device.maxExposureTargetBias))
                    device.setExposureTargetBias(boundedBias, completionHandler: nil)
                    exposureBias = boundedBias
                }
                if focusExposureLockEnabled {
                    if device.isFocusModeSupported(.locked), focusModePreset == .auto {
                        device.focusMode = .locked
                    }
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                }
                if device.hasTorch {
                    if torchEnabled {
                        try? device.setTorchModeOn(level: min(1.0, AVCaptureDevice.maxAvailableTorchLevel))
                    } else {
                        device.torchMode = .off
                    }
                } else {
                    torchEnabled = false
                }
                device.unlockForConfiguration()
            } catch {
                lastError = error.localizedDescription
            }
        }
        configureMetadataTypes()
        isConfigured = true
    }

    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTripleCamera,
        ]

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        let devices = discovery.devices
        for type in deviceTypes {
            if let match = devices.first(where: { $0.deviceType == type }) {
                return match
            }
        }
        return devices.first
    }

    private func clampedExposureDuration(seconds: Double, for device: AVCaptureDevice) -> CMTime {
        let minSeconds = max(CMTimeGetSeconds(device.activeFormat.minExposureDuration), 1.0 / 1000.0)
        let maxSeconds = max(minSeconds, min(CMTimeGetSeconds(device.activeFormat.maxExposureDuration), 1.0))
        let bounded = max(minSeconds, min(seconds, maxSeconds))
        return CMTimeMakeWithSeconds(bounded, preferredTimescale: 1_000_000_000)
    }

    private func bestFormat(for device: AVCaptureDevice, preferredFPS: Int) -> AVCaptureDevice.Format? {
        device.formats
            .filter { format in
                format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= Double(preferredFPS) }
            }
            .max { lhs, rhs in
                let lhsDimensions = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                let rhsDimensions = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                let lhsScore = Int(lhsDimensions.width) * Int(lhsDimensions.height)
                let rhsScore = Int(rhsDimensions.width) * Int(rhsDimensions.height)
                return lhsScore < rhsScore
            }
    }

    private func whiteBalanceGains(for preset: WhiteBalancePreset, device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        let values: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues
        switch preset {
        case .auto:
            return device.deviceWhiteBalanceGains
        case .warm:
            values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 6800, tint: 18)
        case .cool:
            values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 4200, tint: -10)
        }
        return normalizedWhiteBalanceGains(device.deviceWhiteBalanceGains(for: values), device: device)
    }

    private func normalizedWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains, device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        let maxGain = device.maxWhiteBalanceGain
        var normalized = gains
        normalized.redGain = max(1.0, min(gains.redGain, maxGain))
        normalized.greenGain = max(1.0, min(gains.greenGain, maxGain))
        normalized.blueGain = max(1.0, min(gains.blueGain, maxGain))
        return normalized
    }

    private func recordingsDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = documents.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func configureMetadataTypes() {
        let supported = metadataOutput.availableMetadataObjectTypes
        let preferred: [AVMetadataObject.ObjectType] = [
            .qr,
            .ean13,
            .ean8,
            .code128,
            .dataMatrix,
            .pdf417,
            .aztec,
        ]
        metadataOutput.metadataObjectTypes = scannerEnabled ? preferred.filter { supported.contains($0) } : []
        if scannerEnabled {
            metadataOutput.rectOfInterest = scannerRectOfInterest
        }
    }

    private func maybeDeliverMonitoringSample(from sampleBuffer: CMSampleBuffer) {
        guard onMonitoringSample != nil else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastMonitoringSampleUptime >= 0.14 else { return }
        lastMonitoringSampleUptime = uptime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let plane = CVPixelBufferGetPlaneCount(pixelBuffer) > 0 ? 0 : -1
        let width = plane >= 0 ? CVPixelBufferGetWidthOfPlane(pixelBuffer, plane) : CVPixelBufferGetWidth(pixelBuffer)
        let height = plane >= 0 ? CVPixelBufferGetHeightOfPlane(pixelBuffer, plane) : CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = plane >= 0 ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane) : CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let rawBaseAddress = plane >= 0 ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane) : CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }

        let baseAddress = rawBaseAddress.assumingMemoryBound(to: UInt8.self)
        let histogramBins = 16
        var histogram = Array(repeating: 0.0, count: histogramBins)
        let sampleStride = max(2, min(width, height) / 120)
        var totalLuma = 0.0
        var sampleCount = 0.0

        let zebraColumns = 12
        let zebraRows = 20
        let zebraThreshold = 235
        let zebraRatioThreshold = 0.38
        let cellWidth = max(1, width / zebraColumns)
        let cellHeight = max(1, height / zebraRows)
        var zebraRects: [CGRect] = []
        var focusCells: [(rect: CGRect, strength: Double)] = []
        var centerFocusTotal = 0.0
        var centerFocusCount = 0.0

        for y in stride(from: 0, to: height, by: sampleStride) {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let luma = Int(row[x])
                let binIndex = min(histogramBins - 1, (luma * histogramBins) / 256)
                histogram[binIndex] += 1
                totalLuma += Double(luma)
                sampleCount += 1
            }
        }

        for rowIndex in 0 ..< zebraRows {
            for columnIndex in 0 ..< zebraColumns {
                let startX = columnIndex * cellWidth
                let startY = rowIndex * cellHeight
                let endX = min(width, startX + cellWidth)
                let endY = min(height, startY + cellHeight)
                guard endX > startX, endY > startY else { continue }

                var overexposed = 0
                var inspected = 0
                var gradientTotal = 0.0
                var gradientSamples = 0.0
                var y = startY
                while y < endY {
                    let row = baseAddress.advanced(by: y * bytesPerRow)
                    let nextRow = baseAddress.advanced(by: min(height - 1, y + max(2, sampleStride)) * bytesPerRow)
                    var x = startX
                    while x < endX {
                        let current = Int(row[x])
                        if current >= zebraThreshold {
                            overexposed += 1
                        }
                        let nextX = min(endX - 1, x + max(2, sampleStride))
                        let diffX = abs(Int(row[nextX]) - current)
                        let diffY = abs(Int(nextRow[x]) - current)
                        gradientTotal += Double(diffX + diffY)
                        gradientSamples += 1
                        inspected += 1
                        x += max(2, sampleStride)
                    }
                    y += max(2, sampleStride)
                }

                guard inspected > 0 else { continue }
                let ratio = Double(overexposed) / Double(inspected)
                if ratio >= zebraRatioThreshold {
                    zebraRects.append(
                        CGRect(
                            x: CGFloat(startX) / CGFloat(width),
                            y: CGFloat(startY) / CGFloat(height),
                            width: CGFloat(endX - startX) / CGFloat(width),
                            height: CGFloat(endY - startY) / CGFloat(height)
                        )
                    )
                }

                let focusStrength = gradientSamples > 0 ? gradientTotal / (gradientSamples * 510.0) : 0
                let normalizedRect = CGRect(
                    x: CGFloat(startX) / CGFloat(width),
                    y: CGFloat(startY) / CGFloat(height),
                    width: CGFloat(endX - startX) / CGFloat(width),
                    height: CGFloat(endY - startY) / CGFloat(height)
                )
                focusCells.append((rect: normalizedRect, strength: focusStrength))
                if columnIndex >= 3, columnIndex <= 8, rowIndex >= 5, rowIndex <= 14 {
                    centerFocusTotal += focusStrength
                    centerFocusCount += 1
                }
            }
        }

        let maxBin = histogram.max() ?? 1
        let normalizedHistogram = histogram.map { maxBin > 0 ? $0 / maxBin : 0 }
        let averageLuma = sampleCount > 0 ? totalLuma / sampleCount : 0
        let averageCenterFocus = centerFocusCount > 0 ? centerFocusTotal / centerFocusCount : 0
        let averageFocusStrength = focusCells.isEmpty ? 0 : focusCells.reduce(0) { $0 + $1.strength } / Double(focusCells.count)
        let maxFocusStrength = focusCells.map(\.strength).max() ?? 0
        let focusThreshold = max(0.035, averageFocusStrength * 1.8, maxFocusStrength * 0.52)
        let focusPeakingRects = focusCells
            .filter { $0.strength >= focusThreshold }
            .sorted { $0.strength > $1.strength }
            .prefix(20)
            .map(\.rect)
        let focusScore = min(1.0, averageCenterFocus / 0.085)
        let sample = FrameMonitoringSample(
            histogram: normalizedHistogram,
            overexposedRects: zebraRects,
            averageLuma: averageLuma,
            focusScore: focusScore,
            focusPeakingRects: focusPeakingRects
        )

        DispatchQueue.main.async { [weak self] in
            self?.onMonitoringSample?(sample)
        }
    }

    private func maybeDeliverRecognizedText(from sampleBuffer: CMSampleBuffer) {
        guard textRecognitionEnabled, onRecognizedText != nil, !isProcessingTextRecognition else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastTextRecognitionUptime >= 0.45 else { return }
        lastTextRecognitionUptime = uptime
        isProcessingTextRecognition = true

        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self else { return }

            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                let boundingBox = CGRect(
                    x: observation.boundingBox.minX,
                    y: 1 - observation.boundingBox.maxY,
                    width: observation.boundingBox.width,
                    height: observation.boundingBox.height
                )
                return RecognizedTextBlock(text: text, boundingBox: boundingBox, confidence: candidate.confidence)
            }
            .sorted {
                if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.025 {
                    return $0.boundingBox.minY < $1.boundingBox.minY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }

            let combinedText = blocks.prefix(8).map(\.text).joined(separator: "\n")
            let sample = TextRecognitionSample(blocks: blocks, combinedText: combinedText)

            DispatchQueue.main.async { [weak self] in
                self?.onRecognizedText?(sample)
            }
            self.sessionQueue.async {
                self.isProcessingTextRecognition = false
            }
        }

        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.025
        request.recognitionLanguages = ["cs-CZ", "en-US"]

        do {
            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: visionImageOrientation(),
                options: [:]
            )
            try handler.perform([request])
        } catch {
            isProcessingTextRecognition = false
        }
    }

    private func maybeDeliverDetectedDocument(from sampleBuffer: CMSampleBuffer) {
        guard documentDetectionEnabled, onDetectedDocument != nil, !isProcessingDocumentDetection else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastDocumentDetectionUptime >= 0.38 else { return }
        lastDocumentDetectionUptime = uptime
        isProcessingDocumentDetection = true

        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let quad = (request.results as? [VNRectangleObservation])?
                .sorted(by: { ($0.boundingBox.width * $0.boundingBox.height) > ($1.boundingBox.width * $1.boundingBox.height) })
                .first
                .map { observation in
                    DetectedDocumentQuad(
                        topLeft: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y),
                        topRight: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y),
                        bottomRight: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y),
                        bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y),
                        confidence: observation.confidence
                    )
                }

            DispatchQueue.main.async { [weak self] in
                self?.onDetectedDocument?(quad)
            }
            self.sessionQueue.async {
                self.isProcessingDocumentDetection = false
            }
        }

        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.45
        request.quadratureTolerance = 25
        request.minimumSize = 0.25

        do {
            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: visionImageOrientation(),
                options: [:]
            )
            try handler.perform([request])
        } catch {
            isProcessingDocumentDetection = false
        }
    }

    private func maybeDeliverImageClassification(from sampleBuffer: CMSampleBuffer) {
        guard mlClassificationEnabled,
              onImageClassification != nil,
              !isProcessingMLClassification else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastMLClassificationUptime >= 0.8 else { return }
        lastMLClassificationUptime = uptime
        isProcessingMLClassification = true

        guard let request = makeClassificationRequest(resultHandler: { [weak self] observations in
            guard let self else { return }
            let sample = Self.classificationSample(from: observations)
            let stableSample = self.smoothedClassificationSample(from: sample)
            DispatchQueue.main.async { [weak self] in
                self?.onImageClassification?(stableSample)
            }
            self.sessionQueue.async {
                self.isProcessingMLClassification = false
            }
        }) else {
            isProcessingMLClassification = false
            return
        }

        do {
            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: visionImageOrientation(),
                options: [:]
            )
            try handler.perform([request])
        } catch {
            isProcessingMLClassification = false
        }
    }

    private func maybeDeliverDetectedObjects(from sampleBuffer: CMSampleBuffer) {
        guard objectDetectionEnabled,
              onDetectedObjects != nil,
              !isProcessingObjectDetection else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastObjectDetectionUptime >= 0.55 else { return }
        lastObjectDetectionUptime = uptime
        isProcessingObjectDetection = true

        guard let request = makeObjectDetectionRequest(resultHandler: { [weak self] observations in
            guard let self else { return }
            let sample = Self.objectDetectionSample(from: observations)
            let stableSample = self.smoothedObjectDetectionSample(from: sample)
            DispatchQueue.main.async { [weak self] in
                self?.onDetectedObjects?(stableSample)
            }
            self.sessionQueue.async {
                self.isProcessingObjectDetection = false
            }
        }) else {
            isProcessingObjectDetection = false
            return
        }

        do {
            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: visionImageOrientation(),
                options: [:]
            )
            try handler.perform([request])
        } catch {
            isProcessingObjectDetection = false
        }
    }

    private func makeClassificationRequest(resultHandler: @escaping ([VNClassificationObservation]) -> Void) -> VNRequest? {
#if canImport(CoreML)
        if let downloadedCoreMLVisionModel {
            return VNCoreMLRequest(model: downloadedCoreMLVisionModel) { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                resultHandler(observations)
            }
        }
#endif

        guard #available(iOS 15.0, *) else { return nil }
        return VNClassifyImageRequest { request, _ in
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            resultHandler(observations)
        }
    }

    private static func classificationSample(from observations: [VNClassificationObservation]) -> ImageClassificationSample? {
        let labels = observations
            .filter { $0.confidence >= 0.12 }
            .prefix(4)
            .map {
                ImageClassificationLabel(
                    title: humanizedClassificationTitle($0.identifier),
                    confidence: $0.confidence
                )
            }
        return labels.isEmpty ? nil : ImageClassificationSample(labels: Array(labels))
    }

    private func makeObjectDetectionRequest(resultHandler: @escaping ([VNRecognizedObjectObservation]) -> Void) -> VNRequest? {
#if canImport(CoreML)
        guard let downloadedObjectDetectorVisionModel else { return nil }
        let request = VNCoreMLRequest(model: downloadedObjectDetectorVisionModel) { request, _ in
            let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
            resultHandler(observations)
        }
        request.imageCropAndScaleOption = .scaleFill
        return request
#else
        return nil
#endif
    }

    private static func objectDetectionSample(from observations: [VNRecognizedObjectObservation]) -> ObjectDetectionSample? {
        let objects = observations
            .prefix(6)
            .compactMap { observation -> DetectedObject? in
                guard let label = observation.labels.first else { return nil }
                guard label.confidence >= 0.22 else { return nil }
                let rect = CGRect(
                    x: observation.boundingBox.minX,
                    y: 1 - observation.boundingBox.maxY,
                    width: observation.boundingBox.width,
                    height: observation.boundingBox.height
                )
                return DetectedObject(
                    label: humanizedClassificationTitle(label.identifier),
                    confidence: label.confidence,
                    boundingBox: rect
                )
            }
        return objects.isEmpty ? nil : ObjectDetectionSample(objects: Array(objects))
    }

    private func smoothedClassificationSample(from sample: ImageClassificationSample?) -> ImageClassificationSample? {
        guard let sample else {
            classificationHistory.removeAll()
            return nil
        }

        classificationHistory.append(sample)
        if classificationHistory.count > 3 {
            classificationHistory.removeFirst(classificationHistory.count - 3)
        }

        var aggregated: [String: Float] = [:]
        let divisor = Float(classificationHistory.count)

        for item in classificationHistory {
            for label in item.labels {
                aggregated[label.title, default: 0] += label.confidence
            }
        }

        let labels = aggregated
            .compactMap { title, total -> ImageClassificationLabel? in
                let confidence = total / divisor
                guard confidence >= 0.18 else { return nil }
                return ImageClassificationLabel(title: title, confidence: confidence)
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(4)

        return labels.isEmpty ? nil : ImageClassificationSample(labels: Array(labels))
    }

    private func smoothedObjectDetectionSample(from sample: ObjectDetectionSample?) -> ObjectDetectionSample? {
        guard let sample else {
            objectDetectionHistory.removeAll()
            return nil
        }

        objectDetectionHistory.append(sample)
        if objectDetectionHistory.count > 3 {
            objectDetectionHistory.removeFirst(objectDetectionHistory.count - 3)
        }

        struct ObjectKey: Hashable {
            let label: String
            let xBucket: Int
            let yBucket: Int
        }

        var totals: [ObjectKey: (confidence: Float, rect: CGRect, count: Int)] = [:]

        for item in objectDetectionHistory {
            for object in item.objects {
                let centerX = object.boundingBox.midX
                let centerY = object.boundingBox.midY
                let key = ObjectKey(
                    label: object.label,
                    xBucket: Int((centerX * 6).rounded()),
                    yBucket: Int((centerY * 8).rounded())
                )

                if var existing = totals[key] {
                    existing.confidence += object.confidence
                    existing.rect.origin.x += object.boundingBox.origin.x
                    existing.rect.origin.y += object.boundingBox.origin.y
                    existing.rect.size.width += object.boundingBox.width
                    existing.rect.size.height += object.boundingBox.height
                    existing.count += 1
                    totals[key] = existing
                } else {
                    totals[key] = (object.confidence, object.boundingBox, 1)
                }
            }
        }

        let historyCount = max(1, objectDetectionHistory.count)
        let objects = totals
            .compactMap { key, value -> DetectedObject? in
                let confidence = value.confidence / Float(historyCount)
                guard confidence >= 0.26 else { return nil }
                let count = CGFloat(max(1, value.count))
                let rect = CGRect(
                    x: value.rect.origin.x / count,
                    y: value.rect.origin.y / count,
                    width: value.rect.size.width / count,
                    height: value.rect.size.height / count
                )
                return DetectedObject(label: key.label, confidence: confidence, boundingBox: rect)
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(6)

        return objects.isEmpty ? nil : ObjectDetectionSample(objects: Array(objects))
    }

    private func visionImageOrientation() -> CGImagePropertyOrientation {
        switch currentPosition {
        case .front:
            return .leftMirrored
        default:
            return .right
        }
    }

    private static func humanizedClassificationTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        sessionQueue.async {
            let continuation = self.captureContinuation
            self.captureContinuation = nil

            if let error {
                continuation?.resume(throwing: error)
                return
            }

            guard let data = photo.fileDataRepresentation() else {
                continuation?.resume(throwing: CameraServiceError.imageDataUnavailable)
                return
            }

            continuation?.resume(returning: data)
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        sessionQueue.async {
            let continuation = self.recordingStopContinuation
            self.recordingStopContinuation = nil

            if let error {
                continuation?.resume(throwing: error)
                return
            }

            continuation?.resume(returning: outputFileURL)
        }
    }
}

extension CameraService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard scannerEnabled, !movieOutput.isRecording else { return }

        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let payload = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !payload.isEmpty else {
            return
        }

        let now = Date()
        if payload == lastScannedCode, now.timeIntervalSince(lastScannedAt) < 1.2 {
            return
        }

        lastScannedCode = payload
        lastScannedAt = now

        let code = ScannedCode(payload: payload, type: object.type.rawValue)
        DispatchQueue.main.async { [weak self] in
            self?.onCodeScanned?(code)
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard output == videoDataOutput, !movieOutput.isRecording else { return }
        maybeDeliverMonitoringSample(from: sampleBuffer)
        maybeDeliverRecognizedText(from: sampleBuffer)
        maybeDeliverDetectedDocument(from: sampleBuffer)
        maybeDeliverImageClassification(from: sampleBuffer)
        maybeDeliverDetectedObjects(from: sampleBuffer)
    }
}
#endif
