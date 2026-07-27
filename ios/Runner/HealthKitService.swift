import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [])
            return true
        } catch {
            return false
        }
    }

    func saveWorkout(start: Date, end: Date, totalReps: Int) {
        guard isAvailable else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        builder.beginCollection(withStart: start) { _, _ in
            builder.endCollection(withEnd: end) { _, _ in
                builder.finishWorkout { _, _ in }
            }
        }
    }
}
