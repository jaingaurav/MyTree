# MyTree Resources

This directory contains data files and assets used by the MyTree application at runtime.

## Contents

### Data Files

- **`male_names.json`** - List of common male given names for gender inference
- **`female_names.json`** - List of common female given names for gender inference
- **`languages.json`** - Configuration of supported localization languages

### Localizations Directory

The `Localizations/` subdirectory contains relationship term translations for different languages:

- **`en.json`** - English relationship terms
- **`es.json`** - Spanish (Español) relationship terms
- **`fr.json`** - French (Français) relationship terms
- **`gu.json`** - Gujarati (ગુજરાતી) relationship terms
- **`hi.json`** - Hindi (हिन्दी) relationship terms
- **`ur.json`** - Urdu (اردو) relationship terms
- **`zh.json`** - Chinese (中文) relationship terms

## Usage

These files are loaded by the app using `Bundle.main` APIs:

- **Gender name lists**: Used by `RelationshipCalculator` via `RemoteConfigManager`
- **Language config**: Used by `FamilyMember.Language` to list available languages
- **Localizations**: Used by `RelationshipLocalizer` to provide culturally appropriate relationship terms

## Firebase Remote Config Integration

The app supports Firebase Remote Config for dynamic updates:

1. **Local files** serve as the default/fallback data
2. **Firebase Remote Config** can override these with remotely-fetched values
3. **Local caching** stores fetched remote configs for offline use

See `RemoteConfigManager` for implementation details.

## File Formats

### Gender Name Lists (`male_names.json`, `female_names.json`)

Simple JSON array of strings:

```json
[
  "John",
  "Michael",
  "David"
]
```

### Languages Config (`languages.json`)

Array of language configuration objects:

```json
[
  {
    "code": "en",
    "displayName": "English",
    "configFile": "en.json"
  }
]
```

### Localization Files (`Localizations/*.json`)

Key-value pairs mapping relationship types to localized terms:

```json
{
  "father": "Father",
  "mother": "Mother",
  "brother": "Brother",
  "sister": "Sister"
}
```

## Adding New Languages

To add a new language:

1. Create a new JSON file in `Localizations/` (e.g., `de.json` for German)
2. Populate it with relationship term translations
3. Add an entry to `languages.json`
4. Add a new case to `FamilyMember.Language` enum
5. Test the localization in the app

## Build Integration

These files are automatically copied to the app bundle during build:

- Source location: `MyTree/Resources/`
- Bundle location: `MyTree.app/Contents/Resources/`
- Xcode flattens the directory structure during copy

The files are marked as "Copy Bundle Resources" in the Xcode project.
