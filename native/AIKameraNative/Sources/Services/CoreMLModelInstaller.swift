#if canImport(CoreML)
import CoreML
import Foundation

enum CoreMLModelInstallerError: LocalizedError {
    case invalidURL
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppStrings.isCzech ? "URL Core ML modelu není platná." : "The Core ML model URL is invalid."
        case .applicationSupportUnavailable:
            return AppStrings.isCzech ? "Application Support není k dispozici." : "Application Support is unavailable."
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
                return "https://ml-assets.apple.com/coreml/models/ObjectDetection/YOLOv3Tiny/YOLOv3TinyFP16.mlmodel"
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

        let temporaryCompiledURL = try await MLModel.compileModel(at: rawURL)
        if fileManager.fileExists(atPath: compiledURL.path) {
            try? fileManager.removeItem(at: compiledURL)
        }
        try fileManager.copyItem(at: temporaryCompiledURL, to: compiledURL)
        return compiledURL
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: try baseDirectory, withIntermediateDirectories: true)
    }

    private func downloadModel(_ kind: ModelKind, to destinationURL: URL) async throws {
        let (temporaryURL, _) = try await URLSession.shared.download(from: try remoteModelURL(for: kind))
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = destinationURL
        try? mutableURL.setResourceValues(values)
    }
}
#endif
