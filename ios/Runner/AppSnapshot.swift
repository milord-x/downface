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
    let remindersEnabled: Bool
    let reminderHours: [Int]
    let remindersAsked: Bool

    static let empty = AppSnapshot(
        workouts: [],
        streak: StreakSnapshot(current: 0, longest: 0, brokenToday: false),
        repsToday: 0,
        repsThisWeek: 0,
        repsThisMonth: 0,
        repsAllTime: 0,
        activeDayTimestamps: [],
        remindersEnabled: false,
        reminderHours: [19],
        remindersAsked: true
    )

    static func decode(from json: String) -> AppSnapshot {
        guard let data = json.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
