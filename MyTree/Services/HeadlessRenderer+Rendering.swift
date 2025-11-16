//
//  HeadlessRenderer+Rendering.swift
//  MyTree
//
//  Rendering functions for HeadlessRenderer
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit

extension HeadlessRenderer {
    // MARK: - Rendering

    /// Resolves the actual dark mode state based on appearance mode setting
    private func resolveIsDarkMode(_ appearanceMode: AppearanceMode) -> Bool {
        switch appearanceMode {
        case .light:
            return false
        case .dark:
            return true
        case .system:
            #if os(macOS)
            // Check the actual system appearance
            let appearance = NSApp.effectiveAppearance
            if let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                return bestMatch == .darkAqua
            }
            return false
            #else
            return false
            #endif
        }
    }

    func renderTreeView(
        treeData: FamilyTreeData,
        rootContact: FamilyMember,
        membersToRender: [FamilyMember],
        config: Config
    ) async throws -> NSImage {
        log("Creating FamilyTreeView with \(treeData.members.count) members, root: \(rootContact.fullName)")
        log("Image size: \(config.imageWidth)x\(config.imageHeight)")
        log("Degree of separation: \(config.degreeOfSeparation)")
        log("Show sidebar: \(config.showSidebar)")
        log("Debug mode: \(config.debugMode)")
        log("Show debug overlay: \(config.showDebugOverlay)")
        log("Members to render: \(membersToRender.count)")

        // Calculate visible member IDs based on degree of separation
        let membersWithinDegree = treeData.members(withinDegree: config.degreeOfSeparation)
        let visibleMemberIds = Set(membersWithinDegree.map { $0.id })
        log("Visible members within degree \(config.degreeOfSeparation): \(visibleMemberIds.count)")
        log("Root contact: \(rootContact.fullName) (ID: \(rootContact.id))")

        // Debug: Check root's relationships
        let rootNeighbors = treeData.neighbors(of: rootContact.id)
        log("Root has \(rootNeighbors.count) neighbors")
        let rootDegree = treeData.degreeOfSeparation(for: rootContact.id)
        log("Root's own degree: \(rootDegree == Int.max ? "unreachable" : String(rootDegree))")
        if rootNeighbors.isEmpty {
            log("WARNING: Root has no neighbors - tree will only show root node")
        }

        // Use the actual FamilyTreeView to ensure identical rendering to the Mac app
        // We need to manually trigger layout since onAppear may not fire in headless rendering
        let view = HeadlessTreeViewContainer(
            treeData: treeData,
            rootContact: rootContact,
            visibleMemberIds: visibleMemberIds,
            degreeOfSeparation: config.degreeOfSeparation,
            imageWidth: config.imageWidth,
            imageHeight: config.imageHeight,
            appearanceMode: config.appearanceMode,
            showDebugOverlay: config.showDebugOverlay,
            saveIntermediateRenders: config.saveIntermediateRenders,
            outputImagePath: config.outputImagePath
        )

        // Render SwiftUI view to NSImage
        log("Starting SwiftUI view rendering to NSImage...")
        let renderStart = CFAbsoluteTimeGetCurrent()
        let imageSize = CGSize(width: config.imageWidth, height: config.imageHeight)
        let image = try await renderViewToImage(view, size: imageSize)
        let renderDuration = (CFAbsoluteTimeGetCurrent() - renderStart) * 1000
        log("View rendering completed in \(String(format: "%.1f", renderDuration))ms")

        // Save intermediate renders if requested
        if config.saveIntermediateRenders {
            log("Saving intermediate render steps...")
            try await saveIntermediateRenders(
                treeData: treeData,
                rootContact: rootContact,
                visibleMemberIds: visibleMemberIds,
                config: config
            )
        }

        return image
    }

    func saveIntermediateRenders(
        treeData: FamilyTreeData,
        rootContact: FamilyMember,
        visibleMemberIds: Set<String>,
        config: Config
    ) async throws {
        let filteredMembers = treeData.members.filter { visibleMemberIds.contains($0.id) }

        let layoutManager = ContactLayoutManager(
            members: filteredMembers,
            root: rootContact,
            treeData: treeData,
            baseSpacing: 180,
            spouseSpacing: 180,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        let placementSteps = layoutManager.layoutNodesIncremental(language: .english)
        log("Rendering \(placementSteps.count) intermediate steps...")

        let imageSize = CGSize(width: config.imageWidth, height: config.imageHeight)

        // Save each step
        let baseURL = URL(fileURLWithPath: config.outputImagePath)
        let directory = baseURL.deletingLastPathComponent()
        let fileExtension = baseURL.pathExtension
        let baseFilename = baseURL.deletingPathExtension().lastPathComponent

        for (index, step) in placementSteps.enumerated() {
            let stepNum = index + 1
            let stepFilename = "\(baseFilename)_step_\(String(format: "%03d", stepNum)).\(fileExtension)"
            let stepPath = directory.appendingPathComponent(stepFilename).path

            log("Rendering step \(stepNum)/\(placementSteps.count)...")

            // Calculate centering offset for THIS step (keep root centered in every step)
            guard let rootNode = step.first(where: { $0.member.id == rootContact.id }) else {
                log("Could not find root node in step \(stepNum)")
                continue
            }
            let stepOffset = CGSize(width: -rootNode.x, height: -rootNode.y)

            let stepImage = try await renderStepImage(
                step: step,
                rootContact: rootContact,
                offset: stepOffset,
                imageSize: imageSize,
                config: config
            )

            try saveImage(stepImage, to: stepPath)
            log("Saved step \(stepNum) to \(stepFilename)")
        }

        log("Completed saving all \(placementSteps.count) intermediate renders")
    }

    func renderStepImage(
        step: [NodePosition],
        rootContact: FamilyMember,
        offset: CGSize,
        imageSize: CGSize,
        config: Config
    ) async throws -> NSImage {
        #if os(macOS)
        let isDarkMode = resolveIsDarkMode(config.appearanceMode)
        let stepView = HeadlessStepView(
            nodePositions: step,
            rootContact: rootContact,
            offset: offset,
            scale: 1.0,
            imageSize: imageSize,
            isDarkMode: isDarkMode,
            showDebugOverlay: config.showDebugOverlay
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let hostingView = NSHostingView(rootView: stepView)
                hostingView.frame = NSRect(origin: .zero, size: imageSize)

                // Small delay for SwiftUI to render
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hostingView.needsLayout = true
                    hostingView.layoutSubtreeIfNeeded()

                    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                        continuation.resume(throwing: HeadlessError.renderingFailed("Could not create bitmap for step"))
                        return
                    }

                    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

                    let nsImage = NSImage(size: imageSize)
                    nsImage.addRepresentation(bitmapRep)
                    continuation.resume(returning: nsImage)
                }
            }
        }
        #else
        throw HeadlessError.platformNotSupported
        #endif
    }

    func renderViewToImage<V: View>(_ view: V, size: CGSize) async throws -> NSImage {
        #if os(macOS)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let setupStart = CFAbsoluteTimeGetCurrent()

                // Create NSHostingView for rendering
                let hostingView = NSHostingView(rootView: view)
                hostingView.frame = NSRect(origin: .zero, size: size)

                let setupTime = (CFAbsoluteTimeGetCurrent() - setupStart) * 1000
                AppLog.headless.info("[HeadlessRender] NSHostingView created in \(String(format: "%.1f", setupTime))ms")

                // Normal wait time - intermediate renders happen after this
                let waitTime: TimeInterval = 3.0
                AppLog.headless.info("[HeadlessRender] Waiting \(Int(waitTime)) seconds for SwiftUI to render view and connections...")

                // Give SwiftUI time to initialize, layout, and save intermediate steps
                DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                    let captureStart = CFAbsoluteTimeGetCurrent()

                    // Force layout
                    hostingView.needsLayout = true
                    hostingView.layoutSubtreeIfNeeded()

                    // Create bitmap representation
                    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                        continuation.resume(throwing: HeadlessError.renderingFailed("Could not create bitmap"))
                        return
                    }

                    // Cache the display
                    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

                    // Create NSImage from bitmap
                    let nsImage = NSImage(size: size)
                    nsImage.addRepresentation(bitmapRep)

                    let captureTime = (CFAbsoluteTimeGetCurrent() - captureStart) * 1000
                    AppLog.headless.info("[HeadlessRender] Image captured in \(String(format: "%.1f", captureTime))ms")

                    continuation.resume(returning: nsImage)
                }
            }
        }
        #else
        throw HeadlessError.platformNotSupported
        #endif
    }

    func saveImage(_ image: NSImage, to path: String) throws {
        #if os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw HeadlessError.imageSaveFailed(path)
        }

        let url = URL(fileURLWithPath: path)
        try pngData.write(to: url)
        log("Image saved successfully to \(path)")
        #else
        throw HeadlessError.platformNotSupported
        #endif
    }

    func saveLogs(to path: String, logBuffer: [String]) throws {
        let logContent = logBuffer.joined(separator: "\n")
        let url = URL(fileURLWithPath: path)
        try logContent.write(to: url, atomically: true, encoding: .utf8)
        log("Logs saved successfully to \(path)")
    }
}

#endif
