import SwiftUI

enum AppTheme {
    static let sky = Color(red: 104 / 255, green: 164 / 255, blue: 211 / 255)
    static let ice = Color(red: 216 / 255, green: 230 / 255, blue: 242 / 255)
    static let deepBlue = Color(red: 23 / 255, green: 72 / 255, blue: 113 / 255)
    static let selectedBlue = Color(red: 49 / 255, green: 108 / 255, blue: 155 / 255)
    static let warning = Color(red: 204 / 255, green: 74 / 255, blue: 83 / 255)
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
            Image("snow-background")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 558)
                .opacity(snowOpacity)
                .blur(radius: blurRadius)
                .offset(y: snowOffset)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}
