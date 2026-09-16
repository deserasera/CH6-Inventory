import SwiftUI

struct ProductDetailsView: View {
    let product: Product
    let referenceDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reminder: ProductReminder = .none
    @State private var heroIsVisible = false

    var body: some View {
        ZStack {
            IcyBackground(snowOffset: 250, blurRadius: 18, snowOpacity: 0.52)
            ScrollView {
                VStack(spacing: 12) {
                    ProductDetailsHero(
                        brand: product.brand,
                        name: product.name,
                        assetName: product.assetName,
                        isInUse: product.isInUse,
                        isVisible: heroIsVisible
                    )
                    ProductExpirationSection(product: product, referenceDate: referenceDate)
                    ProductFactsSection(product: product)
                    ProductReminderRow(selection: $reminder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { }
                    .buttonStyle(.glass)
            }
        }
        .onAppear {
            if reduceMotion {
                heroIsVisible = true
            } else {
                withAnimation(.spring(duration: 0.72, bounce: 0.18)) {
                    heroIsVisible = true
                }
            }
        }
    }
}

private struct ProductDetailsHero: View {
    let brand: String
    let name: String
    let assetName: String
    let isInUse: Bool
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(brand)
                .font(.title3)
            Text(name)
                .font(.title)
                .fontWeight(.semibold)
            Text(isInUse ? "In use" : "Not in use")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.15), in: Capsule())
                .padding(.top, 4)

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 238)
                .scaleEffect(isVisible ? 1 : 0.72)
                .offset(y: isVisible ? 0 : 70)
                .shadow(color: AppTheme.deepBlue.opacity(0.28), radius: 12, y: 10)
                .accessibilityLabel("\(brand) \(name)")
        }
        .foregroundStyle(AppTheme.deepBlue)
        .padding(.top, 12)
    }
}

private struct ProductExpirationSection: View {
    let product: Product
    let referenceDate: Date

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Good to use")
                Spacer()
                Text(product.effectiveExpirationDate(), format: .dateTime.day().month().year())
            }
            .font(.headline)
            .fontWeight(.semibold)
            ExpirationBar(
                progress: product.shelfLifeProgress(on: referenceDate),
                daysRemaining: product.daysRemaining(on: referenceDate)
            )
        }
        .foregroundStyle(AppTheme.deepBlue)
    }
}

private struct ProductFactsSection: View {
    let product: Product

    var body: some View {
        HStack(spacing: 10) {
            ProductFactCard(title: "Opened date") {
                if let openedDate = product.openedDate {
                    Text(openedDate, format: .dateTime.day().month().year())
                } else {
                    Text("Unopened")
                }
            }
            ProductFactCard(title: "PAO") {
                Text("\(product.periodAfterOpeningMonths)")
                    .font(.title2)
                Text("months")
                    .font(.caption)
            }
            ProductFactCard(title: "Expiration date") {
                Text(product.printedExpirationDate, format: .dateTime.day().month().year())
            }
        }
        .foregroundStyle(AppTheme.deepBlue)
    }
}

private struct ProductFactCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                content
            }
            .font(.headline)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, minHeight: 174)
        .background(.white.opacity(0.27), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.65), lineWidth: 0.8)
        }
    }
}

private struct ProductReminderRow: View {
    @Binding var selection: ProductReminder

    var body: some View {
        HStack {
            Label("Set Reminder", systemImage: "bell")
                .font(.caption)
            Spacer()
            Picker("Set Reminder", selection: $selection) {
                ForEach(ProductReminder.allCases) { reminder in
                    Text(reminder.title).tag(reminder)
                }
            }
            .labelsHidden()
            .font(.headline)
        }
        .foregroundStyle(AppTheme.deepBlue)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.65), lineWidth: 0.8)
        }
    }
}

private enum ProductReminder: String, CaseIterable, Identifiable {
    case none
    case expirationDay
    case oneDayBefore
    case oneWeekBefore
    case oneMonthBefore

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .none: "None"
        case .expirationDay: "On expiration day"
        case .oneDayBefore: "1 day before"
        case .oneWeekBefore: "1 week before"
        case .oneMonthBefore: "1 month before"
        }
    }
}
