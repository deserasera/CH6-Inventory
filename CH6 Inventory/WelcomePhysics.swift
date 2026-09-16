import CoreGraphics
import Foundation

struct WelcomeBody: Equatable, Sendable {
    let productID: Product.ID
    var position: CGPoint
    var velocity: CGVector
    var angle: Double
    var angularVelocity: Double
    var radius: CGFloat = 50
}

struct WelcomePhysicsState: Sendable {
    private(set) var bodies: [Product.ID: WelcomeBody] = [:]

    mutating func reconcile(products: [Product], in size: CGSize) {
        let validIDs = Set(products.map(\.id))
        bodies = bodies.filter { validIDs.contains($0.key) }

        for (index, product) in products.enumerated() where bodies[product.id] == nil {
            bodies[product.id] = makeBody(for: product.id, index: index, size: size)
        }
    }

    mutating func step(deltaTime rawDeltaTime: TimeInterval, in size: CGSize) {
        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 20.0)
        guard deltaTime > 0 else { return }
        let ids = bodies.keys.sorted { $0.uuidString < $1.uuidString }

        for id in ids {
            guard var body = bodies[id] else { continue }
            body.velocity.dy += 260 * deltaTime
            body.position.x += body.velocity.dx * deltaTime
            body.position.y += body.velocity.dy * deltaTime
            body.angle += body.angularVelocity * deltaTime
            body.velocity.dx *= 0.992
            body.velocity.dy *= 0.992
            body.angularVelocity *= 0.996
            resolveBounds(for: &body, in: size)
            bodies[id] = body
        }

        for firstIndex in ids.indices {
            for secondIndex in ids.indices where secondIndex > firstIndex {
                resolveCollision(ids[firstIndex], ids[secondIndex])
            }
        }
    }

    private func makeBody(for id: Product.ID, index: Int, size: CGSize) -> WelcomeBody {
        let referencePositions: [CGPoint] = [
            CGPoint(x: 315, y: 116), CGPoint(x: 230, y: 225),
            CGPoint(x: 112, y: 390), CGPoint(x: 316, y: 545),
            CGPoint(x: 105, y: 635), CGPoint(x: 253, y: 704),
            CGPoint(x: 113, y: 812), CGPoint(x: 337, y: 810)
        ]
        let unit = deterministicUnit(for: id)
        let position: CGPoint
        if index < referencePositions.count {
            let reference = referencePositions[index]
            position = CGPoint(
                x: reference.x / 402 * max(size.width, 1),
                y: reference.y / 874 * max(size.height, 1)
            )
        } else {
            position = CGPoint(
                x: 60 + unit.x * max(size.width - 120, 1),
                y: 90 + unit.y * max(size.height - 180, 1)
            )
        }
        return WelcomeBody(
            productID: id,
            position: position,
            velocity: CGVector(dx: (unit.x - 0.5) * 9, dy: (unit.y - 0.5) * 7),
            angle: (unit.x - 0.5) * 32,
            angularVelocity: (unit.y - 0.5) * 4
        )
    }

    private func deterministicUnit(for id: UUID) -> CGPoint {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let x = CGFloat((Int(bytes[0]) * 257 + Int(bytes[5]))) / 65790
        let y = CGFloat((Int(bytes[10]) * 257 + Int(bytes[15]))) / 65790
        return CGPoint(x: x, y: y)
    }

    private func resolveBounds(for body: inout WelcomeBody, in size: CGSize) {
        let minX = body.radius
        let maxX = max(size.width - body.radius, minX)
        let minY = body.radius + 35
        let maxY = max(size.height - body.radius, minY)
        if body.position.x < minX || body.position.x > maxX {
            body.position.x = min(max(body.position.x, minX), maxX)
            body.velocity.dx *= -0.64
        }
        if body.position.y < minY || body.position.y > maxY {
            body.position.y = min(max(body.position.y, minY), maxY)
            body.velocity.dy *= -0.64
        }
    }

    private mutating func resolveCollision(_ firstID: Product.ID, _ secondID: Product.ID) {
        guard var first = bodies[firstID], var second = bodies[secondID] else { return }
        let dx = second.position.x - first.position.x
        let dy = second.position.y - first.position.y
        let distance = max(hypot(dx, dy), 0.001)
        let minimum = first.radius + second.radius
        guard distance < minimum else { return }
        let nx = dx / distance
        let ny = dy / distance
        let correction = (minimum - distance) / 2
        first.position.x -= nx * correction
        first.position.y -= ny * correction
        second.position.x += nx * correction
        second.position.y += ny * correction
        let relative = (second.velocity.dx - first.velocity.dx) * nx
            + (second.velocity.dy - first.velocity.dy) * ny
        if relative < 0 {
            let impulse = -relative * 0.86
            first.velocity.dx -= impulse * nx
            first.velocity.dy -= impulse * ny
            second.velocity.dx += impulse * nx
            second.velocity.dy += impulse * ny
        }
        bodies[firstID] = first
        bodies[secondID] = second
    }
}
