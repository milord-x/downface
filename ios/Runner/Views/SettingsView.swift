import SwiftUI

struct SettingsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWipeConfirm = false
    @State private var statusMessage: String?
    @State private var showAddTime = false
    @State private var newTimeHour = 19

    private let availableHours: [Int] = Array(6...23)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Daily reminder", isOn: Binding(
                        get: { bridge.snapshot.remindersEnabled },
                        set: { bridge.setRemindersEnabled($0, hours: bridge.snapshot.reminderHours) }
                    ))

                    if bridge.snapshot.remindersEnabled {
                        ForEach(bridge.snapshot.reminderHours.sorted(), id: \.self) { hour in
                            HStack {
                                Text(formattedHour(hour))
                                    .foregroundStyle(DFColor.textPrimary)
                                Spacer()
                                if bridge.snapshot.reminderHours.count > 1 {
                                    Button {
                                        let remaining = bridge.snapshot.reminderHours.filter { $0 != hour }
                                        bridge.setRemindersEnabled(true, hours: remaining)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }

                        Button {
                            showAddTime = true
                        } label: {
                            Label("Add another time", systemImage: "plus.circle.fill")
                        }
                        .foregroundStyle(DFColor.textPrimary)
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

                Section("health") {
                    Toggle("Sync with Apple Health", isOn: Binding(
                        get: { bridge.healthSyncEnabled },
                        set: { bridge.setHealthSyncEnabled($0) }
                    ))
                    Text("Writes each finished set to Health as a workout, so it shows up alongside your other activity.")
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textSecondary)
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

                    Link(destination: URL(string: "https://github.com/milord-x/downface/discussions")!) {
                        HStack {
                            Text("FAQ & discussions")
                                .foregroundStyle(DFColor.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(DFColor.textSecondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/sponsors/milord-x")!) {
                        HStack {
                            Text("Support this project")
                                .foregroundStyle(DFColor.textPrimary)
                            Spacer()
                            Image(systemName: "heart.fill")
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
            .sheet(isPresented: $showAddTime) {
                NavigationStack {
                    Picker("Time", selection: $newTimeHour) {
                        ForEach(availableHours, id: \.self) { hour in
                            Text(formattedHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .navigationTitle("add reminder")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddTime = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                var hours = Set(bridge.snapshot.reminderHours)
                                hours.insert(newTimeHour)
                                bridge.setRemindersEnabled(true, hours: Array(hours))
                                showAddTime = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(280)])
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
