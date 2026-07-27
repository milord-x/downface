import SwiftUI

struct SettingsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWipeConfirm = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Daily reminder", isOn: Binding(
                        get: { bridge.snapshot.remindersEnabled },
                        set: { bridge.setRemindersEnabled($0, hour: bridge.snapshot.reminderHour) }
                    ))
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
}
