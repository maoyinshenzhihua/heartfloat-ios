import AVFoundation
import UIKit

class MusicService {
    static let shared = MusicService()

    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var isPlaying: Bool = false

    private init() {}

    func startMusic() {
        guard GameSettings.shared.musicEnabled else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }

        guard let url = Bundle.main.url(forResource: "game_music", withExtension: "mp3") else {
            print("Music file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play music: \(error)")
        }
    }

    func stopMusic() {
        fadeOutAndStop()
    }

    private func fadeOutAndStop() {
        fadeTimer?.invalidate()

        guard let player = audioPlayer, player.isPlaying else {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
            return
        }

        var volume: Float = player.volume
        let fadeStep: Float = 0.1
        let interval: TimeInterval = 0.1

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            volume -= fadeStep
            if volume <= 0 {
                timer.invalidate()
                self?.audioPlayer?.stop()
                self?.audioPlayer = nil
                self?.isPlaying = false
            } else {
                self?.audioPlayer?.volume = volume
            }
        }
    }

    func pauseMusic() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resumeMusic() {
        guard GameSettings.shared.musicEnabled else { return }
        audioPlayer?.play()
        isPlaying = true
    }

    var isMusicPlaying: Bool {
        return isPlaying
    }
}
