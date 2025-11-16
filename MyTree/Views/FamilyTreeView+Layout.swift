import SwiftUI

extension FamilyTreeView {
    // MARK: - Layout Management

    /// Sorts members using the same logic as the sidebar: degree, then date, then name.
    private func sortMembersLikeSidebar(_ members: [FamilyMember]) -> [FamilyMember] {
        return members.sorted { first, second in
            // First sort by degree of separation (ascending)
            let degree1 = viewModel.treeData.degreeOfSeparation(for: first.id)
            let degree2 = viewModel.treeData.degreeOfSeparation(for: second.id)
            let normalizedDegree1 = degree1 == Int.max ? 999 : degree1
            let normalizedDegree2 = degree2 == Int.max ? 999 : degree2

            if normalizedDegree1 != normalizedDegree2 {
                return normalizedDegree1 < normalizedDegree2
            }

            // Then by date (ascending - older dates first)
            // Use marriage date for spouses, birth date for others
            let hasSpouse1 = first.relations.contains { $0.relationType == .spouse }
            let hasSpouse2 = second.relations.contains { $0.relationType == .spouse }
            let sortDate1 = hasSpouse1 ? first.marriageDate : first.birthDate
            let sortDate2 = hasSpouse2 ? second.marriageDate : second.birthDate

            switch (sortDate1, sortDate2) {
            case let (date1?, date2?):
                if date1 != date2 {
                    return date1 < date2
                }
            case (nil, _?):
                return false  // Put nil dates after non-nil
            case (_?, nil):
                return true   // Put non-nil dates before nil
            case (nil, nil):
                break  // Both nil, continue to name sorting
            }

            // Finally by name
            return first.fullName < second.fullName
        }
    }

    /// Updates the filtered members based on the current degree of separation.
    func updateFilteredMembers() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Use precomputed degrees from treeData
        let filterStartTime = CFAbsoluteTimeGetCurrent()

        // Filter to only include visible members, then sort using sidebar order
        let filtered = viewModel.members.filter { viewModel.visibleMemberIds.contains($0.id) }
        viewModel.filteredMembers = sortMembersLikeSidebar(filtered)

        let filterDuration = (CFAbsoluteTimeGetCurrent() - filterStartTime) * 1000

        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        AppLog.tree.debug("\n📊 [updateFilteredMembers] Filtering members:")
        AppLog.tree.debug("   - Degree limit: \(viewModel.degreeOfSeparation)")
        AppLog.tree.debug("   - Total members: \(viewModel.treeData.members.count)")
        AppLog.tree.debug("   - Visible member IDs: \(viewModel.visibleMemberIds.count)")
        AppLog.tree.debug("   - Filtered members: \(viewModel.filteredMembers.count)")
        AppLog.tree.debug("   ⏱️ Filter operation: \(String(format: "%.2f", filterDuration))ms")
        AppLog.tree.debug("   ⏱️ Total duration: \(String(format: "%.2f", totalDuration))ms")

        // Debug: show first few filtered members
        if viewModel.filteredMembers.count <= 10 {
            for member in viewModel.filteredMembers {
                let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("   - \(member.fullName): degree \(degree)")
            }
        } else {
            for member in viewModel.filteredMembers.prefix(5) {
                let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("   - \(member.fullName): degree \(degree)")
            }
            AppLog.tree.debug("   ... and \(viewModel.filteredMembers.count - 5) more")
        }
    }

    /// Handles layout of nodes based on the current filtered members and geometry.
    func layoutNodes(in geometry: GeometryProxy) {
        let layoutStartTime = CFAbsoluteTimeGetCurrent()
        AppLog.tree.debug("\n📐 [TIMING] layoutNodes() started for \(viewModel.filteredMembers.count) members")

        guard !viewModel.filteredMembers.isEmpty else {
            AppLog.tree.debug("  ⚠️ [layoutNodes] No filtered members to layout")
            viewModel.nodePositions = viewModel.deduplicatePositions([])
            viewModel.visibleNodeIds.removeAll()
            return
        }
        guard let myContactId = viewModel.myContact?.id else {
            AppLog.tree.debug("  ⚠️ [layoutNodes] No root contact")
            return
        }

        // IMPORTANT: Use the root member from filteredMembers, not myContact
        // myContact might be a different instance without relations loaded
        guard let me = viewModel.filteredMembers.first(where: { $0.id == myContactId }) else {
            AppLog.tree.debug("  ⚠️ [layoutNodes] Root contact not in filtered members")
            return
        }

        let animMsg = "layoutNodes animated: count=\(viewModel.filteredMembers.count)"
        AppLog.tree.debug("\(animMsg) degree=\(viewModel.degreeOfSeparation)")

        // Use the new comprehensive layout manager
        let managerStart = CFAbsoluteTimeGetCurrent()
        let layoutManager = ContactLayoutManager(
            members: viewModel.filteredMembers,
            root: me,
            treeData: viewModel.treeData,
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )
        let managerTime = (CFAbsoluteTimeGetCurrent() - managerStart) * 1000
        logTiming("ContactLayoutManager init", value: managerTime)

        // Get incremental placement steps for animation
        let incrementalStart = CFAbsoluteTimeGetCurrent()
        let placementSteps = layoutManager.layoutNodesIncremental(language: viewModel.selectedLanguage)
        let incrementalTime = (CFAbsoluteTimeGetCurrent() - incrementalStart) * 1000

        // Extract and store rendering priorities
        extractRenderingPriorities(from: layoutManager)

        let layoutDuration = (CFAbsoluteTimeGetCurrent() - layoutStartTime) * 1000
        logTiming("layoutNodesIncremental", value: incrementalTime)
        AppLog.tree.debug("Layout steps: \(placementSteps.count) in \(ms(layoutDuration))ms")
        AppLog.tree.debug("  ⏱️ Animation speed: \(Int(viewModel.animationSpeedMs))ms per contact")

        // Animate incremental placement with dynamic recomputation
        animateIncrementalPlacement(
            placementSteps: placementSteps,
            layoutManager: layoutManager,
            geometry: geometry
        )
    }

    /// Handles incremental layout for NEW members only when degree slider increases.
    /// Preserves existing visible members and only renders new ones in sidebar order.
    func layoutNodesIncrementalForNewMembers(
        newMemberIds: Set<String>,
        previousVisibleIds: Set<String>,
        geometry: GeometryProxy
    ) {
        guard !newMemberIds.isEmpty else {
            AppLog.tree.debug("  ⚠️ [layoutNodesIncrementalForNewMembers] No new members to render")
            return
        }

        AppLog.tree.debug("\n📐 [TIMING] layoutNodesIncrementalForNewMembers() started")
        AppLog.tree.debug("   - New members: \(newMemberIds.count)")
        AppLog.tree.debug("   - Previous visible: \(previousVisibleIds.count)")
        AppLog.tree.debug("   - Total filtered: \(viewModel.filteredMembers.count)")

        guard let myContactId = viewModel.myContact?.id else {
            AppLog.tree.debug("  ⚠️ [layoutNodesIncrementalForNewMembers] No root contact")
            return
        }

        guard let me = viewModel.filteredMembers.first(where: { $0.id == myContactId }) else {
            AppLog.tree.debug("  ⚠️ [layoutNodesIncrementalForNewMembers] Root contact not in filtered members")
            return
        }

        // Filter new members in sidebar order (already sorted in filteredMembers)
        let newMembersInOrder = viewModel.filteredMembers.filter { newMemberIds.contains($0.id) }
        let memberNames = newMembersInOrder.map { $0.fullName }.joined(separator: ", ")
        AppLog.tree.debug("   - New members in sidebar order: \(memberNames)")

        // Layout ALL filtered members (needed for correct positioning)
        // but only animate the NEW ones
        let managerStart = CFAbsoluteTimeGetCurrent()
        let layoutManager = ContactLayoutManager(
            members: viewModel.filteredMembers,
            root: me,
            treeData: viewModel.treeData,
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )
        let managerTime = (CFAbsoluteTimeGetCurrent() - managerStart) * 1000
        logTiming("ContactLayoutManager init", value: managerTime)

        // Get incremental placement steps
        let incrementalStart = CFAbsoluteTimeGetCurrent()
        let allPlacementSteps = layoutManager.layoutNodesIncremental(language: viewModel.selectedLanguage)
        let incrementalTime = (CFAbsoluteTimeGetCurrent() - incrementalStart) * 1000

        // Extract rendering priorities
        extractRenderingPriorities(from: layoutManager)

        // Filter steps to only include NEW members, preserving order
        let filteredSteps = filterPlacementStepsForNewMembers(
            allSteps: allPlacementSteps,
            newMemberIds: newMemberIds,
            previousVisibleIds: previousVisibleIds
        )

        logTiming("layoutNodesIncremental (filtered)", value: incrementalTime)
        AppLog.tree.debug("All steps: \(allPlacementSteps.count), Filtered steps: \(filteredSteps.count)")
        AppLog.tree.debug("  ⏱️ Animation speed: \(Int(viewModel.animationSpeedMs))ms per contact")

        // Animate only the new members
        animateIncrementalPlacementForNewMembers(
            placementSteps: filteredSteps,
            newMemberIds: newMemberIds,
            layoutManager: layoutManager,
            geometry: geometry
        )
    }

    /// Filters placement steps to only include steps that add NEW members.
    /// Preserves existing node positions and only animates new additions.
    private func filterPlacementStepsForNewMembers(
        allSteps: [[NodePosition]],
        newMemberIds: Set<String>,
        previousVisibleIds: Set<String>
    ) -> [[NodePosition]] {
        guard let firstStep = allSteps.first else { return [] }

        var filteredSteps: [[NodePosition]] = [firstStep] // Always include root step
        var accumulatedVisibleIds = Set(firstStep.map { $0.member.id })

        for step in allSteps.dropFirst() {
            let stepIds = Set(step.map { $0.member.id })
            let newInStep = stepIds.subtracting(accumulatedVisibleIds)

            // Only include steps that add NEW members (not already visible)
            if !newInStep.isEmpty && newInStep.isSubset(of: newMemberIds) {
                // Include all nodes in this step (for correct positioning)
                // but mark only new ones for animation
                filteredSteps.append(step)
                accumulatedVisibleIds.formUnion(stepIds)
            } else if !newInStep.isEmpty {
                // Step adds members that were already visible - skip animation but update positions
                // This handles repositioning of existing nodes
                filteredSteps.append(step)
                accumulatedVisibleIds.formUnion(stepIds)
            }
        }

        return filteredSteps
    }

    /// Extracts rendering priorities from the layout manager's priority queue.
    func extractRenderingPriorities(from layoutManager: ContactLayoutManager) {
        var priorities: [String: Double] = [:]

        // Add root member priority
        if let me = viewModel.myContact {
            priorities[me.id] = 1000.0
        }

        // Add priorities from the priority queue
        for item in layoutManager.priorityQueue {
            priorities[item.member.id] = item.priority
        }

        // Also add any placed members that might not be in the queue
        for member in viewModel.filteredMembers where priorities[member.id] == nil {
            let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
            priorities[member.id] = Double(1000 - degree * 100)
        }

        viewModel.renderingPriorities = priorities
    }
}
