import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import CH6_Inventory

@MainActor
struct InventoryModelTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func openedProductUsesEarlierPAODate() {
        let opened = date(2026, 1, 1)
        let product = Product(
            id: UUID(1), brand: "Brand", name: "Cream", assetName: "cream",
            openedDate: opened, periodAfterOpeningMonths: 6,
            printedExpirationDate: date(2028, 1, 1), isInUse: true
        )

        #expect(product.effectiveExpirationDate(calendar: calendar) == date(2026, 7, 1))
    }

    @Test func unopenedProductUsesPrintedExpiration() {
        let product = Product(
            id: UUID(2), brand: "Brand", name: "Serum", assetName: "serum",
            openedDate: nil, periodAfterOpeningMonths: 12,
            printedExpirationDate: date(2027, 3, 1), isInUse: false
        )

        #expect(product.effectiveExpirationDate(calendar: calendar) == date(2027, 3, 1))
    }

    @Test(arguments: [(179, true), (180, true), (181, false), (-1, false)])
    func expiringSoonBoundary(days: Int, expected: Bool) {
        let reference = date(2026, 1, 1)
        let expiration = calendar.date(byAdding: .day, value: days, to: reference)!
        let product = Product(
            id: UUID(days + 20), brand: "Brand", name: "Item", assetName: "item",
            openedDate: nil, periodAfterOpeningMonths: 12,
            printedExpirationDate: expiration, isInUse: false
        )

        #expect(product.isExpiringSoon(on: reference, calendar: calendar) == expected)
    }

    @Test func progressIsClamped() {
        let reference = date(2026, 1, 1)
        let product = Product(
            id: UUID(3), brand: "Brand", name: "Item", assetName: "item",
            openedDate: date(2025, 1, 1), periodAfterOpeningMonths: 12,
            printedExpirationDate: date(2027, 1, 1), isInUse: true
        )

        #expect(product.shelfLifeProgress(on: date(2024, 1, 1), calendar: calendar) == 1)
        #expect(product.shelfLifeProgress(on: date(2027, 1, 1), calendar: calendar) == 0)
        #expect(product.shelfLifeProgress(on: reference, calendar: calendar) == 0)
    }

    @Test func searchAndFilterCompose() {
        let reference = date(2026, 1, 1)
        let matching = Product(
            id: UUID(4), brand: "Laneige", name: "Mask", assetName: "mask",
            openedDate: nil, periodAfterOpeningMonths: 6,
            printedExpirationDate: date(2026, 3, 1), isInUse: false
        )
        let other = Product(
            id: UUID(5), brand: "SK-II", name: "Cleanser", assetName: "cleanser",
            openedDate: date(2025, 1, 1), periodAfterOpeningMonths: 48,
            printedExpirationDate: date(2029, 1, 1), isInUse: true
        )
        let visibleProducts = Product.visibleProducts(
            [matching, other],
            filter: .notInUse,
            searchText: "lane",
            referenceDate: reference
        )

        #expect(visibleProducts.map(\.id) == [matching.id])
    }

    @Test func visibleProductsSortByEffectiveExpirationThenName() {
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

    @Test func deletingProductRemovesItFromPersistentInventory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let product = Product.fixture(name: "Delete Me")
        context.insert(product)
        try context.save()

        try context.deleteProduct(product)

        let verificationContext = ModelContext(container)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Product>()) == 0)
    }

    @Test func importedPhotoTakesPriorityOverBundledAsset() {
        let bytes = Data([0x01, 0x02])
        let product = Product.fixture(assetName: "sample", photoData: bytes)

        #expect(product.imageSource == .photoData(bytes))
    }

    @Test func bundledAssetIsUsedWithoutPhotoData() {
        let product = Product.fixture(assetName: "sample", photoData: nil)

        #expect(product.imageSource == .asset("sample"))
    }

    @Test func addDraftRequiresBrandAndName() {
        var draft = AddProductDraft()
        draft.name = "Mask"
        #expect(!draft.isValid(hasPhoto: true))

        draft.brand = "Laneige"
        draft.name = "   "
        #expect(!draft.isValid(hasPhoto: true))
    }

    @Test func addDraftRequiresPhoto() {
        var draft = AddProductDraft()
        draft.brand = "Laneige"
        draft.name = "Mask"

        #expect(!draft.isValid(hasPhoto: false))
    }

    @Test func addDraftRequiresOpenedDateWhenInUse() {
        var draft = AddProductDraft()
        draft.brand = "Laneige"
        draft.name = "Mask"
        draft.isInUse = true

        #expect(!draft.isValid(hasPhoto: true))

        draft.openedDate = date(2026, 9, 1)
        #expect(draft.isValid(hasPhoto: true))
    }

    @Test func addDraftCanBeOpenedWithoutCurrentlyInUse() {
        let opened = date(2026, 9, 1)
        var draft = AddProductDraft()

        draft.setOpened(true, defaultDate: opened)
        draft.setInUse(false, defaultOpenedDate: date(2026, 9, 2))

        #expect(draft.openedDate == opened)
        #expect(!draft.isInUse)
    }

    @Test func addDraftCurrentlyInUseAutomaticallyMarksProductOpened() {
        let opened = date(2026, 9, 1)
        var draft = AddProductDraft()

        draft.setInUse(true, defaultOpenedDate: opened)

        #expect(draft.openedDate == opened)
        #expect(draft.isInUse)
    }

    @Test func addDraftClearingOpenedAlsoClearsCurrentlyInUse() {
        var draft = AddProductDraft()
        draft.openedDate = date(2026, 9, 1)
        draft.isInUse = true

        draft.setOpened(false, defaultDate: date(2026, 9, 2))

        #expect(draft.openedDate == nil)
        #expect(!draft.isInUse)
    }

    @Test func addDraftAcceptsCompleteUnusedProduct() {
        var draft = AddProductDraft()
        draft.brand = "Laneige"
        draft.name = "Mask"

        #expect(draft.isValid(hasPhoto: true))
    }

    @Test func addDraftTrimsIdentityWhenMakingProduct() {
        let openedDate = date(2026, 9, 1)
        let expirationDate = date(2027, 9, 1)
        var draft = AddProductDraft()
        draft.brand = "  Laneige \n"
        draft.name = "\tMask  "
        draft.isInUse = true
        draft.openedDate = openedDate
        draft.periodAfterOpeningMonths = 18
        draft.printedExpirationDate = expirationDate
        let photoData = Data([0x01, 0x02])

        let product = draft.makeProduct(photoData: photoData)

        #expect(product.brand == "Laneige")
        #expect(product.name == "Mask")
        #expect(product.assetName == nil)
        #expect(product.photoData == photoData)
        #expect(product.openedDate == openedDate)
        #expect(product.periodAfterOpeningMonths == 18)
        #expect(product.printedExpirationDate == expirationDate)
        #expect(product.isInUse)
    }

    @Test func addDraftCanBePrefilledFromExistingProduct() {
        let openedDate = date(2026, 9, 1)
        let expirationDate = date(2027, 9, 1)
        let product = Product(
            brand: "Laneige",
            name: "Lip Sleeping Mask",
            assetName: "laneige-mask",
            openedDate: openedDate,
            periodAfterOpeningMonths: 18,
            printedExpirationDate: expirationDate,
            isInUse: true
        )

        let draft = AddProductDraft(product: product)

        #expect(draft.brand == "Laneige")
        #expect(draft.name == "Lip Sleeping Mask")
        #expect(draft.isInUse)
        #expect(draft.openedDate == openedDate)
        #expect(draft.periodAfterOpeningMonths == 18)
        #expect(draft.printedExpirationDate == expirationDate)
    }

    @Test func addDraftUpdatesExistingProductWithoutReplacingBundledAsset() {
        let openedDate = date(2026, 10, 1)
        let expirationDate = date(2028, 1, 1)
        let product = Product.fixture(
            brand: "Old Brand",
            name: "Old Name",
            expiration: date(2027, 1, 1),
            assetName: "sample-asset",
            photoData: nil
        )
        var draft = AddProductDraft()
        draft.brand = "  New Brand "
        draft.name = "\nNew Name  "
        draft.isInUse = true
        draft.openedDate = openedDate
        draft.periodAfterOpeningMonths = 24
        draft.printedExpirationDate = expirationDate

        draft.update(product, photoData: nil)

        #expect(product.brand == "New Brand")
        #expect(product.name == "New Name")
        #expect(product.assetName == "sample-asset")
        #expect(product.photoData == nil)
        #expect(product.openedDate == openedDate)
        #expect(product.periodAfterOpeningMonths == 24)
        #expect(product.printedExpirationDate == expirationDate)
        #expect(product.isInUse)
    }

    @Test func addDraftUpdatesExistingProductWithNewImportedPhoto() {
        let product = Product.fixture(assetName: "sample-asset", photoData: nil)
        let newPhoto = Data([0x09, 0x08, 0x07])
        let draft = AddProductDraft(product: product)

        draft.update(product, photoData: newPhoto)

        #expect(product.assetName == nil)
        #expect(product.photoData == newPhoto)
    }

    @Test func welcomePhysicsMatchesInventoryCountAndPreservesRetainedBodies() {
        let products = Product.samples(referenceDate: date(2026, 9, 16))
        var state = WelcomePhysicsState()
        state.reconcile(products: Array(products.prefix(3)), in: CGSize(width: 402, height: 874))
        #expect(state.bodies.count == 3)

        let retainedID = products[1].id
        let retainedPosition = state.bodies[retainedID]?.position
        state.reconcile(products: Array(products.prefix(5)), in: CGSize(width: 402, height: 874))
        #expect(state.bodies.count == 5)
        #expect(state.bodies[retainedID]?.position == retainedPosition)

        state.reconcile(products: [], in: CGSize(width: 402, height: 874))
        #expect(state.bodies.isEmpty)
    }

    @Test func welcomePhysicsUsesTheVisibleHundredPointSquareAsItsCollider() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()

        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))

        #expect(state.bodies[product.id]?.halfSize == 50)
    }

    @Test func welcomePhysicsStartsEveryProductFullyAboveTheScreen() {
        let products = Product.samples(referenceDate: date(2026, 9, 16))
        var state = WelcomePhysicsState()

        state.reconcile(products: products, in: CGSize(width: 402, height: 874))

        #expect(state.bodies.values.allSatisfy { body in
            body.position.y + body.rotatedExtent <= 0
        })
    }

    @Test func welcomePhysicsAcceleratesProductsLikeFallingIce() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()
        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))
        let initialVelocity = state.bodies[product.id]?.velocity.dy ?? 0

        state.step(deltaTime: 1.0 / 20.0, in: CGSize(width: 402, height: 874))

        let updatedVelocity = state.bodies[product.id]?.velocity.dy ?? 0
        #expect(updatedVelocity - initialVelocity > 30)
    }

    @Test func welcomePhysicsDoesNotKeepRotatingWithStableGravity() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()
        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))
        let initialAngle = state.bodies[product.id]?.angle ?? 0

        for _ in 0..<30 {
            state.step(deltaTime: 1.0 / 60.0, in: CGSize(width: 402, height: 874))
        }

        let updatedAngle = state.bodies[product.id]?.angle ?? 0
        #expect(abs(updatedAngle - initialAngle) < 1)
    }

    @Test func welcomePhysicsRotatesSlightlyWhenDeviceGravityChanges() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()
        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))
        let initialAngle = state.bodies[product.id]?.angle ?? 0

        state.step(
            deltaTime: 1.0 / 60.0,
            in: CGSize(width: 402, height: 874),
            gravity: CGVector(dx: 0, dy: 1)
        )
        state.step(
            deltaTime: 1.0 / 60.0,
            in: CGSize(width: 402, height: 874),
            gravity: CGVector(dx: 0.45, dy: 0.89)
        )
        for _ in 0..<20 {
            state.step(
                deltaTime: 1.0 / 60.0,
                in: CGSize(width: 402, height: 874),
                gravity: CGVector(dx: 0.45, dy: 0.89)
            )
        }

        let updatedAngle = state.bodies[product.id]?.angle ?? 0
        #expect(abs(updatedAngle - initialAngle) > 0.2)
        #expect(abs(updatedAngle - initialAngle) < 5)
    }

    @Test func deviceGravityMapsToSwiftUIScreenCoordinates() {
        #expect(
            DeviceGravityMapping.physicsGravity(x: 0.4, y: -0.8)
                == CGVector(dx: 0.4, dy: 0.8)
        )
        #expect(
            DeviceGravityMapping.physicsGravity(x: 0, y: 1)
                == CGVector(dx: 0, dy: -1)
        )
    }

    @Test func welcomePhysicsAcceleratesInTheDeviceGravityDirection() {
        #expect(
            WelcomePhysicsState.acceleration(
                for: CGVector(dx: 0.4, dy: -0.8)
            ) == CGVector(dx: 392, dy: -784)
        )
    }

    @Test func reduceMotionDoesNotPauseWelcomePhysics() {
        #expect(!WelcomeMotionPolicy.pausesPhysics(reduceMotionEnabled: true))
    }

    @Test func welcomePhysicsKeepsFallingBlocksSeparated() {
        let sample = Product.samples(referenceDate: date(2026, 9, 16))[0]
        let products = (0..<16).map { index in
            Product(
                id: UUID(index + 100),
                brand: sample.brand,
                name: "\(sample.name) \(index)",
                assetName: sample.assetName,
                openedDate: sample.openedDate,
                periodAfterOpeningMonths: sample.periodAfterOpeningMonths,
                printedExpirationDate: sample.printedExpirationDate,
                isInUse: sample.isInUse
            )
        }
        var state = WelcomePhysicsState()
        state.reconcile(products: products, in: CGSize(width: 402, height: 874))

        for _ in 0..<120 {
            state.step(deltaTime: 1.0 / 60.0, in: CGSize(width: 402, height: 874))
        }

        let bodies = Array(state.bodies.values)
        for firstIndex in bodies.indices {
            for secondIndex in bodies.indices where secondIndex > firstIndex {
                let first = bodies[firstIndex]
                let second = bodies[secondIndex]
                #expect(!WelcomePhysicsState.overlaps(first, second, tolerance: 0.5))
            }
        }
    }

    @Test func welcomeFeedbackTriggersAgainForASeparateMovingImpact() {
        var gate = WelcomeImpactFeedbackGate()

        let firstImpact = gate.shouldTrigger(impactSpeed: 120, motionSpeed: 120, at: 0)
        let duplicateImpact = gate.shouldTrigger(impactSpeed: 120, motionSpeed: 120, at: 0.02)
        let separateImpact = gate.shouldTrigger(impactSpeed: 120, motionSpeed: 120, at: 0.08)

        #expect(firstImpact)
        #expect(!duplicateImpact)
        #expect(separateImpact)
    }

    @Test func welcomeFeedbackIgnoresSettledContacts() {
        var gate = WelcomeImpactFeedbackGate()

        let slowImpact = gate.shouldTrigger(impactSpeed: 41, motionSpeed: 120, at: 0)
        let settledContact = gate.shouldTrigger(impactSpeed: 120, motionSpeed: 5, at: 1)

        #expect(!slowImpact)
        #expect(!settledContact)
    }

    @Test func productIdentityDetectionFindsKnownBrandAndProductName() {
        let observations = [
            ProductTextObservation(
                text: "KIEHL'S",
                confidence: 0.96,
                boundingBox: CGRect(x: 0.2, y: 0.78, width: 0.6, height: 0.10)
            ),
            ProductTextObservation(
                text: "Clearly Corrective Dark Spot Solution",
                confidence: 0.94,
                boundingBox: CGRect(x: 0.12, y: 0.54, width: 0.76, height: 0.12)
            ),
            ProductTextObservation(
                text: "30 ml",
                confidence: 0.99,
                boundingBox: CGRect(x: 0.4, y: 0.12, width: 0.2, height: 0.04)
            )
        ]

        let suggestion = ProductIdentityDetector.suggestion(from: observations)

        #expect(suggestion.brand == "Kiehl’s")
        #expect(suggestion.name == "Clearly Corrective Dark Spot Solution")
    }

    @Test func productIdentityDetectionLeavesUnclearBrandEmpty() {
        let observations = [
            ProductTextObservation(
                text: "GLOW LABORATORY",
                confidence: 0.58,
                boundingBox: CGRect(x: 0.2, y: 0.8, width: 0.6, height: 0.08)
            ),
            ProductTextObservation(
                text: "Hydrating Serum",
                confidence: 0.93,
                boundingBox: CGRect(x: 0.2, y: 0.55, width: 0.6, height: 0.11)
            )
        ]

        let suggestion = ProductIdentityDetector.suggestion(from: observations)

        #expect(suggestion.brand == nil)
        #expect(suggestion.name == "Hydrating Serum")
    }

    @Test func detectedIdentityOnlyFillsBlankEditableFields() {
        var draft = AddProductDraft(brand: "My Brand", name: "")

        draft.apply(
            ProductIdentitySuggestion(brand: "Laneige", name: "Lip Sleeping Mask")
        )

        #expect(draft.brand == "My Brand")
        #expect(draft.name == "Lip Sleeping Mask")
    }

    @Test func addProductPhotoControlLivesOutsideTheForm() {
        #expect(AddProductLayout.photoPlacement == .outsideForm)
    }

    @Test(arguments: [(-0.5, 0.0), (0.0, 0.0), (0.4, 80.0), (1.0, 200.0), (1.5, 200.0)])
    func expirationBarFillIsClamped(progress: Double, expectedWidth: Double) {
        #expect(ExpirationBar.fillWidth(totalWidth: 200, progress: progress) == expectedWidth)
    }

    @Test func expirationBarHeightCanBeCustomized() {
        let expirationBar = ExpirationBar(progress: 0.5, height: 32)

        #expect(expirationBar.height == 32)
    }

    @Test(arguments: [(12, "12 days remaining"), (1, "1 day remaining"), (0, "Expires today"), (-3, "Expired 3 days ago")])
    func productExpirationCountdownUsesReadableWording(days: Int, expected: String) {
        let referenceDate = date(2026, 9, 17)
        let expirationDate = calendar.date(byAdding: .day, value: days, to: referenceDate)!
        let product = Product.fixture(expiration: expirationDate)

        #expect(product.expirationCountdownLabel(on: referenceDate, calendar: calendar) == expected)
    }

    @Test func welcomeProductImageFrameIsCenteredInsideItsBlock() {
        let imageFrame = WelcomeProductLayout.imageFrame(
            blockSize: CGSize(width: 100, height: 100),
            inset: 8
        )

        #expect(imageFrame == CGRect(x: 8, y: 8, width: 84, height: 84))
        #expect(imageFrame.midX == 50)
        #expect(imageFrame.midY == 50)
    }

    @Test func snowBackgroundPreservesReplacementAssetAspectRatioAtScreenWidth() {
        let scaledSize = IcyBackground.scaledSnowSize(
            assetSize: CGSize(width: 850, height: 2001),
            containerWidth: 402
        )

        #expect(scaledSize.width == 402)
        #expect(abs(scaledSize.height - 946.3553) < 0.001)
    }

    @Test func detailSnowBackgroundUsesOnePointTwoTimesScreenWidth() {
        let fittedSize = IcyBackground.detailBackgroundSize(
            assetSize: CGSize(width: 850, height: 2001),
            containerSize: CGSize(width: 402, height: 874)
        )

        #expect(abs(fittedSize.width - 482.4) < 0.001)
        #expect(abs(fittedSize.height - 1_135.6263) < 0.001)
    }

    @Test func detailProductImageEndsAtNinetyPercentScale() {
        #expect(ProductDetailsHero.imageScale(isVisible: true) == 0.9)
        #expect(abs(ProductDetailsHero.imageScale(isVisible: false) - 0.648) < 0.001)
    }

    @Test func detailProductShadowUsesTheApprovedOvalProportions() {
        #expect(ProductDetailsHero.shadowSize == CGSize(width: 210, height: 42))
    }

    @Test func inventoryPullDownReturnsOnlyAfterThresholdAndRelease() {
        var gesture = InventoryPullDownGesture()

        let shortPull = gesture.update(offset: -60)
        let shortRelease = gesture.update(offset: 0)
        let deepPull = gesture.update(offset: -95)
        let deepPullContinuation = gesture.update(offset: -40)
        let deepRelease = gesture.update(offset: 0)
        let repeatedRest = gesture.update(offset: 0)

        #expect(!shortPull)
        #expect(!shortRelease)
        #expect(!deepPull)
        #expect(!deepPullContinuation)
        #expect(deepRelease)
        #expect(!repeatedRest)
    }

    @Test func inventoryTopEdgePullDownRequiresAnEdgeStartAndEnoughDistance() {
        #expect(!InventoryTopEdgePullDownGesture.shouldReturn(
            startY: 120,
            translationHeight: 130
        ))
        #expect(!InventoryTopEdgePullDownGesture.shouldReturn(
            startY: 40,
            translationHeight: 70
        ))
        #expect(InventoryTopEdgePullDownGesture.shouldReturn(
            startY: 40,
            translationHeight: 100
        ))
    }

    @Test func productCardUsesProvidedBackgroundAndOverlayAssets() {
        #expect(ProductCard.backgroundAssetName == "product-card-background")
        #expect(ProductCard.overlayAssetName == "product-card-overlay")
        #expect(UIImage(named: ProductCard.backgroundAssetName) != nil)
        #expect(UIImage(named: ProductCard.overlayAssetName) != nil)
    }

    @Test func productCardDetailsArePinnedToTheBottomOverlay() {
        #expect(ProductCard.detailsFrameAlignment == .bottomLeading)
        #expect(ProductCard.detailsBottomPadding == 12)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Product.self, configurations: configuration)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private extension Product {
    static func fixture(
        brand: String = "Brand",
        name: String = "Product",
        expiration: Date = .now,
        assetName: String? = nil,
        photoData: Data? = nil
    ) -> Product {
        Product(
            brand: brand,
            name: name,
            assetName: assetName,
            photoData: photoData,
            openedDate: nil,
            periodAfterOpeningMonths: 12,
            printedExpirationDate: expiration,
            isInUse: false
        )
    }
}

private extension UUID {
    init(_ value: Int) {
        self.init(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
