#if canImport(CoreML)
import CoreML
import Foundation

enum CoreMLModelInstallerError: LocalizedError {
    case invalidURL
    case applicationSupportUnavailable
    case badHTTPStatus(Int)
    case invalidDownloadedPayload

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppStrings.isCzech ? "URL Core ML modelu není platná." : "The Core ML model URL is invalid."
        case .applicationSupportUnavailable:
            return AppStrings.isCzech ? "Application Support není k dispozici." : "Application Support is unavailable."
        case .badHTTPStatus(let statusCode):
            return AppStrings.isCzech
                ? "Stažení Core ML modelu selhalo (HTTP \(statusCode))."
                : "Failed to download Core ML model (HTTP \(statusCode))."
        case .invalidDownloadedPayload:
            return AppStrings.isCzech
                ? "Stažený Core ML soubor není platný model."
                : "Downloaded Core ML payload is not a valid model."
        }
    }
}

struct CoreMLModelInstaller {
    enum ModelKind {
        case classifier
        case detector

        var fileName: String {
            switch self {
            case .classifier:
                return "MobileNetV2FP16.mlmodel"
            case .detector:
                return "YOLOv3TinyFP16.mlmodel"
            }
        }

        var compiledFolderName: String {
            switch self {
            case .classifier:
                return "MobileNetV2FP16.mlmodelc"
            case .detector:
                return "YOLOv3TinyFP16.mlmodelc"
            }
        }

        var remoteModelURLString: String {
            switch self {
            case .classifier:
                return "https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2FP16.mlmodel"
            case .detector:
                return "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3TinyFP16.mlmodel"
            }
        }
    }

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        get throws {
            guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw CoreMLModelInstallerError.applicationSupportUnavailable
            }
            return applicationSupport
                .appendingPathComponent("ToPwnZNativeAICam", isDirectory: true)
                .appendingPathComponent("CoreML", isDirectory: true)
        }
    }

    private func rawModelURL(for kind: ModelKind) throws -> URL {
        try baseDirectory.appendingPathComponent(kind.fileName)
    }

    private func compiledModelURL(for kind: ModelKind) throws -> URL {
        try baseDirectory.appendingPathComponent(kind.compiledFolderName, isDirectory: true)
    }

    private func remoteModelURL(for kind: ModelKind) throws -> URL {
        guard let url = URL(string: kind.remoteModelURLString) else {
            throw CoreMLModelInstallerError.invalidURL
        }
        return url
    }

    func prepareClassifierModel() async throws -> URL {
        try await prepareModel(.classifier)
    }

    func prepareObjectDetectorModel() async throws -> URL {
        try await prepareModel(.detector)
    }

    private func prepareModel(_ kind: ModelKind) async throws -> URL {
        try ensureDirectory()

        let compiledURL = try compiledModelURL(for: kind)
        if fileManager.fileExists(atPath: compiledURL.path) {
            return compiledURL
        }

        let rawURL = try rawModelURL(for: kind)
        if !fileManager.fileExists(atPath: rawURL.path) {
            try await downloadModel(kind, to: rawURL)
        }

        do {
            try await compileModel(rawURL: rawURL, compiledURL: compiledURL)
        } catch {
            // Recover from stale/corrupted cached payload by forcing a clean re-download once.
            try? fileManager.removeItem(at: rawURL)
            try? fileManager.removeItem(at: compiledURL)
            try await downloadModel(kind, to: rawURL)
            try await compileModel(rawURL: rawURL, compiledURL: compiledURL)
        }

        return compiledURL
    }

    private func compileModel(rawURL: URL, compiledURL: URL) async throws {
        let temporaryCompiledURL = try await MLModel.compileModel(at: rawURL)
        if fileManager.fileExists(atPath: compiledURL.path) {
            try? fileManager.removeItem(at: compiledURL)
        }
        try fileManager.copyItem(at: temporaryCompiledURL, to: compiledURL)
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: try baseDirectory, withIntermediateDirectories: true)
    }

    private func downloadModel(_ kind: ModelKind, to destinationURL: URL) async throws {
        let (temporaryURL, response) = try await URLSession.shared.download(from: try remoteModelURL(for: kind))
        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw CoreMLModelInstallerError.badHTTPStatus(httpResponse.statusCode)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        let payloadPrefix = (try? Data(contentsOf: destinationURL, options: .mappedIfSafe).prefix(96)) ?? Data()
        if !payloadPrefix.isEmpty {
            let prefixString = String(data: payloadPrefix, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if prefixString.hasPrefix("<?xml") || prefixString.hasPrefix("<html") || prefixString.contains("<error>") {
                try? fileManager.removeItem(at: destinationURL)
                throw CoreMLModelInstallerError.invalidDownloadedPayload
            }
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = destinationURL
        try? mutableURL.setResourceValues(values)
    }
}
#endif
