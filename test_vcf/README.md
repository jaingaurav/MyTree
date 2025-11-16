# Test VCF Files

This directory contains test VCF files for validating the MyTree layout algorithm and rendering behavior.

## Test Files

### 1. `nuclear_family.vcf` (5 members)

**Purpose:** Test basic nuclear family layout
**Structure:**

- 2 parents (Root + Spouse)
- 3 children (different ages for sibling ordering)

**Tests:**

- Spouse placement adjacent to root
- Children positioned below parents
- Sibling age-based ordering (older left, younger right)

**Expected Layout:**

```text
Root  Spouse
  |     |
OlderChild  MiddleChild  YoungerChild
```

### 2. `three_generations.vcf` (9 members)

**Purpose:** Test three-generation vertical layout
**Structure:**

- 4 grandparents (2 paternal, 2 maternal)
- 2 parents (Root + Spouse)
- 3 children

**Tests:**

- Multi-generation vertical spacing
- Grandparent positioning above parents
- Parent centering above children

**Expected Layout:**

```text
Paternal    PaternalSpouse    Maternal    MaternalSpouse
         \        |              |          /
               Root  RootSpouse
                 |       |
        FirstChild  SecondChild  ThirdChild
```

### 3. `siblings_test.vcf` (7 members)

**Purpose:** Test sibling ordering algorithm
**Structure:**

- 2 parents
- 5 siblings with different birth dates

**Tests:**

- Age-based sibling ordering
- Sibling spacing consistency
- Centering siblings under parents

**Expected Order (left to right):**

- OldestSibling (1976)
- SecondOldest (1978)
- MiddleSibling (1980)
- SecondYoungest (1983)
- YoungestSibling (1985)

### 4. `extended_family.vcf` (16 members)

**Purpose:** Test extended family with aunts/uncles/cousins
**Structure:**

- 4 grandparents
- 2 parents
- 2 children
- 1 paternal uncle + spouse
- 1 maternal aunt + spouse
- 4 cousins (2 paternal, 2 maternal)

**Tests:**

- Uncle/aunt positioning (same generation as parents)
- Cousin positioning (same generation as children)
- Paternal vs maternal side separation
- Family grouping (couples + their children)

### 5. `complex_marriage.vcf` (8 members)

**Purpose:** Test multiple marriages and blended families
**Structure:**

- 1 root with 2 spouses (sequential marriages)
- 2 children from first marriage
- 2 children from second marriage
- 1 step-child

**Tests:**

- Multiple spouse handling
- Half-sibling relationships
- Step-child positioning
- Blended family visualization

**Challenge:** How to position both spouses? Options:

- Show only current spouse
- Show both with visual distinction
- Position sequentially

### 6. `single_person.vcf` (1 member)

**Purpose:** Test minimal edge case
**Structure:**

- Single person with no relatives

**Tests:**

- Handles empty relationship graph
- Root-only rendering
- No crashes with minimal data

**Expected Layout:**

```text
OnlyPerson
```

### 7. `large_family.vcf` (24 members)

**Purpose:** Test performance and layout quality with larger tree
**Structure:**

- 4 generations (great-grandparents → grandchildren)
- Multiple siblings at each level
- Uncles, aunts, cousins, nephews, nieces

**Tests:**

- Dynamic spacing expansion
- Performance with 20+ nodes
- Layout balance and symmetry
- Generation alignment

## Usage

### With Headless Renderer

```bash
# Test specific VCF file
./build/Build/Products/Release/MyTree.app/Contents/MacOS/MyTree \
  --headless \
  --vcf test_vcf/nuclear_family.vcf \
  --root-name "Root RootPerson" \
  --degree 2 \
  --output test_nuclear.png

# Test all files in sequence
for vcf in test_vcf/*.vcf; do
  name=$(basename "$vcf" .vcf)
  ./build/MyTree.app/Contents/MacOS/MyTree \
    --headless \
    --vcf "$vcf" \
    --degree 3 \
    --output "test_output_${name}.png"
done
```

### With UI (Interactive Testing)

1. Launch MyTree application
2. File → Import → Select test VCF
3. Verify layout visually
4. Adjust degree of separation
5. Check animations and transitions

## Validation Criteria

### Layout Correctness

- ✅ Spouses appear adjacent (same Y coordinate)
- ✅ Children appear below parents (negative Y direction)
- ✅ Parents appear above children (positive Y direction)
- ✅ Siblings ordered by age (left = older, right = younger)
- ✅ Generations aligned horizontally (same Y for same generation)
- ✅ No node overlaps (minimum spacing maintained)
- ✅ Family groups centered (parents above children)

### Performance

- ✅ Layout completes in < 100ms for small trees (< 10 members)
- ✅ Layout completes in < 500ms for medium trees (10-30 members)
- ✅ Layout completes in < 2s for large trees (30-100 members)
- ✅ No memory leaks
- ✅ Smooth animations (60 FPS)

### Visual Quality

- ✅ Balanced tree (not heavily skewed left/right)
- ✅ Adequate spacing (not cramped, not too sparse)
- ✅ Clear visual hierarchy (generations distinguishable)
- ✅ Relationship lines don't obscure nodes
- ✅ Text labels readable at default zoom

## Automated Testing

### Unit Tests

```swift
func testNuclearFamilyLayout() {
    let parser = VCFParser()
    let result = parser.parseVCF(at: "test_vcf/nuclear_family.vcf")
    // Assert layout properties
}
```

### Visual Regression Tests

```swift
func testNuclearFamilyRendering() throws {
    let image = renderTreeFromVCF("test_vcf/nuclear_family.vcf")
    let golden = loadGoldenImage("nuclear_family_golden.png")
    XCTAssertImagesEqual(image, golden, tolerance: 0.01)
}
```

## Contributing New Test Files

When adding new test VCF files:

1. Use descriptive filenames (e.g., `multiple_marriages_complex.vcf`)
2. Use test-describing names for contacts (not realistic names)
3. Include BDAY fields for age-based sorting
4. Document the test purpose in this README
5. Keep files focused (test one scenario per file)
6. Include both simple and complex variants

## Notes

- All VCF files use VERSION:3.0 (standard vCard format)
- Birth dates are used for sibling ordering (SiblingAgeComparator)
- Family names group related members (e.g., all "Large" family)
- Given names describe the role (e.g., "Root", "Spouse", "OlderChild")
- No photos included (keeps files small and focused on structure)
