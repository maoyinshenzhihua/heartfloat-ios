import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]
    private var isSoundEnabled: Bool = true

    enum SoundType: String {
        case validClick = "validclick"
        case invalidOperation = "invalidoperation"
        case jidan = "jidan"
        case baicai = "baicai"
        case yantou = "yantou"
        case baba = "baba"
        case shitou = "shitou"
        case jieshu = "jieshu"
    }

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func initSoundManager(soundEnabled: Bool) {
        isSoundEnabled = soundEnabled
    }

    func playSound(_ soundType: SoundType) {
        guard isSoundEnabled else { return }

        if let player = players[soundType.rawValue] {
            player.currentTime = 0
            player.play()
            return
        }

        guard let url = Bundle.main.url(forResource: soundType.rawValue, withExtension: "mp3") else {
            print("Sound file not found: \(soundType.rawValue)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[soundType.rawValue] = player
        } catch {
            print("Failed to play sound: \(error)")
        }
    }

    func playValidClickSound() {
        playSound(.validClick)
    }

    func playInvalidOperationSound() {
        playSound(.invalidOperation)
    }

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    func release() {
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }
}
