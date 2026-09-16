# CH6 Inventory Revision Design

Date: 2026-09-17
Branch: `feature/inventory-revision`
Figma source: Product Details Page, node `59:4425`

## Goal

Extend the existing SwiftUI skincare inventory prototype into a persistent local inventory. Users can add products with a camera or library photo, delete products from the grid, and view the revised Figma-based product details screen. The revision also replaces the product-card text glass with an adjustable image blur and changes collision audio from an icy chime to a lower marble-like impact.

## Existing Context

The app currently uses an in-memory `InventoryStore`, immutable value-type products, eight bundled samples, ID-based navigation, a custom two-column grid, procedural collision physics and audio, and a four-screen icy visual identity. The add button only displays an informational alert. Edit and reminder controls are presentational. The working tree already contains uncommitted visual, asset, physics, audio, and test changes; implementation must preserve those changes.

## Persistence Architecture

Use SwiftData as the local persistence layer.

- Convert `Product` into a persistent model.
- Persist the stable UUID, brand, name, usage state, optional opened date, PAO months, and printed expiration date.
- Represent product imagery with an optional bundled asset name and optional imported photo data. Imported binary data uses external storage so it does not unnecessarily inflate the primary record.
- Install the model container at the app entry point.
- Seed the bundled sample catalog only when the persistent store is empty.
- Use an in-memory model container in tests.
- Save insertions and deletions explicitly and present recoverable errors to the user.

The inventory screen reads the persistent collection and applies the existing search and filter rules locally. Its visible results are sorted by effective expiration date ascending, placing the soonest-expiring product first. Brand and product name provide deterministic tie-breakers when dates match. The welcome animation, inventory grid, and product details screen use the same persistent products.

## Shared Product Image Rendering

Create a reusable product-image view that accepts a product and renders imported photo data when present, otherwise the bundled image asset. It owns decoding, content mode, and a safe fallback. Inventory cards, the welcome screen, and product details use this shared rendering path so newly added products appear throughout the app.

## Add Product Flow

The plus button presents a native sheet containing a `NavigationStack` and `Form`.

The form contains:

- A prominent product-photo preview.
- A source menu with **Take Photo** and **Choose from Library**.
- Brand and product-name text fields.
- An in-use toggle.
- An opened-date picker shown only when the product is in use.
- A PAO duration control in months.
- A printed-expiration date picker.

Use `PhotosPicker` for the photo library. Use a narrowly scoped `UIImagePickerController` representable for camera capture because SwiftUI does not provide an equivalent still-photo camera picker. When the camera is unavailable, disable or explain that option rather than failing silently.

The confirmation toolbar item uses the native semantic placement and remains disabled until the form has a photo, nonempty brand and name, and valid date information. Photo loading and save failures show an alert while preserving the user’s form values. A successful save inserts the product, saves the model context, and dismisses the sheet.

## Delete Interaction

Long-pressing a product card opens a native context menu with a destructive Delete action. Choosing Delete opens a confirmation dialog that names the product. Confirmation deletes the SwiftData record and saves the context. Cancellation leaves the product unchanged. Deletion errors are surfaced without pretending the action succeeded.

## Product Details Translation

Implement Figma frame `59:4425` using idiomatic SwiftUI rather than copying its absolute React layout.

- Retain native navigation and back-swipe behavior.
- Use an inline **Product Details** navigation title and native Edit toolbar button.
- Place the brand, product name, and usage-status capsule at the upper leading edge.
- Center a large product image over the snowy landscape.
- Present a full-width **Good to use** row and expiration bar.
- Present three equal-height fact cards for opened date, PAO, and printed expiration.
- Present the compact reminder row below the cards.
- Preserve the app’s existing sky, ice, deep-blue, warning, and snow imagery.

The current Edit action and reminder selection remain local/presentational because product editing and notification scheduling are outside this revision.

## Product Card Blur

Remove the glass effect from the card’s lower text background. Re-render the same product image in a clipped lower region, align it with the original image, and apply a Gaussian blur. Keep the existing blue readability gradient and text above this blurred region. Define the blur radius and lower-region height as clearly named adjustable constants so the effect can be tuned without restructuring the card.

This approach blurs the lower portion of the product itself, unlike a fixed translucent fill, and provides direct blur-strength control.

## Marble Impact Audio

Keep audio procedural and generated locally. Replace the high crystalline partials with a short, lower-frequency resonant impact, a restrained transient, and speed-dependent pitch and volume. Preserve throttling, ambient audio-session behavior, and collision-speed scaling. The target is a small marble striking a hard surface rather than breaking ice.

## UI Comments

Add concise comments above meaningful UI regions and reusable controls throughout the SwiftUI source: backgrounds, navigation surfaces, headers, grids, forms, photo regions, toolbars, status elements, and accessibility-sensitive sections. Do not narrate obvious individual modifiers, because that would obscure structure rather than document it.

## File Organization

- `InventoryModel.swift`: persistent product model, expiration behavior, filtering support, and sample seeding.
- `ProductImageView.swift`: bundled/imported product image rendering.
- `AddProductView.swift`: form state, validation, photo selection, and insertion flow.
- `CameraPicker.swift`: isolated UIKit camera bridge.
- `MyApp.swift`: SwiftData model container.
- `InventoryView.swift`: query/filter presentation, add sheet, context menu, and deletion dialog.
- `ProductCard.swift`: adjustable lower-image blur and comments.
- `ProductDetailsView.swift`: Figma-aligned layout and comments.
- `IceImpactSoundPlayer.swift`: lower marble-like synthesis.
- Other SwiftUI files: section-level UI comments without unrelated refactoring.

## Accessibility and Native Behavior

- Preserve Reduce Motion behavior in the welcome and detail animations.
- Provide labels and hints for photo actions, add/delete controls, and product cards.
- Use semantic SwiftUI fonts so Dynamic Type continues to work.
- Use native `Form`, toolbars, context menus, dialogs, pickers, and navigation behavior.
- Keep destructive actions explicitly labeled and confirmed.
- Ensure photo controls remain operable with VoiceOver and without relying on image-only meaning.

## Error Handling

- Photo decoding or transfer failure: show an alert and retain form state.
- Camera unavailable: disable or explain the camera action; library selection remains available.
- SwiftData insertion or deletion save failure: show an alert and keep the UI consistent with the persisted result.
- Invalid form: disable confirmation and retain inline native controls rather than allowing a failing save.
- Missing or corrupt stored photo: show the shared product-image fallback.

## Testing and Verification

Automated tests use an in-memory SwiftData container and cover:

- Empty-store sample seeding without duplication.
- Persistent product insertion and deletion.
- Add-form validation rules.
- Bundled versus imported image-source selection.
- Search and filter composition.
- Effective-expiration sorting, including deterministic tie-breakers.
- Effective expiration, expiring-soon boundaries, and progress clamping.
- Existing welcome physics and expiration-bar behavior.

Verification includes:

- Refreshing Xcode diagnostics for every changed Swift file.
- Running the unit-test target.
- Building the full project with Xcode.
- Simulator checks for add-sheet presentation, library selection, camera-unavailable fallback, save, long-press deletion and confirmation, adjustable card blur, Figma-aligned details, welcome animation, and marble-like collision sound.

## Out of Scope

- Product editing from the detail screen.
- Scheduling local reminder notifications.
- Cloud synchronization or account support.
- Product categories, barcode scanning, OCR, or background removal.
- Redesigning screens other than the requested add flow, card treatment, and Figma detail revision.
