import SwiftUI

struct ProductCard: View {
    static let backgroundAssetName = "product-card-background"
    static let overlayAssetName = "product-card-overlay"
    static let detailsFrameAlignment = Alignment.bottomLeading
    static let detailsBottomPadding: CGFloat = 16

    let product: Product
    let referenceDate: Date

    var body: some View {
        ZStack(alignment: Self.detailsFrameAlignment) {
            // Supplied background artwork replaces the generated card surface.
            Image(Self.backgroundAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .accessibilityHidden(true)

            // Product image region supports bundled assets and imported photos.
            ProductImageView(product: product, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 122)
                .padding(.bottom, 48)
                .accessibilityHidden(true)

            // Supplied liquid-glass artwork sits in front of the product image.
            Image(Self.overlayAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.5), lineWidth: 0.3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(product.brand)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppTheme.selectedBlue)
                Text(product.name)
                    .font(AppTypography.smallBodySemibold)
                    .foregroundStyle(AppTheme.deepBlue)
                    .lineLimit(2)
            }
            .frame(height: 56, alignment: .bottomLeading)
            .padding(.horizontal, 16)
            .padding(.bottom, Self.detailsBottomPadding)

            if product.isExpiringSoon(on: referenceDate) {
                Text("\(product.daysRemaining(on: referenceDate)) d left")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(AppTheme.warning, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
        }
        // EDIT HERE — overall product-card height.
        .frame(height: 180)
        .shadow(color: AppTheme.deepBlue.opacity(0.10), radius: 1.5, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [product.brand, product.name, product.isInUse ? "In use" : "Not in use"]
        if product.isExpiringSoon(on: referenceDate) {
            parts.append("\(product.daysRemaining(on: referenceDate)) days remaining")
        }
        return parts.joined(separator: ", ")
    }
}
