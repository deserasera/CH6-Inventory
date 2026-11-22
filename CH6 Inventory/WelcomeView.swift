import SwiftUI
import UIKit

enum WelcomeProductLayout {
    static let blockSize = CGSize(width: 100, height: 100)
    static let imageInset: CGFloat = 8

    static func imageFrame(blockSize: CGSize, inset: CGFloat) -> CGRect {
        CGRect(
            x: inset,
            y: inset,
            width: max(blockSize.width - inset * 2, 0),
            height: max(blockSize.height - inset * 2, 0)
        )
    }
}

struct WelcomeView: View {
    let products: [Product]
    let onComplete: () -> Void

    @State private var physics = WelcomePhysicsState()
    @State private var lastTick: Date?
    @State private var soundPlayer = IceImpactSoundPlayer()
    @State private var impactFeedbackGate = WelcomeImpactFeedbackGate()
    @State private var impactHaptic = UIImpactFeedbackGenerator(style: .rigid)
    @StateObject private var motionController = WelcomeMotionController()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                ZStack {
                    Image("playground-background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                    WelcomeProductField(
                        products: products,
                        bodies: physics.bodies
                    )
                    Button(action: onComplete) {
                        Image(systemName: "xmark")
                            .font(AppTypography.productTitle)
                            .foregroundStyle(AppTheme.selectedBlue)
                            .frame(width: 48, height: 48)
                            .glassEffect(.clear.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close playground")
                    .position(x: 40, y: 84)
                }
                .contentShape(Rectangle())
                .onAppear {
                    physics.reconcile(products: products, in: proxy.size)
                    lastTick = context.date
                    impactHaptic.prepare()
                    motionController.start()
                }
                .onDisappear(perform: motionController.stop)
                .onChange(of: products) { _, newProducts in
                    physics.reconcile(products: newProducts, in: proxy.size)
                }
                .onChange(of: context.date) { oldDate, newDate in
                    let previous = lastTick ?? oldDate
                    if let impact = physics.step(
                        deltaTime: newDate.timeIntervalSince(previous),
                        in: proxy.size,
                        gravity: motionController.gravity
                    ), impactFeedbackGate.shouldTrigger(
                        impactSpeed: impact.speed,
                        motionSpeed: physics.maximumMotionSpeed,
                        at: newDate.timeIntervalSinceReferenceDate
                    ) {
                        soundPlayer.play(impactSpeed: impact.speed)
                        impactHaptic.impactOccurred(intensity: Self.hapticIntensity(
                            for: impact.speed
                        ))
                        impactHaptic.prepare()
                    }
                    lastTick = newDate
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityAction(named: "Close play mode") {
            onComplete()
        }
    }

    private static func hapticIntensity(for impactSpeed: CGFloat) -> CGFloat {
        min(max((impactSpeed - 42) / 240, 0.35), 1)
    }
}

private struct WelcomeProductField: View {
    let products: [Product]
    let bodies: [Product.ID: WelcomeBody]

    var body: some View {
        ForEach(products) { product in
            if let body = bodies[product.id] {
                WelcomeProductBlock(product: product)
                    .rotationEffect(.degrees(body.angle))
                    .position(body.position)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct WelcomeProductBlock: View {
    let product: Product

    var body: some View {
        ZStack {
            Image("playground-product-block")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)

            ProductImageView(product: product, contentMode: .fit)
                .frame(width: 50, height: 50, alignment: .center)
                .scaleEffect(1.6)
        }
        // The 100 pt artwork matches the existing physics collider.
        .frame(width: 100, height: 100, alignment: .center)
        .accessibilityLabel(product.name)
    }
}

#Preview("Welcome with sample products") {
    WelcomeView(products: Product.samples()) { }
        .preferredColorScheme(.light)
}
