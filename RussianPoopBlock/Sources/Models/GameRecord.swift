import Foundation

struct GameRecord: Codable {
    let score: Int
    let time: String
    let date: String

    init(score: Int, time: String, date: String) {
        self.score = score
        self.time = time
        self.date = date
    }

    static func fromString(_ recordString: String) -> GameRecord? {
        let parts = recordString.split(separator: "|")
        guard parts.count == 3,
              let score = Int(parts[0]) else {
            return nil
        }
        return GameRecord(
            score: score,
            time: String(parts[1]),
            date: String(parts[2])
        )
    }

    func toString() -> String {
        return "\(score)|\(time)|\(date)"
    }
}

class GameRecordStorage {
    static let shared = GameRecordStorage()

    private let defaults = UserDefaults.standard
    private let prefName = "game_records"
    private let recordCountKey = "record_count"
    private let recordPrefix = "record_"

    private init() {}

    func saveRecord(_ record: GameRecord) {
        var count = defaults.integer(forKey: recordCountKey)
        defaults.set(record.toString(), forKey: recordPrefix + "\(count)")
        defaults.set(count + 1, forKey: recordCountKey)
    }

    func loadRecords() -> [GameRecord] {
        var records: [GameRecord] = []
        let count = defaults.integer(forKey: recordCountKey)

        for i in 0..<count {
            if let recordString = defaults.string(forKey: recordPrefix + "\(i)"),
               let record = GameRecord.fromString(recordString) {
                records.append(record)
            }
        }

        return records.sorted { $0.score > $1.score }
    }

    func clearAllRecords() {
        let count = defaults.integer(forKey: recordCountKey)
        for i in 0..<count {
            defaults.removeObject(forKey: recordPrefix + "\(i)")
        }
        defaults.set(0, forKey: recordCountKey)
    }
}
