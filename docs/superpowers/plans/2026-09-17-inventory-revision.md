# CH6 Inventory Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing prototype into a persistent inventory with photo-based product creation, expiration-first sorting, confirmed long-press deletion, the approved Figma detail design, an adjustable blurred card footer, and marble-like collision audio.

**Architecture:** Use a SwiftData `Product` model as the single source of truth, with bundled asset names for seeded samples and externally stored `Data` for user photos. Query products at the inventory root, derive searched/filtered/sorted results in pure model helpers, and share one product-image renderer across welcome, cards, and details. Present product creation as a native form sheet and isolate camera capture in a small UIKit bridge.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PhotosUI, UIKit camera picker, AVFoundation, Testing, XCUIAutomation, iOS 27.

**Spec:** `docs/superpowers/specs/2026-09-17-inventory-revision-design.md`

## Global Constraints

- Preserve all pre-existing uncommitted visual, asset, physics, audio, and test changes.
- Do not add third-party dependencies.
- Match Figma file `0BrPxFxAgsokbBU6qSUnPF`, frame `59:4425`, using idiomatic native SwiftUI.
- Persist added products and imported photos locally across launches.
- Support both camera capture and photo-library selection.
- Sort visible inventory products by effective expiration date ascending, then brand, then product name.
- Confirm destructive deletion after the user chooses Delete from a long-press context menu.
- Comment meaningful UI sections and reusable controls, not individual obvious modifiers.
- Keep Edit and Reminder behavior presentational; scheduling notifications and editing products are out of scope.
- Preserve Reduce Motion and current accessibility behavior.

---

### Task 1: Persistent Product Model and Expiration-First Ordering

**Files:**
- Modify: `CH6 Inventory/InventoryModel.swift:1-111`
- Modify: `CH6 Inventory/MyApp.swift:1-10`
- Modify: `CH6 Inventory/ContentView.swift:1-43`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Produces: `@Model final class Product`, `Product.visibleProducts(_:filter:searchText:referenceDate:) -> [Product]`, `Product.seedSamplesIfNeeded(in:referenceDate:) throws`, and a SwiftData model container in `MyApp`.
- Consumes: Existing expiration calculations and bundled sample catalog.

- [ ] **Step 1: Add failing in-memory persistence and sorting tests**

Add test helpers that create an in-memory `ModelContainer` and tests with three products whose effective expiration dates are out of order. Assert that `visibleProducts` returns ascending effective expiration order and uses localized brand/name comparison for equal dates. Add a seed test that calls `seedSamplesIfNeeded` twice and asserts exactly eight records.

```swift
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Product.self, configurations: configuration)
}

@Test func visibleProductsSortByEffectiveExpirationThenName() throws {
    let reference = date(2026, 1, 1)
    let late = Product.fixture(brand: "Zeta", name: "Late", expiration: date(2026, 6, 1))
    let earlyB = Product.fixture(brand: "Beta", name: "Early", expiration: date(2026, 2, 1))
    let earlyA = Product.fixture(brand: "Alpha", name: "Early", expiration: date(2026, 2, 1))

    let result = Product.visibleProducts(
        [late, earlyB, earlyA],
        filter: .all,
        searchText: "",
        referenceDate: reference
    )

    #expect(result.map(\.id) == [earlyA.id, earlyB.id, late.id])
}

@Test func sampleSeedingIsIdempotent() throws {
    let container = try makeContainer()
    try Product.seedSamplesIfNeeded(in: container.mainContext, referenceDate: date(2026, 9, 17))
    try Product.seedSamplesIfNeeded(in: container.mainContext, referenceDate: date(2026, 9, 17))
    #expect(try container.mainContext.fetchCount(FetchDescriptor<Product>()) == 8)
}
```

- [ ] **Step 2: Run the unit-test target and verify the new tests fail**

Run the `MyAppUnitTests` target in Xcode. Expected failures: `Product` is not a SwiftData model and the new helpers do not exist.

- [ ] **Step 3: Convert Product to a SwiftData model and centralize visible ordering**

Import SwiftData. Preserve existing field names, make `assetName` optional, and add externally stored photo data.

```swift
@Model
final class Product {
    @Attribute(.unique) var id: UUID
    var brand: String
    var name: String
    var assetName: String?
    @Attribute(.externalStorage) var photoData: Data?
    var openedDate: Date?
    var periodAfterOpeningMonths: Int
    var printedExpirationDate: Date
    var isInUse: Bool

    init(
        id: UUID = UUID(),
        brand: String,
        name: String,
        assetName: String? = nil,
        photoData: Data? = nil,
        openedDate: Date?,
        periodAfterOpeningMonths: Int,
        printedExpirationDate: Date,
        isInUse: Bool
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.assetName = assetName
        self.photoData = photoData
        self.openedDate = openedDate
        self.periodAfterOpeningMonths = periodAfterOpeningMonths
        self.printedExpirationDate = printedExpirationDate
        self.isInUse = isInUse
    }
}
```

Implement `visibleProducts` by filtering search/filter matches, then sorting with effective expiration first and deterministic localized brand/name tie-breakers. Implement idempotent seeding with a fetch-count guard followed by insertions and `context.save()`.

- [ ] **Step 4: Install the model container and seed on app startup**

Attach `.modelContainer(for: Product.self)` to `WindowGroup`. In `ContentView`, read `modelContext`, run `Product.seedSamplesIfNeeded(in:)` once from `.task`, store any thrown localized message in optional state, and present it with an **Inventory Unavailable** alert rather than crashing.

- [ ] **Step 5: Run model tests and verify they pass**

Run `MyAppUnitTests`. Expected: persistence, seed, filter, sort, and expiration tests pass.

- [ ] **Step 6: Commit the persistent model slice**

```bash
git add 'CH6 Inventory/InventoryModel.swift' 'CH6 Inventory/MyApp.swift' 'CH6 Inventory/ContentView.swift' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: persist inventory products with SwiftData'
```

---

### Task 2: Shared Bundled and User Photo Rendering

**Files:**
- Create: `CH6 Inventory/ProductImageView.swift`
- Modify: `CH6 Inventory/WelcomeView.swift`
- Modify: `CH6 Inventory/ProductCard.swift`
- Modify: `CH6 Inventory/ProductDetailsView.swift`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Consumes: `Product.assetName: String?`, `Product.photoData: Data?`.
- Produces: `ProductImageSource`, `Product.imageSource`, and `ProductImageView(product:contentMode:)`.

- [ ] **Step 1: Add failing image-source selection tests**

```swift
@Test func importedPhotoTakesPriorityOverBundledAsset() {
    let bytes = Data([0x01, 0x02])
    let product = Product.fixture(assetName: "sample", photoData: bytes)
    #expect(product.imageSource == .photoData(bytes))
}

@Test func bundledAssetIsUsedWithoutPhotoData() {
    let product = Product.fixture(assetName: "sample", photoData: nil)
    #expect(product.imageSource == .asset("sample"))
}
```

- [ ] **Step 2: Run tests and confirm missing image-source failures**

Run `MyAppUnitTests`. Expected: `ProductImageSource` and `imageSource` are unresolved.

- [ ] **Step 3: Implement the source enum and shared view**

Define an equatable source enum with `.photoData(Data)`, `.asset(String)`, and `.placeholder`. Decode user images safely and render a `photo` SF Symbol fallback when decoding fails. Keep resizing and content mode inside the shared view while leaving frame sizes to callers.

- [ ] **Step 4: Replace direct product `Image(assetName)` calls**

Use `ProductImageView` in welcome blocks, product cards, and product details. Add concise comments above each product-image region. Preserve the existing accessibility labels and hidden decorative-image behavior.

- [ ] **Step 5: Run tests and refresh diagnostics for all four changed view files**

Expected: tests pass and Xcode reports no file diagnostics.

- [ ] **Step 6: Commit the shared image slice**

```bash
git add 'CH6 Inventory/ProductImageView.swift' 'CH6 Inventory/WelcomeView.swift' 'CH6 Inventory/ProductCard.swift' 'CH6 Inventory/ProductDetailsView.swift' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: render persisted product photos'
```

---

### Task 3: Native Add Product Form with Camera and Photo Library

**Files:**
- Create: `CH6 Inventory/AddProductView.swift`
- Create: `CH6 Inventory/CameraPicker.swift`
- Modify: `CH6 Inventory/InventoryView.swift`
- Modify: `CH6 Inventory.xcodeproj/project.pbxproj:360-420`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Consumes: SwiftData `ModelContext`, shared `ProductImageView` image conventions.
- Produces: `AddProductDraft`, `AddProductDraft.isValid`, `AddProductDraft.makeProduct(photoData:)`, `AddProductView`, and `CameraPicker`.

- [ ] **Step 1: Add failing draft-validation tests**

Test empty brand/name, missing photo, an in-use product without an opened date, and a fully valid draft. Test that whitespace is trimmed when `makeProduct` constructs the model.

```swift
@Test func addDraftRequiresIdentityPhotoAndOpenedDateWhenInUse() {
    var draft = AddProductDraft()
    #expect(!draft.isValid(hasPhoto: false))
    draft.brand = " Laneige "
    draft.name = " Mask "
    draft.isInUse = true
    #expect(!draft.isValid(hasPhoto: true))
    draft.openedDate = date(2026, 9, 1)
    #expect(draft.isValid(hasPhoto: true))
}
```

- [ ] **Step 2: Run tests and confirm the draft type is missing**

Run `MyAppUnitTests`. Expected: compilation fails because `AddProductDraft` is undefined.

- [ ] **Step 3: Implement draft state and validation**

Create a value-type draft with brand, name, `isInUse`, optional opened date, PAO months defaulting to 12, and printed expiration. Keep validation pure and independently testable.

- [ ] **Step 4: Implement native photo acquisition**

Use `PhotosPickerItem.loadTransferable(type: Data.self)` asynchronously for library selection. Implement `CameraPicker: UIViewControllerRepresentable` around `UIImagePickerController`, returning JPEG data through a closure. Guard `UIImagePickerController.isSourceTypeAvailable(.camera)` and dismiss cleanly on cancel.

- [ ] **Step 5: Implement the add sheet**

Build `AddProductView` as `NavigationStack { Form { ... } }` with commented UI sections for photo, identity, usage, shelf life, and dates. Use cancellation and confirmation toolbar placements, an action menu for camera/library, a loading indicator during transfer, and alerts for photo/save failures. Insert, save, and dismiss only after a successful context save.

- [ ] **Step 6: Present the sheet from InventoryView**

Replace the informational alert state with `showAddProduct`, and present `AddProductView` using `.sheet(isPresented:)`. Keep the existing plus button appearance and accessibility label.

- [ ] **Step 7: Add the generated Info.plist camera usage description**

Add `INFOPLIST_KEY_NSCameraUsageDescription = "Take a photo of a product to add it to your inventory.";` to both Debug and Release app-target build settings only.

- [ ] **Step 8: Run validation tests, refresh diagnostics, and build**

Expected: draft tests pass, new files have no diagnostics, and the project builds with camera privacy configuration.

- [ ] **Step 9: Commit the add-product flow**

```bash
git add 'CH6 Inventory/AddProductView.swift' 'CH6 Inventory/CameraPicker.swift' 'CH6 Inventory/InventoryView.swift' 'CH6 Inventory.xcodeproj/project.pbxproj' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: add products with camera or library photos'
```

---

### Task 4: Persistent Inventory Query, Sorting, and Confirmed Long-Press Deletion

**Files:**
- Modify: `CH6 Inventory/ContentView.swift`
- Modify: `CH6 Inventory/InventoryView.swift`
- Modify: `CH6 Inventory/InventoryModel.swift`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Consumes: `Product.visibleProducts`, SwiftData `ModelContext`, `AddProductView`.
- Produces: query-driven inventory presentation and `deleteProduct(_:)` behavior.

- [ ] **Step 1: Add a failing persistent deletion test**

Insert a product into an in-memory context, save, delete it, save again, and assert the fetch count is zero. Keep this model-context test independent of view gestures.

- [ ] **Step 2: Run tests and verify the new persistence behavior is exercised**

Expected: the test exposes any missing save/delete helper contract.

- [ ] **Step 3: Replace InventoryStore ownership with a SwiftData query**

Move search text and selected filter into `InventoryView` state. Read products with `@Query`, compute `visibleProducts` through the pure helper, and pass persisted products to welcome/details navigation. Keep navigation by UUID and handle a missing product with `ContentUnavailableView` rather than an empty destination.

- [ ] **Step 4: Add context-menu deletion and confirmation**

Attach a context menu to each navigation link/card with a destructive Delete button. Store the pending product, show `confirmationDialog`, name the product in the prompt, and delete/save on confirmation. Present save errors with an alert and clear pending state deterministically.

- [ ] **Step 5: Verify expiration-first ordering after filters and search**

Run unit tests and use an Xcode preview or simulator with sample dates. Expected: the 75-day item precedes the 105-day and 144-day items; search and filters retain the same ordering.

- [ ] **Step 6: Commit the inventory mutation slice**

```bash
git add 'CH6 Inventory/ContentView.swift' 'CH6 Inventory/InventoryView.swift' 'CH6 Inventory/InventoryModel.swift' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: sort and delete persistent inventory items'
```

---

### Task 5: Adjustable Blurred Product-Card Footer

**Files:**
- Modify: `CH6 Inventory/ProductCard.swift`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Consumes: `ProductImageView` and existing blue gradient.
- Produces: named `footerHeight` and `footerBlurRadius` tuning constants and a clipped duplicate-image blur layer.

- [ ] **Step 1: Extract testable blur configuration**

Define internal static constants with positive values and add a small test asserting `footerHeight` is less than card height and `footerBlurRadius` is nonnegative. This prevents accidental invalid tuning values.

- [ ] **Step 2: Remove the footer glass and add duplicated-image blur**

Render the same product image in a bottom-aligned layer using identical image sizing and alignment, apply `.blur(radius: footerBlurRadius)`, then clip it to a bottom rounded rectangle of `footerHeight`. Keep the selected-blue gradient between imagery and text. Do not apply `.glassEffect` or a material to the text container.

- [ ] **Step 3: Refresh diagnostics and visually inspect bundled and imported images**

Expected: only the lower product pixels blur, text remains crisp, corners are clipped, and changing `footerBlurRadius` visibly changes strength.

- [ ] **Step 4: Commit the card treatment**

```bash
git add 'CH6 Inventory/ProductCard.swift' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: blur product imagery beneath card labels'
```

---

### Task 6: Figma-Aligned Product Details Screen

**Files:**
- Modify: `CH6 Inventory/ProductDetailsView.swift`
- Modify: `CH6 Inventory/ExpirationBar.swift`

**Interfaces:**
- Consumes: persistent `Product`, `ProductImageView`, Figma frame `59:4425`.
- Produces: the approved detail hierarchy using native navigation and toolbar behavior.

- [ ] **Step 1: Rebuild the detail hierarchy from the Figma measurements**

Keep the gradient/snow background, then structure the scroll content into commented regions: identity and status, centered hero image, expiration summary, equal fact cards, and reminder row. Match the Figma’s 16-point horizontal inset, 10-point card gaps, 146-point fact-card height, 51-point reminder height, and deep-blue foreground token while allowing vertical flow to adapt to Dynamic Type.

- [ ] **Step 2: Use native navigation chrome**

Keep `.navigationTitle("Product Details")`, inline display mode, native back navigation, and the Edit toolbar button. Do not reproduce the status bar or hand-draw the back button from Figma.

- [ ] **Step 3: Align expiration presentation**

Show **Good to use** leading and the days-remaining caption trailing above the full-width bar. Keep clamped progress and accessibility value in `ExpirationBar`; avoid placing duplicate text inside the bar when the Figma frame shows it above.

- [ ] **Step 4: Refresh diagnostics and compare against the Figma screenshot**

Expected: navigation, identity position, hero scale, expiration region, three cards, and reminder row match frame `59:4425` without fixed full-screen positioning.

- [ ] **Step 5: Commit the detail redesign**

```bash
git add 'CH6 Inventory/ProductDetailsView.swift' 'CH6 Inventory/ExpirationBar.swift'
git commit -m 'feat: align product details with approved Figma design'
```

---

### Task 7: Lower Marble-Like Collision Audio

**Files:**
- Modify: `CH6 Inventory/IceImpactSoundPlayer.swift`
- Test: `MyAppUnitTests/MyAppUnitTests.swift`

**Interfaces:**
- Consumes: collision impact speed from `WelcomePhysicsState`.
- Produces: testable `MarbleImpactProfile` frequency/envelope mapping and lower-frequency PCM synthesis.

- [ ] **Step 1: Add failing profile tests**

Extract pure profile calculation and assert audible impacts remain in a low-mid range, stronger impacts increase frequency and gain, and normalization clamps at both ends.

```swift
@Test func marbleImpactProfileStaysBelowCrystallineRange() {
    let soft = MarbleImpactProfile(impactSpeed: 42)
    let hard = MarbleImpactProfile(impactSpeed: 402)
    #expect(soft.primaryFrequency >= 280)
    #expect(hard.primaryFrequency <= 900)
    #expect(hard.primaryFrequency > soft.primaryFrequency)
    #expect(hard.gain > soft.gain)
}
```

- [ ] **Step 2: Run tests and confirm the profile is missing**

Run `MyAppUnitTests`. Expected: `MarbleImpactProfile` is unresolved.

- [ ] **Step 3: Implement warmer impact synthesis**

Use a fundamental approximately in the 320–720 Hz range, a quieter inharmonic partial, a short low-amplitude noise transient, and a slightly longer resonant decay than the current ice sound. Drive player volume and pitch from the pure profile while preserving the 75 ms throttle and ambient audio session.

- [ ] **Step 4: Run tests and audition in Simulator**

Expected: profile tests pass; impacts sound short, solid, and lower than the previous crystalline chime without clipping or masking other audio.

- [ ] **Step 5: Commit the audio revision**

```bash
git add 'CH6 Inventory/IceImpactSoundPlayer.swift' 'MyAppUnitTests/MyAppUnitTests.swift'
git commit -m 'feat: synthesize marble-like collision impacts'
```

---

### Task 8: Section-Level UI Documentation and Final Verification

**Files:**
- Modify: `CH6 Inventory/AppTheme.swift`
- Modify: `CH6 Inventory/ContentView.swift`
- Modify: `CH6 Inventory/ExpirationBar.swift`
- Modify: `CH6 Inventory/InventoryView.swift`
- Modify: `CH6 Inventory/ProductCard.swift`
- Modify: `CH6 Inventory/ProductDetailsView.swift`
- Modify: `CH6 Inventory/WelcomeView.swift`
- Modify: `CH6 Inventory/ProductImageView.swift`
- Modify: `CH6 Inventory/AddProductView.swift`
- Modify: `CH6 Inventory/CameraPicker.swift`

**Interfaces:**
- Consumes: all completed UI work.
- Produces: concise section comments and a verified build.

- [ ] **Step 1: Audit every SwiftUI file for meaningful UI regions**

Add comments above backgrounds, navigation containers, headers, lists/grids, product imagery, overlays, forms, toolbars, status controls, animation/gesture surfaces, and accessibility groupings. Remove redundant comments that merely restate a modifier name.

- [ ] **Step 2: Refresh Xcode diagnostics for every changed Swift file**

Expected: zero errors. Resolve all new warnings introduced by this branch; do not rewrite unrelated pre-existing code.

- [ ] **Step 3: Run the full unit-test target**

Expected: all persistence, validation, image-source, filtering, sorting, expiration, physics, blur-configuration, and audio-profile tests pass with zero failures.

- [ ] **Step 4: Build the complete project with Xcode**

Expected: successful app and test-target compilation with no build errors.

- [ ] **Step 5: Perform Simulator acceptance checks**

Verify welcome physics and lower impact sound; expiration-first inventory order; search/filter composition; add sheet; library import; camera-unavailable explanation or camera capture on supported hardware; persisted relaunch; long-press menu; named confirmation; deletion persistence; adjustable footer blur; Figma-aligned detail screen; Dynamic Type; VoiceOver labels; and Reduce Motion.

- [ ] **Step 6: Review the branch diff against the specification**

Confirm every requested revision is implemented and no unrelated behavior or generated assets were changed. Pay special attention to preserving the user’s pre-existing dirty-worktree changes.

- [ ] **Step 7: Commit the UI documentation and final adjustments**

```bash
git add 'CH6 Inventory/AppTheme.swift' 'CH6 Inventory/ContentView.swift' 'CH6 Inventory/ExpirationBar.swift' 'CH6 Inventory/InventoryView.swift' 'CH6 Inventory/ProductCard.swift' 'CH6 Inventory/ProductDetailsView.swift' 'CH6 Inventory/WelcomeView.swift' 'CH6 Inventory/ProductImageView.swift' 'CH6 Inventory/AddProductView.swift' 'CH6 Inventory/CameraPicker.swift'
git commit -m 'docs: document SwiftUI layout sections'
```
