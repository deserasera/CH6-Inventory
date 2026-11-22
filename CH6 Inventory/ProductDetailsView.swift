import SwiftUI
import UIKit

struct ProductDetailsView: View {
    let product: Product
    let referenceDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reminder: ProductReminder = .none
    @State private var heroIsVisible = false
    @State private var isEditProductPresented = false

    var body: some View {
        ZStack {
            ProductDetailsBackground()
            ScrollView {
                VStack(spacing: 12) {
                    ProductDetailsHero(product: product, isVisible: heroIsVisible)
                    ProductExpirationSection(product: product, referenceDate: referenceDate)
                    ProductFactsSection(product: product)
                    ProductReminderRow(selection: $reminder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(AppTypography.heading)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Back to inventory")
            }
            ToolbarItem(placement: .principal) {
                Text("Product Details")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppTheme.deepBlue)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditProductPresented = true
                } label: {
                    Text("Edit")
                        .font(AppTypography.heading)
                        .frame(minWidth: 52, minHeight: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .tint(AppTheme.selectedBlue)
        .sheet(isPresented: $isEditProductPresented) {
            AddProductView(product: product)
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

private struct ProductDetailsBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let assetSize = UIImage(named: "snow-background")?.size ?? .zero
            let fittedSize = IcyBackground.detailBackgroundSize(
                assetSize: assetSize,
                containerSize: proxy.size
            )

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [AppTheme.sky, AppTheme.ice],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // EDIT HERE — replace this asset to change the transparent snow/ice landscape.
                Image("snow-background")
                    .resizable()
                    .frame(width: fittedSize.width, height: fittedSize.height)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                    .offset(y: 258)
                    .opacity(0.75)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

struct ProductDetailsHero: View {
    static let shadowSize = CGSize(width: 210, height: 42)

    let product: Product
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.brand)
                .font(AppTypography.heading)
            Text(product.name)
                .font(AppTypography.productTitle)
            Text(product.isInUse ? "In use" : "Not in use")
                .font(AppTypography.smallBodySemibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.sky, in: Capsule())
                .padding(.top, 4)

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.selectedBlue.opacity(0.20),
                                AppTheme.selectedBlue.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: Self.shadowSize.width / 2
                        )
                    )
                    .frame(width: Self.shadowSize.width, height: Self.shadowSize.height)
                    .blur(radius: 14)
                    .offset(y: -8)
                    .accessibilityHidden(true)

                // Product image region supports bundled assets and imported photos.
                ProductImageView(product: product, contentMode: .fit)
                    .scaleEffect(Self.imageScale(isVisible: isVisible))
                    .offset(y: isVisible ? 0 : 70)
                    .shadow(color: AppTheme.deepBlue.opacity(0.28), radius: 12, y: 10)
            }
                .frame(maxWidth: .infinity)
                .frame(height: 238)
                .accessibilityLabel("\(product.brand) \(product.name)")
        }
        .foregroundStyle(AppTheme.deepBlue)
        .padding(.top, 12)
    }

    static func imageScale(isVisible: Bool) -> CGFloat {
        (isVisible ? 1 : 0.72) * 0.9
    }
}

private struct ProductExpirationSection: View {
    let product: Product
    let referenceDate: Date

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(product.daysRemaining(on: referenceDate) >= 0 ? "Good to use" : "Expired")
                Spacer()
                Text(product.expirationCountdownLabel(on: referenceDate))
            }
            .font(AppTypography.heading)
            ExpirationBar(progress: product.shelfLifeProgress(on: referenceDate))
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
                    .font(AppTypography.heading)
                Text("months")
                    .font(AppTypography.heading)
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
        VStack(spacing: 0) {
            Text(title)
                .font(AppTypography.smallBodyRegular)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 0) {
                content
            }
            .font(AppTypography.heading)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 136)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ProductReminderRow: View {
    @Binding var selection: ProductReminder

    var body: some View {
        HStack {
            Text("Set Reminder")
                .font(AppTypography.heading)
            Spacer()
            Picker("Set Reminder", selection: $selection) {
                ForEach(ProductReminder.allCases) { reminder in
                    Text(reminder.title).tag(reminder)
                }
            }
            .labelsHidden()
            .font(AppTypography.heading)
            .tint(AppTheme.deepBlue)
        }
        .foregroundStyle(AppTheme.deepBlue)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
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
