import AVFoundation

@MainActor
final class IceImpactSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var lastPlayback = Date.distantPast
    private var isPrepared = false
    private var isActivationRequested = false
    private var isSessionActive = false
    private var pendingImpactSpeed: CGFloat?

    func play(impactSpeed: CGFloat) {
#if os(iOS)
        guard isSessionActive else {
            pendingImpactSpeed = max(pendingImpactSpeed ?? 0, impactSpeed)
            activateSessionIfNeeded()
            return
        }
#endif
        playPreparedImpact(speed: impactSpeed)
    }

    private func playPreparedImpact(speed impactSpeed: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastPlayback) >= 0.075 else { return }
        prepareIfNeeded()
        guard isPrepared, let buffer = makeBuffer(impactSpeed: impactSpeed) else { return }

        // EDIT HERE — 42 is the audible-impact threshold; 360 is the loud-impact range.
        let normalized = min(max((impactSpeed - 42) / 360, 0), 1)
        player.volume = Float(0.12 + normalized * 0.34)
        pitch.pitch = Float(-90 + normalized * 210)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            do {
                try player.playAudio()
            } catch {
                return
            }
        }
        lastPlayback = now
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.attach(pitch)
        do {
            try engine.connectNode(player, to: pitch, format: format)
            try engine.connectNode(pitch, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            isPrepared = true
        } catch {
            isPrepared = false
        }
    }

#if os(iOS)
    private func activateSessionIfNeeded() {
        guard !isActivationRequested else { return }
        isActivationRequested = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        session.activate { [weak self] didActivate, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSessionActive = didActivate
                self.isActivationRequested = false
                guard didActivate, let impactSpeed = self.pendingImpactSpeed else { return }
                self.pendingImpactSpeed = nil
                self.playPreparedImpact(speed: impactSpeed)
            }
        }
    }
#endif

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
