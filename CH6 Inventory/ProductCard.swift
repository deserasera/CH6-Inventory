import SwiftUI

struct ProductCard: View {
    let product: Product
    let referenceDate: Date

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 17)
                .fill(.white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(.white.opacity(0.72), lineWidth: 0.8)
                }

            Image(product.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 122)
                .padding(.bottom, 48)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [AppTheme.selectedBlue.opacity(0), AppTheme.selectedBlue.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)
            .clipShape(.rect(bottomLeadingRadius: 17, bottomTrailingRadius: 17))

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
            .padding(.bottom, 14)

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
        .frame(height: 180)
        .shadow(color: AppTheme.deepBlue.opacity(0.16), radius: 7, y: 5)
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
