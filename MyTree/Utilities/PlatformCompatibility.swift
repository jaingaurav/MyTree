//
//  PlatformCompatibility.swift
//  MyTree
//
//  Platform compatibility layer for macOS and iOS
//

import SwiftUI

/// Namespace for platform compatibility utilities
enum PlatformCompatibility {}

// MARK: - Platform Type Aliases

/// Type aliases for platform-specific types:
/// - `PlatformColor`: NSColor on macOS, UIColor on iOS
/// - `PlatformImage`: NSImage on macOS, UIImage on iOS

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#elseif os(iOS)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#endif

// MARK: - Color Extensions

extension Color {
    /// Platform-agnostic window/system background color.
    static var windowBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #elseif os(iOS)
        return Color(uiColor: .systemBackground)
        #endif
    }

    /// Platform-agnostic control background color.
    static var controlBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #elseif os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// MARK: - Image Extensions

extension Image {
    /// Initialize an Image from raw platform image data, validating size on macOS.
    init?(platformImageData data: Data) {
        #if os(macOS)
        // Try creating NSImage from data
        guard let nsImage = NSImage(data: data) else {
            // If NSImage creation fails, log for debugging
            AppLog.image.error("Failed to create NSImage from data (\(data.count) bytes)")
            return nil
        }

        // Ensure the image is valid (has a valid size)
        guard nsImage.size.width > 0 && nsImage.size.height > 0 else {
            AppLog.image.error("NSImage has invalid size: \(nsImage.size)")
            return nil
        }

        self.init(nsImage: nsImage)
        #elseif os(iOS)
        guard let uiImage = UIImage(data: data) else {
            AppLog.image.error("Failed to create UIImage from data (\(data.count) bytes)")
            return nil
        }
        self.init(uiImage: uiImage)
        #endif
    }
}
