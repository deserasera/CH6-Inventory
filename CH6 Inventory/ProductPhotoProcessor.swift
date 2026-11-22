import CoreImage
import Foundation
import UIKit
import Vision

struct ProductTextObservation: Equatable, Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct ProductIdentitySuggestion: Equatable, Sendable {
    let brand: String?
    let name: String?
}

struct ProcessedProductPhoto: Sendable {
    let photoData: Data
    let identity: ProductIdentitySuggestion
}

enum ProductIdentityDetector {
    nonisolated private static let knownBrands: [String: String] = {
        let brands = [
            "AESTURA", "ANUA", "Aquaphor", "Avène", "Aveeno", "Beauty of Joseon",
            "Biodance", "Biossance", "BYOMA", "Caudalie", "CeraVe", "Cetaphil",
            "CHANEL", "Clarins", "Clinique", "cocokind", "COSRX", "Dermalogica",
            "Dior", "Dr. Jart+", "Drunk Elephant", "Estée Lauder", "FARMACY",
            "First Aid Beauty", "fresh", "Garnier", "Good Molecules", "Hero Cosmetics",
            "Isntree", "Kiehl’s", "Laneige", "La Roche-Posay", "medicube", "MEDIHEAL",
            "Minimalist", "MISSHA", "Mixsoon", "Murad", "Naturium", "Neutrogena",
            "The Ordinary", "PEACH & LILY", "Shiseido", "SK-II", "SKIN1004",
            "Skinfix", "Skintific", "Sol de Janeiro", "SOME BY MI", "Sulwhasoo",
            "Summer Fridays", "Sunday Riley", "Supergoop!", "TATCHA", "The INKEY List",
            "TIRTIR", "TONYMOLY", "TULA", "Versed"
        ]
        return Dictionary(uniqueKeysWithValues: brands.map { (normalize($0), $0) })
    }()

    nonisolated private static let productTerms = [
        "balm", "cleanser", "cleansing", "cream", "essence", "exfoliant", "gel",
        "lotion", "mask", "mist", "moisturizer", "oil", "serum", "solution",
        "sunscreen", "toner", "treatment", "wash"
    ]

    nonisolated private static let ignoredPhrases = [
        "dermatologist tested", "for external use", "ingredients", "made in",
        "normal skin", "sensitive skin", "all skin types", "directions"
    ]

    nonisolated static func suggestion(
        from observations: [ProductTextObservation]
    ) -> ProductIdentitySuggestion {
        let usable = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.confidence >= 0.55
        }
        let brandMatch = bestBrandMatch(in: usable)
        let name = bestProductName(in: usable, excluding: brandMatch?.observation)
        return ProductIdentitySuggestion(brand: brandMatch?.canonicalName, name: name)
    }

    nonisolated private static func bestBrandMatch(
        in observations: [ProductTextObservation]
    ) -> (canonicalName: String, observation: ProductTextObservation)? {
        let matches = observations.compactMap { observation -> (String, ProductTextObservation, Double)? in
            guard observation.confidence >= 0.72,
                  let canonicalName = knownBrands[normalize(observation.text)] else { return nil }
            let prominence = min(Double(observation.boundingBox.height / 0.12), 1)
            let score = Double(observation.confidence) * 0.65
                + Double(observation.boundingBox.midY) * 0.20
                + prominence * 0.15
            return (canonicalName, observation, score)
        }
        .sorted { $0.2 > $1.2 }

        guard let first = matches.first else { return nil }
        if matches.count > 1, first.2 - matches[1].2 < 0.08 {
            return nil
        }
        return (first.0, first.1)
    }

    nonisolated private static func bestProductName(
        in observations: [ProductTextObservation],
        excluding brandObservation: ProductTextObservation?
    ) -> String? {
        let candidates = observations.compactMap { observation -> (String, Double)? in
            guard observation != brandObservation,
                  observation.confidence >= 0.65 else { return nil }
            let text = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = text.lowercased()
            guard text.count >= 4,
                  !looksLikeQuantity(lowercased),
                  !ignoredPhrases.contains(where: lowercased.contains) else { return nil }

            let hasProductTerm = productTerms.contains(where: lowercased.contains)
            guard hasProductTerm || observation.confidence >= 0.88 else { return nil }

            let prominence = min(Double(observation.boundingBox.height / 0.12), 1)
            let categoryBonus = hasProductTerm ? 0.18 : 0
            let score = Double(observation.confidence) * 0.62
                + prominence * 0.20
                + categoryBonus
            guard score >= 0.72 else { return nil }
            return (text, score)
        }
        .sorted { $0.1 > $1.1 }

        guard let first = candidates.first else { return nil }
        if candidates.count > 1, first.1 - candidates[1].1 < 0.04 {
            return nil
        }
        return first.0
    }

    nonisolated private static func looksLikeQuantity(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        return compact.range(
            of: #"^\d+([.,]\d+)?(ml|g|kg|oz|fl\.oz|%)$"#,
            options: .regularExpression
        ) != nil
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

enum ProductPhotoProcessor {
    static func process(_ data: Data) async -> ProcessedProductPhoto {
        await Task.detached(priority: .userInitiated) {
            processSynchronously(data)
        }.value
    }

    nonisolated private static func processSynchronously(_ data: Data) -> ProcessedProductPhoto {
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            return ProcessedProductPhoto(
                photoData: data,
                identity: ProductIdentitySuggestion(brand: nil, name: nil)
            )
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        let foregroundRequest = VNGenerateForegroundInstanceMaskRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLanguages = ["en-US", "id-ID"]

        do {
            try handler.perform([foregroundRequest, textRequest])
        } catch {
            return ProcessedProductPhoto(
                photoData: data,
                identity: ProductIdentitySuggestion(brand: nil, name: nil)
            )
        }

        let recognizedText: [VNRecognizedTextObservation] = textRequest.results ?? []
        let textObservations: [ProductTextObservation] = recognizedText.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return ProductTextObservation(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
        let identity = ProductIdentityDetector.suggestion(from: textObservations)
        let transparentData = transparentSquarePNG(
            observation: foregroundRequest.results?.first,
            handler: handler
        ) ?? data

        return ProcessedProductPhoto(photoData: transparentData, identity: identity)
    }

    nonisolated private static func transparentSquarePNG(
        observation: VNInstanceMaskObservation?,
        handler: VNImageRequestHandler
    ) -> Data? {
        guard let observation, !observation.allInstances.isEmpty,
              let pixelBuffer = try? observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
              ) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let maskedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let subject = UIImage(cgImage: maskedCGImage)
        let side = max(subject.size.width, subject.size.height) / 0.84
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let squareImage = renderer.image { _ in
            let origin = CGPoint(
                x: (side - subject.size.width) / 2,
                y: (side - subject.size.height) / 2
            )
            subject.draw(at: origin)
        }
        return squareImage.pngData()
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
