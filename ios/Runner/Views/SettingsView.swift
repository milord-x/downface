import SwiftUI

struct SettingsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWipeConfirm = false
    @State private var statusMessage: String?

    private let reminderHours: [Int] = Array(6...23)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Daily reminder", isOn: Binding(
                        get: { bridge.snapshot.remindersEnabled },
                        set: { bridge.setRemindersEnabled($0, hour: bridge.snapshot.reminderHour) }
                    ))

                    if bridge.snapshot.remindersEnabled {
                        Picker("Remind me at", selection: Binding(
                            get: { bridge.snapshot.reminderHour },
                            set: { bridge.setRemindersEnabled(true, hour: $0) }
                        )) {
                            ForEach(reminderHours, id: \.self) { hour in
                                Text(formattedHour(hour)).tag(hour)
                            }
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("backup") {
                    Button("Export backup file") {
                        bridge.requestExport()
                    }
                    .foregroundStyle(DFColor.textPrimary)

                    Button("Import backup file") {
                        bridge.requestImport()
                    }
                    .foregroundStyle(DFColor.textPrimary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("data") {
                    Button("Delete all data", role: .destructive) {
                        showWipeConfirm = true
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("about") {
                    Link(destination: URL(string: "https://github.com/milord-x/downface")!) {
                        HStack {
                            Text("Source code")
                                .foregroundStyle(DFColor.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(DFColor.textSecondary)
                        }
                    }

                    NavigationLink("Terms of use") {
                        LegalTextView(title: "Terms of use", text: Self.termsText)
                    }

                    NavigationLink("Privacy policy") {
                        LegalTextView(title: "Privacy policy", text: Self.privacyText)
                    }

                    HStack {
                        Text("Version")
                            .foregroundStyle(DFColor.textPrimary)
                        Spacer()
                        Text(Self.appVersion)
                            .foregroundStyle(DFColor.textSecondary)
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section {
                    Text("made with love, no ads, no tracking")
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(DFType.caption)
                            .foregroundStyle(DFColor.textSecondary)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Delete all data", isPresented: $showWipeConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    bridge.requestWipe()
                    statusMessage = "All data deleted"
                }
            } message: {
                Text("This removes every workout on this device. This cannot be undone.")
            }
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private static let termsText = """
    Downface is provided as-is, free of charge, with no warranty of any kind. \
    You use it at your own risk, including for any physical activity performed with it. \
    All workout data stays on your device unless you explicitly export it. \
    The source code is available under the MIT license \u{2014} see the GitHub repository for details.
    """

    private static let privacyText = """
    Downface has no server, no analytics, and no account. \
    Your camera is used only during an active set to track head movement, and no video or image ever leaves your device. \
    Workout history is stored locally in a SQLite database. \
    Backups you export are encrypted and only readable by Downface itself. \
    Nothing is ever sent anywhere.
    """
}

private struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(DFType.body)
                .foregroundStyle(DFColor.textPrimary)
                .padding(DFSpacing.screenPadding)
        }
        .background(DFColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
