import Foundation
import UIKit

class SettingsManager {
    
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let bpmNumberSize = "bpm_number_size"
        static let bpmNumberColor = "bpm_number_color"
        static let bpmLabelSize = "bpm_label_size"
        static let bpmLabelColor = "bpm_label_color"
        static let backgroundOpacity = "background_opacity"
        static let httpPushEnabled = "http_push_enabled"
        static let httpPushPort = "http_push_port"
    }
    
    enum Position: Int {
        case top = 0
        case bottom = 1
        case left = 2
        case right = 3
    }
    
    var bpmNumberSize: Int {
        get { defaults.integer(forKey: Keys.bpmNumberSize) }
        set {
            let clamped = max(12, min(48, newValue))
            defaults.set(clamped, forKey: Keys.bpmNumberSize)
            notifySettingsChanged()
        }
    }
    
    var bpmNumberColor: UIColor {
        get {
            let hex = defaults.string(forKey: Keys.bpmNumberColor) ?? "#FF6B6B"
            return UIColor(hex: hex) ?? .systemRed
        }
        set {
            defaults.set(newValue.hexString, forKey: Keys.bpmNumberColor)
            notifySettingsChanged()
        }
    }
    
    var bpmLabelSize: Int {
        get { defaults.integer(forKey: Keys.bpmLabelSize) }
        set {
            let clamped = max(8, min(32, newValue))
            defaults.set(clamped, forKey: Keys.bpmLabelSize)
            notifySettingsChanged()
        }
    }
    
    var bpmLabelColor: UIColor {
        get {
            let hex = defaults.string(forKey: Keys.bpmLabelColor) ?? "#FFFFFF"
            return UIColor(hex: hex) ?? .white
        }
        set {
            defaults.set(newValue.hexString, forKey: Keys.bpmLabelColor)
            notifySettingsChanged()
        }
    }
    
    var backgroundOpacity: Int {
        get { defaults.integer(forKey: Keys.backgroundOpacity) }
        set {
            let clamped = max(0, min(100, newValue))
            defaults.set(clamped, forKey: Keys.backgroundOpacity)
            notifySettingsChanged()
        }
    }
    
    var isHttpPushEnabled: Bool {
        get { defaults.bool(forKey: Keys.httpPushEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.httpPushEnabled)
            notifySettingsChanged()
        }
    }
    
    var httpPushPort: Int {
        get { defaults.integer(forKey: Keys.httpPushPort) }
        set {
            let clamped = max(1024, min(65535, newValue))
            defaults.set(clamped, forKey: Keys.httpPushPort)
            notifySettingsChanged()
        }
    }
    
    private var listeners = [WeakSettingsListener]()
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if defaults.object(forKey: Keys.bpmNumberSize) == nil {
            bpmNumberSize = 36
        }
        if defaults.object(forKey: Keys.bpmLabelSize) == nil {
            bpmLabelSize = 14
        }
        if defaults.object(forKey: Keys.backgroundOpacity) == nil {
            backgroundOpacity = 80
        }
        if defaults.object(forKey: Keys.httpPushPort) == nil {
            httpPushPort = 8080
        }
    }
    
    func resetToDefaults() {
        bpmNumberSize = 36
        bpmNumberColor = UIColor(hex: "#FF6B6B") ?? .systemRed
        bpmLabelSize = 14
        bpmLabelColor = .white
        backgroundOpacity = 80
        isHttpPushEnabled = false
        httpPushPort = 8080
    }
    
    func addListener(_ listener: SettingsChangeListener) {
        listeners.append(WeakSettingsListener(value: listener))
    }
    
    func removeListener(_ listener: SettingsChangeListener) {
        listeners.removeAll { $0.value === listener }
    }
    
    private func notifySettingsChanged() {
        listeners.removeAll { $0.value == nil }
        listeners.forEach { $0.value?.onSettingsChanged() }
    }
}

protocol SettingsChangeListener: AnyObject {
    func onSettingsChanged()
}

class WeakSettingsListener {
    weak var value: SettingsChangeListener?
    init(value: SettingsChangeListener) {
        self.value = value
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        } else if length == 8 {
            self.init(
                red: CGFloat((rgb & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgb & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgb & 0x000000FF) / 255.0
            )
        } else {
            return nil
        }
    }
    
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
