//
//  HeadlessTreeViewContainers.swift
//  MyTree
//
//  Container views for headless rendering
//

import Foundation
import SwiftUI

#if os(macOS)

/// Namespace for headless tree view container types
enum HeadlessTreeViewContainers {}

// MARK: - Headless Tree View Container

/// Container view that manually initializes FamilyTreeView for headless rendering
struct HeadlessTreeViewContainer: View {
    let treeData: FamilyTreeData
    let rootContact: FamilyMember
    let visibleMemberIds: Set<String>
    let degreeOfSeparation: Int
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let appearanceMode: HeadlessRenderer.AppearanceMode
    let showDebugOverlay: Bool
    let saveIntermediateRenders: Bool
    let outputImagePath: String

    @Environment(\.colorScheme)
    var systemColorScheme

    var effectiveColorScheme: ColorScheme {
        switch appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemColorScheme
        }
    }

    var backgroundColor: Color {
        effectiveColorScheme == .dark ? Color.black : Color.white
    }

    var body: some View {
        GeometryReader { geometry in
            HeadlessTreeViewContent(
                treeData: treeData,
                rootContact: rootContact,
                visibleMemberIds: visibleMemberIds,
                degreeOfSeparation: degreeOfSeparation,
                geometry: geometry,
                isDarkMode: effectiveColorScheme == .dark,
                showDebugOverlay: showDebugOverlay,
                saveIntermediateRenders: saveIntermediateRenders,
                outputImagePath: outputImagePath,
                imageSize: CGSize(width: imageWidth, height: imageHeight)
            )
        }
        .frame(width: imageWidth, height: imageHeight)
        .background(backgroundColor)
        .preferredColorScheme(appearanceMode == .system ? nil : effectiveColorScheme)
    }
}

/// Manual implementation of tree rendering that doesn't rely on onAppear
struct HeadlessTreeViewContent: View {
    let treeData: FamilyTreeData
    let rootContact: FamilyMember
    let visibleMemberIds: Set<String>
    let degreeOfSeparation: Int
    let geometry: GeometryProxy
    let isDarkMode: Bool
    let showDebugOverlay: Bool
    let saveIntermediateRenders: Bool
    let outputImagePath: String
    let imageSize: CGSize

    @State private var nodePositions: [NodePosition] = []
    @State private var hasInitialized = false
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var currentStep: Int = 0
    @State private var placementSteps: [[NodePosition]] = []

    var backgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }

    var lineColor: Color {
        isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    var debugColor: Color {
        isDarkMode ? Color.green : Color.red
    }

    var debugTextColor: Color {
        isDarkMode ? Color.white : Color.black
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            // Draw connections
            if hasInitialized {
                Canvas { context, size in
                    drawConnections(context: &context, size: size)
                }
            }

            // Draw nodes
            ForEach(nodePositions, id: \.member.id) { nodePos in
                // Apply scale and offset to match UI version
                let posX = nodePos.x * scale + offset.width + geometry.size.width / 2
                let posY = nodePos.y * scale + offset.height + geometry.size.height / 2

                ZStack {
                    ContactNodeView(
                        member: nodePos.member,
                        isSelected: false,
                        isHighlighted: false,
                        relationshipInfo: nodePos.relationshipInfo,
                        language: .english
                    )

                    // Debug overlay
                    if showDebugOverlay {
                        VStack(spacing: 2) {
                            // Debug info box above node
                            VStack(alignment: .leading, spacing: 1) {
                                Text("ID: \(nodePos.member.id.prefix(8))...")
                                    .font(.system(size: 8))
                                Text("Pos: (\(Int(nodePos.x)), \(Int(nodePos.y)))")
                                    .font(.system(size: 8))
                                Text("Screen: (\(Int(posX)), \(Int(posY)))")
                                    .font(.system(size: 8))
                                Text("Gen: \(nodePos.generation)")
                                    .font(.system(size: 8))
                            }
                            .padding(4)
                            .background(debugColor.opacity(0.8))
                            .foregroundColor(debugTextColor)
                            .cornerRadius(4)
                            .offset(y: -100)

                            Spacer()
                        }
                    }
                }
                .position(x: posX, y: posY)
            }

            // Draw debug overlay elements
            if showDebugOverlay && hasInitialized {
                Canvas { context, size in
                    // Draw bounding boxes around nodes
                    for nodePos in nodePositions {
                        // Apply scale and offset to match UI version
                        let posX = nodePos.x * scale + offset.width + size.width / 2
                        let posY = nodePos.y * scale + offset.height + size.height / 2

                        // Draw a rectangle around the node
                        let rect = CGRect(x: posX - 60, y: posY - 60, width: 120, height: 120)
                        context.stroke(
                            Path(roundedRect: rect, cornerRadius: 4),
                            with: .color(debugColor.opacity(0.5)),
                            lineWidth: 1
                        )

                        // Draw center crosshair
                        var crosshair = Path()
                        crosshair.move(to: CGPoint(x: posX - 5, y: posY))
                        crosshair.addLine(to: CGPoint(x: posX + 5, y: posY))
                        crosshair.move(to: CGPoint(x: posX, y: posY - 5))
                        crosshair.addLine(to: CGPoint(x: posX, y: posY + 5))
                        context.stroke(crosshair, with: .color(debugColor), lineWidth: 2)
                    }

                    // Draw center axis lines
                    var centerLines = Path()
                    centerLines.move(to: CGPoint(x: size.width / 2, y: 0))
                    centerLines.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    centerLines.move(to: CGPoint(x: 0, y: size.height / 2))
                    centerLines.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    let centerLineStyle = StrokeStyle(lineWidth: 1, dash: [5, 5])
                    context.stroke(centerLines, with: .color(debugColor.opacity(0.3)), style: centerLineStyle)
                }
            }
        }
        .onAppear {
            performLayout()
        }
        .task {
            // Alternative to onAppear for async context
            if !hasInitialized {
                performLayout()
            }
        }
    }

    private func performLayout() {
        guard !hasInitialized else { return }

        AppLog.headless.info("[HeadlessRender] Starting incremental layout...")

        // Get filtered members
        let filteredMembers = treeData.members.filter { visibleMemberIds.contains($0.id) }
        AppLog.headless.info("[HeadlessRender] Filtered to \(filteredMembers.count) members")

        // Use LayoutOrchestrator with stateless engine
        let orchestrator = LayoutOrchestrator()
        let layoutConfig = LayoutConfiguration(
            baseSpacing: 180,
            spouseSpacing: 180,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        // Compute incremental placement steps
        if case .success(let steps) = orchestrator.layoutTreeIncremental(
            members: filteredMembers,
            root: rootContact,
            treeData: treeData,
            config: layoutConfig,
            language: .english
        ) {
            placementSteps = steps
        } else {
            placementSteps = []
            AppLog.headless.error("[HeadlessRender] Failed to compute incremental layout")
        }
        AppLog.headless.info("[HeadlessRender] Computed \(placementSteps.count) placement steps")

        // Log each step
        for (index, step) in placementSteps.enumerated() {
            let stepNum = index + 1
            let names = step.map { $0.member.fullName }.joined(separator: ", ")
            AppLog.headless.info("[HeadlessRender] Step \(stepNum)/\(placementSteps.count): \(step.count) node(s)")
            AppLog.headless.info("[HeadlessRender]   Members: \(names)")

            // Log positions for each node in this step
            for nodePos in step {
                let posStr = "(\(Int(nodePos.x)), \(Int(nodePos.y)))"
                AppLog.headless.info("[HeadlessRender]   - \(nodePos.member.fullName) @ \(posStr), gen: \(nodePos.generation)")
            }
        }

        // Use the final step as the complete layout
        if let finalStep = placementSteps.last {
            nodePositions = finalStep
        }

        // Calculate centering offset to keep root in the center (matching UI behavior)
        if let rootNode = nodePositions.first(where: { $0.member.id == rootContact.id }) {
            offset = CGSize(width: -rootNode.x * scale, height: -rootNode.y * scale)

            AppLog.headless.info("[HeadlessRender] Root node '\(rootContact.fullName)' at position (\(rootNode.x), \(rootNode.y))")
            AppLog.headless.info("[HeadlessRender] Applied centering offset: (\(offset.width), \(offset.height))")
        }

        hasInitialized = true

        AppLog.headless.info("[HeadlessRender] Layout complete with \(nodePositions.count) total nodes")
    }

    private func drawConnections(context: inout GraphicsContext, size: CGSize) {
        let visiblePositions = nodePositions

        // Helper to convert node position to screen position (matching UI version)
        func toScreen(_ nodePos: NodePosition) -> CGPoint {
            CGPoint(
                x: nodePos.x * scale + offset.width + size.width / 2,
                y: nodePos.y * scale + offset.height + size.height / 2
            )
        }

        // Draw spouse connections
        var processedSpousePairs = Set<String>()
        for node in visiblePositions {
            let spouseRelations = node.member.relations.filter { $0.relationType == .spouse }
            for relation in spouseRelations {
                guard let spouse = visiblePositions.first(where: { $0.member.id == relation.member.id }) else {
                    continue
                }

                let pairID = [node.member.id, spouse.member.id].sorted().joined(separator: "-")
                guard processedSpousePairs.insert(pairID).inserted else { continue }

                let nodeCenter = toScreen(node)
                let spouseCenter = toScreen(spouse)

                var path = Path()
                // Adjust for circle radius (40px)
                if nodeCenter.x < spouseCenter.x {
                    path.move(to: CGPoint(x: nodeCenter.x + 40, y: nodeCenter.y - 29))
                    path.addLine(to: CGPoint(x: spouseCenter.x - 40, y: spouseCenter.y - 29))
                } else {
                    path.move(to: CGPoint(x: nodeCenter.x - 40, y: nodeCenter.y - 29))
                    path.addLine(to: CGPoint(x: spouseCenter.x + 40, y: spouseCenter.y - 29))
                }

                context.stroke(path, with: .color(lineColor), lineWidth: 2)
            }
        }

        // Draw parent-child connections
        var processedFamilies = Set<String>()
        for node in visiblePositions {
            let children = node.member.relations
                .filter { $0.relationType == .child }
                .compactMap { relation in
                    visiblePositions.first { $0.member.id == relation.member.id }
                }

            guard !children.isEmpty else { continue }

            var parents = [node]
            if let spouseRelation = node.member.relations.first(where: { $0.relationType == .spouse }),
               let spouse = visiblePositions.first(where: { $0.member.id == spouseRelation.member.id }) {
                parents.append(spouse)
            }

            let familyID = (parents.map { $0.member.id }.sorted() + children.map { $0.member.id }.sorted())
                .joined(separator: "-")
            guard processedFamilies.insert(familyID).inserted else { continue }

            let parentCenter: CGPoint
            if parents.count == 2 {
                let parent1 = toScreen(parents[0])
                let parent2 = toScreen(parents[1])
                parentCenter = CGPoint(
                    x: (parent1.x + parent2.x) / 2,
                    y: max(parent1.y, parent2.y) + 40 - 29
                )
            } else {
                let singleParent = toScreen(parents[0])
                parentCenter = CGPoint(x: singleParent.x, y: singleParent.y + 40 - 29)
            }

            let childCenters = children.map { child -> CGPoint in
                toScreen(child)
            }

            guard let firstChild = childCenters.first else { continue }
            let minX = childCenters.map { $0.x }.min() ?? firstChild.x
            let maxX = childCenters.map { $0.x }.max() ?? firstChild.x
            let barY = firstChild.y - 40 - 30 - 29

            // Vertical stem from parent
            var stem = Path()
            stem.move(to: parentCenter)
            stem.addLine(to: CGPoint(x: parentCenter.x, y: barY))
            context.stroke(stem, with: .color(lineColor), lineWidth: 2)

            // Horizontal bar
            var bar = Path()
            bar.move(to: CGPoint(x: minX, y: barY))
            bar.addLine(to: CGPoint(x: maxX, y: barY))
            context.stroke(bar, with: .color(lineColor), lineWidth: 2)

            // Vertical drops to children
            for childCenter in childCenters {
                var drop = Path()
                drop.move(to: CGPoint(x: childCenter.x, y: barY))
                drop.addLine(to: CGPoint(x: childCenter.x, y: childCenter.y - 40 - 29))
                context.stroke(drop, with: .color(lineColor), lineWidth: 2)
            }
        }
    }
}

// MARK: - Helper View for Rendering Individual Steps

/// Helper view for rendering a single incremental step
struct HeadlessStepView: View {
    let nodePositions: [NodePosition]
    let rootContact: FamilyMember
    let offset: CGSize
    let scale: CGFloat
    let imageSize: CGSize
    let isDarkMode: Bool
    let showDebugOverlay: Bool

    var backgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }

    var lineColor: Color {
        isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    var debugColor: Color {
        isDarkMode ? Color.green : Color.red
    }

    var debugTextColor: Color {
        isDarkMode ? Color.white : Color.black
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()

                // Draw connections
                Canvas { context, size in
                    drawStepConnections(context: &context, size: size)
                }

                // Draw nodes
                ForEach(nodePositions, id: \.member.id) { nodePos in
                    let posX = nodePos.x * scale + offset.width + geometry.size.width / 2
                    let posY = nodePos.y * scale + offset.height + geometry.size.height / 2

                    ZStack {
                        ContactNodeView(
                            member: nodePos.member,
                            isSelected: false,
                            isHighlighted: false,
                            relationshipInfo: nodePos.relationshipInfo,
                            language: .english
                        )

                        // Debug overlay
                        if showDebugOverlay {
                            VStack(spacing: 2) {
                                // Debug info box above node
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("ID: \(nodePos.member.id.prefix(8))...")
                                        .font(.system(size: 8))
                                    Text("Pos: (\(Int(nodePos.x)), \(Int(nodePos.y)))")
                                        .font(.system(size: 8))
                                    Text("Screen: (\(Int(posX)), \(Int(posY)))")
                                        .font(.system(size: 8))
                                    Text("Gen: \(nodePos.generation)")
                                        .font(.system(size: 8))
                                }
                                .padding(4)
                                .background(debugColor.opacity(0.8))
                                .foregroundColor(debugTextColor)
                                .cornerRadius(4)
                                .offset(y: -80)

                                Spacer()
                            }
                        }
                    }
                    .position(x: posX, y: posY)
                }

                // Draw debug overlay elements
                if showDebugOverlay {
                    Canvas { context, size in
                        // Draw bounding boxes around nodes
                        for nodePos in nodePositions {
                            let posX = nodePos.x * scale + offset.width + size.width / 2
                            let posY = nodePos.y * scale + offset.height + size.height / 2

                            // Draw a rectangle around the node
                            let rect = CGRect(x: posX - 45, y: posY - 45, width: 90, height: 90)
                            context.stroke(
                                Path(rect),
                                with: .color(debugColor),
                                lineWidth: 1
                            )

                            // Draw crosshair at node center
                            let centerPath = Path { path in
                                path.move(to: CGPoint(x: posX - 5, y: posY))
                                path.addLine(to: CGPoint(x: posX + 5, y: posY))
                                path.move(to: CGPoint(x: posX, y: posY - 5))
                                path.addLine(to: CGPoint(x: posX, y: posY + 5))
                            }
                            context.stroke(
                                centerPath,
                                with: .color(debugColor),
                                lineWidth: 2
                            )
                        }
                    }
                }
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
        .background(backgroundColor)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private func drawStepConnections(context: inout GraphicsContext, size: CGSize) {
        // Helper to convert node position to screen position
        func toScreen(_ nodePos: NodePosition) -> CGPoint {
            CGPoint(
                x: nodePos.x * scale + offset.width + size.width / 2,
                y: nodePos.y * scale + offset.height + size.height / 2
            )
        }

        // Draw spouse connections
        var processedSpousePairs = Set<String>()
        for node in nodePositions {
            for relation in node.member.relations where relation.relationType == .spouse {
                guard let spouse = nodePositions.first(where: { $0.member.id == relation.member.id }) else {
                    continue
                }

                let pairID = [node.member.id, spouse.member.id].sorted().joined(separator: "-")
                guard processedSpousePairs.insert(pairID).inserted else { continue }

                let nodeCenter = toScreen(node)
                let spouseCenter = toScreen(spouse)

                var path = Path()
                if nodeCenter.x < spouseCenter.x {
                    path.move(to: CGPoint(x: nodeCenter.x + 40, y: nodeCenter.y - 29))
                    path.addLine(to: CGPoint(x: spouseCenter.x - 40, y: spouseCenter.y - 29))
                } else {
                    path.move(to: CGPoint(x: nodeCenter.x - 40, y: nodeCenter.y - 29))
                    path.addLine(to: CGPoint(x: spouseCenter.x + 40, y: spouseCenter.y - 29))
                }

                context.stroke(path, with: .color(lineColor), lineWidth: 2)
            }
        }

        // Draw parent-child connections
        var processedFamilies = Set<String>()
        for node in nodePositions {
            let children = node.member.relations
                .filter { $0.relationType == .child }
                .compactMap { relation in
                    nodePositions.first { $0.member.id == relation.member.id }
                }

            guard !children.isEmpty else { continue }

            var parents = [node]
            if let spouseRelation = node.member.relations.first(where: { $0.relationType == .spouse }),
               let spouse = nodePositions.first(where: { $0.member.id == spouseRelation.member.id }) {
                parents.append(spouse)
            }

            let familyID = (parents.map { $0.member.id }.sorted() + children.map { $0.member.id }.sorted())
                .joined(separator: "-")
            guard processedFamilies.insert(familyID).inserted else { continue }

            let parentCenter: CGPoint
            if parents.count == 2 {
                let parent1 = toScreen(parents[0])
                let parent2 = toScreen(parents[1])
                parentCenter = CGPoint(
                    x: (parent1.x + parent2.x) / 2,
                    y: max(parent1.y, parent2.y) + 40 - 29
                )
            } else {
                let singleParent = toScreen(parents[0])
                parentCenter = CGPoint(x: singleParent.x, y: singleParent.y + 40 - 29)
            }

            let childCenters = children.map { toScreen($0) }
            guard let firstChild = childCenters.first else { continue }
            let minX = childCenters.map { $0.x }.min() ?? firstChild.x
            let maxX = childCenters.map { $0.x }.max() ?? firstChild.x
            let barY = firstChild.y - 40 - 30 - 29

            // Vertical stem from parent
            var stem = Path()
            stem.move(to: parentCenter)
            stem.addLine(to: CGPoint(x: parentCenter.x, y: barY))
            context.stroke(stem, with: .color(lineColor), lineWidth: 2)

            // Horizontal bar
            var bar = Path()
            bar.move(to: CGPoint(x: minX, y: barY))
            bar.addLine(to: CGPoint(x: maxX, y: barY))
            context.stroke(bar, with: .color(lineColor), lineWidth: 2)

            // Vertical drops to children
            for childCenter in childCenters {
                var drop = Path()
                drop.move(to: CGPoint(x: childCenter.x, y: barY))
                drop.addLine(to: CGPoint(x: childCenter.x, y: childCenter.y - 40 - 29))
                context.stroke(drop, with: .color(lineColor), lineWidth: 2)
            }
        }
    }
}

#endif
