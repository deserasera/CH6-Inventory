import SwiftUI

struct ExpirationBar: View {
    let progress: Double
    var height: CGFloat = 21
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.ice)
                Capsule()
                    .fill(AppTheme.deepBlue)
                    .frame(width: Self.fillWidth(
                        totalWidth: proxy.size.width,
                        progress: displayedProgress
                    ))
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.30), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 48)
                        .clipShape(Capsule())
                    }
            }
        }
        .frame(height: height)
        .onAppear {
            if reduceMotion {
                displayedProgress = progress
            } else {
                withAnimation(.smooth(duration: 0.85, extraBounce: 0.08)) {
                    displayedProgress = progress
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shelf life remaining")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    static func fillWidth(totalWidth: Double, progress: Double) -> Double {
        totalWidth * min(max(progress, 0), 1)
    }
}
