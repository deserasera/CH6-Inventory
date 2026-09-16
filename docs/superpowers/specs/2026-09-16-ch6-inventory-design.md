# CH6 Inventory Design Specification

## Goal

Build the four-frame CH6 Inventory experience from Figma as a functional SwiftUI app, preserving its icy visual language, motion-driven welcome flow, product filtering, scroll-responsive inventory header, and animated product details.

## Source of Truth

- Figma file: `CH6 Inventory` (`0BrPxFxAgsokbBU6qSUnPF`)
- Loading/Welcome Page: `63:4686`
- Main Page: `51:3122`
- Main Page (Scrolled): `66:5134`
- Product Details Page: `59:4425`
- Target canvas: iPhone, 402 x 874 points
- Existing Xcode project: blank SwiftUI starter with `ContentView` as its root

Figma screenshots are the visual source of truth. Generated React/Tailwind is structural reference only and must be translated into idiomatic SwiftUI.

## Product Flow

The app opens on the welcome screen on every launch. One cosmetic product block is generated for every product currently in the inventory and floats over the stacked `IN / VEN / TORY` title and snow background. The count label uses the live inventory count. The user starts an upward drag in the bottom interaction region around the chevron. A sufficiently intentional upward swipe transitions to the inventory; incomplete drags spring back.

During entry, the welcome content travels upward while the shared snow background moves downward toward its Main Page resting position. Selecting a product in the inventory pushes Product Details. During that transition, the snow background moves upward and becomes softer and more prominent behind the hero product. Back navigation reverses the motion.

## Architecture

Use pure SwiftUI with no third-party dependencies. `ContentView` owns the launch-phase state and presents a `NavigationStack`. Feature views remain focused:

- `WelcomeView`: layered title, product-block physics, swipe affordance, and entry transition.
- `InventoryView`: header, filters, searchable two-column grid, scroll-state adaptation, and product navigation.
- `ProductDetailsView`: product hero, status, animated shelf-life bar, date facts, and reminder picker.
- Reusable presentation pieces: shared background, glass product block, filter chip, product card, and expiry bar.

An `@Observable` inventory store owns products, search text, and the selected filter. The welcome physics state stays local to `WelcomeView` because it is transient presentation state. Navigation passes stable `Product.ID` values and resolves them through the store.

## Data Model and Rules

Each product contains a stable ID, brand, name, asset name, opened date, period-after-opening in months, printed expiration date, and usage state. The effective expiration date is the earlier of the printed date and opened date plus PAO when the item is in use; unopened/not-in-use products use the printed expiration date.

Derived values:

- `daysRemaining`: calendar-day distance from the injected reference date to effective expiration.
- `isExpiringSoon`: true when `daysRemaining` is 180 or fewer and nonnegative.
- `shelfLifeProgress`: remaining duration divided by total tracked duration, clamped to `0...1`.
- Filters: All, Not in use, and Expiring soon.
- Search matches brand or product name case-insensitively and combines with the active filter.

Seed eight products matching the Figma content: Laneige Lip Sleeping Mask Ex, Kiehl's Dark Spot Solution, SK-II Facial Treatment Cleansing Oil, Kiehl's Calendula Serum Cream, Estee Lauder Night Repair Serum, SK-II Facial Cleanser, plus repeated catalog entries represented in the design. At least two are expiring soon and at least two are not in use so every filter has visible results. Expiring-soon cards show the red remaining-days flag.

Dates are generated relative to a single sample-data reference date so the demo remains meaningful instead of becoming stale.

## Visual System

- Background gradient: `#68A4D3` to `#D8E6F2`.
- Deep blue foreground: `#174871`; selected control blue: `#316C9B`; warning accent: `#CC4A53`.
- Use SF Pro through semantic SwiftUI fonts where possible. Preserve the oversized welcome display title as a scaled system bold face.
- Download and commit the exact snow and product PNG assets returned by Figma; do not depend on expiring MCP URLs at runtime.
- Use system SF Symbols for `chevron.up`, `chevron.left`, `plus`, `magnifyingglass`, `mic.fill`, `bell`, and `chevron.up.chevron.down`.
- Use native Liquid Glass APIs for custom interactive surfaces where supported, grouped in as few `GlassEffectContainer`s as practical. Standard controls receive their system glass treatment without a second glass layer.
- Keep the interface light-only to match the supplied frames.

## Welcome Motion and Physics

Render a dynamic number of product blocks using a small deterministic SwiftUI physics engine driven by `TimelineView(.animation)`. The bodies are keyed by stable product IDs, so inserting or removing inventory items adds or removes exactly one corresponding block without resetting the others. Each body stores position, velocity, angle, and angular velocity. Per frame:

1. Integrate velocity with low gravity and gentle drift.
2. Apply damping.
3. Resolve collisions against safe-area bounds.
4. Resolve approximate circle collisions between blocks.
5. Clamp delta time to avoid jumps after app suspension.

For the eight-item seed data, initial positions and angles match the Figma composition. Additional products receive deterministic seeded positions within safe bounds; smaller collections use the matching prefix of the composition while keeping a balanced spread. A fixed seed derived from each stable product ID keeps previews and UI tests repeatable. Blocks remain decorative and do not intercept the entry gesture. Empty inventory shows the title, `0 items`, and swipe affordance without product blocks.

The title is rendered twice: a white-to-transparent base gradient and a low-opacity blue/glass highlight layer, producing the Figma `Text_Base` and `Text_Glass Effect` icy appearance.

The entry gesture only activates when its start point is within the bottom 150 points. Progress follows the upward drag and completes when translation exceeds 110 points or predicted translation exceeds 170 points. Completion uses a smooth spring; cancellation returns to zero. Reduce Motion disables continuous block physics and replaces the transition with a short opacity/vertical movement.

## Inventory Interaction

The inventory uses a vertical `ScrollView` with a lazy two-column grid. The expanded header contains the 34-point uppercase title, item count, and horizontally scrollable filter chips. Search and add controls remain pinned near the bottom safe area in a glass container.

Scroll geometry drives a normalized collapse progress. Between the Figma Main and Scrolled states:

- Large title and filter row fade and move away.
- A compact centered `Inventory` title and item count appear beneath the status bar.
- Grid content moves from its expanded top inset to the compact position without snapping.
- The compact header receives the blue blurred scroll-edge treatment shown in Figma.

Filtering and search animate grid insertions/removals with stable product identity. Tapping any card opens its real details. The add control is present and accessible but does not create an unrequested product-editing subsystem.

## Product Details Motion

Use a navigation destination with system back behavior and a trailing Edit glass button. The background rises behind the product and uses a stronger blur. The hero image enters with spring scale/vertical movement and settles above its soft shadow.

The expiry bar animates from zero to `shelfLifeProgress` when the screen appears. The fill uses deep blue, clips to a capsule, and carries the remaining-days label when space permits. Its animation combines a smooth width reveal, a subtle highlight sweep, and a single low-amplitude spring settle; it must not loop indefinitely. The three information cards and reminder row use translucent rounded surfaces matching Figma.

Reminder choices are None, On expiration day, 1 day before, 1 week before, and 1 month before. This build stores the selection in memory and does not request notification permission because notification scheduling is not represented in the supplied flow.

## Accessibility and Adaptation

- Every product image has a meaningful accessibility label; decorative snow and title highlight layers are hidden from accessibility.
- Product cards expose brand, name, status, and remaining days as one element.
- Filter chips expose selected state.
- Swipe-up entry also provides an accessibility action and a tappable chevron fallback.
- Dynamic Type is supported for functional text; the decorative welcome title scales only within safe bounds.
- Reduce Motion freezes drifting blocks and simplifies transitions and the expiry animation.
- Layout supports the 402 x 874 reference and adapts down to compact iPhone widths without horizontal clipping.

## Testing and Validation

Use Swift Testing for deterministic model behavior:

- effective expiration chooses the correct date;
- days remaining uses calendar days;
- expiring-soon boundary behavior;
- progress clamps below zero and above one;
- filters and search compose correctly;
- seed data populates every required filter.
- welcome physics creates exactly one stable body per inventory product and reconciles insertions/removals without resetting retained bodies.

Add focused UI tests only if a UI-test target already exists; otherwise validate interaction using simulator runs and screenshots. Build the project after each implementation slice, use Xcode diagnostics for changed files, and visually compare all four states against Figma. Validate normal and Reduce Motion behavior.

## Out of Scope

- Persistent database or cloud synchronization
- Product creation/editing flows
- Camera or barcode scanning
- Real notification authorization and scheduling
- iPad-specific redesign
- Dark mode design not supplied in Figma
