import Foundation

/// Mirrors the encrypted backup file into the app's iCloud Documents
/// container so a user moving to a new device can restore automatically
/// instead of needing to have manually exported and kept the .dfbak file
/// themselves. The file is still the same AES-GCM encrypted blob produced
/// by BackupCodec on the Dart side — iCloud only ever sees ciphertext.
final class ICloudBackupService {
    static let shared = ICloudBackupService()

    private static let containerID = "iCloud.com.downface.app"
    private static let fileName = "downface_backup.dfbak"

    private var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Documents")
    }

    var isAvailable: Bool { containerURL != nil }

    func upload(fileAt path: String) {
        guard let documentsURL = containerURL else { return }
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
            } catch {
                // Best-effort background sync — a failed upload here just
                // means the next successful one carries the latest data.
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
