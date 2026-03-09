import Foundation

struct CameraAnalysis: Equatable {
    let title: String
    let summary: String
    let tags: [String]
    let findings: [String]
    let recommendations: [String]
    let detectedText: [String]
    let confidenceLabel: String
    let rawText: String

    static func fallback(from rawText: String) -> CameraAnalysis {
        CameraAnalysis(
            title: AppStrings.isCzech ? "AI výstup" : "AI output",
            summary: rawText,
            tags: [],
            findings: [],
            recommendations: [],
            detectedText: [],
            confidenceLabel: AppStrings.confidenceLabel(nil),
            rawText: rawText
        )
    }
}

struct ParsedAnalysisPayload: Decodable {
    let title: String?
    let summary: String?
    let tags: [String]?
    let findings: [String]?
    let recommendations: [String]?
    let detectedText: [String]?
    let confidence: String?

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case tags
        case findings
        case recommendations
        case detectedText = "detected_text"
        case confidence
    }
}
