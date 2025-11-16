//
//  FamilyTreeView+Handlers.swift
//  MyTree
//
//  Event handlers, gestures, and lifecycle management for FamilyTreeView
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Gestures

extension FamilyTreeView {
    /// The magnification gesture for zooming the tree visualization.
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                viewModel.scale = min(max(viewModel.lastScale * value, 0.5), 3.0)
            }
            .onEnded { _ in
                viewModel.lastScale = viewModel.scale
            }
    }

    /// The drag gesture for panning the tree visualization.
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.offset = CGSize(
                    width: viewModel.offset.width + value.translation.width / 10,
                    height: viewModel.offset.height + value.translation.height / 10
                )
            }
    }
}

// MARK: - Lifecycle Handlers

extension FamilyTreeView {
    /// Handles the view's onAppear lifecycle event.
    func handleOnAppear(geometry: GeometryProxy) {
        let appearStart = CFAbsoluteTimeGetCurrent()
        AppLog.tree.debug("\n🎨 FamilyTreeView.onAppear() started")

        // Precompute degree cache for efficient filtering (must happen first)
        if let root = viewModel.myContact {
            let cacheStart = CFAbsoluteTimeGetCurrent()
            RelationshipCacheManager.shared.precomputeAllDegrees(
                from: root,
                members: viewModel.members
            )
            let cacheTime = (CFAbsoluteTimeGetCurrent() - cacheStart) * 1000
            logTiming("Cache precompute", value: cacheTime)
        }

        // Initialize visible members - use environment values if available (headless mode)
        // otherwise default to just the root
        if let initialVisibleIds = initialVisibleMemberIds, !initialVisibleIds.isEmpty {
            viewModel.visibleMemberIds = initialVisibleIds
            if let initialDegree = initialDegreeOfSeparation {
                viewModel.degreeOfSeparation = initialDegree
            }
            let msg = "Using initial state from environment: degree=\(viewModel.degreeOfSeparation)"
            AppLog.tree.debug("\(msg), visibleIds=\(viewModel.visibleMemberIds.count)")
            // Trigger the degree change handler to properly initialize the view
            handleDegreeChange(geometry: geometry)
        } else if let root = viewModel.myContact {
            viewModel.visibleMemberIds = [root.id]
            viewModel.updateFilteredMembers()
            if viewModel.nodePositions.isEmpty {
                layoutNodes(in: geometry)
            } else {
                // Ensure root is visible immediately
                if let rootId = viewModel.myContact?.id, !viewModel.visibleNodeIds.contains(rootId) {
                    viewModel.visibleNodeIds.insert(rootId)
                }
            }
        }

        // Select, highlight, and center on me card on launch
        if let meCard = viewModel.myContact,
           let meNode = viewModel.nodePositions.first(where: { $0.member.id == meCard.id }) {
            // Select the me contact
            viewModel.selectedMember = meCard

            // Highlight the path to root (though this is the root, it ensures consistency)
            viewModel.highlightPathToRoot(from: meCard.id)

            // Center the view on the me contact
            viewModel.offset = calculateCenteringOffset(for: meNode, in: geometry)

            // Calculate screen position after centering (node will be at screen center)
            let sidebarWidth: CGFloat = viewModel.showSidebar ? 480 : 0
            let settingsWidth: CGFloat = viewModel.showSettings ? 280 : 0
            let toolbarHeight: CGFloat = 44
            let effectiveWidth = geometry.size.width - sidebarWidth - settingsWidth
            let effectiveHeight = geometry.size.height - toolbarHeight
            let posX = meNode.x * viewModel.scale + viewModel.offset.width + sidebarWidth + effectiveWidth / 2
            let posY = meNode.y * viewModel.scale + viewModel.offset.height + toolbarHeight + effectiveHeight / 2
            viewModel.selectedNodePosition = ScreenCoordinate(x: posX, y: posY)
        }

        let appearTime = (CFAbsoluteTimeGetCurrent() - appearStart) * 1000
        logTiming("onAppear() duration", value: appearTime)
    }

    /// Handles changes in the members list.
    func handleMembersChange(geometry: GeometryProxy) {
        // Clear and recompute cache when members change
        if let root = viewModel.myContact {
            RelationshipCacheManager.shared.clear()
            RelationshipCacheManager.shared.precomputeAllDegrees(
                from: root,
                members: viewModel.members
            )
        }
        viewModel.updateFilteredMembers()
        layoutNodes(in: geometry)
    }

    /// Handles changes to the root contact.
    func handleMyContactChange(geometry: GeometryProxy) {
        // Clear and recompute cache when root contact changes
        RelationshipCacheManager.shared.clear()
        if let root = viewModel.myContact {
            RelationshipCacheManager.shared.precomputeAllDegrees(
                from: root,
                members: viewModel.members
            )
        }
        viewModel.updateFilteredMembers()
        layoutNodes(in: geometry)
    }

    /// Handles changes in the degree of separation.
    func handleDegreeChange(geometry: GeometryProxy) {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLog.tree.debug("\n🔄 [Degree Change] Starting re-render for degree: \(viewModel.degreeOfSeparation)")

        // Set flag to prevent re-entrant triggers from visibleMemberIds change
        // Reset after a delay to ensure onChange handlers have fired
        viewModel.isHandlingDegreeChange = true
        DispatchQueue.main.async {
            self.viewModel.isHandlingDegreeChange = false
        }

        // Store current visible members to detect if we're adding or removing
        let previousVisibleIds = viewModel.visibleNodeIds

        // Update visible members based on new degree
        let membersWithinDegree = viewModel.treeData.members(withinDegree: viewModel.degreeOfSeparation)
        viewModel.visibleMemberIds = Set(membersWithinDegree.map { $0.id })

        let filterStartTime = CFAbsoluteTimeGetCurrent()
        viewModel.updateFilteredMembers()
        let filterDuration = (CFAbsoluteTimeGetCurrent() - filterStartTime) * 1000
        logTiming("Filter update", value: filterDuration)

        // Determine if we're growing or shrinking the graph
        let newVisibleIds = Set(viewModel.filteredMembers.map { $0.id })
        let isGrowing = newVisibleIds.count > previousVisibleIds.count

        AppLog.tree.debug("   📊 Previous visible: \(previousVisibleIds.count), New visible: \(newVisibleIds.count)")
        let addedIds = newVisibleIds.subtracting(previousVisibleIds)
        let removedIds = previousVisibleIds.subtracting(newVisibleIds)
        if !addedIds.isEmpty {
            let addedNames = addedIds.compactMap { id in viewModel.filteredMembers.first { $0.id == id }?.fullName }
            AppLog.tree.debug("   ➕ Added: \(addedNames.joined(separator: ", "))")
        }
        if !removedIds.isEmpty {
            let removedNames = removedIds.compactMap { id in viewModel.members.first { $0.id == id }?.fullName }
            AppLog.tree.debug("   ➖ Removed: \(removedNames.joined(separator: ", "))")
        }

        if isGrowing {
            // Use incremental placement for smooth progressive rendering when growing
            // Only render NEW members (those not already visible) to match sidebar order
            AppLog.tree.debug("   📈 Growing graph: using incremental placement for new members only")
            layoutNodesIncrementalForNewMembers(
                newMemberIds: addedIds,
                previousVisibleIds: previousVisibleIds,
                geometry: geometry
            )
        } else {
            // Use transition system when shrinking (better for removals)
            AppLog.tree.debug("   📉 Shrinking graph: using transition system")

            // Capture current state before making changes
            let currentConnections = GraphState.extractConnections(from: viewModel.nodePositions)
            let currentState = GraphState(
                nodePositions: viewModel.nodePositions,
                visibleNodeIds: viewModel.visibleNodeIds,
                connections: currentConnections
            )

            let layoutStartTime = CFAbsoluteTimeGetCurrent()
            let destinationState = computeDestinationState(in: geometry)
            let layoutDuration = (CFAbsoluteTimeGetCurrent() - layoutStartTime) * 1000
            logTiming("Layout calculation", value: layoutDuration)

            // Calculate the transition
            let transition = GraphTransitionCalculator.computeTransition(
                from: currentState,
                to: destinationState
            )

            // Log all changes
            transition.logTransition()

            // Apply the transition with animations
            applyGraphTransition(transition, geometry: geometry)
        }

        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logTiming("Degree change total", value: totalDuration)
    }

    /// Handles changes in spacing parameters.
    func handleSpacingChange(geometry: GeometryProxy) {
        withAnimation(.easeInOut(duration: 0.5)) {
            layoutNodes(in: geometry)
        }
    }

    /// Handles changes in the geometry size.
    func handleGeometryChange(geometry: GeometryProxy) {
        // If viewport size changes, recalculate centering offset
        if let selectedMember = viewModel.selectedMember,
           let selectedNode = viewModel.nodePositions.first(where: { $0.member.id == selectedMember.id }) {
            let targetOffset = calculateCenteringOffset(for: selectedNode, in: geometry)
            viewModel.offset = targetOffset  // Apply immediately without animation
        } else if let meCard = viewModel.myContact,
                  let meNode = viewModel.nodePositions.first(where: { $0.member.id == meCard.id }) {
            let targetOffset = calculateCenteringOffset(for: meNode, in: geometry)
            viewModel.offset = targetOffset
        }
    }

    /// Handles changes in the visible members set.
    func handleVisibleMembersChange(geometry: GeometryProxy) {
        // Skip if we're already handling a degree change (prevents double-trigger)
        guard !viewModel.isHandlingDegreeChange else {
            AppLog.tree.debug("🔄 [Visible Members Change] Skipping (already handling degree change)")
            return
        }

        let msg = "Re-rendering with \(viewModel.visibleMemberIds.count) visible members"
        AppLog.tree.debug("\n🔄 [Visible Members Change] \(msg)")

        // Store current visible members to detect if we're adding or removing
        let previousVisibleIds = viewModel.visibleNodeIds

        // Update filtered members to only include visible ones
        viewModel.updateFilteredMembers()

        // Determine if we're growing or shrinking the graph
        let newVisibleIds = Set(viewModel.filteredMembers.map { $0.id })
        let isGrowing = newVisibleIds.count > previousVisibleIds.count

        AppLog.tree.debug("   📊 Previous visible: \(previousVisibleIds.count), New visible: \(newVisibleIds.count)")
        let addedIds = newVisibleIds.subtracting(previousVisibleIds)
        let removedIds = previousVisibleIds.subtracting(newVisibleIds)
        if !addedIds.isEmpty {
            let addedNames = addedIds.compactMap { id in viewModel.members.first { $0.id == id }?.fullName }
            AppLog.tree.debug("   ➕ Added: \(addedNames.joined(separator: ", "))")
        }
        if !removedIds.isEmpty {
            let removedNames = removedIds.compactMap { id in viewModel.members.first { $0.id == id }?.fullName }
            AppLog.tree.debug("   ➖ Removed: \(removedNames.joined(separator: ", "))")
        }

        // Special case: If we're starting from empty (initial load), use incremental placement
        if previousVisibleIds.isEmpty && isGrowing {
            AppLog.tree.debug("   🚀 Initial load: using incremental placement")
            layoutNodes(in: geometry)
            return
        }

        // For all other cases (growing or shrinking), use smooth transition system
        if isGrowing {
            AppLog.tree.debug("   📈 Growing graph: using transition system")
        } else {
            AppLog.tree.debug("   📉 Shrinking graph: using transition system")
        }

        // Capture current state before making changes
        let currentConnections = GraphState.extractConnections(from: viewModel.nodePositions)
        let currentState = GraphState(
            nodePositions: viewModel.nodePositions,
            visibleNodeIds: viewModel.visibleNodeIds,
            connections: currentConnections
        )

        // Compute destination state by laying out the new visible members
        let destinationState = computeDestinationState(in: geometry)

        // Calculate the transition
        let transition = GraphTransitionCalculator.computeTransition(
            from: currentState,
            to: destinationState
        )

        // Log all changes
        transition.logTransition()

        // Apply the transition with animations
        applyGraphTransition(transition, geometry: geometry)
    }
}

// MARK: - Keyboard Monitoring

extension FamilyTreeView {
    /// Sets up keyboard monitoring for debug mode (spacebar key).
    func setupKeyboardMonitoring() {
        #if canImport(AppKit)
        viewModel.keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // Spacebar keycode
                if self.viewModel.debugMode {
                    AppLog.tree.debug("🔵 [DEBUG] Spacebar pressed - advancing to next step")
                    DispatchQueue.main.async {
                        self.viewModel.debugStepReady = true
                    }
                    return nil // Event handled
                }
            }
            return event // Pass through
        }
        #endif
    }

    /// Tears down keyboard monitoring when debug mode is off or view disappears.
    func teardownKeyboardMonitoring() {
        #if canImport(AppKit)
        if let monitor = viewModel.keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            viewModel.keyboardMonitor = nil
        }
        #endif
    }
}

// MARK: - Helper Methods

extension FamilyTreeView {
    /// Helper to get parent positions for a given child node.
    func getParentPositions(for childNode: NodePosition) -> ParentLookup {
        let visiblePositions = viewModel.nodePositions.filter { viewModel.visibleNodeIds.contains($0.member.id) }
        return parentPositions(for: childNode, visiblePositions: visiblePositions)
    }

    /// Checks if there are any active animations that require continuous redraws
    var hasActiveAnimations: Bool {
        // Check if any path animations are still in progress (not yet at 1.0)
        if viewModel.isAnimating {
            return true
        }
        // Check if any path animation progress is less than 1.0
        // Use a small epsilon to account for floating point precision
        return viewModel.pathAnimations.values.contains { $0 < 0.999 }
    }
}

// MARK: - Helper Views

extension FamilyTreeView {
    var sidebarView: some View {
        FamilyMemberSidebar(
            allMembers: viewModel.members,
            filteredMembers: viewModel.filteredMembers,
            rootMember: viewModel.myContact ?? viewModel.members.first!,
            treeData: viewModel.treeData,
            renderingPriorities: viewModel.renderingPriorities,
            visibleMemberIds: $viewModel.visibleMemberIds,
            language: viewModel.selectedLanguage
        )
    }

    var backgroundView: some View {
        Color.adaptiveBackground
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        viewModel.clearSelection()
                    }
            )
    }

    @ViewBuilder var canvasView: some View {
        if hasActiveAnimations {
            TimelineView(.animation) { _ in
                Canvas { context, size in
                    drawConnections(context: context, size: size)
                }
            }
        } else {
            Canvas { context, size in
                drawConnections(context: context, size: size)
            }
        }
    }
}
