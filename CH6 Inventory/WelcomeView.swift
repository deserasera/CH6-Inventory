import SwiftUI

struct WelcomeView: View {
    let products: [Product]
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var physics = WelcomePhysicsState()
    @State private var lastTick: Date?
    @State private var dragProgress: CGFloat = 0
    @State private var isCompleting = false
    @State private var soundPlayer = IceImpactSoundPlayer()
    @State private var impactSoundGate = WelcomeImpactSoundGate()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion || isCompleting)) { context in
                ZStack {
                    WelcomeTitle(size: proxy.size)
                    WelcomeProductField(
                        products: products,
                        bodies: physics.bodies,
                        isCompleting: isCompleting
                    )
                    Text("\(products.count) items")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.65)
                    WelcomeSwipeAffordance(action: complete)
                        .position(x: proxy.size.width / 2, y: proxy.size.height - 34)
                }
                .contentShape(Rectangle())
                .offset(y: -dragProgress * 0.18 - (isCompleting ? proxy.size.height : 0))
                .opacity(isCompleting ? 0 : 1)
                .gesture(entryGesture(in: proxy.size))
                .onAppear {
                    physics.reconcile(products: products, in: proxy.size)
                    lastTick = context.date
                }
                .onChange(of: products) { _, newProducts in
                    physics.reconcile(products: newProducts, in: proxy.size)
                }
                .onChange(of: context.date) { oldDate, newDate in
                    guard !reduceMotion else { return }
                    let previous = lastTick ?? oldDate
                    if let impact = physics.step(
                        deltaTime: newDate.timeIntervalSince(previous),
                        in: proxy.size
                    ), impactSoundGate.shouldPlayImpact() {
                        soundPlayer.play(impactSpeed: impact.speed)
                    }
                    lastTick = newDate
                }
                .animation(.smooth(duration: 0.7), value: isCompleting)
            }
        }
        .accessibilityAction(named: "Open inventory") {
            complete()
        }
    }

    private func entryGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard value.startLocation.y >= size.height - 150,
                      value.translation.height < 0 else { return }
                dragProgress = min(-value.translation.height, 150)
            }
            .onEnded { value in
                guard value.startLocation.y >= size.height - 150 else {
                    dragProgress = 0
                    return
                }
                let shouldComplete = -value.translation.height > 110
                    || -value.predictedEndTranslation.height > 170
                if shouldComplete {
                    complete()
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.28)) {
                        dragProgress = 0
                    }
                }
            }
    }

    private func complete() {
        guard !isCompleting else { return }
        if reduceMotion {
            onComplete()
        } else {
            withAnimation(.smooth(duration: 0.72, extraBounce: 0.05)) {
                isCompleting = true
                dragProgress = 150
            } completion: {
                onComplete()
            }
        }
    }
}

private struct WelcomeTitle: View {
    let size: CGSize

    var body: some View {
        ZStack {
            titleLayer(
                LinearGradient(
                    colors: [.white, .white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            titleLayer(AppTheme.deepBlue.opacity(0.10))
                .blur(radius: 0.35)
            titleLayer(.white.opacity(0.18))
                .glassEffect(.clear, in: .rect(cornerRadius: 28))
                .mask(titleLayer(.white))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inventory")
    }

    private func titleLayer(_ style: some ShapeStyle) -> some View {
        // EDIT HERE — negative spacing brings the IN / VEN / TORY lines closer together.
        VStack(spacing: -30) {
            Text("IN")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("VEN")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("TORY")
                .frame(maxWidth: .infinity)
        }
        // EDIT HERE — 0.37 and 148 control the responsive and maximum title sizes.
        .font(.system(size: min(size.width * 0.37, 148), weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .foregroundStyle(style)
        .padding(.horizontal, 12)
        .frame(width: size.width)
        // EDIT HERE — change 0.35 to move the whole title vertically.
        .position(x: size.width / 2, y: size.height * 0.35)
    }
}

private struct WelcomeProductField: View {
    let products: [Product]
    let bodies: [Product.ID: WelcomeBody]
    let isCompleting: Bool

    var body: some View {
        ForEach(products) { product in
            if let body = bodies[product.id] {
                WelcomeProductBlock(product: product)
                    .rotationEffect(.degrees(body.angle))
                    .position(body.position)
                    .scaleEffect(isCompleting ? 0.82 : 1)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct WelcomeProductBlock: View {
    let product: Product

    var body: some View {
        ZStack {
            // Product image region supports bundled assets and imported photos.
            ProductImageView(product: product, contentMode: .fit)
                // EDIT HERE — image size inside each welcome block.
                .frame(width: 50, height: 50, alignment: .center)
                .scaleEffect(1.6)
        }
        // EDIT HERE — visible welcome block size. Keep halfSize in WelcomePhysics at half this value.
        .frame(width: 100, height: 100, alignment: .center)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.72), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(product.name)
    }
}

private struct WelcomeSwipeAffordance: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.up")
                // EDIT HERE — chevron glyph size and weight.
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppTheme.deepBlue)
                .shadow(color: .white.opacity(0.9), radius: 5)
                // EDIT HERE — size of the highlighted glass touch target.
                .frame(width: 68, height: 54)
                .glassEffect(.clear.interactive(), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(isPulsing ? 0.85 : 0.42), lineWidth: 1)
                }
                .shadow(
                    color: AppTheme.selectedBlue.opacity(isPulsing ? 0.55 : 0.25),
                    radius: isPulsing ? 14 : 7
                )
                .scaleEffect(isPulsing ? 1.05 : 0.96)
                .offset(y: isPulsing ? -3 : 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else {
                isPulsing = true
                return
            }
            withAnimation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityLabel("Open inventory")
        .accessibilityHint("Swipe up from this area or activate the button")
    }
}
