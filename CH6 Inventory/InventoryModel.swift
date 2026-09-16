import Foundation
import Observation

struct Product: Identifiable, Hashable, Sendable {
    let id: UUID
    let brand: String
    let name: String
    let assetName: String
    let openedDate: Date?
    let periodAfterOpeningMonths: Int
    let printedExpirationDate: Date
    let isInUse: Bool

    func effectiveExpirationDate(calendar: Calendar = .current) -> Date {
        guard isInUse,
              let openedDate,
              let paoDate = calendar.date(
                byAdding: .month,
                value: periodAfterOpeningMonths,
                to: openedDate
              ) else {
            return printedExpirationDate
        }
        return min(paoDate, printedExpirationDate)
    }

    func daysRemaining(on date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: effectiveExpirationDate(calendar: calendar))
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isExpiringSoon(on date: Date, calendar: Calendar = .current) -> Bool {
        let days = daysRemaining(on: date, calendar: calendar)
        return (0...180).contains(days)
    }

    func shelfLifeProgress(on date: Date, calendar: Calendar = .current) -> Double {
        let expiration = effectiveExpirationDate(calendar: calendar)
        let start = openedDate ?? calendar.date(byAdding: .year, value: -1, to: expiration) ?? expiration
        let total = expiration.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let remaining = expiration.timeIntervalSince(date)
        return min(max(remaining / total, 0), 1)
    }
}

enum InventoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case notInUse = "Not in use"
    case expiringSoon = "Expiring soon"

    var id: Self { self }
}

@MainActor
@Observable
final class InventoryStore {
    var products: [Product]
    var selectedFilter: InventoryFilter = .all
    var searchText = ""
    let referenceDate: Date

    init(products: [Product], referenceDate: Date = .now) {
        self.products = products
        self.referenceDate = referenceDate
    }

    convenience init(referenceDate: Date = .now) {
        self.init(products: Product.samples(referenceDate: referenceDate), referenceDate: referenceDate)
    }

    var filteredProducts: [Product] {
        products.filter { product in
            let matchesFilter = switch selectedFilter {
            case .all: true
            case .notInUse: !product.isInUse
            case .expiringSoon: product.isExpiringSoon(on: referenceDate)
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || product.brand.localizedCaseInsensitiveContains(query)
                || product.name.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
    }
}

extension Product {
    static func samples(referenceDate: Date = .now, calendar: Calendar = .current) -> [Product] {
        func date(days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: referenceDate) ?? referenceDate
        }

        return [
            Product(id: stableID(1), brand: "Laneige", name: "Lip Sleeping Mask Ex", assetName: "laneige-mask", openedDate: date(days: -36), periodAfterOpeningMonths: 6, printedExpirationDate: date(days: 680), isInUse: true),
            Product(id: stableID(2), brand: "Kiehl’s", name: "Dark Spot Solution", assetName: "kiehls-serum", openedDate: date(days: -30), periodAfterOpeningMonths: 12, printedExpirationDate: date(days: 700), isInUse: true),
            Product(id: stableID(3), brand: "SK-II", name: "Facial Treatment Cleansing Oil", assetName: "skii-oil", openedDate: nil, periodAfterOpeningMonths: 12, printedExpirationDate: date(days: 420), isInUse: false),
            Product(id: stableID(4), brand: "Kiehl’s", name: "Calendula Serum Cream", assetName: "kiehls-cream", openedDate: date(days: -260), periodAfterOpeningMonths: 12, printedExpirationDate: date(days: 105), isInUse: true),
            Product(id: stableID(5), brand: "Estee Lauder", name: "Night Repair Serum", assetName: "estee-serum", openedDate: date(days: -80), periodAfterOpeningMonths: 12, printedExpirationDate: date(days: 610), isInUse: true),
            Product(id: stableID(6), brand: "SK-II", name: "Facial Cleanser", assetName: "skii-cleanser", openedDate: nil, periodAfterOpeningMonths: 18, printedExpirationDate: date(days: 500), isInUse: false),
            Product(id: stableID(7), brand: "Kiehl’s", name: "Dark Spot Solution", assetName: "kiehls-serum", openedDate: date(days: -290), periodAfterOpeningMonths: 12, printedExpirationDate: date(days: 75), isInUse: true),
            Product(id: stableID(8), brand: "Laneige", name: "Lip Sleeping Mask Ex", assetName: "laneige-mask", openedDate: nil, periodAfterOpeningMonths: 6, printedExpirationDate: date(days: 144), isInUse: false)
        ]
    }

    private static func stableID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", value))!
    }
}
