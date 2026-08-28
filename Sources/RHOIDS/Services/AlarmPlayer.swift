import AVFoundation
import AudioToolbox
import Foundation
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "AlarmPlayer")

actor AlarmPlayer {
    private var audioPlayer: AVAudioPlayer?
    private var fallbackTask: Task<Void, Never>?
    private var beepPlayer: AVAudioPlayer?

    private static let alarmFallbackSoundID: SystemSoundID = 1304
    private static let warningBeepData = generateBeepData()

    // MARK: - Warning Beep

    /// Plays a short warning beep that works even when the device is on
    /// silent mode. Configures the audio session for `.playback` so the
    /// system doesn't suppress the sound, then plays a brief synthesized
    /// tone. Optionally fires a haptic vibration.
    func playWarningBeep(withHaptic: Bool = true) {
        log.debug("warning beep - haptic=\(withHaptic)")
        configureAudioSession()

        // Haptic vibration (works even if sound is muted)
        if withHaptic {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }

        // Generate a short sine-wave beep so we have a real sound that
        // respects the .playback audio session (bypasses silent switch).
        if let tone = Self.warningBeepData {
            do {
                let player = try AVAudioPlayer(data: tone)
                player.volume = 0.7
                player.prepareToPlay()
                player.play()
                beepPlayer = player  // retain until playback finishes
                log.debug("beep tone playing ✓")
            } catch {
                log.error("beep tone failed: \(error) - falling back to system sound")
                AudioServicesPlayAlertSound(1057)
            }
        } else {
            log.error("tone generation failed - falling back to system sound")
            AudioServicesPlayAlertSound(1057)
        }
    }

    // MARK: - Alarm Loop

    /// Starts looping the chosen alarm sound for timer completion.
    /// Fires a haptic pulse if `withHaptic` is true.
    func startAlarmLoop(sound: AlarmSound, withHaptic: Bool = true) {
        log.debug("startAlarmLoop - sound=\(String(describing: sound)), haptic=\(withHaptic)")
        stopAlarm()
        configureAudioSession()

        // Haptic burst on completion
        if withHaptic {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }

        if let name = sound.bundledFileName,
           let url = Bundle.main.url(forResource: name, withExtension: nil),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            log.debug("looping bundled file \(name)")
            return
        }

        log.debug("no bundled file, using system sound fallback")
        fallbackTask = Task { [id = Self.alarmFallbackSoundID] in
            while !Task.isCancelled {
                AudioServicesPlayAlertSound(id)
                try? await Task.sleep(for: .seconds(1.2))
            }
        }
    }

    func stopAlarm() {
        guard audioPlayer != nil || fallbackTask != nil || beepPlayer != nil else { return }
        log.debug("stopAlarm")
        audioPlayer?.stop()
        audioPlayer = nil
        beepPlayer?.stop()
        beepPlayer = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback ignores the silent switch - sound always plays
            try session.setCategory(.playback, options: [])
            try session.setActive(true)
        } catch {
            log.error("failed to configure audio session: \(error)")
        }
    }

    // MARK: - Tone Generation

    /// Generates a short ~200ms 880Hz sine-wave beep as WAV data.
    /// This lets us play a warning sound through AVAudioPlayer with the
    /// `.playback` audio session, which bypasses the silent switch.
    private static func generateBeepData(
        frequency: Double = 880,
        duration: Double = 0.2,
        sampleRate: Double = 44100,
        amplitude: Double = 0.5
    ) -> Data? {
        let sampleCount = Int(sampleRate * duration)
        let bytesPerSample = 2  // 16-bit PCM
        let dataSize = sampleCount * bytesPerSample

        // WAV header (44 bytes)
        var data = Data()
        let totalSize = UInt32(36 + dataSize)

        // RIFF chunk
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: totalSize.littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"

        // fmt sub-chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // sub-chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })  // sample rate
        let byteRate = UInt32(sampleRate) * UInt32(bytesPerSample)
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })    // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bytesPerSample).littleEndian) { Array($0) })  // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // bits per sample

        // data sub-chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Generate sine wave samples with fade-in/fade-out envelope
        let fadeLength = min(Int(sampleRate * 0.01), sampleCount / 4)  // 10ms fade
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            var sample = sin(2.0 * .pi * frequency * t) * amplitude

            // Fade in
            if i < fadeLength {
                sample *= Double(i) / Double(fadeLength)
            }
            // Fade out
            if i > sampleCount - fadeLength {
                sample *= Double(sampleCount - i) / Double(fadeLength)
            }

            let intSample = Int16(max(-32767, min(32767, sample * 32767)))
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }
}
