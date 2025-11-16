import SwiftUI

// swiftlint:disable file_length
extension FamilyTreeView {
    // MARK: - Path Animation Updates

    func updatePathAnimations(currentNodeIds: Set<String>, previousNodeIds: Set<String>) {
        let newNodes = currentNodeIds.subtracting(previousNodeIds)
        guard !newNodes.isEmpty else { return }

        let currentPositions = viewModel.nodePositions.filter { currentNodeIds.contains($0.member.id) }
        animateSpousePaths(in: currentPositions, newNodes: newNodes)
        animateFamilyPaths(
            currentPositions: currentPositions,
            newNodes: newNodes,
            previousNodeIds: previousNodeIds
        )
    }

    private func animateSpousePaths(in positions: [NodePosition], newNodes: Set<String>) {
        for node in positions {
            for relation in node.member.relations where relation.relationType == .spouse {
                guard let spouse = positions.first(where: { $0.member.id == relation.member.id }) else {
                    continue
                }

                guard newNodes.contains(node.member.id) || newNodes.contains(spouse.member.id) else { continue }

                let pairID = [node.member.id, spouse.member.id].sorted().joined(separator: "-")
                let pathID = "spouse-\(pairID)"
                startPathAnimationIfNeeded(id: pathID, duration: 0.5)
            }
        }
    }

    private func animateFamilyPaths(
        currentPositions: [NodePosition],
        newNodes: Set<String>,
        previousNodeIds: Set<String>
    ) {
        let previousPositions = viewModel.nodePositions.filter { previousNodeIds.contains($0.member.id) }
        let previousFamilyIDs = familyIDs(for: previousPositions)
        var processedFamilies = Set<String>()

        for child in currentPositions {
            let lookup = getParentPositions(for: child)

            if !lookup.parents.isEmpty {
                let parentIDs = lookup.parents.map { $0.member.id }.sorted()
                let familyID = makeFamilyID(parents: parentIDs, children: [child.member.id])
                guard processedFamilies.insert(familyID).inserted else { continue }

                let isNewChild = newNodes.contains(child.member.id)
                let hasNewParent = lookup.parents.contains { newNodes.contains($0.member.id) }
                let transitionedFromSingle = transitionedFromSingleParent(
                    parentIDs: parentIDs,
                    childId: child.member.id,
                    previousFamilyIDs: previousFamilyIDs
                )

                if (isNewChild || hasNewParent) && startPathAnimationIfNeeded(id: "family-\(familyID)", duration: 0.6) {
                    if transitionedFromSingle {
                        clearLegacySingleParentAnimation(parentIDs: parentIDs, childId: child.member.id)
                    }
                }
            } else if lookup.hasFilteredParents {
                animateFilteredParentConnections(for: child, newNodes: newNodes, positions: currentPositions)
            }
        }
    }

    private func familyIDs(for positions: [NodePosition]) -> Set<String> {
        var ids = Set<String>()

        for child in positions {
            let parents = child.member.relations
                .filter { $0.relationType == .parent }
                .compactMap { relation in
                    positions.first { $0.member.id == relation.member.id }?.member.id
                }

            guard !parents.isEmpty else { continue }
            let familyID = makeFamilyID(parents: parents.sorted(), children: [child.member.id])
            ids.insert(familyID)
        }

        return ids
    }

    private func transitionedFromSingleParent(
        parentIDs: [String],
        childId: String,
        previousFamilyIDs: Set<String>
    ) -> Bool {
        guard parentIDs.count == 2 else { return false }
        guard let primaryParent = parentIDs.first else { return false }

        let singleParentID = makeFamilyID(parents: [primaryParent], children: [childId])
        return previousFamilyIDs.contains(singleParentID)
    }

    private func clearLegacySingleParentAnimation(parentIDs: [String], childId: String) {
        guard let primaryParent = parentIDs.first else { return }
        let singleID = makeFamilyID(parents: [primaryParent], children: [childId])
        viewModel.pathAnimations.removeValue(forKey: "family-\(singleID)")
    }

    private func animateFilteredParentConnections(
        for child: NodePosition,
        newNodes: Set<String>,
        positions: [NodePosition]
    ) {
        guard newNodes.contains(child.member.id) else { return }

        let siblings = positions.filter { sibling in
            sibling.member.id != child.member.id && abs(sibling.y - child.y) < 1.0
        }

        guard siblings.count > 1 else { return }

        let siblingIDs = siblings.map { $0.member.id }.sorted().joined(separator: "-")
        startPathAnimationIfNeeded(id: "filtered-family-\(siblingIDs)", duration: 0.6)
    }

    @discardableResult
    private func startPathAnimationIfNeeded(id: String, duration: Double) -> Bool {
        guard viewModel.pathAnimations[id] == nil else { return false }
        viewModel.pathAnimations[id] = 0.0
        withAnimation(.easeOut(duration: duration)) {
            viewModel.pathAnimations[id] = 1.0
        }
        return true
    }

    // MARK: - Incremental Placement

    func animateIncrementalPlacement(
        placementSteps: [[NodePosition]],
        layoutManager: ContactLayoutManager,
        geometry: GeometryProxy
    ) {
        guard let initialNodes = placementSteps.first else { return }

        resetPlacementState(with: initialNodes, totalSteps: placementSteps.count)
        logPlacementSteps(placementSteps)

        if viewModel.debugMode {
            runDebugPlacement(steps: placementSteps, geometry: geometry)
        } else {
            runTimedPlacement(steps: placementSteps, geometry: geometry)
        }
    }

    /// Animates incremental placement for NEW members only, preserving existing visible nodes.
    /// This ensures rendering order matches sidebar order when degree slider increases.
    func animateIncrementalPlacementForNewMembers(
        placementSteps: [[NodePosition]],
        newMemberIds: Set<String>,
        layoutManager: ContactLayoutManager,
        geometry: GeometryProxy
    ) {
        guard let initialNodes = placementSteps.first else { return }

        // Don't reset state - preserve existing visible nodes
        // Only add new nodes incrementally
        viewModel.isAnimating = true
        // Process all filtered steps (they now only contain steps with new members)
        viewModel.totalDebugSteps = placementSteps.count
        viewModel.currentDebugStep = 0
        viewModel.debugStepReady = false

        // Ensure root is visible if not already (for initial degree 0 load)
        if let root = initialNodes.first, !viewModel.visibleNodeIds.contains(root.member.id) {
            viewModel.visibleNodeIds.insert(root.member.id)
            if !viewModel.nodePositions.contains(where: { $0.member.id == root.member.id }) {
                viewModel.nodePositions.append(root)
            }
        }

        logPlacementSteps(placementSteps)

        if viewModel.debugMode {
            runDebugPlacementForNewMembers(
                steps: placementSteps,
                newMemberIds: newMemberIds,
                geometry: geometry
            )
        } else {
            runTimedPlacementForNewMembers(
                steps: placementSteps,
                newMemberIds: newMemberIds,
                geometry: geometry
            )
        }
    }

    private func runTimedPlacementForNewMembers(
        steps: [[NodePosition]],
        newMemberIds: Set<String>,
        geometry: GeometryProxy
    ) {
        let delayPerStep = viewModel.animationSpeedMs / 1000.0
        var accumulatedDelay = delayPerStep
        var previousPositions = Set(viewModel.visibleNodeIds)

        // Start from index 0 since filtered steps now only contain steps with new members
        for index in steps.indices {
            let step = steps[index]
            let delay = accumulatedDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.applyPlacementStepForNewMembers(
                    step: step,
                    index: index,
                    newMemberIds: newMemberIds,
                    previousPositions: &previousPositions,
                    geometry: geometry
                )
            }
            accumulatedDelay += delayPerStep
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + accumulatedDelay + 0.5) {
            self.viewModel.isAnimating = false
        }
    }

    private func runDebugPlacementForNewMembers(
        steps: [[NodePosition]],
        newMemberIds: Set<String>,
        geometry: GeometryProxy
    ) {
        // Start from index 0 since filtered steps now only contain steps with new members
        processDebugStepForNewMembers(
            placementSteps: steps,
            currentIndex: 0,
            newMemberIds: newMemberIds,
            previousPositions: Set(viewModel.visibleNodeIds),
            geometry: geometry
        )
    }

    private func processDebugStepForNewMembers(
        placementSteps: [[NodePosition]],
        currentIndex: Int,
        newMemberIds: Set<String>,
        previousPositions: Set<String>,
        geometry: GeometryProxy
    ) {
        guard currentIndex < placementSteps.count else {
            finalizeDebugAnimation()
            return
        }

        let step = placementSteps[currentIndex]
        var mutablePreviousPositions = previousPositions

        logDebugWaitingState(index: currentIndex, previousPositions: previousPositions)

        waitForSpacebar {
            self.applyPlacementStepForNewMembers(
                step: step,
                index: currentIndex,
                newMemberIds: newMemberIds,
                previousPositions: &mutablePreviousPositions,
                geometry: geometry
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processDebugStepForNewMembers(
                    placementSteps: placementSteps,
                    currentIndex: currentIndex + 1,
                    newMemberIds: newMemberIds,
                    previousPositions: mutablePreviousPositions,
                    geometry: geometry
                )
            }
        }
    }

    /// Applies a placement step, but only animates NEW members (not already visible ones).
    func applyPlacementStepForNewMembers(
        step: [NodePosition],
        index: Int,
        newMemberIds: Set<String>,
        previousPositions: inout Set<String>,
        geometry: GeometryProxy
    ) {
        AppLog.tree.debug("\n🎬 [applyPlacementStepForNewMembers] Step \(index) starting")
        AppLog.tree.debug("  📊 Step has \(step.count) nodes")

        let stepIds = Set(step.map { $0.member.id })
        let trulyNewIds = stepIds.subtracting(previousPositions).intersection(newMemberIds)
        let existingIds = stepIds.intersection(previousPositions)

        AppLog.tree.debug("  ➕ Truly new members: \(trulyNewIds.count)")
        AppLog.tree.debug("  🔄 Existing members (updating positions): \(existingIds.count)")

        // Update positions for all nodes in step (needed for correct layout)
        let mergedPositions = mergePositions(with: step)
        viewModel.nodePositions = viewModel.deduplicatePositions(mergedPositions)

        // Only add NEW members to visible set (skip already visible ones)
        trulyNewIds.forEach { viewModel.visibleNodeIds.insert($0) }
        previousPositions.formUnion(stepIds)

        // Update path animations only for new members
        updatePathAnimations(
            currentNodeIds: Set(viewModel.visibleNodeIds),
            previousNodeIds: previousPositions.subtracting(trulyNewIds)
        )

        // Update connections
        viewModel.updateConnections()

        // Animate new connections appearing
        let newConnectionIds = Set(viewModel.connections.filter { $0.drawProgress < 0.1 }.map { $0.id })
        if !newConnectionIds.isEmpty {
            viewModel.animateNewConnections(connectionIds: newConnectionIds)
        }

        // Update centering
        withAnimation(.none) {
            updateCenteringDuringAnimation(geometry: geometry)
        }

        // Only animate placement of NEW members (skip already visible)
        if !trulyNewIds.isEmpty {
            animatePlacement(of: trulyNewIds, preserveExisting: true)
        }

        AppLog.tree.debug("✅ [applyPlacementStepForNewMembers] Step \(index) complete\n")
    }

    private func resetPlacementState(with initialNodes: [NodePosition], totalSteps: Int) {
        viewModel.visibleNodeIds.removeAll()
        viewModel.nodePositions = viewModel.deduplicatePositions([])
        viewModel.pathAnimations.removeAll()
        viewModel.previousNodeIds.removeAll()
        viewModel.isAnimating = true
        viewModel.totalDebugSteps = max(totalSteps - 1, 0)
        viewModel.currentDebugStep = 0
        viewModel.debugStepReady = false

        if let root = initialNodes.first {
            viewModel.visibleNodeIds.insert(root.member.id)
            viewModel.nodePositions = viewModel.deduplicatePositions([root])
            viewModel.previousNodeIds.insert(root.member.id)
        }
    }

    private func logPlacementSteps(_ placementSteps: [[NodePosition]]) {
        guard viewModel.debugMode else { return }

        AppLog.tree.debug("\n📋 [Animate Placement] \(placementSteps.count) placement steps:")
        for (index, step) in placementSteps.enumerated() {
            AppLog.tree.debug("   Step \(index + 1): \(step.count) node(s)")
            let names = step.map { $0.member.fullName }
            if names.count <= 5 {
                names.forEach { AppLog.tree.debug("     - \($0)") }
            } else {
                names.prefix(3).forEach { AppLog.tree.debug("     - \($0)") }
                AppLog.tree.debug("     - ... and \(names.count - 3) more")
            }
        }
    }

    private func runDebugPlacement(steps: [[NodePosition]], geometry: GeometryProxy) {
        processDebugStep(
            placementSteps: steps,
            currentIndex: 1,
            previousPositions: Set(steps.first?.map { $0.member.id } ?? []),
            geometry: geometry
        )
    }

    private func runTimedPlacement(steps: [[NodePosition]], geometry: GeometryProxy) {
        let delayPerStep = viewModel.animationSpeedMs / 1000.0
        var accumulatedDelay = delayPerStep
        var previousPositions = Set(steps.first?.map { $0.member.id } ?? [])

        for index in steps.indices where index > 0 {
            let step = steps[index]
            let delay = accumulatedDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.applyPlacementStep(
                    step: step,
                    index: index,
                    previousPositions: &previousPositions,
                    geometry: geometry
                )
            }
            accumulatedDelay += delayPerStep
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + accumulatedDelay + 0.5) {
            self.viewModel.isAnimating = false
        }
    }

    // MARK: - Debug Placement

    func processDebugStep(
        placementSteps: [[NodePosition]],
        currentIndex: Int,
        previousPositions: Set<String>,
        geometry: GeometryProxy
    ) {
        guard currentIndex < placementSteps.count else {
            finalizeDebugAnimation()
            return
        }

        let step = placementSteps[currentIndex]
        var mutablePreviousPositions = previousPositions

        logDebugWaitingState(index: currentIndex, previousPositions: previousPositions)

        waitForSpacebar {
            self.applyPlacementStep(
                step: step,
                index: currentIndex,
                previousPositions: &mutablePreviousPositions,
                geometry: geometry
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processDebugStep(
                    placementSteps: placementSteps,
                    currentIndex: currentIndex + 1,
                    previousPositions: mutablePreviousPositions,
                    geometry: geometry
                )
            }
        }
    }

    private func finalizeDebugAnimation() {
        AppLog.tree.debug("✅ [DEBUG] All steps completed")
        AppLog.tree.debug("  📊 Final nodes: \(joinedNames(for: viewModel.nodePositions))")
        AppLog.tree.debug("  📊 Visible IDs: \(viewModel.visibleNodeIds)")
        viewModel.currentDebugStep = viewModel.totalDebugSteps
        viewModel.debugStepDescription = "Animation complete"
        viewModel.debugChangesSummary = []
        viewModel.isAnimating = false
    }

    private func logDebugWaitingState(index: Int, previousPositions: Set<String>) {
        guard viewModel.debugMode else { return }

        viewModel.currentDebugStep = index
        AppLog.tree.debug("\n🔵 [DEBUG] Step \(index) of \(viewModel.totalDebugSteps) - Waiting for spacebar...")
        AppLog.tree.debug("  📊 Current nodes: \(joinedNames(for: viewModel.nodePositions))")
        AppLog.tree.debug("  📊 Visible node ids: \(viewModel.visibleNodeIds.count)")
        AppLog.tree.debug("  📊 Previous positions: \(previousPositions.count)")
    }

    func waitForSpacebar(completion: @escaping () -> Void) {
        viewModel.debugStepReady = false

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.viewModel.debugStepReady {
                timer.invalidate()
                completion()
            }
        }
    }

    // MARK: - Placement Step Processing

    func applyPlacementStep(
        step: [NodePosition],
        index: Int,
        previousPositions: inout Set<String>,
        geometry: GeometryProxy
    ) {
        AppLog.tree.debug("\n🎬 [applyPlacementStep] Step \(index) starting")
        AppLog.tree.debug("  📊 Step has \(step.count) nodes")

        let stepSummary = analyzeStepChanges(step: step, previousPositions: previousPositions)
        updateDebugState(stepIndex: index, summary: stepSummary)

        AppLog.tree.debug("  ➕ New members: \(stepSummary.newMemberIds.count)")
        AppLog.tree.debug("  🔄 Moved members: \(stepSummary.movedMembers.count)")

        stepSummary.newMemberIds.forEach { viewModel.visibleNodeIds.insert($0) }

        AppLog.tree.debug("  📍 Before merge - nodePositions.count: \(viewModel.nodePositions.count)")
        for node in step {
            AppLog.tree.debug("    Step node: \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        let mergedPositions = mergePositions(with: step)
        viewModel.nodePositions = viewModel.deduplicatePositions(mergedPositions)

        AppLog.tree.debug("  📍 After merge - nodePositions.count: \(viewModel.nodePositions.count)")
        for node in viewModel.nodePositions {
            AppLog.tree.debug("    Merged node: \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        previousPositions.formUnion(step.map { $0.member.id })

        updatePathAnimations(
            currentNodeIds: Set(viewModel.visibleNodeIds),
            previousNodeIds: stepSummary.previousVisibleIds
        )

        // Update connections to match new node state
        viewModel.updateConnections()

        // Animate new connections appearing
        let newConnectionIds = Set(viewModel.connections.filter { $0.drawProgress < 0.1 }.map { $0.id })
        if !newConnectionIds.isEmpty {
            viewModel.animateNewConnections(connectionIds: newConnectionIds)
        }

        // DISABLED: recomputeLayoutForVisibleMembers was overriding incremental step positions
        // The incremental steps already contain correct positions with realignment built-in
        // AppLog.tree.debug("  🔄 Calling recomputeLayoutForVisibleMembers...")
        // recomputeLayoutForVisibleMembers(
        //     layoutManager: nil,
        //     geometry: geometry,
        //     newlyVisibleIds: stepSummary.newMemberIds
        // )

        AppLog.tree.debug("  📍 Final positions - nodePositions.count: \(viewModel.nodePositions.count)")
        for node in viewModel.nodePositions {
            AppLog.tree.debug("    Final node: \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        // Update centering after each step WITHOUT animation to prevent compound visual movement
        // This ensures the viewport shift happens instantly, not animated with the node movements
        let previousOffset = viewModel.offset

        // Use withAnimation(.none) to ensure the offset change is NOT animated
        withAnimation(.none) {
            updateCenteringDuringAnimation(geometry: geometry)
        }

        let widthChanged = abs(viewModel.offset.width - previousOffset.width) > 1
        let heightChanged = abs(viewModel.offset.height - previousOffset.height) > 1
        if widthChanged || heightChanged {
            let prevOffsetStr = "(\(Int(previousOffset.width)), \(Int(previousOffset.height)))"
            let newOffsetStr = "(\(Int(viewModel.offset.width)), \(Int(viewModel.offset.height)))"
            AppLog.tree.debug("  🎯 Centering offset changed: \(prevOffsetStr) → \(newOffsetStr)")
        }

        animatePlacement(of: stepSummary.newMemberIds, preserveExisting: true)

        if !viewModel.debugMode {
            AppLog.tree.debug("Step \(index) complete: visible=\(viewModel.visibleNodeIds.count)")
        }
        AppLog.tree.debug("✅ [applyPlacementStep] Step \(index) complete\n")
    }

    private struct StepSummary {
        let newMemberIds: Set<String>
        let addedMembers: [String]
        let movedMembers: [String]
        let previousVisibleIds: Set<String>
        let debugMessages: [String]
    }

    private func analyzeStepChanges(
        step: [NodePosition],
        previousPositions: Set<String>
    ) -> StepSummary {
        let previousVisibleIds = viewModel.visibleNodeIds
        let stepIds = Set(step.map { $0.member.id })
        let newMemberIds = stepIds.subtracting(previousPositions)

        var addedMembers: [String] = []
        var movedMembers: [String] = []
        var messages: [String] = []

        for memberId in newMemberIds {
            if let node = step.first(where: { $0.member.id == memberId }) {
                addedMembers.append(node.member.fullName)
                messages.append("➕ Added \(node.member.fullName) @ \(formatPosition(node))")
            }
        }

        for node in step where !newMemberIds.contains(node.member.id) {
            guard let previous = viewModel.nodePositions.first(where: { $0.member.id == node.member.id }) else { continue }
            let deltaX = abs(node.x - previous.x)
            let deltaY = abs(node.y - previous.y)
            guard deltaX > 1 || deltaY > 1 else { continue }
            movedMembers.append(node.member.fullName)
            messages.append("🔄 Moved \(node.member.fullName) \(formatPosition(previous)) → \(formatPosition(node))")
        }

        return StepSummary(
            newMemberIds: newMemberIds,
            addedMembers: addedMembers,
            movedMembers: movedMembers,
            previousVisibleIds: previousVisibleIds,
            debugMessages: messages
        )
    }

    private func updateDebugState(stepIndex: Int, summary: StepSummary) {
        guard viewModel.debugMode else { return }

        let additionText: String?
        if summary.addedMembers.isEmpty {
            additionText = nil
        } else {
            let joined = summary.addedMembers.joined(separator: ", ")
            additionText = "Added \(summary.addedMembers.count): \(joined)"
        }

        let movementText: String?
        if summary.movedMembers.isEmpty {
            movementText = nil
        } else {
            let joined = summary.movedMembers.joined(separator: ", ")
            movementText = "Moved \(summary.movedMembers.count): \(joined)"
        }

        var descriptionComponents: [String] = []
        if let additionText { descriptionComponents.append(additionText) }
        if let movementText { descriptionComponents.append(movementText) }

        viewModel.debugStepDescription = descriptionComponents.isEmpty
            ? "Step \(stepIndex): No changes"
            : "Step \(stepIndex): \(descriptionComponents.joined(separator: "; "))"

        viewModel.debugChangesSummary = summary.debugMessages
    }

    private func mergePositions(with step: [NodePosition]) -> [NodePosition] {
        var merged: [NodePosition] = []
        var stepMap = Dictionary(uniqueKeysWithValues: step.map { ($0.member.id, $0) })

        for position in viewModel.nodePositions {
            if let updated = stepMap.removeValue(forKey: position.member.id) {
                merged.append(updated)
            } else {
                merged.append(position)
            }
        }

        merged.append(contentsOf: stepMap.values)
        return merged
    }

    // MARK: - Layout Recompute Helpers

    func recomputeLayoutForVisibleMembers(
        layoutManager: ContactLayoutManager?,
        geometry: GeometryProxy,
        newlyVisibleIds: Set<String>
    ) {
        guard !newlyVisibleIds.isEmpty, let myContact = viewModel.myContact else {
            let hasIds = !newlyVisibleIds.isEmpty
            let hasContact = viewModel.myContact != nil
            AppLog.tree.debug("    ⚠️ [recompute] Skipped: newlyVisibleIds.isEmpty=\(hasIds) myContact=\(hasContact)")
            return
        }

        AppLog.tree.debug("    🔄 [recompute] Starting recomputation")
        AppLog.tree.debug("      Newly visible IDs: \(newlyVisibleIds.count)")
        AppLog.tree.debug("      Filtered members: \(viewModel.filteredMembers.count)")
        AppLog.tree.debug("      Visible node IDs: \(viewModel.visibleNodeIds.count)")

        AppLog.tree.debug("      📍 Positions BEFORE recompute:")
        for node in viewModel.nodePositions.sorted(by: { $0.member.fullName < $1.member.fullName }) {
            AppLog.tree.debug("        \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        // IMPORTANT: Use root from filteredMembers to preserve relations
        guard let rootFromFiltered = viewModel.filteredMembers.first(where: { $0.id == myContact.id }) else {
            AppLog.tree.debug("    ⚠️ [recompute] Root contact not in filtered members")
            return
        }

        let layoutManager = layoutManager ?? ContactLayoutManager(
            members: viewModel.filteredMembers,
            root: rootFromFiltered,
            treeData: viewModel.treeData,
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        AppLog.tree.debug("      🎯 Running layoutNodesIncremental...")
        let steps = layoutManager.layoutNodesIncremental(language: viewModel.selectedLanguage)
        AppLog.tree.debug("      📋 Got \(steps.count) steps from recomputation")

        guard let lastStep = steps.last else {
            AppLog.tree.debug("      ⚠️ No last step found")
            return
        }

        AppLog.tree.debug("      📍 Last step has \(lastStep.count) positions")
        for node in lastStep.sorted(by: { $0.member.fullName < $1.member.fullName }) {
            AppLog.tree.debug("        \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        let updatedPositions = lastStep.filter { viewModel.visibleNodeIds.contains($0.member.id) }
        AppLog.tree.debug("      🔍 Filtered to \(updatedPositions.count) visible positions")

        viewModel.nodePositions = viewModel.deduplicatePositions(updatedPositions)
        AppLog.tree.debug("      📍 Positions AFTER recompute:")
        for node in viewModel.nodePositions.sorted(by: { $0.member.fullName < $1.member.fullName }) {
            AppLog.tree.debug("        \(node.member.fullName) @ (\(Int(node.x)), \(Int(node.y)))")
        }

        updateCenteringDuringAnimation(geometry: geometry)
        AppLog.tree.debug("    ✅ [recompute] Complete")
    }

    func animatePlacement(of nodeIds: Set<String>, preserveExisting: Bool) {
        guard !nodeIds.isEmpty else { return }

        viewModel.isAnimating = true

        let nodesToAnimate: [NodePosition]
        if preserveExisting {
            nodesToAnimate = viewModel.nodePositions.filter { nodeIds.contains($0.member.id) }
        } else {
            nodesToAnimate = viewModel.nodePositions
        }

        let delayBetweenNodes: TimeInterval = 0.05
        var currentDelay: TimeInterval = preserveExisting ? 0.0 : 0.1

        for node in nodesToAnimate {
            let id = node.member.id
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    _ = self.viewModel.visibleNodeIds.insert(id)
                }
            }
            currentDelay += delayBetweenNodes
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay + 0.5) {
            self.viewModel.isAnimating = false
        }
    }

    func animateRemoval(of nodeIds: Set<String>) {
        guard !nodeIds.isEmpty else { return }

        viewModel.isAnimating = true

        // Find connections that involve the nodes being removed
        let affectedConnectionIds = Set(viewModel.connections
            .filter { connection in
                nodeIds.contains(connection.fromNodeId) || nodeIds.contains(connection.toNodeId)
            }
            .map { $0.id })

        // Animate connections disappearing first
        if !affectedConnectionIds.isEmpty {
            viewModel.animateRemovingConnections(connectionIds: affectedConnectionIds)
        }

        // Then animate nodes disappearing
        let delayPerNode: TimeInterval = 0.03
        var currentDelay: TimeInterval = 0.0

        for id in nodeIds {
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = self.viewModel.visibleNodeIds.remove(id)
                }
            }
            currentDelay += delayPerNode
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay + 0.4) {
            self.viewModel.nodePositions.removeAll { nodeIds.contains($0.member.id) }
            self.viewModel.isAnimating = false
        }
    }
}
