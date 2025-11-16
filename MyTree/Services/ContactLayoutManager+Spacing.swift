import SwiftUI

extension ContactLayoutManager {
// MARK: - Spacing & Position Management

    func getCurrentSpacing() -> CGFloat {
        let placedCount = Double(placedMemberIds.count)
        let expansionMultiplier = pow(expansionFactor, log10(max(1, placedCount / 10.0 + 1)))
        return max(minSpacing, baseSpacing * CGFloat(expansionMultiplier))
    }

    func markPositionOccupied(x: CGFloat, y: CGFloat) {
        occupiedXPositions[y, default: Set<CGFloat>()].insert(x)
    }

    func unmarkPositionOccupied(x: CGFloat, y: CGFloat) {
        if var occupiedX = occupiedXPositions[y] {
            occupiedX.remove(x)
            occupiedXPositions[y] = occupiedX
        }
    }

    func findNearestAvailableX(
        nearX: CGFloat,
        atY y: CGFloat,
        minSpacing: CGFloat? = nil,
        preferLeft: Bool? = nil
    ) -> CGFloat {
        let spacing = minSpacing ?? getCurrentSpacing()

        if isPositionAvailable(x: nearX, y: y, minSpacing: spacing) {
            return nearX
        }

        var offset: CGFloat = spacing

        if let preferLeft = preferLeft {
            for _ in 0..<10 {
                if preferLeft {
                    if isPositionAvailable(x: nearX - offset, y: y, minSpacing: spacing) {
                        return nearX - offset
                    }
                    if isPositionAvailable(x: nearX + offset, y: y, minSpacing: spacing) {
                        return nearX + offset
                    }
                } else {
                    if isPositionAvailable(x: nearX + offset, y: y, minSpacing: spacing) {
                        return nearX + offset
                    }
                    if isPositionAvailable(x: nearX - offset, y: y, minSpacing: spacing) {
                        return nearX - offset
                    }
                }
                offset += spacing
            }
        } else {
            for _ in 0..<10 {
                if isPositionAvailable(x: nearX + offset, y: y, minSpacing: spacing) {
                    return nearX + offset
                }
                if isPositionAvailable(x: nearX - offset, y: y, minSpacing: spacing) {
                    return nearX - offset
                }
                offset += spacing
            }
        }

        return nearX
    }

    func isPositionAvailable(x: CGFloat, y: CGFloat, minSpacing: CGFloat? = nil) -> Bool {
        let requiredSpacing = minSpacing ?? self.minSpacing
        guard let occupiedXs = occupiedXPositions[y] else {
            return true
        }
        return occupiedXs.allSatisfy { abs($0 - x) >= requiredSpacing }
    }

    func resolvedX(preferredX: CGFloat, y: CGFloat, minSpacing: CGFloat) -> CGFloat {
        if isPositionAvailable(x: preferredX, y: y, minSpacing: minSpacing) {
            return preferredX
        }
        return findNearestAvailableX(nearX: preferredX, atY: y)
    }

// MARK: - Realignment

    /// Realigns siblings (children) below their parents when a new sibling is added.
    /// This ensures children stay centered below their parents during incremental placement.
    func realignSiblingsUnderParents(forNewlyPlaced memberId: String) {
        guard let newlyPlacedMember = members.first(where: { $0.id == memberId }),
              placedNodes[memberId] != nil else {
            return
        }

        // Get the parents of the newly placed member
        guard let parentPositions = findParentPositions(for: newlyPlacedMember),
              !parentPositions.isEmpty else {
            return
        }

        let parentIds = parentPositions.map { $0.member.id }.sorted()

        // Find all siblings (children of the same parents)
        var siblings: [NodePosition] = []
        for (childId, childPos) in placedNodes {
            guard let childMember = members.first(where: { $0.id == childId }) else { continue }

            let childParentIds = findParentPositions(for: childMember)?.map { $0.member.id }.sorted() ?? []

            if childParentIds == parentIds {
                siblings.append(childPos)
            }
        }

        guard siblings.count >= 2 else { return } // Need at least 2 siblings to realign

        // Calculate center of parents
        let parentsX = parentPositions.map { $0.x }
        guard let minParentX = parentsX.min(), let maxParentX = parentsX.max() else { return }
        let parentsCenterX = (minParentX + maxParentX) / 2

        // Sort siblings by age (oldest to youngest, left to right)
        // Siblings without birth dates are placed after those with dates
        let sortedSiblings = ChildAgeSorter.sort(
            children: siblings,
            birthDate: { $0.member.birthDate },
            xPosition: { $0.x }
        )

        // Calculate total width needed for siblings with spacing
        let siblingCount = sortedSiblings.count
        let totalWidth = CGFloat(siblingCount - 1) * baseSpacing

        // Calculate starting x position to center siblings below parents
        let startX = parentsCenterX - totalWidth / 2

        // Realign each sibling
        for (index, sibling) in sortedSiblings.enumerated() {
            let newX = startX + CGFloat(index) * baseSpacing

            // Only update if position changed significantly
            if abs(sibling.x - newX) > 1 {
                // Unmark old position
                unmarkPositionOccupied(x: sibling.x, y: sibling.y)

                // Update position
                var updated = sibling
                updated.x = newX
                placedNodes[sibling.member.id] = updated

                // Mark new position
                markPositionOccupied(x: newX, y: sibling.y)
            }
        }
    }

    /// Realigns a parent couple above their children when a spouse is added.
    /// This ensures parents stay centered above their children during incremental placement.
    /// IMPORTANT: Does not move the root node — root stays fixed at (0, 0).
    func realignParentCoupleAboveChildren(forNewlyPlaced memberId: String) {
        guard let newlyPlacedMember = members.first(where: { $0.id == memberId }),
              let newlyPlacedPos = placedNodes[memberId] else {
            return
        }

        // Find the spouse of the newly placed member (if any)
        guard let spouseId = findSpousePosition(for: newlyPlacedMember)?.member.id,
              let spousePos = placedNodes[spouseId] else {
            return
        }

        // DON'T move if either parent is the root (root must stay at 0,0)
        if newlyPlacedMember.id == root.id || spouseId == root.id {
            return
        }

        // Find all children of this couple
        var children: [NodePosition] = []
        for (childId, childPos) in placedNodes {
            guard let childMember = members.first(where: { $0.id == childId }) else { continue }

            let childParentIds = findParentPositions(for: childMember)?.map { $0.member.id }.sorted() ?? []
            let coupleIds = [memberId, spouseId].sorted()

            if childParentIds == coupleIds {
                children.append(childPos)
            }
        }

        guard !children.isEmpty else { return }

        // Calculate center of children
        let childrenX = children.map { $0.x }
        guard let minChildX = childrenX.min(), let maxChildX = childrenX.max() else { return }
        let centerX = (minChildX + maxChildX) / 2

        // Determine left and right parents
        let leftParent = newlyPlacedPos.x < spousePos.x ? newlyPlacedPos : spousePos
        let rightParent = newlyPlacedPos.x < spousePos.x ? spousePos : newlyPlacedPos

        let newLeftX = centerX - spouseSpacing / 2
        let newRightX = centerX + spouseSpacing / 2

        // Only realign if there's a significant difference
        if abs(leftParent.x - newLeftX) > 1 || abs(rightParent.x - newRightX) > 1 {
            // Calculate shift amount
            let shiftAmount = newLeftX - leftParent.x

            // Unmark old positions
            unmarkPositionOccupied(x: leftParent.x, y: leftParent.y)
            unmarkPositionOccupied(x: rightParent.x, y: rightParent.y)

            // Update left parent
            var updatedLeft = leftParent
            updatedLeft.x = newLeftX
            placedNodes[leftParent.member.id] = updatedLeft
            markPositionOccupied(x: newLeftX, y: leftParent.y)

            // Update right parent
            var updatedRight = rightParent
            updatedRight.x = newRightX
            placedNodes[rightParent.member.id] = updatedRight
            markPositionOccupied(x: newRightX, y: rightParent.y)

            // Propagate this shift upward to ancestors
            propagateShiftToAncestors(childId: leftParent.member.id, shiftX: shiftAmount)
        }
    }

    /// Realigns only the immediate parents of a newly placed node.
    /// This prevents cascade effects during incremental placement.
    /// IMPORTANT: Does not move if the root is one of the parents (root must stay at 0,0).
    func realignLocalParentsOnly(forNewlyPlaced memberId: String) {
        guard let member = members.first(where: { $0.id == memberId }),
              let parentPositions = findParentPositions(for: member),
              !parentPositions.isEmpty else {
            return
        }

        let parentIds = parentPositions.map { $0.member.id }

        // DON'T move if the root is one of the parents being realigned
        if parentIds.contains(root.id) {
            return
        }

        var allChildren: [NodePosition] = []

        for (childId, childPos) in placedNodes {
            guard let childMember = members.first(where: { $0.id == childId }),
                  let childParents = findParentPositions(for: childMember) else { continue }

            let childParentIds = childParents.map { $0.member.id }.sorted()
            let targetParentIds = parentIds.sorted()

            if childParentIds == targetParentIds {
                allChildren.append(childPos)
            }
        }

        guard !allChildren.isEmpty else { return }

        let childrenX = allChildren.map { $0.x }
        guard let minChildX = childrenX.min(), let maxChildX = childrenX.max() else { return }
        let centerX = (minChildX + maxChildX) / 2

        if parentPositions.count == 1 {
            let parent = parentPositions[0]
            unmarkPositionOccupied(x: parent.x, y: parent.y)

            if abs(centerX - parent.x) > 1 {
                markPositionOccupied(x: centerX, y: parent.y)
                var updatedPos = parent
                updatedPos.x = centerX
                placedNodes[parent.member.id] = updatedPos
            } else {
                markPositionOccupied(x: parent.x, y: parent.y)
            }
        } else if parentPositions.count == 2 {
            guard
                let leftParent = parentPositions.min(by: { $0.x < $1.x }),
                let rightParent = parentPositions.max(by: { $0.x < $1.x })
            else { return }

            let newLeftX = centerX - spouseSpacing / 2
            let newRightX = centerX + spouseSpacing / 2

            unmarkPositionOccupied(x: leftParent.x, y: leftParent.y)
            unmarkPositionOccupied(x: rightParent.x, y: rightParent.y)

            markPositionOccupied(x: newLeftX, y: leftParent.y)
            var updatedLeft = leftParent
            updatedLeft.x = newLeftX
            placedNodes[leftParent.member.id] = updatedLeft

            markPositionOccupied(x: newRightX, y: rightParent.y)
            var updatedRight = rightParent
            updatedRight.x = newRightX
            placedNodes[rightParent.member.id] = updatedRight
        }
    }

    /// Propagates a horizontal shift upward to ancestors.
    ///
    /// When a node shifts horizontally (e.g., to center over children), its parents
    /// should also shift to stay centered above it. This function recursively propagates
    /// the shift upward through generations.
    ///
    /// - Parameters:
    ///   - childId: The ID of the child node that shifted
    ///   - shiftX: The amount of horizontal shift in pixels
    func propagateShiftToAncestors(childId: String, shiftX: CGFloat) {
        // Skip if shift is negligible
        guard abs(shiftX) > 1 else { return }

        guard let childMember = members.first(where: { $0.id == childId }),
              let parentPositions = findParentPositions(for: childMember),
              !parentPositions.isEmpty else {
            return
        }

        // Shift each parent by the same amount
        for parentPos in parentPositions {
            let oldX = parentPos.x
            let newX = oldX + shiftX

            // Unmark old position
            unmarkPositionOccupied(x: oldX, y: parentPos.y)

            // Update position
            var updated = parentPos
            updated.x = newX
            placedNodes[parentPos.member.id] = updated

            // Mark new position
            markPositionOccupied(x: newX, y: parentPos.y)

            // Recursively propagate to this parent's parents (grandparents)
            propagateShiftToAncestors(childId: parentPos.member.id, shiftX: shiftX)
        }
    }

    /// Performs global realignment of all parent groups.
    /// Used for final polish after all nodes are placed.
    /// Iterates until no more adjustments are needed (converges to stable state).
    func realignGroups() {
        let maxIterations = 10 // Prevent infinite loops
        var iteration = 0

        while iteration < maxIterations {
            let adjustedNodes = realignGroupsSinglePass()
            if adjustedNodes.isEmpty {
                // No more adjustments needed - layout is stable
                break
            }
            iteration += 1
        }

        if iteration >= maxIterations {
            let msg = "realignGroups() reached max iterations (\(maxIterations)) - layout may not be fully stable"
            AppLog.tree.error(msg)
        }
    }

    func realignGroupsSinglePass() -> Set<String> {
        var adjustedNodes = Set<String>()
        var movedInThisPass = Set<String>()
        let groupedChildren = groupedChildrenByParents()

        for (parentKey, children) in sortedParentGroups(from: groupedChildren) {
            adjustParentGroup(
                parentKey: parentKey,
                children: children,
                adjustedNodes: &adjustedNodes,
                movedInThisPass: &movedInThisPass
            )
        }

        return adjustedNodes
    }

    func groupedChildrenByParents() -> [String: [NodePosition]] {
        var childrenByParents: [String: [NodePosition]] = [:]

        for (memberId, position) in placedNodes {
            guard let member = members.first(where: { $0.id == memberId }),
                  let parentPositions = findParentPositions(for: member),
                  !parentPositions.isEmpty else { continue }

            let parentIds = parentPositions.map { $0.member.id }.sorted()
            let parentKey = parentIds.joined(separator: "|||")
            childrenByParents[parentKey, default: []].append(position)
        }

        return childrenByParents
    }

    func sortedParentGroups(from groups: [String: [NodePosition]]) -> [(String, [NodePosition])] {
        groups.sorted { group1, group2 in
            let parentIds1 = group1.key.components(separatedBy: "|||")
            let parentIds2 = group2.key.components(separatedBy: "|||")

            let gen1 = parentIds1.compactMap { placedNodes[$0]?.generation }.min() ?? 0
            let gen2 = parentIds2.compactMap { placedNodes[$0]?.generation }.min() ?? 0

            return gen1 < gen2
        }
    }

    func adjustParentGroup(
        parentKey: String,
        children: [NodePosition],
        adjustedNodes: inout Set<String>,
        movedInThisPass: inout Set<String>
    ) {
        let parentIds = parentKey.components(separatedBy: "|||")
        let parentPositions = parentIds.compactMap { placedNodes[$0] }

        guard !parentPositions.isEmpty, !children.isEmpty else { return }

        // REMOVED: Early return when children move - this was preventing parents from recentering
        // when children positions change. Parents should always be centered above their children,
        // regardless of whether children moved in this pass.

        // IMPORTANT: Sort children by age (oldest to youngest, left to right)
        // This preserves age ordering when realigning groups
        let sortedChildren = ChildAgeSorter.sort(
            children: children,
            birthDate: { $0.member.birthDate },
            xPosition: { $0.x }
        )

        // CRITICAL FIX: Calculate children center FIRST (before repositioning children)
        // This ensures parents are centered above the actual current positions of children,
        // not positions calculated from potentially incorrect parent positions
        let currentChildrenX = sortedChildren.map { $0.x }
        guard let minChildX = currentChildrenX.min(), let maxChildX = currentChildrenX.max() else { return }
        let childrenCenterX = (minChildX + maxChildX) / 2

        // Center parents above current children positions
        if parentPositions.count == 1 {
            alignSingleParent(
                parentPosition: parentPositions[0],
                centerX: childrenCenterX,
                adjustedNodes: &adjustedNodes,
                movedInThisPass: &movedInThisPass
            )
        } else if parentPositions.count == 2 {
            alignParentPair(
                parentPositions: parentPositions,
                centerX: childrenCenterX,
                adjustedNodes: &adjustedNodes,
                movedInThisPass: &movedInThisPass
            )
        }

        // AFTER centering parents, recalculate parent center and realign children
        // This ensures children are properly spaced and centered below the now-correctly-positioned parents
        let updatedParentPositions = parentIds.compactMap { placedNodes[$0] }
        guard !updatedParentPositions.isEmpty else { return }

        let updatedParentsX = updatedParentPositions.map { $0.x }
        guard let minParentX = updatedParentsX.min(), let maxParentX = updatedParentsX.max() else { return }
        let parentsCenterX = (minParentX + maxParentX) / 2

        // Calculate total width needed for children with spacing
        let childCount = sortedChildren.count
        let totalWidth = CGFloat(childCount - 1) * baseSpacing
        let startX = parentsCenterX - totalWidth / 2

        // Update children positions to be properly ordered by age and centered below parents
        // CRITICAL: Never move the root - root must stay at its anchored position
        for (index, child) in sortedChildren.enumerated() {
            // Skip if this child is the root - root position is fixed
            if child.member.id == root.id {
                continue
            }

            let newX = startX + CGFloat(index) * baseSpacing

            // Only update if position changed significantly
            if abs(child.x - newX) > 1 {
                // Unmark old position
                unmarkPositionOccupied(x: child.x, y: child.y)

                // Update position
                var updated = child
                updated.x = newX
                placedNodes[child.member.id] = updated

                // Mark new position
                markPositionOccupied(x: newX, y: child.y)
            }
        }

        // If root is among the children, we need to adjust the spacing to account for root's fixed position
        // Recalculate parent center based on actual child positions (including root's fixed position)
        let finalChildrenPositions = sortedChildren.map { placedNodes[$0.member.id] ?? $0 }
        let finalChildrenX = finalChildrenPositions.map { $0.x }
        if let minFinalChildX = finalChildrenX.min(), let maxFinalChildX = finalChildrenX.max() {
            let finalChildrenCenterX = (minFinalChildX + maxFinalChildX) / 2

            // Re-center parents above the actual final child positions (which may include root at fixed position)
            let finalUpdatedParentPositions = parentIds.compactMap { placedNodes[$0] }
            if !finalUpdatedParentPositions.isEmpty {
                let finalParentsX = finalUpdatedParentPositions.map { $0.x }
                if let minFinalParentX = finalParentsX.min(), let maxFinalParentX = finalParentsX.max() {
                    let finalParentsCenterX = (minFinalParentX + maxFinalParentX) / 2
                    let finalCenterError = abs(finalParentsCenterX - finalChildrenCenterX)

                    // If there's still a significant centering error, adjust parents one more time
                    if finalCenterError > 1 {
                        if finalUpdatedParentPositions.count == 1 {
                            alignSingleParent(
                                parentPosition: finalUpdatedParentPositions[0],
                                centerX: finalChildrenCenterX,
                                adjustedNodes: &adjustedNodes,
                                movedInThisPass: &movedInThisPass
                            )
                        } else if finalUpdatedParentPositions.count == 2 {
                            alignParentPair(
                                parentPositions: finalUpdatedParentPositions,
                                centerX: finalChildrenCenterX,
                                adjustedNodes: &adjustedNodes,
                                movedInThisPass: &movedInThisPass
                            )
                        }
                    }
                }
            }
        }
    }

    func alignSingleParent(
        parentPosition: NodePosition,
        centerX: CGFloat,
        adjustedNodes: inout Set<String>,
        movedInThisPass: inout Set<String>
    ) {
        guard !adjustedNodes.contains(parentPosition.member.id) else { return }

        unmarkPositionOccupied(x: parentPosition.x, y: parentPosition.y)
        let newX = resolvedX(preferredX: centerX, y: parentPosition.y, minSpacing: minSpacing)

        if abs(newX - parentPosition.x) > 1 {
            markPositionOccupied(x: newX, y: parentPosition.y)
            var updatedPos = parentPosition
            updatedPos.x = newX
            placedNodes[parentPosition.member.id] = updatedPos
            adjustedNodes.insert(parentPosition.member.id)
            movedInThisPass.insert(parentPosition.member.id)
        } else {
            markPositionOccupied(x: parentPosition.x, y: parentPosition.y)
        }
    }

    func alignParentPair(
        parentPositions: [NodePosition],
        centerX: CGFloat,
        adjustedNodes: inout Set<String>,
        movedInThisPass: inout Set<String>
    ) {
        guard
            let leftParent = parentPositions.min(by: { $0.x < $1.x }),
            let rightParent = parentPositions.max(by: { $0.x < $1.x })
        else { return }

        unmarkPositionOccupied(x: leftParent.x, y: leftParent.y)
        unmarkPositionOccupied(x: rightParent.x, y: rightParent.y)

        let newLeftX = centerX - spouseSpacing / 2
        let newRightX = centerX + spouseSpacing / 2

        markPositionOccupied(x: newLeftX, y: leftParent.y)
        var updatedLeft = leftParent
        updatedLeft.x = newLeftX
        placedNodes[leftParent.member.id] = updatedLeft
        adjustedNodes.insert(leftParent.member.id)
        movedInThisPass.insert(leftParent.member.id)

        markPositionOccupied(x: newRightX, y: rightParent.y)
        var updatedRight = rightParent
        updatedRight.x = newRightX
        placedNodes[rightParent.member.id] = updatedRight
        adjustedNodes.insert(rightParent.member.id)
        movedInThisPass.insert(rightParent.member.id)
    }

    func adjustDynamicSpacing() {
        // Reserved for future enhancements
    }
}
