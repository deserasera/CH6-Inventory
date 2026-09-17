import CoreGraphics
import Foundation
import SwiftData
import Testing
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

    @Test func welcomePhysicsAcceleratesProductsLikeFallingIce() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()
        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))
        let initialVelocity = state.bodies[product.id]?.velocity.dy ?? 0

        state.step(deltaTime: 1.0 / 20.0, in: CGSize(width: 402, height: 874))

        let updatedVelocity = state.bodies[product.id]?.velocity.dy ?? 0
        #expect(updatedVelocity - initialVelocity > 30)
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

    @Test(arguments: [(-0.5, 0.0), (0.0, 0.0), (0.4, 80.0), (1.0, 200.0), (1.5, 200.0)])
    func expirationBarFillIsClamped(progress: Double, expectedWidth: Double) {
        #expect(ExpirationBar.fillWidth(totalWidth: 200, progress: progress) == expectedWidth)
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
