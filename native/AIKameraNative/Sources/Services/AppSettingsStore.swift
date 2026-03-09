import Foundation
import Security

enum AppSettingsStoreError: Error {
    case encodingFailed
}

struct AppSettingsStore {
    private let defaults = UserDefaults.standard
    private let settingsKey = "ai-kamera-native.settings"
    private let keychainService = "com.ipwn666.AIKameraNative"
    private let keychainAccount = "openai_api_key"

    func load() -> AppSettings {
        var settings = AppSettings.default

        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }

        settings.apiKey = loadAPIKey() ?? settings.apiKey
        return settings
    }

    func save(_ settings: AppSettings) throws {
        var persisted = settings
        persisted.apiKey = ""

        guard let data = try? JSONEncoder().encode(persisted) else {
            throw AppSettingsStoreError.encodingFailed
        }

        defaults.set(data, forKey: settingsKey)
        try saveAPIKey(settings.apiKey)
    }

    private func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func saveAPIKey(_ apiKey: String) throws {
        let encoded = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var createQuery = query
            createQuery[kSecValueData as String] = encoded
            SecItemAdd(createQuery as CFDictionary, nil)
        }
    }
}
