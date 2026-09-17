import SwiftUI
import UIKit

enum ProductImageSource: Equatable {
    case photoData(Data)
    case asset(String)
    case placeholder
}

extension Product {
    var imageSource: ProductImageSource {
        if let photoData {
            return .photoData(photoData)
        }
        if let assetName {
            return .asset(assetName)
        }
        return .placeholder
    }
}

struct ProductImageView: View {
    let product: Product
    let contentMode: ContentMode

    var body: some View {
        switch product.imageSource {
        case .photoData(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholderImage
            }
        case .asset(let assetName):
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        case .placeholder:
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}
