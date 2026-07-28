import Foundation

struct WorkoutSetSnapshot: Codable {
    let reps: Int
    let startedAt: Double
    let endedAt: Double
    let restBeforeSeconds: Int
    let repDurationsMs: [Int]
}

struct WorkoutSnapshot: Codable, Identifiable {
    let id: Int
    let startedAt: Double
    let endedAt: Double
    let sets: [WorkoutSetSnapshot]

    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
}

struct StreakSnapshot: Codable {
    let current: Int
    let longest: Int
    let brokenToday: Bool
}

struct AppSnapshot: Codable {
    let workouts: [WorkoutSnapshot]
    let streak: StreakSnapshot
    let repsToday: Int
    let repsThisWeek: Int
    let repsThisMonth: Int
    let repsAllTime: Int
    let activeDayTimestamps: [Double]
    let repsPerDay: [String: Int]
    let remindersEnabled: Bool
    let reminderMinutes: [Int]
    let remindersAsked: Bool

    static let empty = AppSnapshot(
        workouts: [],
        streak: StreakSnapshot(current: 0, longest: 0, brokenToday: false),
        repsToday: 0,
        repsThisWeek: 0,
        repsThisMonth: 0,
        repsAllTime: 0,
        activeDayTimestamps: [],
        repsPerDay: [:],
        remindersEnabled: false,
        reminderMinutes: [19 * 60],
        remindersAsked: true
    )

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    /// repsPerDay keys are "yyyy-MM-dd" in local time — a plain calendar-day
    /// string instead of a millisecond timestamp, so there's no floating
    /// point precision to lose across the Dart -> JSON -> Swift round trip.
    func reps(on date: Date) -> Int {
        let key = Self.dayKeyFormatter.string(from: date)
        return repsPerDay[key] ?? 0
    }

    static func decode(from json: String) -> AppSnapshot {
        guard let data = json.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
