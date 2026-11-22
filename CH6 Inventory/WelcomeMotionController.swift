import Combine
import CoreGraphics
import CoreMotion
import Foundation

enum DeviceGravityMapping {
    nonisolated static func physicsGravity(x: Double, y: Double) -> CGVector {
        CGVector(dx: x, dy: -y)
    }
}

enum WelcomeMotionPolicy {
    nonisolated static func pausesPhysics(reduceMotionEnabled: Bool) -> Bool {
        false
    }
}

@MainActor
final class WelcomeMotionController: ObservableObject {
    @Published private(set) var gravity = CGVector(dx: 0, dy: 1)

    private let manager = CMMotionManager()
    private var samplingTimer: Timer?

    func start() {
        guard manager.isDeviceMotionAvailable else {
            gravity = CGVector(dx: 0, dy: 1)
            return
        }
        guard !manager.isDeviceMotionActive else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        samplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let sensorGravity = self.manager.deviceMotion?.gravity else { return }
                self.gravity = DeviceGravityMapping.physicsGravity(
                    x: sensorGravity.x,
                    y: sensorGravity.y
                )
            }
        }
    }

    func stop() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        manager.stopDeviceMotionUpdates()
        gravity = CGVector(dx: 0, dy: 1)
    }
}
