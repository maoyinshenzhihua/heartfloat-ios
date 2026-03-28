import Foundation

class GameSettings {
    static let shared = GameSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let animationEnabled = "animation_enabled"
        static let musicEnabled = "music_enabled"
        static let controllerEnabled = "controller_enabled"
        static let gameSoundEnabled = "game_sound_enabled"
        static let smallScreenEnabled = "small_screen_enabled"
    }

    var animationEnabled: Bool {
        get { defaults.bool(forKey: Keys.animationEnabled) }
        set { defaults.set(newValue, forKey: Keys.animationEnabled) }
    }

    var musicEnabled: Bool {
        get { defaults.object(forKey: Keys.musicEnabled) == nil ? true : defaults.bool(forKey: Keys.musicEnabled) }
        set { defaults.set(newValue, forKey: Keys.musicEnabled) }
    }

    var controllerEnabled: Bool {
        get { defaults.bool(forKey: Keys.controllerEnabled) }
        set { defaults.set(newValue, forKey: Keys.controllerEnabled) }
    }

    var gameSoundEnabled: Bool {
        get { defaults.object(forKey: Keys.gameSoundEnabled) == nil ? true : defaults.bool(forKey: Keys.gameSoundEnabled) }
        set { defaults.set(newValue, forKey: Keys.gameSoundEnabled) }
    }

    var smallScreenEnabled: Bool {
        get { defaults.bool(forKey: Keys.smallScreenEnabled) }
        set { defaults.set(newValue, forKey: Keys.smallScreenEnabled) }
    }

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.animationEnabled: false,
            Keys.musicEnabled: true,
            Keys.controllerEnabled: false,
            Keys.gameSoundEnabled: true,
            Keys.smallScreenEnabled: false
        ])
    }
}
