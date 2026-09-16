# CH6 Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the four-frame CH6 Inventory SwiftUI app with inventory-driven welcome physics, functional filtering, scroll-responsive layout, navigation, and animated details.

**Architecture:** A root `NavigationStack` owns the welcome-to-inventory phase and an `@Observable` store. Focused SwiftUI views consume stable product values; deterministic pure model types calculate expiry, filtering, and physics state. Figma assets are stored in the asset catalog.

**Tech Stack:** Swift 5, SwiftUI, Observation, Swift Testing, iOS 27 Liquid Glass APIs

**Spec:** `docs/superpowers/specs/2026-09-16-ch6-inventory-design.md`

## Global Constraints

- No third-party dependencies.
- iOS deployment target is 27.0.
- Figma screenshots and exported assets are the visual source of truth.
- One welcome block must exist per inventory product, including zero and non-eight counts.
- Respect Reduce Motion and provide accessible alternatives.
- The workspace has no Git repository, so commit steps are omitted.

---

### Task 1: Inventory domain and unit-test target

**Files:**
- Create: `Untitled Project/MyApp/InventoryModel.swift`
- Create target: `MyAppTests`
- Create: `Untitled Project/MyAppTests/InventoryModelTests.swift`

**Interfaces:**
- Produces: `Product`, `InventoryFilter`, `InventoryStore`, `Product.effectiveExpirationDate`, `Product.daysRemaining(on:)`, `Product.shelfLifeProgress(on:)`, and `InventoryStore.filteredProducts`.

- [ ] Create an iOS unit-test target using Swift Testing.
- [ ] Write failing tests covering effective expiration, 180-day boundary, progress clamping, combined search/filter behavior, and seed coverage.
- [ ] Run `MyAppTests` and verify failures occur because the domain types do not exist.
- [ ] Implement stable `Product.ID`, calendar-based expiry calculations, three filter cases, relative-date seed products, and an `@Observable` store.
- [ ] Run `MyAppTests` and verify all domain tests pass.

### Task 2: Dynamic welcome physics

**Files:**
- Create: `Untitled Project/MyApp/WelcomePhysics.swift`
- Create: `Untitled Project/MyApp/WelcomeView.swift`
- Modify: `Untitled Project/MyAppTests/InventoryModelTests.swift`

**Interfaces:**
- Consumes: `[Product]` from `InventoryStore`.
- Produces: `WelcomePhysicsState.reconcile(products:in:)`, `WelcomeView(products:onComplete:)`.

- [ ] Write failing tests proving zero products creates zero bodies, N products creates N bodies, retained IDs preserve state, and added/removed IDs reconcile independently.
- [ ] Run the tests and verify the reconciliation assertions fail for missing implementation.
- [ ] Implement deterministic bodies keyed by `Product.ID`, seeded Figma positions for the first eight, bounded generated positions thereafter, delta-time clamping, damping, boundary collision, and approximate pair collision.
- [ ] Run the tests and verify physics reconciliation passes.
- [ ] Build `WelcomeView` with the gradient, committed snow asset, layered icy title, dynamic item count, `TimelineView`, and one product block per body.
- [ ] Add the bottom-region upward gesture with completion/cancellation thresholds, tappable chevron fallback, accessibility action, and Reduce Motion behavior.
- [ ] Refresh Xcode diagnostics and build the app.

### Task 3: Inventory grid, filters, and collapsing header

**Files:**
- Create: `Untitled Project/MyApp/InventoryView.swift`
- Create: `Untitled Project/MyApp/ProductCard.swift`
- Create: `Untitled Project/MyApp/AppTheme.swift`

**Interfaces:**
- Consumes: bindable `InventoryStore` and selected product callback.
- Produces: `InventoryView(store:)` and reusable `ProductCard(product:referenceDate:)`.

- [ ] Add a failing store test for a product collection whose count differs from eight and verify item count/filter output remains collection-driven.
- [ ] Implement semantic colors and shared background constants from Figma.
- [ ] Implement the lazy two-column grid with stable product IDs, exact product imagery, warning flags, functional chips, and search.
- [ ] Use scroll geometry to interpolate the expanded title/filter layout into the compact centered title/count from `Main Page (Scrolled)`.
- [ ] Add the bottom search/add glass controls using native Liquid Glass without duplicating system material.
- [ ] Run tests, refresh diagnostics, and build.

### Task 4: Product details and coordinated navigation

**Files:**
- Create: `Untitled Project/MyApp/ProductDetailsView.swift`
- Create: `Untitled Project/MyApp/ExpirationBar.swift`
- Modify: `Untitled Project/MyApp/ContentView.swift`

**Interfaces:**
- Consumes: `Product`, reference date, and store navigation state.
- Produces: complete welcome → inventory → details flow.

- [ ] Write a failing expiry-bar calculation test for zero, partial, and complete fill widths.
- [ ] Implement the clamped fill calculation and verify the test passes.
- [ ] Implement the details hero, usage badge, three information cards, reminder menu, system back behavior, and Edit glass button.
- [ ] Animate background upward, hero entrance, and one-shot expiry fill/highlight/spring; simplify under Reduce Motion.
- [ ] Replace the starter `ContentView` with the root flow and inject one shared `InventoryStore`.
- [ ] Run all tests, refresh diagnostics for every changed Swift file, and build.

### Task 5: Assets and visual verification

**Files:**
- Modify: `Untitled Project/MyApp/Assets.xcassets`
- Modify only if needed after comparison: feature Swift files from Tasks 2-4

**Interfaces:**
- Consumes: Figma MCP asset URLs while valid.
- Produces: bundled snow and product image sets referenced by stable asset names.

- [ ] Download the exact snow background and six unique product PNGs returned by Figma and add correctly scaled image sets.
- [ ] Run the app on an iPhone simulator and capture welcome, expanded inventory, scrolled inventory, and details states.
- [ ] Compare each state to its Figma screenshot and correct only measurable layout, color, clipping, or motion discrepancies.
- [ ] Enable Reduce Motion in the simulator and verify the alternate behavior remains usable.
- [ ] Run all tests and a final clean project build.

