import SwiftUI
import UIKit

enum AppTheme {
    static let sky = Color(red: 104 / 255, green: 164 / 255, blue: 211 / 255)
    static let ice = Color(red: 216 / 255, green: 230 / 255, blue: 242 / 255)
    static let deepBlue = Color(red: 23 / 255, green: 72 / 255, blue: 113 / 255)
    static let selectedBlue = Color(red: 49 / 255, green: 108 / 255, blue: 155 / 255)
    static let warning = Color(red: 204 / 255, green: 74 / 255, blue: 83 / 255)
}

enum AppTypography {
    static let displayTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let productTitle = Font.system(size: 24, weight: .bold, design: .default)
    static let heading = Font.system(size: 17, weight: .semibold, design: .default)
    static let smallBodySemibold = Font.system(size: 13, weight: .semibold, design: .default)
    static let smallBodyRegular = Font.system(size: 13, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)
    static let captionRegular = Font.system(size: 11, weight: .regular, design: .default)
}

struct IcyBackground: View {
    let snowOffset: CGFloat
    var blurRadius: CGFloat = 0
    var snowOpacity: Double = 0.75

    var body: some View {
        LinearGradient(
            colors: [AppTheme.sky, AppTheme.ice],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            GeometryReader { proxy in
                let assetSize = UIImage(named: "snow-background")?.size ?? .zero
                let scaledSize = Self.scaledSnowSize(
                    assetSize: assetSize,
                    containerWidth: proxy.size.width
                )

                Image("snow-background")
                    .resizable()
                    .frame(width: scaledSize.width, height: scaledSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(snowOpacity)
                    .blur(radius: blurRadius)
                    .offset(y: snowOffset)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
    }

    static func scaledSnowSize(assetSize: CGSize, containerWidth: CGFloat) -> CGSize {
        guard assetSize.width > 0, containerWidth > 0 else { return .zero }
        return CGSize(
            width: containerWidth,
            height: containerWidth * assetSize.height / assetSize.width
        )
    }

    static func detailBackgroundSize(assetSize: CGSize, containerSize: CGSize) -> CGSize {
        guard assetSize.width > 0,
              assetSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else { return .zero }
        return scaledSnowSize(
            assetSize: assetSize,
            containerWidth: containerSize.width * 1.2
        )
    }
}
