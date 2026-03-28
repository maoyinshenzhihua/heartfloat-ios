import Foundation

struct HeartRateData: Codable {
    let bpm: Int
    let isContact: Bool
    let lastUpdate: TimeInterval
    let timestamp: TimeInterval
    
    static func empty() -> HeartRateData {
        return HeartRateData(
            bpm: 0,
            isContact: false,
            lastUpdate: 0,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
