import Foundation

struct ActivitySnapshot: Codable {
    let repsPerDay: [String: Int]
    let currentStreak: Int

    static let appGroupID = "group.com.downface.app"
    static let sharedKey = "activity_snapshot"

    static var empty: ActivitySnapshot {
        ActivitySnapshot(repsPerDay: [:], currentStreak: 0)
    }

    static func load() -> ActivitySnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: sharedKey),
              let snapshot = try? JSONDecoder().decode(ActivitySnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: ActivitySnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: sharedKey)
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    func reps(on date: Date) -> Int {
        repsPerDay[Self.dayFormatter.string(from: date)] ?? 0
    }
}
