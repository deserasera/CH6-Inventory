import CoreGraphics
import Foundation

struct WelcomeImpactFeedbackGate: Sendable {
    private static let minimumImpactSpeed: CGFloat = 42
    private static let minimumMotionSpeed: CGFloat = 42
    private static let minimumInterval: TimeInterval = 0.075
    private var lastFeedbackTime: TimeInterval?

    mutating func shouldTrigger(
        impactSpeed: CGFloat,
        motionSpeed: CGFloat,
        at time: TimeInterval
    ) -> Bool {
        guard impactSpeed >= Self.minimumImpactSpeed,
              motionSpeed >= Self.minimumMotionSpeed else { return false }
        if let lastFeedbackTime,
           time - lastFeedbackTime < Self.minimumInterval {
            return false
        }
        lastFeedbackTime = time
        return true
    }
}
