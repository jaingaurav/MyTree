# Firebase Remote Config Setup

MyTree supports Firebase Remote Config for managing configuration files
remotely. This allows you to update gender names, localizations, and
language lists without releasing a new app version.

## Overview

The `RemoteConfigManager` provides a unified interface that:

1. **Fetches from Firebase Remote Config** (if configured)
2. **Falls back to cached configs** (from previous Firebase fetches)
3. **Falls back to local JSON files** (bundled with the app)

This ensures the app works offline and without Firebase, while allowing remote updates when Firebase is configured.

## Setup Instructions

### Step 1: Add Firebase SDK

Add Firebase Remote Config to your Xcode project via Swift Package Manager:

1. In Xcode: **File** → **Add Package Dependencies...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select **FirebaseRemoteConfig** product
4. Add to your target

### Step 2: Configure Firebase in Your App

Update `MyTree/MyTreeApp.swift` to initialize Firebase:

```swift
import SwiftUI
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
import FirebaseCore
#endif

@main
struct MyTreeApp: App {
    init() {
        #if canImport(FirebaseRemoteConfig)
        // Configure Firebase
        FirebaseApp.configure()

        // Configure Remote Config
        let remoteConfig = RemoteConfig.remoteConfig()

        // Set default values from local JSON files (optional but recommended)
        // This ensures the app works even if Firebase is unavailable
        let defaults: [String: NSObject] = [
            "male_names": loadDefaultJSON("male_names.json") as NSObject,
            "female_names": loadDefaultJSON("female_names.json") as NSObject,
            "localization_en": loadDefaultJSON("localizations/en.json") as NSObject,
            // ... add other localizations
        ]
        remoteConfig.setDefaults(defaults)

        // Configure Remote Config Manager
        RemoteConfigManager.shared.configureFirebase(remoteConfig)

        // Fetch and activate remote config (non-blocking)
        Task {
            do {
                try await remoteConfig.fetchAndActivate()
                print("✅ Remote Config fetched and activated")
            } catch {
                print("⚠️ Remote Config fetch failed: \(error)")
                // App will use local defaults
            }
        }
        #endif

        // ... rest of init code
    }

    #if canImport(FirebaseRemoteConfig)
    private func loadDefaultJSON(_ fileName: String) -> String {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil),
              let data = try? Data(contentsOf: url),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
    #endif
}
```

### Step 3: Configure Firebase Console

1. **Create Firebase Project**: Go to [Firebase Console](https://console.firebase.google.com/)
2. **Add iOS/macOS App**: Register your app with bundle ID
3. **Download `GoogleService-Info.plist`**: Add to your Xcode project
4. **Enable Remote Config**: In Firebase Console → Remote Config

### Step 4: Set Up Remote Config Keys

In Firebase Console → Remote Config, add the following keys:

#### Gender Names

- **Key**: `male_names`
- **Type**: JSON
- **Default Value**: Content of `male_names.json` (as JSON string)

- **Key**: `female_names`
- **Type**: JSON
- **Default Value**: Content of `female_names.json` (as JSON string)

#### Localizations

For each language, add a key:

- **Key**: `localization_en` (for English)
- **Type**: JSON
- **Default Value**: Content of `localizations/en.json` (as JSON string)

- **Key**: `localization_hi` (for Hindi)
- **Key**: `localization_zh` (for Chinese)
- **Key**: `localization_es` (for Spanish)
- ... (one key per language)

#### Languages List

- **Key**: `languages`
- **Type**: JSON
- **Default Value**: Content of `languages.json` (as JSON string)

### Step 5: Publish Remote Config

After setting up keys and values in Firebase Console:

1. Click **Publish changes**
2. Remote configs will be available to apps on next fetch

## Remote Config Key Naming Convention

- **Gender names**: `male_names`, `female_names`
- **Localizations**: `localization_{language_code}` (e.g., `localization_en`, `localization_hi`)
- **Languages list**: `languages`

## How It Works

### Loading Priority

1. **Firebase Remote Config** (if enabled and fetched)
2. **Cached Remote Config** (from previous Firebase fetch, stored in app cache)
3. **Local JSON Files** (bundled with app)

### Caching

Remote configs are automatically cached to:

- `~/Library/Caches/MyTree/RemoteConfig/`

This ensures:

- **Offline support**: App works without internet
- **Fast loading**: No network delay after first fetch
- **Automatic updates**: New configs fetched in background

### Fetch Strategy

Remote Config is fetched:

- **On app launch** (non-blocking, async)
- **Periodically** (Firebase handles this automatically)
- **Manually** (can be triggered programmatically)

## Testing Without Firebase

The app works perfectly without Firebase! It will:

- Use local JSON files from the app bundle
- Function normally offline
- Work in CLI mode

Firebase is **optional** - the app is designed to work with or without it.

## Updating Configs Remotely

### Adding New Names

1. Edit `male_names` or `female_names` in Firebase Console
2. Add/remove names in JSON array format
3. Publish changes
4. Apps will receive updates on next fetch (typically within minutes)

### Adding New Localization

1. Create new key: `localization_{code}` (e.g., `localization_it`)
2. Paste JSON content from `localizations/it.json`
3. Publish changes
4. Add language to `languages` key if needed

### A/B Testing

Firebase Remote Config supports:

- **Conditional values** based on user properties
- **Gradual rollouts** (percentage-based)
- **A/B testing** with experiments

Example: Test new localization terms with 10% of users before full rollout.

## Troubleshooting

### Configs Not Updating

- Check Firebase Console → Remote Config → **Publish changes**
- Verify app has internet connection
- Check fetch interval (default: 12 hours)
- Force fetch: `remoteConfig.fetch()` in code

### Fallback to Local Files

If Firebase is unavailable, the app automatically uses local JSON files. This is expected behavior and ensures reliability.

### Cache Issues

Clear cache programmatically:

```swift
RemoteConfigManager.shared.clearCache()
```

Or manually delete: `~/Library/Caches/MyTree/RemoteConfig/`

## Security Considerations

- **Sensitive data**: Don't store sensitive information in Remote Config
- **Validation**: Always validate remote config values before use
- **Defaults**: Always provide local defaults (already done in code)
- **Rate limiting**: Firebase handles rate limiting automatically

## Best Practices

1. **Always set defaults**: Use local JSON files as defaults
2. **Validate values**: Remote configs should match expected format
3. **Version configs**: Consider versioning your config structure
4. **Monitor changes**: Use Firebase Analytics to track config usage
5. **Test locally**: Test config changes in Firebase Console before publishing

## Example: Adding a New Name

**In Firebase Console:**

1. Open Remote Config
2. Edit `male_names` key
3. Add new name to JSON array: `["amit", "anil", "new_name", ...]`
4. Publish changes

**Result:**

- Apps fetch update within 12 hours (or immediately if you force fetch)
- New name is used for gender inference
- No app update required!

## Example: Updating Localization

**In Firebase Console:**

1. Open Remote Config
2. Edit `localization_en` key
3. Update JSON: `{"father": "Dad", "mother": "Mom", ...}`
4. Publish changes

**Result:**

- English localization updates across all apps
- Changes visible after next config fetch
- No app update required!
