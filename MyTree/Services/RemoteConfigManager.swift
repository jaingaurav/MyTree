import Foundation

/// Manages configuration loading from Firebase Remote Config with local fallback.
///
/// This service provides a unified interface for loading configuration data:
/// 1. Attempts to fetch from Firebase Remote Config (if enabled)
/// 2. Falls back to local JSON files if Firebase is unavailable
/// 3. Caches remote configs locally for offline use
///
/// **Supported Config Types:**
/// - Gender names (Resources/male_names.json, Resources/female_names.json)
/// - Language localizations (Resources/Localizations/*.json)
/// - Supported languages list (Resources/languages.json)
class RemoteConfigManager {
    static let shared = RemoteConfigManager()

    private var isFirebaseEnabled = false
    private var remoteConfig: RemoteConfigProtocol?
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.mytree.remoteconfig", attributes: .concurrent)

    private init() {
        // Initialize cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cacheDir.appendingPathComponent("MyTree/RemoteConfig", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Check if Firebase is available (will be set by configureFirebase if available)
        // For now, default to local-only mode
    }

    /// Configure Firebase Remote Config (call this if Firebase SDK is available)
    /// This method should be called from AppDelegate or App initialization
    func configureFirebase(_ config: RemoteConfigProtocol) {
        queue.async(flags: .barrier) {
            self.remoteConfig = config
            self.isFirebaseEnabled = true
        }
    }

    /// Load a JSON array from remote config or local file
    /// - Parameters:
    ///   - key: Remote Config key (e.g., "male_names")
    ///   - localFileName: Local JSON file name (e.g., "male_names.json")
    /// - Returns: Array of strings, or empty array if not found
    func loadStringArray(key: String, localFileName: String) -> [String] {
        return queue.sync {
            // Try Firebase Remote Config first
            if isFirebaseEnabled, let remoteConfig = remoteConfig {
                if let jsonString = remoteConfig.getString(key: key),
                   let data = jsonString.data(using: .utf8),
                   let array = try? JSONDecoder().decode([String].self, from: data) {
                    // Cache the remote config
                    cacheConfig(key: key, data: data)
                    return array
                }
            }

            // Try cached version
            if let cached = loadCachedConfig(key: key),
               let array = try? JSONDecoder().decode([String].self, from: cached) {
                return array
            }

            // Fallback to local JSON file
            return loadLocalStringArray(fileName: localFileName)
        }
    }

    /// Load a JSON object from remote config or local file
    /// - Parameters:
    ///   - key: Remote Config key (e.g., "localization_en")
    ///   - localFileName: Local JSON file name (e.g., "en.json")
    ///   - subdirectory: Optional subdirectory (e.g., "localizations")
    /// - Returns: Dictionary mapping strings to strings, or empty dict if not found
    func loadStringDictionary(
        key: String,
        localFileName: String,
        subdirectory: String? = nil
    ) -> [String: String] {
        return queue.sync {
            // Try Firebase Remote Config first
            if isFirebaseEnabled, let remoteConfig = remoteConfig {
                if let jsonString = remoteConfig.getString(key: key),
                   let data = jsonString.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    // Cache the remote config
                    cacheConfig(key: key, data: data)
                    return dict
                }
            }

            // Try cached version
            if let cached = loadCachedConfig(key: key),
               let dict = try? JSONSerialization.jsonObject(with: cached) as? [String: String] {
                return dict
            }

            // Fallback to local JSON file
            return loadLocalStringDictionary(fileName: localFileName, subdirectory: subdirectory)
        }
    }

    /// Load local JSON array from bundle
    private func loadLocalStringArray(fileName: String) -> [String] {
        // Handle both "male_names.json" and "male_names" formats
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "json" : (fileName as NSString).pathExtension

        guard let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// Load local JSON dictionary from bundle
    private func loadLocalStringDictionary(fileName: String, subdirectory: String?) -> [String: String] {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: subdirectory) ??
                       bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    /// Cache a config value locally
    private func cacheConfig(key: String, data: Data) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(key).json")
        try? data.write(to: cacheFile)
    }

    /// Load cached config value
    private func loadCachedConfig(key: String) -> Data? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(key).json")
        return try? Data(contentsOf: cacheFile)
    }

    /// Clear all cached remote configs
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

/// Protocol for Firebase Remote Config abstraction
/// This allows us to support Firebase without directly importing it everywhere
protocol RemoteConfigProtocol {
    func getString(key: String) -> String?
    func fetchAndActivate() async throws
}

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig

/// Firebase Remote Config implementation
extension RemoteConfig: RemoteConfigProtocol {
    func getString(key: String) -> String? {
        return self.configValue(forKey: key).stringValue
    }

    func fetchAndActivate() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.fetchAndActivate { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
#endif
