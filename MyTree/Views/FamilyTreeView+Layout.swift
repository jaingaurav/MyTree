import SwiftUI

extension FamilyTreeView {
    // MARK: - Layout Management

    /// Sorts members using relationship-based BFS ordering.
    ///
    /// Uses the same priority queue algorithm as the layout engine:
    /// For each person, add relatives in this order:
    /// 1. Parents (ordered by age - older first)
    /// 2. Siblings (ordered by age - older first)
    /// 3. Spouse
    /// 4. Children (ordered by age - older first)
    ///
    /// This ensures the sidebar matches the rendering order.
    private func sortMembersLikeSidebar(_ members: [FamilyMember]) -> [FamilyMember] {
        guard let myContact = viewModel.myContact else {
            // Fallback to simple sorting if no root
            return members.sorted { $0.fullName < $1.fullName }
        }

        // Find root in members list
        guard let root = members.first(where: { $0.id == myContact.id }) else {
            return members.sorted { $0.fullName < $1.fullName }
        }

        let memberLookup = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        var orderedMembers: [FamilyMember] = []
        var addedMembers: Set<String> = []

        // BFS-style traversal
        var processingQueue: [FamilyMember] = [root]
        addedMembers.insert(root.id)
        orderedMembers.append(root)

        let siblingComparator = SiblingAgeComparator()

        while !processingQueue.isEmpty {
            let currentMember = processingQueue.removeFirst()

            // 1. Parents (ordered by age - older first)
            var parentsList: [FamilyMember] = []

            // Forward relations: member → parent
            for relation in currentMember.relations where relation.relationType == .parent {
                if let parent = memberLookup[relation.member.id] {
                    parentsList.append(parent)
                }
            }

            // Reverse relations: other members → child (this member)
            for candidateMember in members where candidateMember.id != currentMember.id {
                for relation in candidateMember.relations where relation.relationType == .child {
                    if relation.member.id == currentMember.id, !parentsList.contains(where: { $0.id == candidateMember.id }) {
                        parentsList.append(candidateMember)
                        break
                    }
                }
            }

            let parents = parentsList.sorted { first, second in
                if let date1 = first.birthDate, let date2 = second.birthDate {
                    return date1 < date2
                }
                return first.id < second.id
            }

            for parent in parents {
                if !addedMembers.contains(parent.id) {
                    orderedMembers.append(parent)
                    processingQueue.append(parent)
                    addedMembers.insert(parent.id)
                }
            }

            // 2. Siblings (ordered by age - older first)
            let siblings = currentMember.relations
                .filter { $0.relationType == .sibling && memberLookup[$0.member.id] != nil }
                .map { $0.member }
                .sorted { first, second in
                    let firstIsOlder = siblingComparator.isSiblingOlder(first, relativeTo: currentMember)
                    let secondIsOlder = siblingComparator.isSiblingOlder(second, relativeTo: currentMember)

                    if firstIsOlder != secondIsOlder {
                        return firstIsOlder
                    }
                    if let date1 = first.birthDate, let date2 = second.birthDate {
                        return date1 < date2
                    }
                    return first.id < second.id
                }

            for sibling in siblings {
                if !addedMembers.contains(sibling.id) {
                    orderedMembers.append(sibling)
                    processingQueue.append(sibling)
                    addedMembers.insert(sibling.id)
                }
            }

            // 3. Spouse
            if let spouse = currentMember.relations
                .first(where: { $0.relationType == .spouse && memberLookup[$0.member.id] != nil }) {
                if !addedMembers.contains(spouse.member.id) {
                    orderedMembers.append(spouse.member)
                    processingQueue.append(spouse.member)
                    addedMembers.insert(spouse.member.id)
                }
            }

            // 4. Children (ordered by age - older first)
            var childrenList: [FamilyMember] = []

            // Forward relations: member → child
            for relation in currentMember.relations where relation.relationType == .child {
                if let child = memberLookup[relation.member.id] {
                    childrenList.append(child)
                }
            }

            // Reverse relations: other members → parent (this member)
            for candidateMember in members where candidateMember.id != currentMember.id {
                for relation in candidateMember.relations where relation.relationType == .parent {
                    if relation.member.id == currentMember.id, !childrenList.contains(where: { $0.id == candidateMember.id }) {
                        childrenList.append(candidateMember)
                        break
                    }
                }
            }

            let children = childrenList.sorted { first, second in
                if let date1 = first.birthDate, let date2 = second.birthDate {
                    return date1 < date2
                }
                return first.id < second.id
            }

            for child in children {
                if !addedMembers.contains(child.id) {
                    orderedMembers.append(child)
                    processingQueue.append(child)
                    addedMembers.insert(child.id)
                }
            }
        }

        // Add any remaining members not reached by BFS (disconnected members)
        for member in members {
            if !addedMembers.contains(member.id) {
                orderedMembers.append(member)
            }
        }

        return orderedMembers
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

        // Debug: show filtered members in sidebar order
        AppLog.tree.debug("   📋 Sidebar order (rendering will follow this order):")
        if viewModel.filteredMembers.count <= 10 {
            for (index, member) in viewModel.filteredMembers.enumerated() {
                let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("      \(index + 1). \(member.fullName): degree \(degree)")
            }
        } else {
            for (index, member) in viewModel.filteredMembers.prefix(5).enumerated() {
                let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
                AppLog.tree.debug("      \(index + 1). \(member.fullName): degree \(degree)")
            }
            AppLog.tree.debug("      ... and \(viewModel.filteredMembers.count - 5) more")
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

        // Use LayoutOrchestrator with stateless engine
        let orchestrator = LayoutOrchestrator()
        let config = LayoutConfiguration(
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )

        // Get incremental placement steps for animation
        let incrementalStart = CFAbsoluteTimeGetCurrent()
        let result = orchestrator.layoutTreeIncremental(
            members: viewModel.filteredMembers,
            root: me,
            treeData: viewModel.treeData,
            config: config,
            language: viewModel.selectedLanguage
        )

        guard case .success(let placementSteps) = result else {
            AppLog.tree.error("Failed to compute incremental layout")
            return
        }
        let incrementalTime = (CFAbsoluteTimeGetCurrent() - incrementalStart) * 1000

        // Extract and store rendering priorities
        extractRenderingPriorities()

        let layoutDuration = (CFAbsoluteTimeGetCurrent() - layoutStartTime) * 1000
        logTiming("layoutNodesIncremental", value: incrementalTime)
        AppLog.tree.debug("Layout steps: \(placementSteps.count) in \(ms(layoutDuration))ms")
        AppLog.tree.debug("  ⏱️ Animation speed: \(Int(viewModel.animationSpeedMs))ms per contact")

        // Animate incremental placement
        animateIncrementalPlacement(
            placementSteps: placementSteps,
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
        let orchestrator = LayoutOrchestrator()
        let config = LayoutConfiguration(
            baseSpacing: viewModel.layoutConfig.baseSpacing,
            spouseSpacing: viewModel.layoutConfig.spouseSpacing,
            verticalSpacing: 200,
            minSpacing: 80,
            expansionFactor: 1.15
        )
        // Get incremental placement steps
        let incrementalStart = CFAbsoluteTimeGetCurrent()
        let result = orchestrator.layoutTreeIncremental(
            members: viewModel.filteredMembers,
            root: me,
            treeData: viewModel.treeData,
            config: config,
            language: viewModel.selectedLanguage
        )

        guard case .success(let allPlacementSteps) = result else {
            AppLog.tree.error("Failed to compute incremental layout for new members")
            return
        }
        let incrementalTime = (CFAbsoluteTimeGetCurrent() - incrementalStart) * 1000

        // Extract rendering priorities
        extractRenderingPriorities()

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
        guard !allSteps.isEmpty else { return [] }

        var filteredSteps: [[NodePosition]] = []
        // Start with previously visible IDs to correctly identify which steps are truly new
        var accumulatedVisibleIds = previousVisibleIds

        for step in allSteps {
            let stepIds = Set(step.map { $0.member.id })
            let newInStep = stepIds.subtracting(accumulatedVisibleIds)

            // Only include steps that add at least one NEW member from newMemberIds
            if !newInStep.isEmpty && !newInStep.isDisjoint(with: newMemberIds) {
                // This step adds genuinely new members - include it
                filteredSteps.append(step)
                accumulatedVisibleIds.formUnion(stepIds)
            }
        }

        return filteredSteps
    }

    /// Extracts rendering priorities based on degree of separation.
    /// No longer needs layoutManager since we use stateless engine.
    func extractRenderingPriorities() {
        var priorities: [String: Double] = [:]

        // Add root member priority
        if let me = viewModel.myContact {
            priorities[me.id] = 1000.0
        }

        // Compute priorities based on degree (same logic as priority queue)
        for member in viewModel.filteredMembers {
            if priorities[member.id] == nil {
                let degree = viewModel.treeData.degreeOfSeparation(for: member.id)
                // Higher priority = lower degree, with index-based tiebreaker
                let index = viewModel.filteredMembers.firstIndex(where: { $0.id == member.id }) ?? 0
                priorities[member.id] = Double(10000 - degree * 1000 - index)
            }
        }

        viewModel.renderingPriorities = priorities
    }
}
