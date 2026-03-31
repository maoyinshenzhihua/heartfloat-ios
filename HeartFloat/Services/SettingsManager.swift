import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("bpmNumberSize") var bpmNumberSize: Double = 36
    @AppStorage("bpmNumberColor") var bpmNumberColorData: Data = Data()
    @AppStorage("bpmLabelSize") var bpmLabelSize: Double = 14
    @AppStorage("bpmLabelColor") var bpmLabelColorData: Data = Data()
    @AppStorage("bpmPosition") var bpmPosition: Int = 3
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 80
    @AppStorage("httpPushEnabled") var httpPushEnabled: Bool = false
    @AppStorage("httpPushPort") var httpPushPort: Int = 8080

    var bpmNumberColor: Color {
        get {
            if let color = try? JSONDecoder().decode(Color.self, from: bpmNumberColorData) {
                return color
            }
            return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                bpmNumberColorData = data
            }
        }
    }

    var bpmLabelColor: Color {
        get {
            if let color = try? JSONDecoder().decode(Color.self, from: bpmLabelColorData) {
                return color
            }
            return .white
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                bpmLabelColorData = data
            }
        }
    }

    let positionOptions = ["上方", "下方", "左侧", "右侧"]
    let presetColors: [Color] = [
        Color(red: 1.0, green: 0.42, blue: 0.42),
        Color(red: 0.31, green: 0.80, blue: 0.77),
        Color(red: 0.27, green: 0.72, blue: 0.82),
        Color(red: 0.59, green: 0.81, blue: 0.71),
        Color(red: 1.0, green: 0.92, blue: 0.65),
        Color(red: 0.87, green: 0.90, blue: 0.91),
        Color(red: 1.0, green: 0.46, blue: 0.46),
        Color(red: 0.46, green: 0.73, blue: 1.0),
        Color(red: 0.64, green: 0.61, blue: 1.0),
        Color(red: 0.99, green: 0.47, blue: 0.66),
        Color(red: 0.0, green: 0.72, blue: 0.58),
        Color(red: 0.88, green: 0.44, blue: 0.33)
    ]

    func applyPresetClassic() {
        bpmNumberColor = Color(red: 1.0, green: 0.42, blue: 0.42)
        bpmLabelColor = .white
        bpmNumberSize = 36
        bpmLabelSize = 14
    }

    func applyPresetNeon() {
        bpmNumberColor = Color(red: 0.0, green: 1.0, blue: 0.53)
        bpmLabelColor = Color(red: 0.0, green: 1.0, blue: 1.0)
        bpmNumberSize = 40
        bpmLabelSize = 16
    }

    func applyPresetOcean() {
        bpmNumberColor = Color(red: 0.0, green: 0.75, blue: 1.0)
        bpmLabelColor = Color(red: 0.53, green: 0.81, blue: 0.92)
        bpmNumberSize = 38
        bpmLabelSize = 15
    }
}
