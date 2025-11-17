//
//  FamilyTreeViewModel.swift
//  MyTree
//
//  Centralized state management for FamilyTreeView.
//  Resolves the 20+ @State variable explosion by consolidating all view state
//  and orchestration logic into a single, testable ViewModel.
//

import SwiftUI
import Combine

/// ViewModel managing all state and orchestration for family tree visualization.
/// Separates business logic from view presentation for improved testability.
final class FamilyTreeViewModel: ObservableObject {
    // MARK: - Dependencies

    let treeData: FamilyTreeData
    let myContact: FamilyMember?

    // MARK: - Layout State

    @Published var nodePositions: [NodePosition] = []
    @Published var visibleNodeIds: Set<String> = []
    @Published var filteredMembers: [FamilyMember] = []
    @Published var renderingPriorities: [String: Double] = [:]

    // MARK: - Connection State

    @Published var connections: [Connection] = []

    // MARK: - Selection State

    @Published var selectedMember: FamilyMember?
    @Published var selectedNodePosition: ScreenCoordinate?
    @Published var showingDetail = false
    @Published var highlightedPath: Set<String> = []
    @Published var highlightedPathOrdered: [String] = []

    // MARK: - Viewport State

    @Published var offset: CGSize = .zero
    @Published var scale: CGFloat = 1.0
    @Published var lastScale: CGFloat = 1.0

    // MARK: - Animation State

    @Published var isAnimating = false
    @Published var pathAnimations: [String: Double] = [:]
    @Published var previousNodeIds: Set<String> = []
    @Published var animationSpeedMs: Double = 1000.0

    // MARK: - Configuration State

    @Published var degreeOfSeparation: Int = 0
    @Published var visibleMemberIds: Set<String> = []
    @Published var layoutConfig: LayoutConfiguration = .default
    @Published var selectedLanguage: Language = .english

    // MARK: - UI State

    @Published var showSidebar: Bool = true
    @Published var showSettings: Bool = false

    // MARK: - Internal State Flags

    /// Flag to prevent re-entrant layout triggers during degree changes
    var isHandlingDegreeChange: Bool = false

    // MARK: - Debug State

    @Published var debugMode: Bool = false
    @Published var debugStepReady: Bool = false
    @Published var currentDebugStep: Int = 0
    @Published var totalDebugSteps: Int = 0
    @Published var debugStepDescription: String = ""
    @Published var debugChangesSummary: [String] = []
    var keyboardMonitor: Any?
    @Published var lastLoggedNodeCount: Int = 0
    @Published var lastCanvasRedrawTime = Date()
    @Published var canvasRedrawCount: Int = 0

    // MARK: - Computed Properties

    var members: [FamilyMember] {
        treeData.members
    }

    var hasActiveAnimations: Bool {
        isAnimating || pathAnimations.values.contains { $0 < 0.999 } ||
        connections.contains { $0.needsAnimation }
    }

    // MARK: - Initialization

    init(treeData: FamilyTreeData, myContact: FamilyMember?) {
        self.treeData = treeData
        self.myContact = myContact

        // Initialize layout configuration
        self.layoutConfig = .default
    }

    // MARK: - Layout Orchestration

    /// Updates filtered members based on currently visible member IDs.
    func updateFilteredMembers() {
        let startTime = CFAbsoluteTimeGetCurrent()

        filteredMembers = members.filter { visibleMemberIds.contains($0.id) }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        AppLog.tree.debug("\n📊 [updateFilteredMembers] Filtering members:")
        AppLog.tree.debug("   - Total members: \(treeData.members.count)")
        AppLog.tree.debug("   - Visible member IDs: \(visibleMemberIds.count)")
        AppLog.tree.debug("   - Filtered members: \(filteredMembers.count)")
        AppLog.tree.debug("   ⏱️ Duration: \(String(format: "%.2f", duration))ms")

        // Debug: show filtered members
        if filteredMembers.count <= 10 {
            for member in filteredMembers {
                let degree = treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("   - \(member.fullName): degree \(degree)")
            }
        } else {
            for member in filteredMembers.prefix(5) {
                let degree = treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("   - \(member.fullName): degree \(degree)")
            }
            AppLog.tree.debug("   ... and \(filteredMembers.count - 5) more")
        }
    }

    /// Extracts rendering priorities based on degree of separation.
    /// No longer needs layoutManager since we use stateless engine.
    func extractRenderingPriorities() {
        var priorities: [String: Double] = [:]

        // Root member gets highest priority
        if let me = myContact {
            priorities[me.id] = 1000.0
        }

        // Compute priorities based on degree (same logic as priority queue)
        for member in filteredMembers {
            if priorities[member.id] == nil {
                let degree = treeData.degreeOfSeparation(for: member.id)
                // Higher priority = lower degree, with index-based tiebreaker
                let index = filteredMembers.firstIndex(where: { $0.id == member.id }) ?? 0
                priorities[member.id] = Double(10000 - degree * 1000 - index)
            }
        }

        renderingPriorities = priorities
    }

    // MARK: - Selection Management

    /// Highlights the path from a member to the root contact.
    func highlightPathToRoot(from memberId: String) {
        guard let relationshipInfo = treeData.relationshipInfo(for: memberId) else {
            highlightedPath = []
            highlightedPathOrdered = []
            return
        }

        let pathIds = relationshipInfo.path.map { $0.id }
        highlightedPath = Set(pathIds)
        highlightedPathOrdered = pathIds
    }

    /// Clears current selection and highlighting.
    func clearSelection() {
        selectedMember = nil
        selectedNodePosition = nil
        showingDetail = false
        highlightedPath = []
        highlightedPathOrdered = []
    }

    /// Clears highlighting but keeps selection.
    func clearHighlighting() {
        highlightedPath = []
        highlightedPathOrdered = []
    }

    // MARK: - Viewport Management

    /// Calculates offset needed to center a node in the viewport.
    func calculateCenteringOffset(
        for node: NodePosition,
        viewportSize: CGSize,
        sidebarVisible: Bool
    ) -> CGSize {
        let sidebarWidth: CGFloat = sidebarVisible ? 480 : 0
        let settingsWidth: CGFloat = showSettings ? 280 : 0
        let toolbarHeight: CGFloat = 44
        let effectiveWidth = viewportSize.width - sidebarWidth - settingsWidth
        let effectiveHeight = viewportSize.height - toolbarHeight

        let targetX = -(node.x * scale) + effectiveWidth / 2
        let targetY = -(node.y * scale) + effectiveHeight / 2 + toolbarHeight

        return CGSize(width: targetX, height: targetY)
    }

    /// Centers viewport on a specific node.
    func centerOnNode(
        _ node: NodePosition,
        viewportSize: CGSize
    ) {
        let targetOffset = calculateCenteringOffset(
            for: node,
            viewportSize: viewportSize,
            sidebarVisible: showSidebar
        )

        withAnimation(.easeInOut(duration: 0.5)) {
            offset = targetOffset
        }
    }

    // MARK: - Viewport Transform

    /// Transforms tree coordinate to screen coordinate using current viewport state.
    func treeToScreen(
        _ treeCoord: TreeCoordinate,
        viewportSize: CGSize
    ) -> ScreenCoordinate {
        let sidebarWidth: CGFloat = showSidebar ? 480 : 0
        let settingsWidth: CGFloat = showSettings ? 280 : 0
        let toolbarHeight: CGFloat = 44
        let centerX = (viewportSize.width - sidebarWidth - settingsWidth) / 2
        let centerY = (viewportSize.height - toolbarHeight) / 2 + toolbarHeight

        return treeCoord.toScreen(
            scale: scale,
            offset: offset,
            viewportCenter: CGPoint(x: centerX, y: centerY)
        )
    }

    // MARK: - Deduplication

    /// Deduplicates node positions by member ID, keeping the last occurrence.
    func deduplicatePositions(_ positions: [NodePosition]) -> [NodePosition] {
        var seen = Set<String>()
        var result: [NodePosition] = []

        // Iterate in reverse to keep the last occurrence
        for position in positions.reversed() where seen.insert(position.member.id).inserted {
            result.append(position)
        }

        return result.reversed()
    }

    // MARK: - Layout Configuration

    /// Updates spacing configuration dynamically.
    func updateSpacing(spouse: CGFloat, general: CGFloat) {
        layoutConfig = LayoutConfiguration(
            baseSpacing: general,
            spouseSpacing: spouse,
            verticalSpacing: layoutConfig.verticalSpacing,
            minSpacing: layoutConfig.minSpacing,
            expansionFactor: layoutConfig.expansionFactor
        )
    }

    // MARK: - Connection Management

    /// Updates connections based on current node state
    func updateConnections() {
        let descriptors = ConnectionManager.calculateDesiredConnections(
            from: nodePositions,
            visibleNodeIds: visibleNodeIds
        )

        let result = ConnectionManager.updateConnections(
            current: connections,
            desired: descriptors,
            highlightedPath: highlightedPath
        )

        if result.hasChanges {
            AppLog.tree.debug("\n🔗 [Connection Update]")
            AppLog.tree.debug("   New connections: \(result.newConnectionIds.count)")
            AppLog.tree.debug("   Removed connections: \(result.removedConnectionIds.count)")

            // Log new connections
            for id in result.newConnectionIds {
                if let conn = result.connections.first(where: { $0.id == id }) {
                    AppLog.tree.debug("   ➕ \(conn.type.rawValue): \(conn.fromNodeName) → \(conn.toNodeName)")
                }
            }

            // Log removed connections
            for id in result.removedConnectionIds {
                if let conn = connections.first(where: { $0.id == id }) {
                    AppLog.tree.debug("   ➖ \(conn.type.rawValue): \(conn.fromNodeName) → \(conn.toNodeName)")
                }
            }
        }

        connections = result.connections
    }

    /// Animates new connections appearing
    func animateNewConnections(connectionIds: Set<String>) {
        for id in connectionIds {
            guard let index = connections.firstIndex(where: { $0.id == id }) else { continue }

            withAnimation(.easeOut(duration: 0.5)) {
                connections[index].drawProgress = 1.0
                connections[index].opacity = 1.0
            }
        }
    }

    /// Animates connections disappearing
    func animateRemovingConnections(connectionIds: Set<String>) {
        for id in connectionIds {
            guard let index = connections.firstIndex(where: { $0.id == id }) else { continue }

            withAnimation(.easeIn(duration: 0.3)) {
                connections[index].opacity = 0.0
            }
        }

        // Remove disappeared connections after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.connections = ConnectionManager.pruneDisappearedConnections(self.connections)
        }
    }

    /// Prunes fully disappeared connections
    func pruneDisappearedConnections() {
        connections = ConnectionManager.pruneDisappearedConnections(connections)
    }
}
