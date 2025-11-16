import SwiftUI

// MARK: - Selection & Path Highlighting

extension FamilyTreeView {
    // MARK: - Helper Methods

    /// Formats a double value as milliseconds string.
    func ms(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Logs timing information with a label.
    func logTiming(_ label: String, value: Double) {
        AppLog.tree.debug("\(label): \(ms(value))ms")
    }

    /// Creates a unique family identifier from parent and child IDs.
    func makeFamilyID(parents: [String], children: [String]) -> String {
        let parentIDs = parents.sorted()
        let childIDs = children.sorted()
        return (parentIDs + ["->"] + childIDs).joined(separator: "-")
    }

    /// Joins member names from positions into a comma-separated string.
    func joinedNames(for positions: [NodePosition]) -> String {
        positions.map { $0.member.fullName }.joined(separator: ", ")
    }

    /// Formats a node position as a coordinate string.
    func formatPosition(_ position: NodePosition) -> String {
        "(\(Int(position.x)), \(Int(position.y)))"
    }

    // MARK: - Path Highlighting

    private struct PathState {
        let current: String
        let path: [String]

        init(start: String) {
            current = start
            path = [start]
        }

        private init(current: String, path: [String]) {
            self.current = current
            self.path = path
        }

        func appending(_ id: String) -> PathState {
            PathState(current: id, path: path + [id])
        }
    }

    /// Clears all path highlighting.
    func clearHighlighting() {
        viewModel.highlightedPath = []
        viewModel.highlightedPathOrdered = []
    }

    /// Clears the selected member and any associated highlighting.
    func clearSelection() {
        viewModel.highlightedPath = []
        viewModel.highlightedPathOrdered = []
        viewModel.selectedMember = nil
        viewModel.selectedNodePosition = nil
        viewModel.showingDetail = false
    }

    /// Calculates the offset needed to center a node in the current viewport.
    func calculateCenteringOffset(for nodePos: NodePosition, in _: GeometryProxy) -> CGSize {
        // Nodes are positioned relative to the center of the canvas, so negating the
        // coordinates (scaled) recenters the view.
        let targetOffsetWidth = -nodePos.x * viewModel.scale
        let targetOffsetHeight = -nodePos.y * viewModel.scale
        return CGSize(width: targetOffsetWidth, height: targetOffsetHeight)
    }

    /// Smoothly animates centering the view on a given node.
    func centerOnNode(_ nodePos: NodePosition, in geometry: GeometryProxy) {
        let targetOffset = calculateCenteringOffset(for: nodePos, in: geometry)

        withAnimation(.easeInOut(duration: 0.6)) {
            viewModel.offset = targetOffset
        }
    }

    /// Updates centering offset during layout animations without further animation.
    /// Keeps the graph centered on the selected contact (or me contact if nothing selected).
    func updateCenteringDuringAnimation(geometry: GeometryProxy) {
        AppLog.tree.debug("      🎯 [updateCenteringDuringAnimation] Starting")
        // Try to center on selected member first
        if let selectedMember = viewModel.selectedMember,
           let selectedNode = viewModel.nodePositions.first(where: { $0.member.id == selectedMember.id }) {
            AppLog.tree.debug("        Centering on selected: \(selectedMember.fullName)")
            AppLog.tree.debug("        Node position: (\(Int(selectedNode.x)), \(Int(selectedNode.y)))")
            let targetOffset = calculateCenteringOffset(for: selectedNode, in: geometry)
            AppLog.tree.debug("        Target offset: (\(Int(targetOffset.width)), \(Int(targetOffset.height)))")
            viewModel.offset = targetOffset
            return
        }

        // Fall back to centering on me contact if no selection
        if let meContact = viewModel.myContact,
           let meNode = viewModel.nodePositions.first(where: { $0.member.id == meContact.id }) {
            AppLog.tree.debug("        Centering on root: \(meContact.fullName)")
            AppLog.tree.debug("        Node position: (\(Int(meNode.x)), \(Int(meNode.y)))")
            let targetOffset = calculateCenteringOffset(for: meNode, in: geometry)
            AppLog.tree.debug("        Target offset: (\(Int(targetOffset.width)), \(Int(targetOffset.height)))")
            viewModel.offset = targetOffset
        } else {
            AppLog.tree.debug("        ⚠️ No center target found")
        }
    }

    /// Highlights the path from a given node ID up to the root node.
    func highlightPathToRoot(from nodeId: String) {
        clearHighlighting()

        guard let rootId = viewModel.myContact?.id, nodeId != rootId else {
            return
        }

        var visited = Set<String>()
        var primaryQueue: [PathState] = [PathState(start: nodeId)]
        var secondaryQueue: [PathState] = []

        while let state = popNextPath(primaryQueue: &primaryQueue, secondaryQueue: &secondaryQueue) {
            if state.current == rootId {
                viewModel.highlightedPath = Set(state.path)
                viewModel.highlightedPathOrdered = state.path
                return
            }

            guard visited.insert(state.current).inserted else { continue }
            guard let node = viewModel.nodePositions.first(where: { $0.member.id == state.current }) else { continue }

            let neighbors = neighborIDs(for: node, excluding: visited)

            for id in neighbors.primary {
                primaryQueue.append(state.appending(id))
            }

            for id in neighbors.secondary {
                secondaryQueue.append(state.appending(id))
            }
        }
    }

    private func popNextPath(
        primaryQueue: inout [PathState],
        secondaryQueue: inout [PathState]
    ) -> PathState? {
        if !primaryQueue.isEmpty {
            return primaryQueue.removeFirst()
        }
        if !secondaryQueue.isEmpty {
            return secondaryQueue.removeFirst()
        }
        return nil
    }

    private func neighborIDs(
        for node: NodePosition,
        excluding visited: Set<String>
    ) -> (primary: [String], secondary: [String]) {
        var primary = OrderedSet<String>()
        var secondary = OrderedSet<String>()

        func append(_ id: String, isPrimary: Bool) {
            guard !visited.contains(id) else { return }
            if isPrimary {
                primary.append(id)
            } else {
                secondary.append(id)
            }
        }

        for relation in node.member.relations {
            guard let neighbor = viewModel.nodePositions.first(where: { $0.member.id == relation.member.id }) else {
                continue
            }
            append(neighbor.member.id, isPrimary: relation.relationType.isParentOrChild)
        }

        for candidate in viewModel.nodePositions where candidate.member.id != node.member.id {
            for relation in candidate.member.relations where relation.member.id == node.member.id {
                append(candidate.member.id, isPrimary: relation.relationType.isParentOrChild)
            }
        }

        return (primary.values, secondary.values)
    }

    /// Checks if two node IDs are consecutive in the highlighted path.
    func areConsecutiveInPath(_ id1: String, _ id2: String) -> Bool {
        guard viewModel.highlightedPathOrdered.count >= 2 else { return false }
        for index in 0..<(viewModel.highlightedPathOrdered.count - 1) {
            let firstId = viewModel.highlightedPathOrdered[index]
            let secondId = viewModel.highlightedPathOrdered[index + 1]
            if (firstId == id1 && secondId == id2) || (firstId == id2 && secondId == id1) {
                return true
            }
        }
        return false
    }

    /// Determines if path highlight flows from a spouse toward the couple's children.
    func isSpouseToChildren(_ fromSpouse: NodePosition, _ otherSpouse: NodePosition) -> Bool {
        guard viewModel.highlightedPath.contains(fromSpouse.member.id) else { return false }

        let children = childIDs(for: fromSpouse, partner: otherSpouse)
        guard viewModel.highlightedPath.contains(where: children.contains) else { return false }

        // If the path jumps directly between spouses, we should not highlight as spouse-to-children.
        guard let index = viewModel.highlightedPathOrdered.firstIndex(of: fromSpouse.member.id) else { return false }
        if viewModel.highlightedPathOrdered.indices.contains(index + 1),
           viewModel.highlightedPathOrdered[index + 1] == otherSpouse.member.id {
            return false
        }
        if viewModel.highlightedPathOrdered.indices.contains(index - 1),
           viewModel.highlightedPathOrdered[index - 1] == otherSpouse.member.id {
            return false
        }

        return true
    }

    private func childIDs(for spouse: NodePosition, partner: NodePosition) -> Set<String> {
        var childIds = Set<String>()

        let directChildren = spouse.member.relations
            .filter { $0.relationType == .child }
            .compactMap { relation in viewModel.nodePositions.first { $0.member.id == relation.member.id } }

        for node in directChildren where viewModel.visibleNodeIds.contains(node.member.id) {
            childIds.insert(node.member.id)
        }

        for node in viewModel.nodePositions where viewModel.visibleNodeIds.contains(node.member.id) {
            let hasParentRelation = node.member.relations.contains {
                $0.relationType == .parent && $0.member.id == spouse.member.id
            }
            let partnerRelation = node.member.relations.contains {
                $0.relationType == .parent && $0.member.id == partner.member.id
            }

            if hasParentRelation || partnerRelation {
                childIds.insert(node.member.id)
            }
        }

        return childIds
    }
}

private struct OrderedSet<Element: Hashable> {
    private(set) var values: [Element] = []
    private var indices = Set<Element>()

    mutating func append(_ element: Element) {
        guard !indices.contains(element) else { return }
        indices.insert(element)
        values.append(element)
    }
}

private extension FamilyMember.RelationType {
    var isParentOrChild: Bool {
        self == .parent || self == .child
    }
}
