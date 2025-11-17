import SwiftUI

extension FamilyTreeView {
    // MARK: - Graph State Transition

    /// Computes the destination graph state by laying out the filtered members
    func computeDestinationState(in geometry: GeometryProxy) -> GraphState {
        guard !viewModel.filteredMembers.isEmpty, let myContactId = viewModel.myContact?.id else {
            return GraphState(
                nodePositions: [],
                visibleNodeIds: [],
                connections: []
            )
        }

        // IMPORTANT: Use root from filteredMembers to preserve relations
        guard let me = viewModel.filteredMembers.first(where: { $0.id == myContactId }) else {
            return GraphState(
                nodePositions: [],
                visibleNodeIds: [],
                connections: []
            )
        }

        // Use LayoutOrchestrator with stateless engine
        let orchestrator = LayoutOrchestrator()
        let config = LayoutConfiguration(
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        // Get the final layout (not incremental, just the final state)
        let result = orchestrator.layoutTree(
            members: viewModel.filteredMembers,
            root: me,
            treeData: viewModel.treeData,
            config: config,
            language: viewModel.selectedLanguage
        )

        guard case .success(var positions) = result else {
            AppLog.tree.error("Failed to compute layout for transition")
            return GraphState(nodePositions: [], visibleNodeIds: [], connections: [])
        }

        // ANCHOR ROOT: If root already has a position, keep it there and shift all others
        if let existingRootPos = viewModel.nodePositions.first(where: { $0.id == me.id }) {
            if let newRootPos = positions.first(where: { $0.id == me.id }) {
                let deltaX = existingRootPos.x - newRootPos.x
                let deltaY = existingRootPos.y - newRootPos.y

                // Shift all positions to anchor the root
                positions = positions.map { position in
                    var updatedPosition = position
                    updatedPosition.x += deltaX
                    updatedPosition.y += deltaY
                    return updatedPosition
                }

                let shiftMsg = "shifted all nodes by Δx=\(Int(deltaX)), Δy=\(Int(deltaY))"
                AppLog.tree.debug("   🔒 Anchored root at existing position, \(shiftMsg)")

                // Note: With stateless engine, we skip the realignment step.
                // The positions are already aligned from the initial layout computation.
            }
        }

        // Extract rendering priorities
        extractRenderingPriorities()

        // Extract connections from the positions
        let connections = GraphState.extractConnections(from: positions)

        // Create the destination state
        return GraphState(
            nodePositions: positions,
            visibleNodeIds: Set(positions.map { $0.member.id }),
            connections: connections
        )
    }

    /// Applies a graph transition with proper animations
    func applyGraphTransition(_ transition: GraphTransition, geometry: GeometryProxy) {
        guard transition.hasChanges else {
            AppLog.tree.debug("   ℹ️  No changes to animate")
            return
        }

        // Log connection animations
        logConnectionAnimations(transition)

        // Phase 1: Start disappearing nodes and connections (fade out quickly)
        if !transition.nodesToDisappear.isEmpty {
            let disappearIds = Set(transition.nodesToDisappear.map { $0.member.id })
            for id in disappearIds {
                withAnimation(.easeOut(duration: 0.25)) {
                    _ = viewModel.visibleNodeIds.remove(id)
                }
            }

            // Remove from nodePositions after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.viewModel.nodePositions.removeAll { disappearIds.contains($0.member.id) }
            }
        }

        // Also fade out disappearing connections
        if !transition.connectionsToDisappear.isEmpty {
            AppLog.tree.debug("   🎨 Animating \(transition.connectionsToDisappear.count) connections to disappear")
            // Path animations will naturally disappear as nodes are removed
        }

        // Phase 2: Move existing nodes to new positions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !transition.nodesToMove.isEmpty {
                // Update positions for moving nodes
                var updatedPositions = self.viewModel.nodePositions

                for movement in transition.nodesToMove {
                    if let index = updatedPositions.firstIndex(
                        where: { $0.member.id == movement.node.member.id }
                    ) {
                        updatedPositions[index] = movement.node
                    }
                }

                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    self.viewModel.nodePositions = self.viewModel.deduplicatePositions(updatedPositions)
                }
            }
        }

        // Phase 3: Add appearing nodes (fade in after moves start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !transition.nodesToAppear.isEmpty {
                // Add new positions to nodePositions
                var updatedPositions = self.viewModel.nodePositions
                updatedPositions.append(contentsOf: transition.nodesToAppear)
                self.viewModel.nodePositions = self.viewModel.deduplicatePositions(updatedPositions)

                // Animate them appearing one by one
                let appearIds = transition.nodesToAppear.map { $0.member.id }
                let delayBetweenNodes: TimeInterval = 0.04

                for (index, id) in appearIds.enumerated() {
                    let delay = TimeInterval(index) * delayBetweenNodes
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            _ = self.viewModel.visibleNodeIds.insert(id)
                        }
                    }
                }
            }
        }

        // Phase 4: Handle recentering and path animations
        let totalAnimationTime = 0.3 + 0.6 + (0.04 * Double(transition.nodesToAppear.count))
        DispatchQueue.main.asyncAfter(deadline: .now() + totalAnimationTime) {
            // Update path animations for connections
            AppLog.tree.debug("   🎨 Animating \(transition.connectionsToAppear.count) new connections to appear")
            self.updatePathAnimations(
                currentNodeIds: self.viewModel.visibleNodeIds,
                previousNodeIds: Set(transition.nodesToDisappear.map { $0.member.id })
            )

            // Update connections to match new graph state
            self.viewModel.updateConnections()

            // Animate new connections appearing
            let newConnectionIds = Set(self.viewModel.connections.filter { $0.drawProgress < 0.1 }.map { $0.id })
            if !newConnectionIds.isEmpty {
                self.viewModel.animateNewConnections(connectionIds: newConnectionIds)
            }

            // Recenter if needed
            self.recenterAfterTransition(geometry: geometry)
        }
    }

    /// Logs detailed animation information for connections
    private func logConnectionAnimations(_ transition: GraphTransition) {
        AppLog.tree.debug("\n   🎨 [Connection Animations]")

        // Build position maps for current and destination states
        // Deduplicate by member ID, keeping the last occurrence
        var currentPositionMap: [String: NodePosition] = [:]
        for position in viewModel.nodePositions {
            currentPositionMap[position.member.id] = position
        }

        // Build destination position map from transition data
        var destinationPositionMap = currentPositionMap
        // Update with nodes that are moving (use destination position)
        for movement in transition.nodesToMove {
            destinationPositionMap[movement.node.member.id] = movement.node
        }
        // Add nodes that are appearing
        for node in transition.nodesToAppear {
            destinationPositionMap[node.member.id] = node
        }
        // Remove nodes that are disappearing
        for node in transition.nodesToDisappear {
            destinationPositionMap.removeValue(forKey: node.member.id)
        }

        if !transition.connectionsToDisappear.isEmpty {
            AppLog.tree.debug("      Fade Out (\(transition.connectionsToDisappear.count)):")
            for connection in transition.connectionsToDisappear.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIconForType(connection.type)
                let fromPos = currentPositionMap[connection.fromNodeId]
                let toPos = currentPositionMap[connection.toNodeId]
                let coordStr = formatConnectionCoordinates(from: fromPos, to: toPos)
                AppLog.tree.debug("         \(icon) \(connection.fromNodeName) ↔ \(connection.toNodeName) \(coordStr)")
            }
        }

        if !transition.connectionsToAppear.isEmpty {
            AppLog.tree.debug("      Draw In (\(transition.connectionsToAppear.count)):")
            for connection in transition.connectionsToAppear.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIconForType(connection.type)
                let fromPos = destinationPositionMap[connection.fromNodeId]
                let toPos = destinationPositionMap[connection.toNodeId]
                let coordStr = formatConnectionCoordinates(from: fromPos, to: toPos)
                AppLog.tree.debug("         \(icon) \(connection.fromNodeName) ↔ \(connection.toNodeName) \(coordStr)")
            }
        }

        // Log connections that are moving (when their nodes move)
        // These are connections that appear/disappear and involve nodes that are moving
        let movingConnectionIds = Set(transition.nodesToMove.map { $0.node.member.id })
        let movingAppearingConnections = transition.connectionsToAppear.filter { connection in
            movingConnectionIds.contains(connection.fromNodeId) || movingConnectionIds.contains(connection.toNodeId)
        }
        let movingDisappearingConnections = transition.connectionsToDisappear.filter { connection in
            movingConnectionIds.contains(connection.fromNodeId) || movingConnectionIds.contains(connection.toNodeId)
        }

        if !movingAppearingConnections.isEmpty || !movingDisappearingConnections.isEmpty {
            let movingCount = movingAppearingConnections.count + movingDisappearingConnections.count
            AppLog.tree.debug("      Moving (\(movingCount)):")
            for connection in movingAppearingConnections.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIconForType(connection.type)
                let fromCurrent = currentPositionMap[connection.fromNodeId]
                let toCurrent = currentPositionMap[connection.toNodeId]
                let fromDest = destinationPositionMap[connection.fromNodeId]
                let toDest = destinationPositionMap[connection.toNodeId]
                let coordStr = formatMovingConnectionCoordinates(
                    fromCurrent: fromCurrent,
                    toCurrent: toCurrent,
                    fromDest: fromDest,
                    toDest: toDest
                )
                AppLog.tree.debug("         \(icon) \(connection.fromNodeName) ↔ \(connection.toNodeName) \(coordStr)")
            }
            for connection in movingDisappearingConnections.sorted(by: { $0.id < $1.id }) {
                let icon = connectionIconForType(connection.type)
                let fromCurrent = currentPositionMap[connection.fromNodeId]
                let toCurrent = currentPositionMap[connection.toNodeId]
                let fromDest = destinationPositionMap[connection.fromNodeId]
                let toDest = destinationPositionMap[connection.toNodeId]
                let coordStr = formatMovingConnectionCoordinates(
                    fromCurrent: fromCurrent,
                    toCurrent: toCurrent,
                    fromDest: fromDest,
                    toDest: toDest
                )
                AppLog.tree.debug("         \(icon) \(connection.fromNodeName) ↔ \(connection.toNodeName) \(coordStr)")
            }
        }

        if transition.connectionsToDisappear.isEmpty && transition.connectionsToAppear.isEmpty {
            AppLog.tree.debug("      No connection changes")
        }
    }

    /// Formats connection coordinates for logging
    private func formatConnectionCoordinates(from: NodePosition?, to: NodePosition?) -> String {
        guard let from = from, let to = to else {
            return "[coordinates unavailable]"
        }
        let fromStr = "(\(Int(from.x)), \(Int(from.y)))"
        let toStr = "(\(Int(to.x)), \(Int(to.y)))"
        return "\(fromStr) → \(toStr)"
    }

    /// Formats moving connection coordinates showing both start and end positions
    private func formatMovingConnectionCoordinates(
        fromCurrent: NodePosition?,
        toCurrent: NodePosition?,
        fromDest: NodePosition?,
        toDest: NodePosition?
    ) -> String {
        guard let fromCurrent = fromCurrent, let toCurrent = toCurrent,
              let fromDest = fromDest, let toDest = toDest else {
            return "[coordinates unavailable]"
        }
        let fromStart = "(\(Int(fromCurrent.x)), \(Int(fromCurrent.y)))"
        let toStart = "(\(Int(toCurrent.x)), \(Int(toCurrent.y)))"
        let fromEnd = "(\(Int(fromDest.x)), \(Int(fromDest.y)))"
        let toEnd = "(\(Int(toDest.x)), \(Int(toDest.y)))"
        // Format: "from: (x1,y1)→(x2,y2), to: (x3,y3)→(x4,y4)"
        return "from: \(fromStart)→\(fromEnd), to: \(toStart)→\(toEnd)"
    }

    private func connectionIconForType(_ type: GraphConnection.ConnectionType) -> String {
        switch type {
        case .spouse: return "💑"
        case .parentChild: return "👨‍👧"
        }
    }

    /// Recenters the view after a transition completes
    func recenterAfterTransition(geometry: GeometryProxy) {
        if let selectedMember = viewModel.selectedMember,
           let selectedNode = viewModel.nodePositions.first(where: { $0.member.id == selectedMember.id }),
           viewModel.visibleNodeIds.contains(selectedMember.id) {
            // Selected card is still visible - recenter on it
            withAnimation(.easeInOut(duration: 0.4)) {
                let targetOffset = calculateCenteringOffset(for: selectedNode, in: geometry)
                viewModel.offset = targetOffset
            }
        } else if viewModel.selectedMember != nil,
                  let meNode = viewModel.nodePositions.first(where: { $0.member.id == viewModel.myContact?.id }) {
            // Selected card disappeared - recenter on me
            clearSelection()
            withAnimation(.easeInOut(duration: 0.4)) {
                let targetOffset = calculateCenteringOffset(for: meNode, in: geometry)
                viewModel.offset = targetOffset
            }
        }
    }
}
