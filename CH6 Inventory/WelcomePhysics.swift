import CoreGraphics
import Foundation

struct WelcomeBody: Equatable, Sendable {
    let productID: Product.ID
    var position: CGPoint
    var velocity: CGVector
    var angle: Double
    var angularVelocity: Double
    // EDIT HERE — collider half-size; 50 matches the visible 100×100 block.
    var halfSize: CGFloat = 50

    var rotatedExtent: CGFloat {
        let radians = angle * .pi / 180
        return halfSize * (abs(cos(radians)) + abs(sin(radians)))
    }
}

struct WelcomeImpact: Equatable, Sendable {
    let speed: CGFloat
}

struct WelcomePhysicsState: Sendable {
    // EDIT HERE — extra invisible spacing around each 100 pt square collider.
    private static let collisionSkin: CGFloat = 1.5
    private(set) var bodies: [Product.ID: WelcomeBody] = [:]

    mutating func reconcile(products: [Product], in size: CGSize) {
        let validIDs = Set(products.map(\.id))
        bodies = bodies.filter { validIDs.contains($0.key) }

        for (index, product) in products.enumerated() where bodies[product.id] == nil {
            bodies[product.id] = makeBody(for: product.id, index: index, size: size)
        }

        settleBodies(in: size)
    }

    @discardableResult
    mutating func step(deltaTime rawDeltaTime: TimeInterval, in size: CGSize) -> WelcomeImpact? {
        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 30.0)
        guard deltaTime > 0 else { return nil }
        let ids = sortedIDs
        var strongestImpact: CGFloat = 0

        for id in ids {
            guard var body = bodies[id] else { continue }
            // EDIT HERE — increase gravity for a faster/heavier fall; decrease for a floatier fall.
            body.velocity.dy += 980 * deltaTime
            body.position.x += body.velocity.dx * deltaTime
            body.position.y += body.velocity.dy * deltaTime
            body.angle += body.angularVelocity * deltaTime
            body.velocity.dx *= 0.994
            body.velocity.dy *= 0.994
            body.angularVelocity *= 0.992
            strongestImpact = max(strongestImpact, resolveBounds(for: &body, in: size))
            bodies[id] = body
        }

        // Iterative SAT resolution prevents a correction in a dense group from
        // pushing one rotating square through a neighboring square.
        for _ in 0..<32 {
            for firstIndex in ids.indices {
                for secondIndex in ids.indices where secondIndex > firstIndex {
                    strongestImpact = max(
                        strongestImpact,
                        resolveCollision(ids[firstIndex], ids[secondIndex])
                    )
                }
            }
            // Bounds are another collision constraint. Solving them every pass
            // prevents the final screen-edge correction from pushing a square
            // back through a neighbor at the bottom of a dense pile.
            for id in ids {
                guard var body = bodies[id] else { continue }
                _ = resolveBounds(for: &body, in: size, applyBounce: false)
                bodies[id] = body
            }
        }

        for id in ids {
            if var body = bodies[id] {
                strongestImpact = max(strongestImpact, resolveBounds(for: &body, in: size))
                bodies[id] = body
            }
        }

        return strongestImpact >= 42 ? WelcomeImpact(speed: strongestImpact) : nil
    }

    static func overlaps(
        _ first: WelcomeBody,
        _ second: WelcomeBody,
        tolerance: CGFloat = 0
    ) -> Bool {
        collisionManifold(first, second, padding: 0)?.depth ?? 0 > tolerance
    }

    private var sortedIDs: [Product.ID] {
        bodies.keys.sorted { $0.uuidString < $1.uuidString }
    }

    private mutating func settleBodies(in size: CGSize) {
        let ids = sortedIDs
        for _ in 0..<16 {
            for firstIndex in ids.indices {
                for secondIndex in ids.indices where secondIndex > firstIndex {
                    _ = resolveCollision(ids[firstIndex], ids[secondIndex], applyImpulse: false)
                }
            }
            for id in ids {
                guard var body = bodies[id] else { continue }
                _ = resolveBounds(for: &body, in: size, applyBounce: false)
                bodies[id] = body
            }
        }
    }

    private func makeBody(for id: Product.ID, index: Int, size: CGSize) -> WelcomeBody {
        let referenceXPositions: [CGFloat] = [
            315, 230, 112, 316, 105, 253, 113, 337
        ]
        let unit = deterministicUnit(for: id)
        let angle = (unit.x - 0.5) * 32
        let halfSize: CGFloat = 50
        let radians = angle * .pi / 180
        let rotatedExtent = halfSize * (abs(cos(radians)) + abs(sin(radians)))
        let xPosition: CGFloat
        if index < referenceXPositions.count {
            xPosition = referenceXPositions[index] / 402 * max(size.width, 1)
        } else {
            xPosition = 58 + unit.x * max(size.width - 116, 1)
        }
        // Start every block fully above the viewport and stagger their entry.
        let yPosition = -rotatedExtent - 12 - CGFloat(index) * 164

        return WelcomeBody(
            productID: id,
            position: CGPoint(x: xPosition, y: yPosition),
            // EDIT HERE — `dy` controls how quickly newly created cubes begin falling.
            velocity: CGVector(dx: (unit.x - 0.5) * 36, dy: 55 + unit.y * 90),
            angle: angle,
            angularVelocity: (unit.y - 0.5) * 4,
            halfSize: halfSize
        )
    }

    private func deterministicUnit(for id: UUID) -> CGPoint {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let x = CGFloat((Int(bytes[0]) * 257 + Int(bytes[5]))) / 65790
        let y = CGFloat((Int(bytes[10]) * 257 + Int(bytes[15]))) / 65790
        return CGPoint(x: x, y: y)
    }

    private func resolveBounds(
        for body: inout WelcomeBody,
        in size: CGSize,
        applyBounce: Bool = true
    ) -> CGFloat {
        let radians = body.angle * .pi / 180
        let collisionHalfSize = body.halfSize + Self.collisionSkin
        let extent = collisionHalfSize * (abs(cos(radians)) + abs(sin(radians)))
        let minX = extent
        let maxX = max(size.width - extent, minX)
        let maxY = max(size.height - extent, extent + 24)
        var impact: CGFloat = 0

        if body.position.x < minX || body.position.x > maxX {
            impact = max(impact, abs(body.velocity.dx))
            body.position.x = min(max(body.position.x, minX), maxX)
            if applyBounce { body.velocity.dx *= -0.34 }
        }
        if body.position.y > maxY {
            impact = max(impact, abs(body.velocity.dy))
            body.position.y = maxY
            if applyBounce { body.velocity.dy *= -0.31 }
        }
        return impact
    }

    private mutating func resolveCollision(
        _ firstID: Product.ID,
        _ secondID: Product.ID,
        applyImpulse: Bool = true
    ) -> CGFloat {
        guard var first = bodies[firstID],
              var second = bodies[secondID],
              let manifold = Self.collisionManifold(
                first,
                second,
                padding: Self.collisionSkin
              ) else { return 0 }

        let correction = max(manifold.depth - 0.0001, 0) / 2
        first.position.x -= manifold.normal.dx * correction
        first.position.y -= manifold.normal.dy * correction
        second.position.x += manifold.normal.dx * correction
        second.position.y += manifold.normal.dy * correction

        let relativeSpeed = (second.velocity.dx - first.velocity.dx) * manifold.normal.dx
            + (second.velocity.dy - first.velocity.dy) * manifold.normal.dy
        let impactSpeed = max(-relativeSpeed, 0)
        if applyImpulse, relativeSpeed < 0 {
            let impulse = -(1 + 0.28) * relativeSpeed / 2
            first.velocity.dx -= impulse * manifold.normal.dx
            first.velocity.dy -= impulse * manifold.normal.dy
            second.velocity.dx += impulse * manifold.normal.dx
            second.velocity.dy += impulse * manifold.normal.dy
        }

        bodies[firstID] = first
        bodies[secondID] = second
        return impactSpeed
    }

    private static func collisionManifold(
        _ first: WelcomeBody,
        _ second: WelcomeBody,
        padding: CGFloat
    ) -> (normal: CGVector, depth: CGFloat)? {
        let firstAxes = axes(for: first.angle)
        let secondAxes = axes(for: second.angle)
        let axes = [firstAxes.0, firstAxes.1, secondAxes.0, secondAxes.1]
        let delta = CGVector(
            dx: second.position.x - first.position.x,
            dy: second.position.y - first.position.y
        )
        var minimumDepth = CGFloat.greatestFiniteMagnitude
        var minimumAxis = axes[0]

        for axis in axes {
            let centerDistance = abs(dot(delta, axis))
            let firstRadius = projectedRadius(of: first, onto: axis, padding: padding)
            let secondRadius = projectedRadius(of: second, onto: axis, padding: padding)
            let depth = firstRadius + secondRadius - centerDistance
            guard depth > 0 else { return nil }
            if depth < minimumDepth {
                minimumDepth = depth
                minimumAxis = dot(delta, axis) < 0
                    ? CGVector(dx: -axis.dx, dy: -axis.dy)
                    : axis
            }
        }

        return (minimumAxis, minimumDepth)
    }

    private static func projectedRadius(
        of body: WelcomeBody,
        onto axis: CGVector,
        padding: CGFloat
    ) -> CGFloat {
        let bodyAxes = axes(for: body.angle)
        return (body.halfSize + padding) * (
            abs(dot(bodyAxes.0, axis)) + abs(dot(bodyAxes.1, axis))
        )
    }

    private static func axes(for angle: Double) -> (CGVector, CGVector) {
        let radians = angle * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        return (
            CGVector(dx: cosine, dy: sine),
            CGVector(dx: -sine, dy: cosine)
        )
    }

    private static func dot(_ first: CGVector, _ second: CGVector) -> CGFloat {
        first.dx * second.dx + first.dy * second.dy
    }
}
