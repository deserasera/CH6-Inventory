import Foundation
import SwiftData

@Model
final class Product: Identifiable, Hashable {
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

    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

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

    func expirationCountdownLabel(on date: Date, calendar: Calendar = .current) -> String {
        let days = daysRemaining(on: date, calendar: calendar)
        switch days {
        case 2...:
            return "\(days) days remaining"
        case 1:
            return "1 day remaining"
        case 0:
            return "Expires today"
        case -1:
            return "Expired 1 day ago"
        default:
            return "Expired \(-days) days ago"
        }
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

    static func visibleProducts(
        _ products: [Product],
        filter: InventoryFilter,
        searchText: String,
        referenceDate: Date
    ) -> [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return products.filter { product in
            let matchesFilter = switch filter {
            case .all:
                true
            case .notInUse:
                !product.isInUse
            case .expiringSoon:
                product.isExpiringSoon(on: referenceDate)
            }
            let matchesSearch = query.isEmpty
                || product.brand.localizedCaseInsensitiveContains(query)
                || product.name.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
        .sorted { left, right in
            let leftExpiration = left.effectiveExpirationDate()
            let rightExpiration = right.effectiveExpirationDate()
            if leftExpiration != rightExpiration {
                return leftExpiration < rightExpiration
            }

            let brandComparison = left.brand.localizedCompare(right.brand)
            if brandComparison != .orderedSame {
                return brandComparison == .orderedAscending
            }

            let nameComparison = left.name.localizedCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.uuidString.localizedCompare(right.id.uuidString) == .orderedAscending
        }
    }

    static func seedSamplesIfNeeded(
        in context: ModelContext,
        referenceDate: Date = .now
    ) throws {
        guard try context.fetchCount(FetchDescriptor<Product>()) == 0 else {
            return
        }

        for product in samples(referenceDate: referenceDate) {
            context.insert(product)
        }
        try context.save()
    }
}

extension ModelContext {
    func deleteProduct(_ product: Product) throws {
        delete(product)

        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}

enum InventoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case notInUse = "Not in use"
    case expiringSoon = "Expiring soon"

    var id: Self { self }
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
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
