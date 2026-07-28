import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let energyType = HKQuantityType(.activeEnergyBurned)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [workoutType, energyType], read: [])
            return true
        } catch {
            return false
        }
    }

    private static let kcalPerRep = 0.4

    func saveWorkout(start: Date, end: Date, totalReps: Int) {
        guard isAvailable else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        builder.beginCollection(withStart: start) { _, _ in
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: Double(totalReps) * Self.kcalPerRep)
            let sample = HKCumulativeQuantitySample(type: self.energyType, quantity: energy, start: start, end: end)
            // HealthKit has no rep-count quantity type for push-ups, so the
            // stock Health app card always shows duration/energy — this
            // metadata key at least makes total reps readable by other apps
            // and in the workout's own detail view.
            builder.addMetadata(["reps_total": totalReps]) { _, _ in
                builder.add([sample]) { _, _ in
                    builder.endCollection(withEnd: end) { _, _ in
                        builder.finishWorkout { _, _ in }
                    }
                }
            }
        }
    }
}
