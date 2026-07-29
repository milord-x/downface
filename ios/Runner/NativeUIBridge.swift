import Flutter
import SwiftUI
import Combine
import WidgetKit
import UIKit

final class NativeUIBridge: ObservableObject {
    static let shared = NativeUIBridge()

    private static let healthSyncKey = "health_sync_enabled"

    @Published var snapshot: AppSnapshot = .empty
    @Published var workoutState: WorkoutUIState = .ready(supported: true) {
        didSet {
            // Rep counting relies on the camera and the user's hands, not
            // touch — the screen reads as idle to iOS the whole set, so the
            // system auto-lock (and Low Power Mode's more aggressive one)
            // turns the display off mid-rep unless we hold it open here.
            switch workoutState {
            case .tracking, .resting:
                UIApplication.shared.isIdleTimerDisabled = true
            case .ready, .finished:
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    @Published var supported: Bool = true
    @Published var healthSyncEnabled: Bool = UserDefaults.standard.bool(forKey: NativeUIBridge.healthSyncKey)
    @Published var iCloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: NativeUIBridge.iCloudSyncKey)
    @Published var iCloudRestoreStatus: ICloudRestoreStatus = .idle

    private static let iCloudSyncKey = "icloud_sync_enabled"

    /// Set once, right when the user taps "done" on the finished-workout
    /// screen, carrying the rep count so HomeView can fly a copy of that
    /// number into the "push-ups today" card as the workout sheet
    /// dismisses. HomeView clears it once the flight animation completes.
    @Published var pendingRepsFlight: PendingRepsFlight?

    private var channel: FlutterMethodChannel?

    func attach(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "downface/native_ui", binaryMessenger: messenger)
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
                updateWidgetData()
            }
            result(nil)
        case "workoutTracking":
            if let args = call.arguments as? [String: Any] {
                let reps = args["reps"] as? Int ?? 0
                let fatigued = args["fatigued"] as? Bool ?? false
                workoutState = .tracking(reps: reps, fatigued: fatigued)
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
                let newBestSet = args["newBestSet"] as? Bool ?? false
                let newBestDay = args["newBestDay"] as? Bool ?? false
                workoutState = .finished(totalReps: totalReps, sets: sets, newBestSet: newBestSet, newBestDay: newBestDay)

                if healthSyncEnabled, sets > 0,
                   let startedAt = args["startedAt"] as? Double,
                   let endedAt = args["endedAt"] as? Double {
                    HealthKitService.shared.saveWorkout(
                        start: Date(timeIntervalSince1970: startedAt / 1000),
                        end: Date(timeIntervalSince1970: endedAt / 1000),
                        totalReps: totalReps
                    )
                }
            }
            result(nil)
        case "workoutReady":
            let isSupported = (call.arguments as? [String: Any])?["supported"] as? Bool ?? true
            supported = isSupported
            workoutState = .ready(supported: isSupported)
            result(nil)
        case "shareFile":
            if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
                presentShareSheet(forFileAt: path)
            }
            result(nil)
        case "iCloudUpload":
            if iCloudSyncEnabled, let args = call.arguments as? [String: Any], let path = args["path"] as? String {
                ICloudBackupService.shared.upload(fileAt: path)
            }
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
    func cancelWorkout() {
        send("cancelWorkout")
        workoutState = .ready(supported: supported)
    }
    func requestExport() { send("exportBackup") }
    func requestImport() { send("importBackup") }
    func requestWipe() { send("wipeData") }
    func setRemindersEnabled(_ enabled: Bool, minutes: [Int]) {
        send("setReminders", ["enabled": enabled, "minutes": minutes])
    }
    func declineReminders() { send("declineReminders") }
    func requestShareCard() { send("shareCard") }

    private func presentShareSheet(forFileAt path: String) {
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.async {
            guard let root = Self.topViewController() else { return }
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = root.view
                popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            root.present(activityVC, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func updateWidgetData() {
        ActivitySnapshot.save(ActivitySnapshot(repsPerDay: snapshot.repsPerDay, currentStreak: snapshot.streak.current))
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setHealthSyncEnabled(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await HealthKitService.shared.requestAuthorization()
                await MainActor.run {
                    healthSyncEnabled = granted
                    UserDefaults.standard.set(granted, forKey: Self.healthSyncKey)
                }
            }
        } else {
            healthSyncEnabled = false
            UserDefaults.standard.set(false, forKey: Self.healthSyncKey)
        }
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.iCloudSyncKey)
        if enabled {
            // Turning sync on doesn't wait for the next workout to upload
            // whatever's already on this device.
            send("exportForICloud")
        }
    }

    /// Downloads whatever backup is currently in this device's iCloud
    /// container and hands it to the same import path a manually picked
    /// .dfbak file goes through — restore is always an explicit action the
    /// user triggers from Settings, never automatic, so a fresh install
    /// never silently overwrites in-progress data.
    func restoreFromICloud() {
        guard ICloudBackupService.shared.isAvailable else {
            iCloudRestoreStatus = .failed
            return
        }
        iCloudRestoreStatus = .restoring
        Task {
            guard let path = await ICloudBackupService.shared.downloadLatest() else {
                await MainActor.run { iCloudRestoreStatus = .noBackupFound }
                return
            }
            await MainActor.run {
                iCloudRestoreStatus = .idle
                send("importBackupFromPath", ["path": path])
            }
        }
    }
}

enum ICloudRestoreStatus: Equatable {
    case idle
    case restoring
    case noBackupFound
    case failed
}

enum WorkoutUIState {
    case ready(supported: Bool)
    case tracking(reps: Int, fatigued: Bool)
    case resting(seconds: Int, setsSoFar: Int)
    case finished(totalReps: Int, sets: Int, newBestSet: Bool, newBestDay: Bool)
}

struct PendingRepsFlight: Equatable {
    let reps: Int
}
