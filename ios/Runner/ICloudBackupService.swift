import Foundation

/// Mirrors the encrypted backup file into the app's iCloud Documents
/// container so a user moving to a new device can restore automatically
/// instead of needing to have manually exported and kept the .dfbak file
/// themselves. The file is still the same AES-GCM encrypted blob produced
/// by BackupCodec on the Dart side – iCloud only ever sees ciphertext.
final class ICloudBackupService {
    static let shared = ICloudBackupService()

    private static let containerID = "iCloud.com.downface.app"
    private static let fileName = "downface_backup.dfbak"
    private static let lastSyncKey = "icloud_last_synced_at"

    /// The toggle in Settings had no feedback at all once turned on – it
    /// fires the upload in the background and the user has no way to tell
    /// whether it actually landed in their iCloud account or is silently
    /// failing. Stamping a timestamp on every successful write, read back
    /// by the UI, turns "I think it's syncing" into "last synced 2m ago".
    var lastSyncedAt: Date? {
        let timestamp = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Documents")
    }

    /// `url(forUbiquityContainerIdentifier:)` is synchronous but its very
    /// first call in a process can return nil even when iCloud is signed in
    /// and the container exists – the system hasn't finished setting the
    /// container up yet, and Apple's own docs warn against trusting that
    /// first call to be instant. A single nil check right when the user
    /// taps Restore reported "iCloud unavailable" on a perfectly working
    /// account just because it happened to be this app's first ever touch
    /// of the container. Retrying a few times with a short wait between
    /// gives the system a moment to finish that one-time setup.
    var isAvailable: Bool {
        get async {
            if containerURL != nil { return true }
            for _ in 0..<4 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if containerURL != nil { return true }
            }
            return false
        }
    }

    func upload(fileAt path: String, completion: ((Date?) -> Void)? = nil) {
        guard let documentsURL = containerURL else {
            completion?(nil)
            return
        }
        let sourceURL = URL(fileURLWithPath: path)

        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default
            do {
                try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                let destinationURL = documentsURL.appendingPathComponent(Self.fileName)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                let syncedAt = Date()
                UserDefaults.standard.set(syncedAt.timeIntervalSince1970, forKey: Self.lastSyncKey)
                completion?(syncedAt)
            } catch {
                // Best-effort background sync – a failed upload here just
                // means the next successful one carries the latest data.
                completion?(nil)
            }
        }
    }

    /// Downloads the iCloud copy to a local temp file and returns its path,
    /// or nil if there's no backup up there yet. Used only for the explicit
    /// "restore from iCloud" action, not run automatically on launch, so a
    /// fresh install never silently overwrites data the user is mid-way
    /// through creating.
    func downloadLatest() async -> String? {
        guard let documentsURL = containerURL else { return nil }
        let remoteURL = documentsURL.appendingPathComponent(Self.fileName)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: remoteURL.path) else { return nil }

        do {
            try fileManager.startDownloadingUbiquitousItem(at: remoteURL)
            for _ in 0..<20 {
                var isDownloaded = false
                if let values = try? remoteURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                   values.ubiquitousItemDownloadingStatus == .current {
                    isDownloaded = true
                }
                if isDownloaded { break }
                try await Task.sleep(nanoseconds: 300_000_000)
            }

            let localURL = fileManager.temporaryDirectory.appendingPathComponent(Self.fileName)
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.copyItem(at: remoteURL, to: localURL)
            return localURL.path
        } catch {
            return nil
        }
    }
}
