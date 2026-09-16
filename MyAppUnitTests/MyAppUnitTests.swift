import CoreGraphics
import Foundation
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
        let store = InventoryStore(products: [matching, other], referenceDate: reference)
        store.selectedFilter = .notInUse
        store.searchText = "lane"

        #expect(store.filteredProducts.map(\.id) == [matching.id])
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

    @Test func welcomePhysicsUsesOneHundredPointBlocks() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()

        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))

        #expect(state.bodies[product.id]?.radius == 50)
    }

    @Test func welcomePhysicsAcceleratesProductsLikeFallingIce() {
        let product = Product.samples(referenceDate: date(2026, 9, 16))[0]
        var state = WelcomePhysicsState()
        state.reconcile(products: [product], in: CGSize(width: 402, height: 874))
        let initialVelocity = state.bodies[product.id]?.velocity.dy ?? 0

        state.step(deltaTime: 1.0 / 20.0, in: CGSize(width: 402, height: 874))

        let updatedVelocity = state.bodies[product.id]?.velocity.dy ?? 0
        #expect(updatedVelocity - initialVelocity > 10)
    }

    @Test(arguments: [(-0.5, 0.0), (0.0, 0.0), (0.4, 80.0), (1.0, 200.0), (1.5, 200.0)])
    func expirationBarFillIsClamped(progress: Double, expectedWidth: Double) {
        #expect(ExpirationBar.fillWidth(totalWidth: 200, progress: progress) == expectedWidth)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private extension UUID {
    init(_ value: Int) {
        self.init(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
