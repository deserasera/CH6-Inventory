import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddProductDraft {
    var brand = ""
    var name = ""
    var isInUse = false
    var openedDate: Date?
    var periodAfterOpeningMonths = 12
    var printedExpirationDate = Date.now

    init(
        brand: String = "",
        name: String = "",
        isInUse: Bool = false,
        openedDate: Date? = nil,
        periodAfterOpeningMonths: Int = 12,
        printedExpirationDate: Date = Date.now
    ) {
        self.brand = brand
        self.name = name
        self.isInUse = isInUse
        self.openedDate = openedDate
        self.periodAfterOpeningMonths = periodAfterOpeningMonths
        self.printedExpirationDate = printedExpirationDate
    }

    init(product: Product) {
        brand = product.brand
        name = product.name
        isInUse = product.isInUse
        openedDate = product.openedDate
        periodAfterOpeningMonths = product.periodAfterOpeningMonths
        printedExpirationDate = product.printedExpirationDate
    }

    mutating func apply(_ suggestion: ProductIdentitySuggestion) {
        if brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let detectedBrand = suggestion.brand {
            brand = detectedBrand
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let detectedName = suggestion.name {
            name = detectedName
        }
    }

    mutating func setOpened(_ isOpened: Bool, defaultDate: Date = .now) {
        if isOpened {
            openedDate = openedDate ?? defaultDate
        } else {
            openedDate = nil
            isInUse = false
        }
    }

    mutating func setInUse(_ currentlyInUse: Bool, defaultOpenedDate: Date = .now) {
        isInUse = currentlyInUse
        if currentlyInUse {
            openedDate = openedDate ?? defaultOpenedDate
        }
    }

    func isValid(hasPhoto: Bool) -> Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasPhoto
            && (!isInUse || openedDate != nil)
    }

    func makeProduct(photoData: Data) -> Product {
        Product(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData,
            openedDate: openedDate,
            periodAfterOpeningMonths: periodAfterOpeningMonths,
            printedExpirationDate: printedExpirationDate,
            isInUse: isInUse
        )
    }

    func update(_ product: Product, photoData: Data?) {
        product.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        product.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        product.openedDate = openedDate
        product.periodAfterOpeningMonths = periodAfterOpeningMonths
        product.printedExpirationDate = printedExpirationDate
        product.isInUse = isInUse

        if let photoData {
            product.assetName = nil
            product.photoData = photoData
        }
    }
}

enum AddProductLayout {
    enum PhotoPlacement {
        case outsideForm
    }

    static let photoPlacement: PhotoPlacement = .outsideForm
}

struct AddProductView: View {
    private let productToEdit: Product?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddProductDraft
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isPhotoLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var activeAlert: AddProductAlert?
    @State private var isAlertPresented = false

    @MainActor
    init(product: Product? = nil) {
        productToEdit = product
        _draft = State(initialValue: product.map(AddProductDraft.init) ?? AddProductDraft())
        _photoData = State(initialValue: product?.photoData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AddProductPhotoControl(
                        photoData: photoData,
                        existingProduct: productToEdit,
                        isLoading: isLoadingPhoto,
                        chooseFromLibrary: { isPhotoLibraryPresented = true },
                        takePhoto: presentCamera
                    )
                    .padding(.top, 12)

                    AddProductIdentitySection(brand: $draft.brand, name: $draft.name)
                    AddProductUsageSection(
                        isInUse: $draft.isInUse,
                        openedDate: $draft.openedDate
                    )
                    AddProductExpirationSection(
                        months: $draft.periodAfterOpeningMonths,
                        expirationDate: $draft.printedExpirationDate
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(.white)
            .navigationTitle(productToEdit == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .presentationCornerRadius(36)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .tint(AppTheme.sky)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid(hasPhoto: hasPhoto))
                        .tint(AppTheme.sky)
                }
            }
            .photosPicker(
                isPresented: $isPhotoLibraryPresented,
                selection: $selectedPhoto,
                matching: .images
            )
            .task(id: selectedPhoto) {
                await loadSelectedPhoto()
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraPicker(completion: handleCameraResult)
                    .ignoresSafeArea()
            }
            .alert(
                productToEdit == nil ? "Unable to Add Product" : "Unable to Edit Product",
                isPresented: $isAlertPresented,
                presenting: activeAlert
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { alert in
                Text(alert.message)
            }
        }
    }

    private var hasPhoto: Bool {
        photoData != nil || productToEdit?.assetName != nil
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentAlert(.cameraUnavailable)
            return
        }
        isCameraPresented = true
    }

    private func handleCameraResult(_ result: CameraPickerResult) {
        isCameraPresented = false

        switch result {
        case .image(let data):
            Task {
                isLoadingPhoto = true
                defer { isLoadingPhoto = false }
                await processPhoto(data)
            }
        case .cancelled:
            break
        case .failed:
            presentAlert(.photoCaptureFailed)
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }

        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            self.selectedPhoto = nil
        }

        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                  UIImage(data: data) != nil else {
                presentAlert(.photoLoadingFailed)
                return
            }
            await processPhoto(data)
        } catch is CancellationError {
            return
        } catch {
            presentAlert(.photoLoadingFailed)
        }
    }

    private func processPhoto(_ data: Data) async {
        let processedPhoto = await ProductPhotoProcessor.process(data)
        photoData = processedPhoto.photoData
        draft.apply(processedPhoto.identity)
    }

    private func save() {
        guard draft.isValid(hasPhoto: hasPhoto) else { return }

        if let productToEdit {
            draft.update(productToEdit, photoData: photoData)

            do {
                try modelContext.save()
                dismiss()
            } catch {
                modelContext.rollback()
                presentAlert(.saveFailed)
            }
            return
        }

        guard let photoData else { return }

        let product = draft.makeProduct(photoData: photoData)
        modelContext.insert(product)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(product)
            presentAlert(.saveFailed)
        }
    }

    private func presentAlert(_ alert: AddProductAlert) {
        activeAlert = alert
        isAlertPresented = true
    }
}

private struct AddProductPhotoControl: View {
    let photoData: Data?
    let existingProduct: Product?
    let isLoading: Bool
    let chooseFromLibrary: () -> Void
    let takePhoto: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.ice)

                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if let existingProduct, existingProduct.imageSource != .placeholder {
                    ProductImageView(product: existingProduct, contentMode: .fit)
                        .padding(8)
                }

                if isLoading {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    ProgressView("Loading Photo")
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityLabel(hasPhoto ? "Selected product photo" : "No product photo selected")

            Menu {
                Button(action: takePhoto) {
                    Label("Take Photo", systemImage: "camera")
                }
                Button(action: chooseFromLibrary) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Text("Change Photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.sky)
            .disabled(isLoading)
        }
    }

    private var hasPhoto: Bool {
        photoData != nil || existingProduct?.imageSource != .placeholder
    }
}

private struct AddProductIdentitySection: View {
    @Binding var brand: String
    @Binding var name: String

    var body: some View {
        AddProductSection(title: "Identity") {
            TextField("Name", text: $brand)
                .textInputAutocapitalization(.words)
                .frame(height: 48)
            Divider()
            TextField("Product Name", text: $name)
                .textInputAutocapitalization(.words)
                .frame(height: 48)
        }
    }
}

private struct AddProductUsageSection: View {
    @Binding var isInUse: Bool
    @Binding var openedDate: Date?

    var body: some View {
        AddProductSection(title: "Usage") {
            Toggle("Opened", isOn: isOpenedBinding)
                .frame(height: 54)

            if let openedDate = Binding($openedDate) {
                Divider()
                DatePicker("Date Opened", selection: openedDate, displayedComponents: .date)
                    .frame(height: 54)
            }

            Divider()
            Toggle("Currently in Use", isOn: isInUseBinding)
                .disabled(openedDate == nil)
                .frame(height: 54)
        }
    }

    private var isOpenedBinding: Binding<Bool> {
        Binding {
            openedDate != nil
        } set: { isOpened in
            if isOpened {
                openedDate = openedDate ?? .now
            } else {
                openedDate = nil
                isInUse = false
            }
        }
    }

    private var isInUseBinding: Binding<Bool> {
        Binding {
            isInUse
        } set: { currentlyInUse in
            isInUse = currentlyInUse
            if currentlyInUse {
                openedDate = openedDate ?? .now
            }
        }
    }
}

private struct AddProductExpirationSection: View {
    @Binding var months: Int
    @Binding var expirationDate: Date

    var body: some View {
        AddProductSection(title: "Expiration") {
            Stepper(value: $months, in: 1...60) {
                HStack {
                    Text("Period After Opening (PAO)")
                    Spacer()
                    Text("\(months) Months")
                        .foregroundStyle(AppTheme.deepBlue)
                }
            }
            .frame(height: 60)
            Divider()
            DatePicker(
                "Printed Expiration Date",
                selection: $expirationDate,
                displayedComponents: .date
            )
            .frame(height: 54)
        }
    }
}

private struct AddProductSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(AppTypography.heading)
                    .foregroundStyle(AppTheme.deepBlue)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .font(AppTypography.smallBodyRegular)
            .foregroundStyle(AppTheme.deepBlue)
            .padding(.horizontal, 16)
            .background(AppTheme.ice.opacity(0.42), in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

private enum AddProductAlert {
    case cameraUnavailable
    case photoCaptureFailed
    case photoLoadingFailed
    case saveFailed

    var message: LocalizedStringResource {
        switch self {
        case .cameraUnavailable:
            "The camera is not available on this device. Choose a photo from the library instead."
        case .photoCaptureFailed:
            "The photo could not be prepared. Please take another photo."
        case .photoLoadingFailed:
            "The selected photo could not be loaded. Please choose another photo."
        case .saveFailed:
            "The product could not be saved. Please try again."
        }
    }
}
