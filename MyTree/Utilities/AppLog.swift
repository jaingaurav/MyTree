import Foundation
import OSLog

/// Centralized logging configuration using Apple's unified logging system.
///
/// Provides category-specific loggers for different parts of the application.
/// Uses OSLog for performance and integration with Console.app and Instruments.
///
/// **Available Categories:**
/// - `general`: General application-level events
/// - `contacts`: Contact fetching, authorization, and conversion
/// - `tree`: Tree building, layout, and rendering
/// - `cache`: Relationship caching operations
/// - `image`: Image loading and processing
///
/// **Logging Levels:**
/// - `debug`: Development-only verbose logging (stripped in release builds)
/// - `info`: Important informational messages (retained in logs)
/// - `error`: Error conditions that should be investigated
///
/// **Usage:**
/// ```swift
/// AppLog.contacts.debug("Loading contacts...")
/// AppLog.tree.error("Layout failed: \(error)")
/// ```
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MyTree"

    /// General application logger
    nonisolated static let general = Category("General")

    /// Contacts operations logger
    nonisolated static let contacts = Category("Contacts")

    /// Family tree operations logger
    nonisolated static let tree = Category("FamilyTree")

    /// Relationship caching logger
    nonisolated static let cache = Category("RelationshipCache")

    /// Image processing logger
    nonisolated static let image = Category("Image")

    /// Headless rendering logger (for CLI output)
    nonisolated static let headless = Category("Headless")

    /// Logging category wrapper for type-safe logging.
    struct Category {
        private let logger: Logger

        init(_ name: String) {
            logger = Logger(subsystem: AppLog.subsystem, category: name)
        }

        /// Logs a debug message (DEBUG builds only).
        nonisolated func debug(_ message: @autoclosure () -> String) {
            #if DEBUG
            let resolvedMessage = message()
            logger.debug("\(resolvedMessage, privacy: .public)")
            #endif
        }

        /// Logs an informational message.
        nonisolated func info(_ message: @autoclosure () -> String) {
            let resolvedMessage = message()
            logger.info("\(resolvedMessage, privacy: .public)")
        }

        /// Logs an error message.
        nonisolated func error(_ message: @autoclosure () -> String) {
            let resolvedMessage = message()
            logger.error("\(resolvedMessage, privacy: .public)")
        }
    }
}
