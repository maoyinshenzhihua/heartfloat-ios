import Foundation

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
