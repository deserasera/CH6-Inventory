import SwiftData
import SwiftUI

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    let referenceDate: Date

    @State private var scrollOffset: CGFloat = 0
    @State private var showAddProduct = false
    @State private var selectedFilter: InventoryFilter = .all
    @State private var searchText = ""
    @State private var pendingProduct: Product?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeletionErrorPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        let visibleProducts = Product.visibleProducts(
            products,
            filter: selectedFilter,
            searchText: searchText,
            referenceDate: referenceDate
        )

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [AppTheme.sky, AppTheme.ice],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    InventoryExpandedHeader(
                        count: visibleProducts.count,
                        selectedFilter: $selectedFilter
                    )
                    .opacity(1 - collapseProgress)
                    .frame(height: 158 - collapseProgress * 72)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleProducts) { product in
                            NavigationLink(value: product.id) {
                                ProductCard(product: product, referenceDate: referenceDate)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingProduct = product
                                    isDeleteConfirmationPresented = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                scrollOffset = max(newValue, 0)
            }

            InventoryCompactHeader(count: visibleProducts.count)
                .opacity(collapseProgress)
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .bottom) {
            InventoryBottomBar(searchText: $searchText) {
                showAddProduct = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showAddProduct) {
            AddProductView()
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingProduct
        ) { product in
            Button("Delete", role: .destructive) {
                deleteProduct(product)
            }
            Button("Cancel", role: .cancel) {
                pendingProduct = nil
            }
        } message: { product in
            Text("This permanently removes \(product.brand) \(product.name) from your inventory.")
        }
        .onChange(of: isDeleteConfirmationPresented) { _, isPresented in
            if !isPresented {
                pendingProduct = nil
            }
        }
        .alert("Unable to Delete Product", isPresented: $isDeletionErrorPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The product could not be deleted. Please try again.")
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var deleteConfirmationTitle: Text {
        if let pendingProduct {
            Text("Delete \(pendingProduct.name)?")
        } else {
            Text("Delete Product?")
        }
    }

    private func deleteProduct(_ product: Product) {
        defer {
            pendingProduct = nil
            isDeleteConfirmationPresented = false
        }

        do {
            try modelContext.deleteProduct(product)
        } catch {
            isDeletionErrorPresented = true
        }
    }

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / 118, 0), 1)
    }
}

private struct InventoryExpandedHeader: View {
    let count: Int
    @Binding var selectedFilter: InventoryFilter

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("INVENTORY")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(count) items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(InventoryFilter.allCases) { filter in
                        Button {
                            withAnimation(.smooth(duration: 0.28)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedFilter == filter
                                        ? AppTheme.selectedBlue
                                        : Color.clear,
                                    in: Capsule()
                                )
                                .overlay {
                                    if selectedFilter != filter {
                                        Capsule().stroke(AppTheme.ice, lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct InventoryCompactHeader: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.sky, AppTheme.sky.opacity(0.92), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 104)
            .blur(radius: 6)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    Text("Inventory")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(count) items")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(.top, 8)
            }
            Spacer()
        }
    }
}

private struct InventoryBottomBar: View {
    @Binding var searchText: String
    let addAction: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                    Image(systemName: "mic.fill")
                }
                .foregroundStyle(AppTheme.selectedBlue)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .glassEffect(.regular, in: .capsule)

                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(AppTheme.selectedBlue)
                .accessibilityLabel("Add product")
            }
        }
    }
}
