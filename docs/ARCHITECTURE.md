# Architecture

MyTree is a SwiftUI family tree visualization app using MVVM architecture with a priority-based layout algorithm.

## Project Structure

```text
MyTree/
├── Models/              # Data models (FamilyMember, NodePosition, RelationshipInfo)
├── Services/            # Business logic (layout, contacts, relationships, localizers)
├── Views/               # SwiftUI views and rendering
├── ViewModels/          # MVVM state management
└── Utilities/           # Helpers and extensions
```

## Core Architectural Patterns

### MVVM State Management

**FamilyTreeViewModel** centralizes all state:

- Selected member and path highlighting
- Filtered members (degree of separation)
- Pan/zoom offsets and scale
- Animation state

**When adding new state:**

1. Add `@Published` property to `FamilyTreeViewModel`
2. Update view to observe via `@StateObject` or `@ObservedObject`
3. Keep business logic in ViewModel, not View

### Coordinate System

Two coordinate spaces:

- **Tree Space**: Logical layout coordinates (root at 0,0)
- **Screen Space**: Visual rendering with pan/zoom transform

**Transform:** `screenPos = (treePos * scale) + offset + screenCenter`

**When adding rendering:** Always work in tree space for layout, convert to screen space for display.

### Priority-Based Layout

**ContactLayoutManager** places nodes by relationship priority:

- Priority = `1000 - (degree * 100) + relationshipBonus`
- Bonuses: Spouse +50, Parent +30, Child +20

**When modifying layout:** Maintain priority-based ordering to keep close relatives together.

See [LAYOUT_ALGORITHM.md](LAYOUT_ALGORITHM.md) for full algorithm details.

## Adding New Functionality

### Adding a New View

1. **Create SwiftUI view** in `MyTree/Views/`
2. **Use ViewModel for state** - Don't create `@State` in views
3. **Follow naming convention**: `ComponentNameView.swift`
4. **Use extensions for complexity**: `ViewName+Feature.swift`

**Example:**

```swift
struct NewFeatureView: View {
    @ObservedObject var viewModel: FamilyTreeViewModel

    var body: some View {
        // Access state via viewModel
        // Keep logic in ViewModel
    }
}
```

### Adding a New Model

1. **Create in `MyTree/Models/`**
2. **Conform to necessary protocols**: `Identifiable`, `Codable`, `Equatable`
3. **Keep models simple** - No business logic, just data
4. **Use value types** (struct) unless reference semantics needed

**Example:**

```swift
struct NewModel: Identifiable, Codable, Equatable {
    let id: UUID
    var property: String

    // Data only, no logic
}
```

### Adding a New Localizer

**No Swift code needed!** Just add configuration files:

1. **Create JSON config file** in `MyTree/localizations/` (e.g., `it.json` for Italian)
2. **Add language to `languages.json`** (optional, for UI display)
3. **Add Language enum case** (if you want it in the UI language picker)

### Step 1: Create JSON config file

Create `MyTree/localizations/it.json` with all relationship kinds
(see [Configuration Files](#configuration-files) section for format).

### Step 2: Add to languages.json (optional)

Add entry to `MyTree/languages.json`:

```json
{
  "code": "it",
  "displayName": "Italiano (Italian)",
  "configFile": "it.json"
}
```

### Step 3: Add Language enum case (if needed for UI)

If you want the language to appear in the UI language picker, add to `MyTree/Models/FamilyMember.swift`:

```swift
enum Language: String, CaseIterable, Identifiable {
    // ... existing cases
    case italian = "Italiano (Italian)"

    var configCode: String {
        switch self {
        // ... existing cases
        case .italian: return "it"
        }
    }
}
```

**That's it!** The `ConfigBasedLocalizer` automatically loads from JSON
files. No Swift localizer struct needed.

**Note:** The JSON config file is loaded automatically from the app bundle.
If a language file is missing, it falls back to English translations.

### Adding a New Service

1. **Create in `MyTree/Services/`**
2. **Keep focused** - Single responsibility
3. **Use protocols** for testability
4. **Avoid singletons** - Pass dependencies

**Pattern:**

```swift
protocol NewServiceProtocol {
    func doSomething() -> Result
}

class NewService: NewServiceProtocol {
    private let dependency: SomeDependency

    init(dependency: SomeDependency) {
        self.dependency = dependency
    }

    func doSomething() -> Result {
        // Implementation
    }
}
```

### Adding Animation

Animations coordinate through **incremental placement**:

1. Layout calculates all positions
2. Nodes appear in priority order (staggered)
3. Connections animate after nodes

**Timing:**

- Node appearance: 0.3s ease-in-out
- Connections: 0.5s bezier
- Pan/zoom: 0.6s smooth

**When adding animations:** Coordinate timing with existing animations to avoid conflicts.

### Adding Connection Types

Connections are **first-class entities** with identity and animation state.

**ConnectionManager** tracks:

- Active connections
- Fade-in/fade-out animations
- Connection identity (prevents duplicates)

**To add new connection type:**

1. Add case to `ConnectionType` enum
2. Update `ConnectionRenderer` drawing logic
3. Update `ConnectionManager` creation logic

## Key Design Decisions

### Why MVVM?

Separates presentation from business logic, enables testing, reduces view complexity.

### Why Priority-Based Layout?

Ensures close relatives placed first, creates balanced trees, prevents distant relatives from blocking family units.

### Why Two Coordinate Spaces?

Decouples logical layout from rendering, enables smooth pan/zoom, simplifies coordinate math.

### Why Connection Manager?

Tracks connection identity for animations, enables smooth transitions, prevents duplicate connections.

## Testing Strategy

- **Unit tests**: Layout algorithm, relationship calculation, localizers
- **Integration tests**: Contact import, layout pipeline, state management
- Test files in `MyTreeIntegrationTests/` and `MyTreeUnitTests/`

## Performance Considerations

- **Layout**: O(n log n) via priority queue
- **Rendering**: Canvas for hardware-accelerated connection drawing
- **Memory**: Lazy photo loading
- **Incremental animations**: Prevent UI blocking

## Configuration Files

MyTree uses JSON configuration files for customizable data that doesn't
require code changes. Configurations can be managed locally (JSON files) or
remotely via **Firebase Remote Config** (optional).

**See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for complete Firebase Remote
Config setup instructions.**

### Gender Names

Gender inference uses name lists loaded from separate JSON files:

- **`male_names.json`**: Alphabetically sorted list of male names
- **`female_names.json`**: Alphabetically sorted list of female names

**Location**: `MyTree/male_names.json` and `MyTree/female_names.json`

**Format**: Simple JSON array of lowercase strings:

```json
[
  "amit",
  "anil",
  "david",
  "james",
  "john",
  ...
]
```

**Usage**: These files are loaded by `RelationshipCalculator.inferGenderFromName()` via `RemoteConfigManager`, which:

- Tries Firebase Remote Config first (if configured)
- Falls back to cached remote configs
- Falls back to local JSON files
- Falls back to hardcoded defaults if all else fails

### Localization Files

All language localizations are stored in JSON config files:

- **Location**: `MyTree/localizations/`
- **Naming**: ISO 639-1 language codes (e.g., `en.json`, `hi.json`, `zh.json`)
- **Format**: JSON object mapping relationship kind keys to localized strings

**Example** (`localizations/en.json`):

```json
{
  "me": "Me",
  "father": "Father",
  "mother": "Mother",
  "paternalGrandfather": "Grandfather",
  "default": "Relative"
}
```

**Keys**: Use camelCase matching `RelationshipKind` enum cases
(e.g., `paternalGrandfather`, `wifesBrother`)

**Fallback Chain**:

1. Firebase Remote Config (if configured)
2. Cached remote configs (from previous Firebase fetch)
3. Local JSON files (bundled with app)
4. Hardcoded defaults (if all else fails)

**Caching**: Labels are loaded once and cached for performance. Remote
configs are also cached locally for offline use.

**Adding names**:

- **Locally**: Edit JSON files and rebuild app
- **Remotely**: Update Firebase Remote Config keys (`male_names`, `female_names`) - no rebuild needed!

**Adding localizations**:

- **Locally**: See [Adding a New Localizer](#adding-a-new-localizer)
  section above. No Swift code needed - just add a JSON file!
- **Remotely**: Update Firebase Remote Config key `localization_{code}` -
  no rebuild needed! See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for details.

**Remote Updates**: When Firebase Remote Config is configured, configs can
be updated remotely without app updates.

## Common Patterns

### ViewModel Updates

```swift
// In ViewModel
@Published var selectedMember: FamilyMember?

func selectMember(_ member: FamilyMember) {
    selectedMember = member
    highlightPathToRoot()
    // Business logic here
}
```

### Service Injection

```swift
// In View
struct FamilyTreeView: View {
    @StateObject var viewModel: FamilyTreeViewModel
    let layoutManager: ContactLayoutManager

    init(layoutManager: ContactLayoutManager = ContactLayoutManager()) {
        self.layoutManager = layoutManager
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel())
    }
}
```

### Extension Organization

```swift
// FamilyTreeView.swift - Main view structure
// FamilyTreeView+Animation.swift - Animation logic
// FamilyTreeView+Selection.swift - Selection handling
// FamilyTreeView+Gestures.swift - Pan/zoom gestures
```

## Build Targets

- **macOS app**: GUI application
- **iOS app**: Mobile version (planned)
- **CLI tool**: Headless rendering via `--vcf`, `--output` flags

**CLI detection**: Arguments like `--vcf` auto-enable headless mode.

## Further Reading

- [LAYOUT_ALGORITHM.md](LAYOUT_ALGORITHM.md) - Detailed layout algorithm
- Root `README.md` - Build and usage instructions
- `CONTRIBUTING.md` - Contribution guidelines
