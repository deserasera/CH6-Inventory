import SwiftUI

struct ProductCard: View {
    static let backgroundAssetName = "product-card-background"
    static let overlayAssetName = "product-card-overlay"

    let product: Product
    let referenceDate: Date

    var body: some View {
        ZStack(alignment: .bottomLeading) {
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

            VStack(alignment: .leading, spacing: 1) {
                Text(product.brand)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            // Keep product details above both supplied card layers.
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)

            if product.isExpiringSoon(on: referenceDate) {
                Text("\(product.daysRemaining(on: referenceDate)) d left")
                    .font(.system(size: 9, weight: .bold))
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
