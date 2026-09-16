import SwiftUI

struct ContentView: View {
    @State private var store = InventoryStore()
    @State private var hasEnteredInventory = false

    var body: some View {
        ZStack {
            IcyBackground(snowOffset: hasEnteredInventory ? 650 : 520)
                .animation(.smooth(duration: 0.8), value: hasEnteredInventory)

            if hasEnteredInventory {
                NavigationStack {
                    InventoryView(store: store)
                        .navigationDestination(for: Product.ID.self) { productID in
                            if let product = store.products.first(where: { $0.id == productID }) {
                                ProductDetailsView(
                                    product: product,
                                    referenceDate: store.referenceDate
                                )
                            }
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                WelcomeView(products: store.products) {
                    withAnimation(.smooth(duration: 0.72, extraBounce: 0.05)) {
                        hasEnteredInventory = true
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
