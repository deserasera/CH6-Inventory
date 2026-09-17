import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @State private var hasEnteredInventory = false
    @State private var inventoryErrorMessage: String?
    @State private var referenceDate = Date.now

    var body: some View {
        ZStack {
            IcyBackground(snowOffset: hasEnteredInventory ? 650 : 520)
                .animation(.smooth(duration: 0.8), value: hasEnteredInventory)

            if hasEnteredInventory {
                NavigationStack {
                    InventoryView(referenceDate: referenceDate)
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                WelcomeView(products: products) {
                    withAnimation(.smooth(duration: 0.72, extraBounce: 0.05)) {
                        hasEnteredInventory = true
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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
