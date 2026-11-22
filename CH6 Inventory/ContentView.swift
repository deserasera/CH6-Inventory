import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var products: [Product]
    @State private var isPlayingWithShelf = false
    @State private var inventoryErrorMessage: String?
    @State private var referenceDate = Date.now

    var body: some View {
        ZStack {
            IcyBackground(snowOffset: isPlayingWithShelf ? 520 : 650)
                .animation(reduceMotion ? nil : .smooth(duration: 0.8), value: isPlayingWithShelf)

            NavigationStack {
                InventoryView(referenceDate: referenceDate) {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.72, extraBounce: 0.05)) {
                        isPlayingWithShelf = true
                    }
                }
                .navigationDestination(for: Product.ID.self) { productID in
                    if let product = products.first(where: { $0.id == productID }) {
                        ProductDetailsView(
                            product: product,
                            referenceDate: referenceDate
                        )
                    } else {
                        ContentUnavailableView(
                            "Product Not Found",
                            systemImage: "shippingbox",
                            description: Text("This product may have been deleted.")
                        )
                    }
                }
            }

            if isPlayingWithShelf {
                WelcomeView(products: products) {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.72, extraBounce: 0.05)) {
                        isPlayingWithShelf = false
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .font(AppTypography.smallBodyRegular)
        .preferredColorScheme(.light)
        .task {
            do {
                try Product.seedSamplesIfNeeded(in: modelContext)
            } catch {
                inventoryErrorMessage = error.localizedDescription
            }
        }
        .alert(
            "Inventory Unavailable",
            isPresented: Binding(
                get: { inventoryErrorMessage != nil },
                set: { if !$0 { inventoryErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(inventoryErrorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
