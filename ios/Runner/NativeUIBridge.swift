import Flutter
import SwiftUI
import Combine

final class NativeUIBridge: ObservableObject {
    static let shared = NativeUIBridge()

    @Published var snapshot: AppSnapshot = .empty
    @Published var workoutState: WorkoutUIState = .ready(supported: true)

    private var channel: FlutterMethodChannel?

    func attach(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "flex/native_ui", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        self.channel = channel
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateSnapshot":
            if let json = call.arguments as? String {
                snapshot = AppSnapshot.decode(from: json)
            }
            result(nil)
        case "workoutTracking":
            if let args = call.arguments as? [String: Any] {
                let reps = args["reps"] as? Int ?? 0
                workoutState = .tracking(reps: reps)
            }
            result(nil)
        case "workoutResting":
            if let args = call.arguments as? [String: Any] {
                let seconds = args["seconds"] as? Int ?? 0
                let sets = args["setsSoFar"] as? Int ?? 0
                workoutState = .resting(seconds: seconds, setsSoFar: sets)
            }
            result(nil)
        case "workoutFinished":
            if let args = call.arguments as? [String: Any] {
                let totalReps = args["totalReps"] as? Int ?? 0
                let sets = args["sets"] as? Int ?? 0
                workoutState = .finished(totalReps: totalReps, sets: sets)
            }
            result(nil)
        case "workoutReady":
            let supported = (call.arguments as? [String: Any])?["supported"] as? Bool ?? true
            workoutState = .ready(supported: supported)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func send(_ method: String, _ arguments: Any? = nil) {
        channel?.invokeMethod(method, arguments: arguments)
    }

    func startWorkoutSet() { send("startSet") }
    func endWorkoutSet() { send("endSet") }
    func finishWorkout() { send("finishWorkout") }
    func requestExport() { send("exportBackup") }
    func requestImport() { send("importBackup") }
    func requestWipe() { send("wipeData") }
    func setRemindersEnabled(_ enabled: Bool, hour: Int) {
        send("setReminders", ["enabled": enabled, "hour": hour])
    }
    func requestShareCard() { send("shareCard") }
}

enum WorkoutUIState {
    case ready(supported: Bool)
    case tracking(reps: Int)
    case resting(seconds: Int, setsSoFar: Int)
    case finished(totalReps: Int, sets: Int)
}
