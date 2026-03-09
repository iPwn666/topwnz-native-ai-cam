import Foundation

enum ScanVaultStoreError: Error {
    case encodingFailed
}

struct ScanVaultStore {
    private let defaults = UserDefaults.standard
    private let vaultKey = "ai-kamera-native.scan-vault"
    private let maximumEntries = 200

    func loadEntries() -> [ScanVaultEntry] {
        guard let data = defaults.data(forKey: vaultKey),
              let decoded = try? JSONDecoder().decode([ScanVaultEntry].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func upsert(scannedCode: ScannedCode, analysis: CameraAnalysis? = nil) throws -> [ScanVaultEntry] {
        var entries = loadEntries()

        if let index = entries.firstIndex(where: { $0.payload == scannedCode.payload && $0.type == scannedCode.type }) {
            entries[index].updatedAt = Date()
            if let analysis {
                entries[index].analysis = CameraAnalysisSnapshot(analysis: analysis)
            }
        } else {
            entries.insert(
                ScanVaultEntry(
                    payload: scannedCode.payload,
                    type: scannedCode.type,
                    updatedAt: Date(),
                    isFavorite: false,
                    analysis: analysis.map(CameraAnalysisSnapshot.init(analysis:))
                ),
                at: 0
            )
        }

        entries = Array(entries.sorted { $0.updatedAt > $1.updatedAt }.prefix(maximumEntries))
        try persist(entries)
        return entries
    }

    @discardableResult
    func delete(entryID: UUID) throws -> [ScanVaultEntry] {
        let entries = loadEntries().filter { $0.id != entryID }
        try persist(entries)
        return entries
    }

    @discardableResult
    func toggleFavorite(entryID: UUID) throws -> [ScanVaultEntry] {
        var entries = loadEntries()
        if let index = entries.firstIndex(where: { $0.id == entryID }) {
            entries[index].isFavorite.toggle()
            entries[index].updatedAt = Date()
        }
        try persist(entries)
        return entries.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func replace(_ entry: ScanVaultEntry) throws -> [ScanVaultEntry] {
        var entries = loadEntries()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
        try persist(entries)
        return entries.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist(_ entries: [ScanVaultEntry]) throws {
        guard let data = try? JSONEncoder().encode(entries) else {
            throw ScanVaultStoreError.encodingFailed
        }
        defaults.set(data, forKey: vaultKey)
    }
}
