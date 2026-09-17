import AVFoundation

@MainActor
final class IceImpactSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var lastPlayback = Date.distantPast
    private var isPrepared = false

    func play(impactSpeed: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastPlayback) >= 0.075 else { return }
        prepareIfNeeded()
        guard isPrepared, let buffer = makeBuffer(impactSpeed: impactSpeed) else { return }

        let normalized = min(max((impactSpeed - 42) / 360, 0), 1)
        player.volume = Float(0.12 + normalized * 0.34)
        pitch.pitch = Float(-90 + normalized * 210)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
        lastPlayback = now
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
#if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
#endif
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do {
            try engine.start()
            isPrepared = true
        } catch {
            isPrepared = false
        }
    }

    private func makeBuffer(impactSpeed: CGFloat) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * 0.09)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        let brightness = Double(min(max((impactSpeed - 42) / 360, 0), 1))
        let primaryFrequency = 1_180 + brightness * 720
        let secondaryFrequency = primaryFrequency * 1.71

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = exp(-time * 42)
            let attack = min(time / 0.0025, 1)
            let tone = sin(2 * .pi * primaryFrequency * time)
                + 0.46 * sin(2 * .pi * secondaryFrequency * time + 0.7)
            let crystallineNoise = sin(Double(frame * 97 % 211)) * 0.08
            samples[frame] = Float((tone + crystallineNoise) * envelope * attack * 0.42)
        }
        return buffer
    }
}
