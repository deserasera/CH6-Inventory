struct WelcomeImpactSoundGate: Sendable {
    private var hasPlayedImpact = false

    mutating func shouldPlayImpact() -> Bool {
        guard !hasPlayedImpact else { return false }
        hasPlayedImpact = true
        return true
    }
}
