# Family Tree Layout Algorithm

## Overview

The MyTree layout algorithm uses a **priority-based, relationship-aware placement strategy** to create visually
balanced family tree layouts. The algorithm achieves O(n log n) complexity through precomputed priorities and
intelligent position caching.

## Key Design Principles

1. **Priority-Based Ordering**: Members are placed in order of relationship importance (closer relatives first)
2. **Relationship-Aware Positioning**: Placement respects family relationships (spouses adjacent, children below
   parents, etc.)
3. **Dynamic Spacing**: Spacing adapts as the tree grows to prevent overcrowding
4. **Incremental Realignment**: Local adjustments after each placement prevent cascading layout changes
5. **Collision Avoidance**: Tracks occupied positions to ensure minimum spacing between nodes

## Algorithm Phases

### Phase 1: Initialization

```swift

func layoutNodesIncremental(language: Language) -> [[NodePosition]]

```

**Steps:**

1. Reset internal state (clear placed nodes, occupied positions)
2. Build priority queue sorted by relationship closeness
3. Initialize degree map for O(1) degree lookups

**Priority Calculation:**

```swift

priority = 1000 - (degree * 100) + relationshipBonus

```

Where:

- `degree`: Degree of separation from root (0 = self, 1 = parent/child/spouse, 2 = grandparent/sibling, etc.)
- `relationshipBonus`: Additional weight for direct relationships (+50 for spouses, +30 for parents, +20 for children)

### Phase 2: Root Placement

```swift

func placeRoot(language: Language)

```

**Action:**

- Place root contact at origin (0, 0)
- Mark position as occupied
- Set generation to 0

**Coordinate System:**

- X-axis: Horizontal position (left-right)
- Y-axis: Vertical position (generation-based)
  - Generation 0: Root and siblings
  - Positive Y: Parents, grandparents (upward)
  - Negative Y: Children, grandchildren (downward)

### Phase 3: Immediate Spouse Placement

```swift

func placeSpouseImmediately(language: Language)

```

**Action:**

- Place root's spouse immediately adjacent
- Position: `(spouseSpacing, 0)` where `spouseSpacing ≈ 180px`
- Ensures married couples appear together

**Why Immediate?**

- Spouses should always be visually grouped
- Prevents spouse from being placed far away by priority queue

### Phase 4: Iterative Placement

```swift

while !priorityQueue.isEmpty {
    let next = priorityQueue.removeFirst()  // O(log n) with sorted queue
    if !placedMemberIds.contains(next.member.id) {
        placeMember(next.member, language: language)
        realignLocalParentsOnly(forNewlyPlaced: next.member.id)
        realignParentCoupleAboveChildren(forNewlyPlaced: next.member.id)
        realignSiblingsUnderParents(forNewlyPlaced: next.member.id)
    }
}

```

**For Each Member:**

#### Step 4.1: Calculate Best Position

```swift

func calculateBestPosition(for member: FamilyMember, language: Language) -> NodePosition?

```

**Position Strategy (in priority order):**

1. **Spouse Position**: If member's spouse is already placed
   - Position: Adjacent to spouse (`spouseX ± spouseSpacing`)
   - Same generation (Y) as spouse

2. **Child Position**: If member's parents are placed
   - Position: Centered below parents
   - Y: `parentY - verticalSpacing` (typically -200px from parents)
   - X: Average of parent X positions
   - Siblings are ordered by age (older left, younger right)

3. **Parent Position**: If member's children are placed
   - Position: Centered above children
   - Y: `childY + verticalSpacing` (+200px above children)
   - X: Average of children X positions
   - If has spouse, both parents centered together

4. **Sibling Position**: If member's siblings are placed
   - Position: Horizontally adjacent to siblings
   - Same Y position as siblings
   - Ordered by birth date (older left, younger right using `SiblingAgeComparator`)

5. **Fallback Position**: Place near closest relative
   - Find closest placed relative by degree of separation
   - Position nearby with appropriate spacing

#### Step 4.2: Collision Avoidance

```swift

func findNearestAvailableX(nearX: CGFloat, atY y: CGFloat, minSpacing: CGFloat) -> CGFloat

```

**Process:**

1. Check if preferred position is available
2. If occupied, search outward in both directions
3. Return first available position meeting minimum spacing requirements

**Spacing Rules:**

- Minimum: 80px (hard constraint)
- Base: 180px (default)
- Dynamic: `baseSpacing * expansionFactor^(log10(nodeCount/10 + 1))`
  - Spacing increases gradually as tree grows
  - Prevents overcrowding in large trees

#### Step 4.3: Local Realignment

After placing each node, perform targeted realignment:

#### A. Realign Parents Above New Child

```swift

func realignLocalParentsOnly(forNewlyPlaced childId: String)

```

If newly placed node is a child:

1. Find both parents (if placed)
2. Calculate centroid of all their children
3. Reposition parents to be centered above children
4. Maintain spouse spacing between parents

#### B. Realign Parent Couple Above Children

```swift

func realignParentCoupleAboveChildren(forNewlyPlaced parentId: String)

```

If newly placed node is a parent with children:

1. Find parent's spouse (if placed)
2. Find all children of the couple
3. Center both parents above children
4. Preserve spouse spacing

#### C. Realign Siblings Under Parents

```swift

func realignSiblingsUnderParents(forNewlyPlaced siblingId: String)

```

If newly placed node is a sibling:

1. Find all placed siblings
2. Find parents (if placed)
3. Sort siblings by age
4. Redistribute siblings horizontally, centered under parents
5. Maintain consistent spacing between siblings

### Phase 5: Global Realignment

```swift

func realignGroups()

```

After all nodes placed, perform comprehensive realignment:

**Actions:**

1. Group nodes by generation (Y coordinate)
2. Within each generation:
   - Group married couples
   - Group siblings under same parents
3. For each group:
   - Recalculate optimal center point
   - Adjust positions to balance around center
   - Maintain spacing constraints

**Parent-Child Centering:**

```swift

func realignGeneration(_ generation: Int)

```

For each family unit:

1. Calculate centroid of children: `childCentroid = Σ(childX) / childCount`
2. Calculate centroid of parents: `parentCentroid = Σ(parentX) / parentCount`
3. Apply centering: `parentX += (childCentroid - parentCentroid)`
4. Repeat for grandparents, great-grandparents, etc.

### Phase 6: Dynamic Spacing Adjustment

```swift

func adjustDynamicSpacing()

```

**Purpose:** Expand spacing if nodes are too crowded

**Process:**

1. Detect overlaps or near-overlaps (< minSpacing)
2. Calculate required expansion: `targetSpacing = minSpacing * expansionFactor`
3. Redistribute nodes horizontally within each generation
4. Preserve relative ordering and family groupings

**Expansion Formula:**

```swift

newX = centerX + (oldX - centerX) * scaleFactor
where scaleFactor = targetSpacing / currentSpacing

```

## Incremental Animation

The algorithm supports incremental rendering for smooth animations:

```swift

func layoutNodesIncremental(language: Language) -> [[NodePosition]]

```

**Returns:** Array of layout snapshots, one per placed node

**Usage:**

```swift

let steps = layoutManager.layoutNodesIncremental(language: .english)
for step in steps {
    // Render current layout state
    // Animate transition from previous state
    // Step contains all currently placed nodes
}

```

**Benefits:**

- Users see tree build progressively (root → immediate family → extended family)
- Smooth animations as each node appears
- Visual feedback for large trees (100+ members)

## Coordinate System

### Tree Space vs Screen Space

The algorithm operates in **tree space** (abstract layout coordinates):

- Origin: Root contact position
- Units: Logical spacing units (not pixels)
- Independent of viewport zoom/pan

Conversion to screen space:

```swift

screenX = treeX * scale + offsetX + viewportCenterX
screenY = treeY * scale + offsetY + viewportCenterY

```

### Generation-Based Y Coordinates

```text
Generation +2: Great-grandparents  (y = +400)
Generation +1: Grandparents        (y = +200)
Generation  0: Root + Siblings     (y = 0)
Generation -1: Children            (y = -200)
Generation -2: Grandchildren       (y = -400)
```

Vertical spacing (`verticalSpacing = 200`) is constant and configurable.

## Performance Characteristics

### Time Complexity

- **Priority Queue Build:** O(n log n) where n = number of members
- **Node Placement:** O(n) iterations
  - Position calculation: O(1) with precomputed relationships
  - Collision check: O(k) where k = nodes at same Y (typically k << n)
  - Local realignment: O(f) where f = family size (typically f < 10)
- **Global Realignment:** O(n)
- **Dynamic Spacing:** O(n)

**Overall:** O(n log n) dominated by priority queue sorting

### Space Complexity

- **Placed Nodes:** O(n) - stores all node positions
- **Occupied Positions:** O(n) - tracks occupied (x, y) pairs
- **Priority Queue:** O(n) - stores pending members
- **Degree Map:** O(n) - precomputed degrees

**Total:** O(n)

### Incremental Rendering

- **Steps:** O(n) - one step per node
- **Each Step:** O(n) - full snapshot of placed nodes
- **Total:** O(n²) space for all steps (acceptable for trees < 200 nodes)

**Optimization:** Steps could be compressed to store only deltas, reducing to O(n) space.

## Configuration Parameters

### Spacing Parameters

```swift

struct LayoutConfiguration {
    var baseSpacing: CGFloat = 180        // Horizontal spacing between unrelated nodes
    var spouseSpacing: CGFloat = 180      // Horizontal spacing between married couples
    var verticalSpacing: CGFloat = 200    // Vertical spacing between generations
    var minSpacing: CGFloat = 80          // Minimum spacing (collision threshold)
    var expansionFactor: CGFloat = 1.15   // Growth rate for dynamic spacing
}

```

**Tuning Guidelines:**

- **Small Trees** (< 20 members): Use default or compact spacing
- **Medium Trees** (20-50 members): Use default spacing
- **Large Trees** (50-100 members): Increase baseSpacing to 240px
- **Very Large Trees** (100+ members): Consider virtualization (future work)

### Language Parameter

The `language` parameter affects relationship labels but not positioning:

```swift
layoutManager.layoutNodes(language: .hindi)  // Uses Hindi labels
```

Languages supported: English, Hindi, Spanish, French (extensible via `RelationshipLocalizer`)

## Edge Cases & Handling

### Disconnected Components

**Problem:** Member not connected to root (orphaned subgraph)

**Handling:**

1. Place orphaned members using fallback strategy
2. Position near bottom of tree (high negative Y)
3. Log warning for user attention

### Complex Families

**Multiple Marriages:**

- Each spouse gets separate position
- Children linked to biological parents
- Step-relationships handled via relationship calculator

**Missing Parents:**

- Child placed based on known parent
- Virtual placeholder for missing parent (optional)

**Adoptive Relationships:**

- Treated identically to biological relationships
- No visual distinction (by design - family is family)

## Testing Strategy

### Unit Tests

1. **Priority Calculation:**
   - Verify degree-based priority
   - Verify relationship bonuses
   - Test edge cases (self, disconnected)

2. **Placement Logic:**
   - Test each placement strategy (spouse, child, parent, sibling, fallback)
   - Verify collision avoidance
   - Test dynamic spacing

3. **Realignment:**
   - Test parent-child centering
   - Test sibling ordering by age
   - Test generation-based grouping

4. **Edge Cases:**
   - Empty member list
   - Single member
   - Disconnected subgraphs
   - Circular relationships (should not occur with proper data)

### Integration Tests

1. **Known Family Structures:**
   - Nuclear family (parents + children)
   - Three-generation family
   - Extended family with aunts/uncles
   - Complex family (multiple marriages, step-children)

2. **VCF Test Files:**
   - `nuclear_family.vcf` (5 members)
   - `three_generations.vcf` (15 members)
   - `extended_family.vcf` (30 members)
   - `complex_family.vcf` (50 members with multiple marriages)

### Visual Regression Tests

1. Render known family structures
2. Compare against golden images
3. Detect unintended layout changes

## Future Enhancements

### Performance Optimizations

1. **Lazy Evaluation:** Compute positions on-demand rather than all upfront
2. **Step Compression:** Store deltas instead of full snapshots
3. **Virtualization:** Only render visible nodes (viewport culling)
4. **WebAssembly:** Offload layout calculation to high-performance WASM module

### Algorithm Improvements

1. **Force-Directed Layout:** Use physics simulation for organic layouts
2. **Minimize Edge Crossings:** Adjust node order to reduce connection overlaps
3. **Aspect Ratio Optimization:** Minimize tree width-to-height ratio
4. **Subtree Compaction:** Collapse/expand subtrees on-demand

### User Customization

1. **Manual Positioning:** Allow users to drag nodes
2. **Layout Styles:** Hierarchical, radial, timeline-based
3. **Relationship Filters:** Show only maternal/paternal side
4. **Generation Emphasis:** Highlight specific generations

## References

### Academic Papers

- **"Drawing Family Trees" (Marriott et al., 2009)**
  - Survey of family tree layout algorithms
  - Comparison of aesthetic criteria

- **"Improved Algorithms for Drawing Trees" (Reingold & Tilford, 1981)**
  - Classic tree layout algorithm
  - Influences our parent-child centering approach

### Related Algorithms

- **Sugiyama Framework:** Hierarchical graph layout
- **Buchheim-Junger-Leipert:** Linear-time tree layout
- **Force-Directed Placement:** Graph layout via physics simulation

### Implementation Notes

- **SwiftUI Integration:** Layout calculation separate from rendering
- **Reactive Updates:** Layout recalculated on data/configuration changes
- **Thread Safety:** Layout manager is not thread-safe (single-threaded by design)
- **Memory Management:** All structures use value types where possible

---

*Last Updated: 2025-11-11*
*Algorithm Version: 1.0*
*Complexity: O(n log n) time, O(n) space*
