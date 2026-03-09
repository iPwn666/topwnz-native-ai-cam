import Foundation

struct CameraAnalysisSnapshot: Equatable, Codable {
    let title: String
    let summary: String
    let tags: [String]
    let findings: [String]
    let recommendations: [String]
    let detectedText: [String]
    let confidenceLabel: String
    let rawText: String

    init(analysis: CameraAnalysis) {
        title = analysis.title
        summary = analysis.summary
        tags = analysis.tags
        findings = analysis.findings
        recommendations = analysis.recommendations
        detectedText = analysis.detectedText
        confidenceLabel = analysis.confidenceLabel
        rawText = analysis.rawText
    }

    var analysis: CameraAnalysis {
        CameraAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            findings: findings,
            recommendations: recommendations,
            detectedText: detectedText,
            confidenceLabel: confidenceLabel,
            rawText: rawText
        )
    }
}

struct ScanVaultEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var payload: String
    var type: String
    var updatedAt: Date
    var isFavorite: Bool
    var analysis: CameraAnalysisSnapshot?

    init(
        id: UUID = UUID(),
        payload: String,
        type: String,
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        analysis: CameraAnalysisSnapshot? = nil
    ) {
        self.id = id
        self.payload = payload
        self.type = type
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.analysis = analysis
    }

    var scannedCode: ScannedCode {
        ScannedCode(payload: payload, type: type)
    }

    var displayTitle: String {
        switch scannedCode.kind {
        case .url(let url):
            return url.host ?? payload
        case .email(let value):
            return value
        case .phone(let value):
            return value
        case .sms(let value):
            return value
        case .wifi(let wifi):
            return wifi.ssid
        case .location(let location):
            return location.label ?? "\(location.latitude), \(location.longitude)"
        case .contact(let contact):
            return contact.fullName
        case .event(let event):
            return event.title
        case .faceTime(let value):
            return value
        case .text:
            return payload
        }
    }

    var displaySubtitle: String {
        let previewSource = analysis?.summary ?? scannedCode.formattedDetails
        let preview = previewSource.replacingOccurrences(of: "\n", with: " ")
        return preview.count > 96 ? "\(preview.prefix(96))…" : preview
    }
}
