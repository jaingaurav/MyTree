import Foundation

/// Protocol for localizing relationship labels
protocol RelationshipLocalizer {
    func localize(info: RelationshipInfo) -> String
}

/// Configuration-based localizer that loads labels from Firebase Remote Config or local JSON files
struct ConfigBasedLocalizer: RelationshipLocalizer {
    private let languageCode: String
    private static var labelCache: [String: [RelationshipKind: String]] = [:]

    init(languageCode: String) {
        self.languageCode = languageCode
    }

    private var labels: [RelationshipKind: String] {
        // Check cache first
        if let cached = Self.labelCache[languageCode] {
            return cached
        }

        // Load from Remote Config Manager (Firebase or local fallback)
        let remoteConfigKey = "localization_\(languageCode)"
        let json = RemoteConfigManager.shared.loadStringDictionary(
            key: remoteConfigKey,
            localFileName: languageCode,
            subdirectory: nil
        )

        // If empty, fallback to English
        guard !json.isEmpty else {
            return Self.loadEnglishFallback()
        }

        var labels: [RelationshipKind: String] = [:]

        // Map JSON keys to RelationshipKind cases
        for (key, value) in json {
            if key == "default" { continue }
            if let kind = RelationshipKind.fromString(key) {
                labels[kind] = value
            }
        }

        // Cache the loaded labels
        Self.labelCache[languageCode] = labels
        return labels
    }

    /// Fallback to English labels if language file is missing
    private static func loadEnglishFallback() -> [RelationshipKind: String] {
        if let cached = labelCache["en"] {
            return cached
        }

        let remoteConfigKey = "localization_en"
        let json = RemoteConfigManager.shared.loadStringDictionary(
            key: remoteConfigKey,
            localFileName: "en",
            subdirectory: nil
        )

        guard !json.isEmpty else {
            return [:] // Return empty dict if even English is missing
        }

        var labels: [RelationshipKind: String] = [:]
        for (key, value) in json {
            if key == "default" { continue }
            if let kind = RelationshipKind.fromString(key) {
                labels[kind] = value
            }
        }

        labelCache["en"] = labels
        return labels
    }

    func localize(info: RelationshipInfo) -> String {
        let labels = self.labels
        return labels[info.kind] ?? labels[.me] ?? "Relative"
    }
}

/// Factory to get the appropriate localizer for a language
enum RelationshipLocalizerFactory {
    static func localizer(for language: Language) -> RelationshipLocalizer {
        return ConfigBasedLocalizer(languageCode: language.configCode)
    }
}
