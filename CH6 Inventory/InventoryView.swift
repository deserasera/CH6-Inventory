import SwiftData
import SwiftUI

struct InventoryPullDownGesture: Sendable {
    private static let threshold: CGFloat = 90
    private var isArmed = false

    mutating func update(offset: CGFloat) -> Bool {
        if offset <= -Self.threshold {
            isArmed = true
            return false
        }
        guard isArmed, offset >= 0 else { return false }
        isArmed = false
        return true
    }
}

enum InventoryTopEdgePullDownGesture {
    private static let maximumStartY: CGFloat = 80
    private static let threshold: CGFloat = 90

    static func shouldReturn(startY: CGFloat, translationHeight: CGFloat) -> Bool {
        startY <= maximumStartY && translationHeight >= threshold
    }
}

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    let referenceDate: Date
    let onOpenPlayMode: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var pullDownGesture = InventoryPullDownGesture()
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
                        selectedFilter: $selectedFilter,
                        productCount: products.count
                    )
                    .opacity(1 - collapseProgress)
                    .frame(height: 108 - collapseProgress * 22, alignment: .top)

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
                if pullDownGesture.update(offset: newValue) {
                    onOpenPlayMode()
                }
            }

            InventoryScrolledBackdrop()
                // EDIT HERE — use statusBackdropProgress below to change how quickly this appears.
                .opacity(statusBackdropProgress)
                .allowsHitTesting(false)

            InventoryCompactHeader(count: visibleProducts.count)
                .opacity(collapseProgress)
                .allowsHitTesting(false)
        }
        .simultaneousGesture(topEdgePullDownGesture)
        .safeAreaInset(edge: .bottom) {
            InventoryBottomBar(searchText: $searchText, openPlayground: onOpenPlayMode) {
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

    private var topEdgePullDownGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard InventoryTopEdgePullDownGesture.shouldReturn(
                    startY: value.startLocation.y,
                    translationHeight: value.translation.height
                ) else { return }
                onOpenPlayMode()
            }
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

    private var statusBackdropProgress: CGFloat {
        // EDIT HERE — smaller divisor makes the status-bar background become opaque sooner.
        min(max(scrollOffset / 24, 0), 1)
    }
}

private struct InventoryScrolledBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.sky, AppTheme.sky, AppTheme.sky, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            // EDIT HERE — height of the opaque-to-clear scrolled header background.
            .frame(height: 152)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(edges: .top)
    }
}

private struct InventoryExpandedHeader: View {
    @Binding var selectedFilter: InventoryFilter
    let productCount: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Image("inventory-title")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 189, height: 41)
                    .accessibilityLabel("Inventory")
                Spacer()
                if selectedFilter == .all {
                    Text("\(productCount) items")
                        .font(AppTypography.captionRegular)
                        .foregroundStyle(.white)
                }
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
                                .font(AppTypography.smallBodySemibold)
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
            VStack(spacing: 0) {
                Image("inventory-title")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 20)
                    .accessibilityLabel("Inventory")
                Text("\(count) items")
                    .font(AppTypography.captionRegular)
            }
            .foregroundStyle(.white)
            .padding(.top, 8)
            .frame(height: 104, alignment: .top)
            Spacer()
        }
    }
}

private struct InventoryBottomBar: View {
    @Binding var searchText: String
    let openPlayground: () -> Void
    let addAction: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: openPlayground) {
                    Image(systemName: "gamecontroller.fill")
                        .font(AppTypography.heading)
                        .frame(width: 44, height: 48)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(AppTheme.selectedBlue)
                .accessibilityLabel("Playground")

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
                        .font(AppTypography.productTitle)
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
