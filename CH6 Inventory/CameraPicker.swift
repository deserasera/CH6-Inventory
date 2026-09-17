import SwiftUI
import UIKit

enum CameraPickerResult {
    case image(Data)
    case cancelled
    case failed
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (CameraPickerResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            Task { @MainActor in
                completion(.failed)
            }
            return picker
        }

        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let completion: (CameraPickerResult) -> Void

        init(completion: @escaping (CameraPickerResult) -> Void) {
            self.completion = completion
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                completion(.failed)
                return
            }

            completion(.image(data))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(.cancelled)
        }
    }
}
