import SwiftUI

extension ContactLayoutManager {
// MARK: - Node Placement

    func placeRoot(language: Language) {
        let relationshipInfo = info(for: root.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)
        let position = NodePosition(
            member: root,
            x: 0,
            y: 0,
            generation: 0,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )

        placedNodes[root.id] = position
        placedMemberIds.insert(root.id)
        markPositionOccupied(x: 0, y: 0)
    }

    func placeSpouseImmediately(language: Language) {
        for relation in root.relations where relation.relationType == .spouse {
            let spouse = relation.member
            // Only place spouse if they're in the filtered members list AND not already placed
            guard !placedMemberIds.contains(spouse.id), memberLookup[spouse.id] != nil else {
                continue
            }

            let spouseX = spouseSpacing
            let relationshipInfo = info(for: spouse.id)
            let relationshipText = localizedRelationship(for: relationshipInfo, language: language)
            let spousePosition = NodePosition(
                member: spouse,
                x: spouseX,
                y: 0,
                generation: 0,
                relationshipToRoot: relationshipText,
                relationshipInfo: relationshipInfo
            )

            placedNodes[spouse.id] = spousePosition
            placedMemberIds.insert(spouse.id)
            markPositionOccupied(x: spouseX, y: 0)
            priorityQueue.removeAll { $0.member.id == spouse.id }
            break
        }
    }

    func placeMember(_ member: FamilyMember, language: Language) {
        guard let position = calculateBestPosition(for: member, language: language) else {
            return
        }

        placedNodes[member.id] = position
        placedMemberIds.insert(member.id)
        markPositionOccupied(x: position.x, y: position.y)
    }

    func calculateBestPosition(for member: FamilyMember, language: Language) -> NodePosition? {
        if let spousePos = findSpousePosition(for: member) {
            return placeAdjacentToSpouse(member: member, spousePos: spousePos, language: language)
        }

        if let parentPositions = findParentPositions(for: member), !parentPositions.isEmpty {
            let calculatedGeneration = parentPositions[0].generation - 1

            // Special handling for root siblings at generation 0
            if calculatedGeneration == 0 {
                let isSiblingOfRoot = root.relations.contains { rel in
                    rel.relationType == .sibling && rel.member.id == member.id
                } || member.relations.contains { rel in
                    rel.relationType == .sibling && rel.member.id == root.id
                }

                if isSiblingOfRoot,
                   let siblingPositions = findSiblingPositions(for: member),
                   !siblingPositions.isEmpty {
                    return placeWithSiblings(member: member, siblingPositions: siblingPositions, language: language)
                }
            }

            return placeBelowParents(member: member, parentPositions: parentPositions, language: language)
        }

        if let childPositions = findChildPositions(for: member), !childPositions.isEmpty {
            return placeAboveChildren(member: member, childPositions: childPositions, language: language)
        }

        if let siblingPositions = findSiblingPositions(for: member), !siblingPositions.isEmpty {
            return placeWithSiblings(member: member, siblingPositions: siblingPositions, language: language)
        }

        return placeNearClosestRelative(member: member, language: language)
    }

// MARK: - Relationship-Based Placement

    func placeAdjacentToSpouse(
        member: FamilyMember,
        spousePos: NodePosition,
        language: Language
    ) -> NodePosition {
        let preferredX = spousePos.x + spouseSpacing
        let x = isPositionAvailable(x: preferredX, y: spousePos.y, minSpacing: spouseSpacing)
            ? preferredX
            : spousePos.x - spouseSpacing

        let finalX = findNearestAvailableX(
            nearX: x,
            atY: spousePos.y,
            minSpacing: spouseSpacing
        )

        let relationshipInfo = info(for: member.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)
        return NodePosition(
            member: member,
            x: finalX,
            y: spousePos.y,
            generation: spousePos.generation,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )
    }

    func placeBelowParents(
        member: FamilyMember,
        parentPositions: [NodePosition],
        language: Language
    ) -> NodePosition {
        let avgParentX = parentPositions.map { $0.x }.reduce(0, +) / CGFloat(parentPositions.count)
        let y = parentPositions[0].y + verticalSpacing
        var preferredX = avgParentX

        // Adjust X position if member has children already placed
        if let childPositions = findChildPositions(for: member), !childPositions.isEmpty {
            let avgChildX = childPositions.map { $0.x }.reduce(0, +) / CGFloat(childPositions.count)
            preferredX = (preferredX + avgChildX) / 2
        }

        let finalX = findNearestAvailableX(nearX: preferredX, atY: y)
        let relationshipInfo = info(for: member.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)

        return NodePosition(
            member: member,
            x: finalX,
            y: y,
            generation: parentPositions[0].generation - 1,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )
    }

    func placeAboveChildren(
        member: FamilyMember,
        childPositions: [NodePosition],
        language: Language
    ) -> NodePosition {
        let avgChildX = childPositions.map { $0.x }.reduce(0, +) / CGFloat(childPositions.count)
        let y = childPositions[0].y - verticalSpacing
        let generation = childPositions[0].generation + 1

        let relationshipInfo = info(for: member.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)

        // If no spouse, place directly above children
        guard let spousePos = findSpousePosition(for: member) else {
            return NodePosition(
                member: member,
                x: avgChildX,
                y: y,
                generation: generation,
                relationshipToRoot: relationshipText,
                relationshipInfo: relationshipInfo
            )
        }

        // Adjust X based on spouse position
        let spouseOffset = spousePos.x - avgChildX

        if abs(spouseOffset) < spouseSpacing / 2 {
            // Spouse is near children center, place with spacing
            let preferredX = avgChildX + spouseSpacing / 2
            let finalX = isPositionAvailable(x: preferredX, y: y, minSpacing: minSpacing)
                ? preferredX
                : avgChildX - spouseSpacing / 2

            return NodePosition(
                member: member,
                x: finalX,
                y: y,
                generation: generation,
                relationshipToRoot: relationshipText,
                relationshipInfo: relationshipInfo
            )
        }

        // Spouse is far from children, mirror spouse offset
        return NodePosition(
            member: member,
            x: avgChildX - spouseOffset,
            y: y,
            generation: generation,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )
    }

    func placeWithSiblings(
        member: FamilyMember,
        siblingPositions: [NodePosition],
        language: Language
    ) -> NodePosition {
        guard let reference = siblingPositions.first else {
            return nodePosition(for: member, x: 0, y: 0, generation: 0, language: language)
        }

        let y = reference.y
        let generation = reference.generation
        let isOlder = isSiblingOlder(member, relativeTo: root)

        guard let rootPosition = placedNodes[root.id], abs(rootPosition.y - y) < 1.0 else {
            return placeSiblingByAge(
                member: member,
                siblingPositions: siblingPositions,
                isOlder: isOlder,
                y: y,
                language: language
            )
        }

        let spouse = spouseContext(atY: y, rootX: rootPosition.x)
        let preferredX = preferredSiblingX(
            member: member,
            isOlder: isOlder,
            rootX: rootPosition.x,
            siblingPositions: siblingPositions,
            spouse: spouse
        )

        let resolvedX = resolveSiblingX(
            preferredX: preferredX,
            isOlder: isOlder,
            rootX: rootPosition.x,
            y: y
        )

        let adjustedX = adjustSiblingX(resolvedX, isOlder: isOlder, rootX: rootPosition.x)

        return nodePosition(
            for: member,
            x: adjustedX,
            y: y,
            generation: generation,
            language: language
        )
    }

    func placeSiblingByAge(
        member: FamilyMember,
        siblingPositions: [NodePosition],
        isOlder: Bool,
        y: CGFloat,
        language: Language
    ) -> NodePosition {
        let generation = siblingPositions.first?.generation ?? 0

        // Sort siblings by age (oldest to youngest, left to right)
        let sortedSiblings = ChildAgeSorter.sort(
            children: siblingPositions,
            birthDate: { $0.member.birthDate },
            xPosition: { $0.x }
        )

        guard let leftmost = sortedSiblings.first, let rightmost = sortedSiblings.last else {
            return nodePosition(for: member, x: 0, y: y, generation: generation, language: language)
        }

        let preferredX = isOlder ? (leftmost.x - baseSpacing) : (rightmost.x + baseSpacing)
        let finalX = findNearestAvailableX(nearX: preferredX, atY: y, minSpacing: baseSpacing)

        return nodePosition(
            for: member,
            x: finalX,
            y: y,
            generation: generation,
            language: language
        )
    }

    func spouseContext(atY y: CGFloat, rootX: CGFloat) -> SpouseContext {
        guard let pair = findSpousePair(atY: y) else {
            return SpouseContext(left: nil, right: nil)
        }

        let rootIsInPair = pair.left.member.id == root.id || pair.right.member.id == root.id

        if rootIsInPair {
            let other = pair.left.member.id == root.id ? pair.right : pair.left
            return other.x < rootX
                ? SpouseContext(left: other, right: nil)
                : SpouseContext(left: nil, right: other)
        }

        var left: NodePosition?
        var right: NodePosition?

        if pair.left.x < rootX {
            left = pair.left
        }
        if pair.right.x > rootX {
            right = pair.right
        }

        // If both are on same side of root, use natural ordering
        if left == nil && right == nil {
            (left, right) = pair.left.x < pair.right.x
                ? (pair.left, pair.right)
                : (pair.right, pair.left)
        }

        return SpouseContext(left: left, right: right)
    }

    func preferredSiblingX(
        member: FamilyMember,
        isOlder: Bool,
        rootX: CGFloat,
        siblingPositions: [NodePosition],
        spouse: SpouseContext
    ) -> CGFloat {
        if isOlder {
            let olderSiblings = siblingPositions.filter { position in
                isSiblingOlder(position.member, relativeTo: root) && position.x < rootX
            }

            if let leftmost = olderSiblings.map({ $0.x }).min() {
                return leftmost - baseSpacing
            }

            if let spouseLeft = spouse.left {
                return spouseLeft.x - baseSpacing
            }

            return rootX - baseSpacing
        }

        // Younger sibling - place to right
        let youngerSiblings = siblingPositions.filter { position in
            !isSiblingOlder(position.member, relativeTo: root) && position.x > rootX
        }

        if let rightmost = youngerSiblings.map({ $0.x }).max() {
            return rightmost + baseSpacing
        }

        if let spouseRight = spouse.right {
            return spouseRight.x + baseSpacing
        }

        return rootX + baseSpacing
    }

    func resolveSiblingX(
        preferredX: CGFloat,
        isOlder: Bool,
        rootX: CGFloat,
        y: CGFloat
    ) -> CGFloat {
        if isOlder {
            if preferredX < rootX && isPositionAvailable(x: preferredX, y: y, minSpacing: baseSpacing) {
                return preferredX
            }

            return searchSiblingX(
                startingAt: rootX - baseSpacing,
                direction: -1,
                rootX: rootX,
                y: y
            )
        }

        // Younger sibling
        if preferredX > rootX && isPositionAvailable(x: preferredX, y: y, minSpacing: baseSpacing) {
            return preferredX
        }

        return searchSiblingX(
            startingAt: rootX + baseSpacing,
            direction: 1,
            rootX: rootX,
            y: y
        )
    }

    func searchSiblingX(
        startingAt start: CGFloat,
        direction: CGFloat,
        rootX: CGFloat,
        y: CGFloat
    ) -> CGFloat {
        var offset: CGFloat = 0
        for _ in 0..<20 {
            let candidate = start + offset * direction
            if (direction < 0 ? candidate < rootX : candidate > rootX)
                && isPositionAvailable(x: candidate, y: y, minSpacing: baseSpacing) {
                return candidate
            }
            offset += baseSpacing
            if offset > 2000 {
                return start
            }
        }
        return start
    }

    func adjustSiblingX(_ x: CGFloat, isOlder: Bool, rootX: CGFloat) -> CGFloat {
        if isOlder && x >= rootX {
            return rootX - baseSpacing * 2
        }
        if !isOlder && x <= rootX {
            return rootX + baseSpacing * 2
        }
        return x
    }

    func nodePosition(
        for member: FamilyMember,
        x: CGFloat,
        y: CGFloat,
        generation: Int,
        language: Language
    ) -> NodePosition {
        let relationshipInfo = info(for: member.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)
        return NodePosition(
            member: member,
            x: x,
            y: y,
            generation: generation,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )
    }

    func siblingPositions(
        in positions: [NodePosition],
        matching predicate: (FamilyMember, NodePosition) -> Bool
    ) -> [NodePosition] {
        positions.compactMap { position in
            guard let sibling = memberLookup[position.member.id], predicate(sibling, position) else {
                return nil
            }
            return position
        }
    }

    struct SpouseContext {
        let left: NodePosition?
        let right: NodePosition?
    }

    func isSiblingOlder(_ sibling: FamilyMember, relativeTo root: FamilyMember) -> Bool {
        return siblingAgeComparator.isSiblingOlder(sibling, relativeTo: root)
    }

    func findSpousePair(atY y: CGFloat) -> (left: NodePosition, right: NodePosition)? {
        let nodesAtY = placedNodes.values.filter { abs($0.y - y) < 1.0 }
        let sortedNodes = nodesAtY.sorted { $0.x < $1.x }

        for i in 0..<(sortedNodes.count - 1) {
            let node1 = sortedNodes[i]
            let node2 = sortedNodes[i + 1]

            if areSpouses(node1.member, node2.member) {
                return (left: node1, right: node2)
            }
        }

        return nil
    }

    func areSpouses(_ member1: FamilyMember, _ member2: FamilyMember) -> Bool {
        return member1.relations.contains { relation in
            relation.relationType == .spouse && relation.member.id == member2.id
        }
    }

    func placeNearClosestRelative(member: FamilyMember, language: Language) -> NodePosition {
        var closestPos: NodePosition?
        var relationshipType: FamilyMember.RelationType?
        var minDistance = Double.infinity

        // Find closest placed relative
        for (placedId, placedPos) in placedNodes {
            guard let relation = findRelationship(from: member, to: placedId) else {
                continue
            }

            let distance: Double
            switch relation.relationType {
            case .parent, .child:
                distance = 1
            case .spouse:
                distance = 1.5
            case .sibling:
                distance = 2
            case .other:
                distance = 3
            }

            if distance < minDistance {
                minDistance = distance
                closestPos = placedPos
                relationshipType = relation.relationType
            }
        }

        // Use closest relative or fall back to root
        let referencePos = closestPos ?? placedNodes[root.id]
        precondition(
            referencePos != nil,
            "Root node must be placed before placing other members. Root ID: \(root.id)"
        )
        guard let ref = referencePos else {
            fatalError("Unreachable - precondition should catch this")
        }

        // Determine generation and Y position based on relationship type
        let (generation, y) = calculateGenerationAndY(
            for: relationshipType,
            relativeTo: ref
        )

        let x = ref.x + getCurrentSpacing()
        let relationshipInfo = info(for: member.id)
        let relationshipText = localizedRelationship(for: relationshipInfo, language: language)

        return NodePosition(
            member: member,
            x: findNearestAvailableX(nearX: x, atY: y),
            y: y,
            generation: generation,
            relationshipToRoot: relationshipText,
            relationshipInfo: relationshipInfo
        )
    }

    private func calculateGenerationAndY(
        for relationType: FamilyMember.RelationType?,
        relativeTo ref: NodePosition
    ) -> (generation: Int, y: CGFloat) {
        guard let relType = relationType else {
            return (ref.generation, ref.y)
        }

        switch relType {
        case .parent:
            return (ref.generation - 1, ref.y + verticalSpacing)
        case .child:
            return (ref.generation + 1, ref.y - verticalSpacing)
        default:
            return (ref.generation, ref.y)
        }
    }
}
