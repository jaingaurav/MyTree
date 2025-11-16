import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct MyTreeApp: App {
    init() {
        // Initialize Remote Config Manager
        // If Firebase is available, configure it here:
        // #if canImport(FirebaseRemoteConfig)
        //     FirebaseApp.configure()
        //     let remoteConfig = RemoteConfig.remoteConfig()
        //     remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
        //     RemoteConfigManager.shared.configureFirebase(remoteConfig)
        //     Task {
        //         try? await remoteConfig.fetchAndActivate()
        //     }
        // #endif

        // For now, RemoteConfigManager will use local JSON files as fallback
        #if os(macOS)
        // Detect CLI mode: check for specific CLI arguments
        // macOS adds system arguments like -NSDocumentRevisionsDebugMode, so we can't just count args
        let cliArguments: Set<String> = [
            "--help", "-h",
            "--vcf", "--contacts", "--names",
            "--root", "--root-name",
            "--output", "--log",
            "--width", "--height", "--degree",
            "--appearance", "--debug", "--save-steps"
        ]
        let isHeadlessMode = CommandLine.arguments.contains { cliArguments.contains($0) }

        // Check for help flag first - exit immediately without starting the app
        if isHeadlessMode && (CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h")) {
            Self.printHeadlessHelp()
            exit(0)
        }

        // If running in CLI mode (with CLI arguments), run in headless mode
        if isHeadlessMode {
            // Initialize NSApplication for headless mode
            let app = NSApplication.shared
            // Use .accessory policy to avoid showing in dock, but allow file access
            app.setActivationPolicy(.accessory)
            // Disable app sandboxing for command-line tool access
            // Note: This requires the app to not have sandbox entitlements when run as CLI

            // Run in headless mode
            Task { @MainActor in
                let renderer = HeadlessRenderer()
                await Self.runHeadlessMode(renderer: renderer)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    #if os(macOS)
    @MainActor
    private static func runHeadlessMode(renderer: HeadlessRenderer) async {
        do {
            let config = Self.parseHeadlessArguments()
            try await renderer.render(config: config)
            // Exit after rendering
            exit(0)
        } catch {
            AppLog.headless.error("Headless mode error: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func parseHeadlessArguments() -> HeadlessRenderer.Config {
        var config = HeadlessRenderer.Config.default
        let args = CommandLine.arguments
        var i = 0

        while i < args.count {
            let consumed = parseArgument(args[i], nextValue: i + 1 < args.count ? args[i + 1] : nil, config: &config)
            i += consumed
        }

        return config
    }

    private static func parseArgument(_ arg: String, nextValue: String?, config: inout HeadlessRenderer.Config) -> Int {
        switch arg {
        case "--vcf":
            return parseStringArgument(nextValue) { config.vcfPath = $0 }
        case "--contacts":
            return parseCommaSeparatedArgument(nextValue) { config.contactIds = $0 }
        case "--root":
            return parseStringArgument(nextValue) { config.rootContactId = $0 }
        case "--root-name":
            return parseStringArgument(nextValue) { config.rootContactName = $0 }
        case "--output":
            return parseStringArgument(nextValue) { config.outputImagePath = $0 }
        case "--log":
            return parseStringArgument(nextValue) { config.outputLogPath = $0 }
        case "--width":
            return parseNumericArgument(nextValue) { config.imageWidth = CGFloat($0) }
        case "--height":
            return parseNumericArgument(nextValue) { config.imageHeight = CGFloat($0) }
        case "--degree":
            return parseIntArgument(nextValue) { config.degreeOfSeparation = $0 }
        case "--appearance":
            return parseAppearanceMode(nextValue, config: &config)
        case "--debug":
            config.showDebugOverlay = true
            return 1
        case "--save-steps":
            config.saveIntermediateRenders = true
            return 1
        case "--names":
            return parseCommaSeparatedArgument(nextValue) { config.contactNames = $0 }
        case "--help", "-h":
            printHeadlessHelp()
            exit(0)
        default:
            return 1
        }
    }

    private static func parseStringArgument(_ value: String?, setter: (String) -> Void) -> Int {
        guard let value = value else { return 1 }
        setter(value)
        return 2
    }

    private static func parseCommaSeparatedArgument(_ value: String?, setter: ([String]) -> Void) -> Int {
        guard let value = value else { return 1 }
        let items = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        setter(items)
        return 2
    }

    private static func parseNumericArgument(_ value: String?, setter: (Double) -> Void) -> Int {
        guard let value = value, let number = Double(value) else { return 1 }
        setter(number)
        return 2
    }

    private static func parseIntArgument(_ value: String?, setter: (Int) -> Void) -> Int {
        guard let value = value, let number = Int(value) else { return 1 }
        setter(number)
        return 2
    }

    private static func parseAppearanceMode(_ value: String?, config: inout HeadlessRenderer.Config) -> Int {
        guard let value = value else { return 1 }
        let appearanceStr = value.lowercased()
        switch appearanceStr {
        case "light":
            config.appearanceMode = .light
        case "dark":
            config.appearanceMode = .dark
        case "system":
            config.appearanceMode = .system
        default:
            AppLog.general.error("Invalid appearance mode: \(appearanceStr). Using system default.")
        }
        return 2
    }

    private static func printHeadlessHelp() {
        // swiftlint:disable:next no_print_in_production
        print("""
        MyTree CLI Tool

        Usage: mytree [options]

        Note: This binary runs in CLI mode when executed as a standalone tool.
              To use the GUI, open the MyTree.app bundle instead.

        Options:
          --vcf <path>              Path to VCF file to load contacts from
          --contacts <ids>          Comma-separated list of contact IDs to render
          --root <id>               Contact ID to use as root
          --root-name <name>        Contact name to use as root (required if auto-detection fails)
          --output <path>           Output image path (default: family_tree.png)
          --log <path>              Output log path (default: family_tree.log)
          --width <pixels>          Image width in pixels (default: 2000)
          --height <pixels>         Image height in pixels (default: 1500)
          --degree <n>              Degree of separation (default: 2)
          --appearance <mode>       Appearance mode: light, dark, or system (default: system)
          --debug                   Enable debug overlay showing node positions and
                                     coordinates
          --save-steps              Save intermediate PNG images for each incremental
                                     placement step (creates step_001.png, step_002.png, etc.)
          --names <names>           Comma-separated list of contact names to render
                                     (filters to these names and their relationships within degree)
          --help, -h                Show this help message

        Examples:
          mytree --help
          mytree --vcf contacts.vcf --output tree.png
          mytree --contacts id1,id2,id3 --root id1 --output tree.png
          mytree --vcf contacts.vcf --names "John Doe,Jane Smith" --degree 2 --output tree.png
          mytree --vcf contacts.vcf --root-name "John Doe" --degree 1 --appearance dark --output tree_dark.png
          mytree --vcf contacts.vcf --root-name "John Doe" --degree 1 --debug --output tree_debug.png
          mytree --vcf contacts.vcf --root-name "John Doe" --degree 2 --save-steps --output tree.png
        """)
        fflush(stdout)
    }
    #endif
}
