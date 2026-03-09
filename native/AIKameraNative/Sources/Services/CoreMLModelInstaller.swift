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
    private static let modelFileName = "MobileNetV2FP16.mlmodel"
    private static let compiledFolderName = "MobileNetV2FP16.mlmodelc"
    private static let remoteModelURLString = "https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2FP16.mlmodel"

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

    private var rawModelURL: URL {
        get throws { try baseDirectory.appendingPathComponent(Self.modelFileName) }
    }

    private var compiledModelURL: URL {
        get throws { try baseDirectory.appendingPathComponent(Self.compiledFolderName, isDirectory: true) }
    }

    private var remoteModelURL: URL {
        get throws {
            guard let url = URL(string: Self.remoteModelURLString) else {
                throw CoreMLModelInstallerError.invalidURL
            }
            return url
        }
    }

    func prepareClassifierModel() async throws -> URL {
        try ensureDirectory()

        let compiledURL = try compiledModelURL
        if fileManager.fileExists(atPath: compiledURL.path) {
            return compiledURL
        }

        let rawURL = try rawModelURL
        if !fileManager.fileExists(atPath: rawURL.path) {
            try await downloadModel(to: rawURL)
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

    private func downloadModel(to destinationURL: URL) async throws {
        let (temporaryURL, _) = try await URLSession.shared.download(from: try remoteModelURL)
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
