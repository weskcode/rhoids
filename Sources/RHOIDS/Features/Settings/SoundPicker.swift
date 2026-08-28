import SwiftUI
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "Settings")

struct SoundPicker: View {
    let title: String
    @Binding var selection: AlarmSound
    @State private var previewPlayer: AVAudioPlayer?

    var body: some View {
        List {
            ForEach(SoundCategory.allCases) { category in
                let sounds = AlarmSound.allCases.filter { $0.category == category }
                if sounds.isEmpty == false {
                    Section(category.displayName) {
                        ForEach(sounds) { sound in
                            soundRow(sound)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        Button {
            selection = sound
            preview(sound)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: sound.symbol)
                    .font(.body)
                    .frame(width: 28)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.displayName)
                        .foregroundStyle(.primary)
                    Text(sound.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if selection == sound {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func preview(_ sound: AlarmSound) {
        previewPlayer?.stop()
        guard let name = sound.bundledFileName,
              let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            previewPlayer = player
            player.prepareToPlay()
            player.play()
        } catch {
            log.error("preview failed: \(error)")
        }
    }
}

#if DEBUG
#Preview("Alarm Sound") {
    NavigationStack {
        SoundPicker(title: "Alarm Sound", selection: .constant(.singingBowl))
    }
}
#endif
