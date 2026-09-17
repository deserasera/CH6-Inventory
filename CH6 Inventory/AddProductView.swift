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
}

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = AddProductDraft()
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isPhotoLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var activeAlert: AddProductAlert?
    @State private var isAlertPresented = false

    var body: some View {
        NavigationStack {
            Form {
                // Photo
                AddProductPhotoSection(
                    photoData: photoData,
                    isLoading: isLoadingPhoto,
                    chooseFromLibrary: { isPhotoLibraryPresented = true },
                    takePhoto: presentCamera
                )

                // Identity
                AddProductIdentitySection(brand: $draft.brand, name: $draft.name)

                // Usage
                AddProductUsageSection(
                    isInUse: $draft.isInUse,
                    openedDate: $draft.openedDate
                )

                // Shelf life
                AddProductShelfLifeSection(months: $draft.periodAfterOpeningMonths)

                // Dates
                AddProductDatesSection(expirationDate: $draft.printedExpirationDate)
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid(hasPhoto: photoData != nil))
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
                "Unable to Add Product",
                isPresented: $isAlertPresented,
                presenting: activeAlert
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { alert in
                Text(alert.message)
            }
        }
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
            photoData = data
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
            photoData = data
        } catch is CancellationError {
            return
        } catch {
            presentAlert(.photoLoadingFailed)
        }
    }

    private func save() {
        guard let photoData, draft.isValid(hasPhoto: true) else { return }

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

private struct AddProductPhotoSection: View {
    let photoData: Data?
    let isLoading: Bool
    let chooseFromLibrary: () -> Void
    let takePhoto: () -> Void

    var body: some View {
        Section("Photo") {
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)

                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }

                    if isLoading {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        ProgressView("Loading Photo")
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(photoData == nil ? "No product photo selected" : "Selected product photo")
                Spacer()
            }

            Menu {
                Button(action: takePhoto) {
                    Label("Take Photo", systemImage: "camera")
                }
                Button(action: chooseFromLibrary) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
            }
            .disabled(isLoading)
        }
    }
}

private struct AddProductIdentitySection: View {
    @Binding var brand: String
    @Binding var name: String

    var body: some View {
        Section("Identity") {
            TextField("Brand", text: $brand)
                .textInputAutocapitalization(.words)
            TextField("Product Name", text: $name)
                .textInputAutocapitalization(.words)
        }
    }
}

private struct AddProductUsageSection: View {
    @Binding var isInUse: Bool
    @Binding var openedDate: Date?

    var body: some View {
        Section("Usage") {
            Toggle("Currently in Use", isOn: $isInUse)
                .onChange(of: isInUse) { _, newValue in
                    openedDate = newValue ? (openedDate ?? .now) : nil
                }

            if let openedDate = Binding($openedDate) {
                DatePicker("Opened", selection: openedDate, displayedComponents: .date)
            }
        }
    }
}

private struct AddProductShelfLifeSection: View {
    @Binding var months: Int

    var body: some View {
        Section("Shelf Life") {
            Stepper(value: $months, in: 1...60) {
                Text("Period After Opening: \(months) months")
            }
        }
    }
}

private struct AddProductDatesSection: View {
    @Binding var expirationDate: Date

    var body: some View {
        Section("Dates") {
            DatePicker(
                "Printed Expiration",
                selection: $expirationDate,
                displayedComponents: .date
            )
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
