import SwiftUI

struct SettingsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWipeConfirm = false
    @State private var statusMessage: LocalizedStringKey?
    @State private var showAddTime = false
    @State private var newTimeMinutesOfDay = Self.currentMinutesOfDay

    /// The time picker's minute wheel only offers 5-minute steps, so the
    /// raw current minute (e.g. 37) wouldn't match any picker tag and would
    /// render blank — round to the nearest step the wheel actually has.
    private static var currentMinutesOfDay: Int {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let totalMinutes = (now.hour ?? 19) * 60 + (now.minute ?? 0)
        let rounded = (totalMinutes / 5) * 5
        return rounded % (24 * 60)
    }

    private var uses24HourClock: Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j")
        return !formatter.dateFormat.contains("a")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    appearanceCard
                    appIconCard
                    remindersCard
                    supportCard
                    groupedCard {
                        actionRow(icon: "square.and.arrow.up", tint: .blue, title: "Export backup file") {
                            bridge.requestExport()
                        }
                        SettingsDivider()
                        actionRow(icon: "square.and.arrow.down", tint: .blue, title: "Import backup file") {
                            bridge.requestImport()
                        }
                    }
                    healthCard
                    aboutCard
                    dangerZoneCard

                    Text("made with love, no ads, no tracking")
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(DFType.caption)
                            .foregroundStyle(DFColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(DFSpacing.screenPadding)
                .padding(.bottom, 32)
            }
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
                addTimeSheet
                    .preferredColorScheme(themeManager.theme.colorScheme)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        groupedCard {
            HStack {
                settingsIcon(themeManager.theme == .dark ? "moon.fill" : "sun.max.fill", tint: .gray)
                Text("Appearance")
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
                Picker("", selection: Binding(
                    get: { themeManager.theme },
                    set: { themeManager.theme = $0 }
                )) {
                    Text("Dark").tag(AppTheme.dark)
                    Text("Light").tag(AppTheme.light)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - App icon

    private var appIconCard: some View {
        groupedCard {
            Text("App icon")
                .foregroundStyle(DFColor.textPrimary)
                .padding(.bottom, 8)

            HStack(spacing: 16) {
                ForEach(AppIconOption.allCases) { option in
                    appIconButton(option)
                }
                Spacer()
            }
        }
    }

    private func appIconButton(_ option: AppIconOption) -> some View {
        let isSelected = UIApplication.shared.alternateIconName == option.iconName
        return Button {
            guard UIApplication.shared.alternateIconName != option.iconName else { return }
            UIApplication.shared.setAlternateIconName(option.iconName)
        } label: {
            Image(option.assetName)
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? DFColor.textPrimary : .clear, lineWidth: 2)
                )
        }
    }

    // MARK: - Reminders

    private var remindersCard: some View {
        groupedCard {
            HStack {
                settingsIcon("bell.fill", tint: .indigo)
                Text("Daily reminder")
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bridge.snapshot.remindersEnabled },
                    set: { bridge.setRemindersEnabled($0, minutes: bridge.snapshot.reminderMinutes) }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)

            if bridge.snapshot.remindersEnabled {
                ForEach(bridge.snapshot.reminderMinutes.sorted(), id: \.self) { minutes in
                    SettingsDivider()
                    HStack {
                        Text(formattedTime(minutes))
                            .foregroundStyle(DFColor.textPrimary)
                        Spacer()
                        if bridge.snapshot.reminderMinutes.count > 1 {
                            Button {
                                let remaining = bridge.snapshot.reminderMinutes.filter { $0 != minutes }
                                bridge.setRemindersEnabled(true, minutes: remaining)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                SettingsDivider()
                Button {
                    newTimeMinutesOfDay = Self.currentMinutesOfDay
                    showAddTime = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another time")
                        Spacer()
                    }
                }
                .foregroundStyle(DFColor.textPrimary)
                .padding(.vertical, 4)
            }
        }
    }

    private var addTimeSheet: some View {
        NavigationStack {
            HourMinutePicker(minutesOfDay: $newTimeMinutesOfDay, uses24HourClock: uses24HourClock)
                .navigationTitle("add reminder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddTime = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            var minutes = Set(bridge.snapshot.reminderMinutes)
                            minutes.insert(newTimeMinutesOfDay)
                            bridge.setRemindersEnabled(true, minutes: Array(minutes))
                            showAddTime = false
                        }
                    }
                }
        }
        .presentationDetents([.height(300)])
    }

    private func formattedTime(_ minutesOfDay: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = uses24HourClock ? "HH:mm" : "h:mm a"
        var components = DateComponents()
        components.hour = minutesOfDay / 60
        components.minute = minutesOfDay % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    // MARK: - Support

    private var supportCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DFColor.cardFill)

            SparkleField()

            Link(destination: URL(string: "https://www.patreon.com/cw/Proxyare/membership")!) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Support Downface")
                            .font(DFType.body.weight(.bold))
                            .foregroundStyle(DFColor.textPrimary)
                        Text("Back the project on Patreon")
                            .font(DFType.caption)
                            .foregroundStyle(DFColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(DFColor.textTertiary)
                }
                .padding(16)
            }
        }
        .frame(height: 80)
    }

    // MARK: - Health

    private var healthCard: some View {
        groupedCard {
            HStack {
                settingsIcon("heart.fill", tint: .pink)
                Text("Sync with Apple Health")
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bridge.healthSyncEnabled },
                    set: { bridge.setHealthSyncEnabled($0) }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)

            Text("Writes each finished set to Health as a workout, so it shows up alongside your other activity.")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
                .padding(.top, 2)
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        groupedCard {
            Link(destination: URL(string: "https://github.com/milord-x/downface")!) {
                externalRow(icon: "chevron.left.forwardslash.chevron.right", tint: .gray, title: "Source code")
            }
            SettingsDivider()
            Link(destination: URL(string: "https://github.com/milord-x/downface/discussions")!) {
                externalRow(icon: "questionmark.circle.fill", tint: .gray, title: "FAQ & discussions")
            }
            SettingsDivider()
            NavigationLink {
                LegalTextView(title: "Terms of use", text: Self.termsText)
            } label: {
                navRow(icon: "hand.raised.fill", tint: .gray, title: "Terms of use")
            }
            SettingsDivider()
            NavigationLink {
                LegalTextView(title: "Privacy policy", text: Self.privacyText)
            } label: {
                navRow(icon: "lock.fill", tint: .gray, title: "Privacy policy")
            }
            SettingsDivider()
            HStack {
                settingsIcon("info.circle.fill", tint: .gray)
                Text("Version")
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
                Text(Self.appVersion)
                    .foregroundStyle(DFColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Danger zone

    private var dangerZoneCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("danger zone")
                .font(DFType.caption.weight(.semibold))
                .foregroundStyle(.red.opacity(0.8))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                Button {
                    showWipeConfirm = true
                } label: {
                    HStack {
                        settingsIcon("trash.fill", tint: .red)
                        Text("Delete all data")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(DFSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DFColor.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Shared row builders

    private func settingsIcon(_ systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.2))
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint == .gray ? DFColor.textPrimary : tint)
        }
        .frame(width: 30, height: 30)
    }

    private func actionRow(icon: String, tint: Color, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                settingsIcon(icon, tint: tint)
                Text(title)
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func externalRow(icon: String, tint: Color, title: LocalizedStringKey) -> some View {
        HStack {
            settingsIcon(icon, tint: tint)
            Text(title)
                .foregroundStyle(DFColor.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13))
                .foregroundStyle(DFColor.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func navRow(icon: String, tint: Color, title: LocalizedStringKey) -> some View {
        HStack {
            settingsIcon(icon, tint: tint)
            Text(title)
                .foregroundStyle(DFColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(DFColor.textTertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(DFSpacing.cardPadding)
        .background(DFColor.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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

private enum AppIconOption: String, CaseIterable, Identifiable {
    case primary
    case classic
    case arrows
    case hands

    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .classic: return "AltIconClassic"
        case .arrows: return "AltIconArrows"
        case .hands: return "AltIconHands"
        }
    }

    var assetName: String {
        switch self {
        case .primary: return "AppIconPreview"
        case .classic: return "AltIconClassic"
        case .arrows: return "AltIconArrows"
        case .hands: return "AltIconHands"
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(DFColor.divider)
            .padding(.vertical, 6)
    }
}

private struct HourMinutePicker: View {
    @Binding var minutesOfDay: Int
    let uses24HourClock: Bool

    private var hourRange: [Int] {
        uses24HourClock ? Array(0...23) : Array(1...12)
    }

    private var hour: Int { minutesOfDay / 60 }

    private var minute: Int { minutesOfDay % 60 }

    private var isPM: Bool { hour >= 12 }

    private var displayHour: Int {
        guard !uses24HourClock else { return hour }
        let h = hour % 12
        return h == 0 ? 12 : h
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hour", selection: hourBinding) {
                ForEach(hourRange, id: \.self) { h in
                    Text(uses24HourClock ? String(format: "%02d", h) : "\(h)").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minute", selection: minuteBinding) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            if !uses24HourClock {
                Picker("AM/PM", selection: amPmBinding) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { uses24HourClock ? hour : displayHour },
            set: { newValue in
                if uses24HourClock {
                    minutesOfDay = newValue * 60 + minute
                } else {
                    let h24 = (newValue % 12) + (isPM ? 12 : 0)
                    minutesOfDay = h24 * 60 + minute
                }
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minute },
            set: { newValue in minutesOfDay = hour * 60 + newValue }
        )
    }

    private var amPmBinding: Binding<Bool> {
        Binding(
            get: { isPM },
            set: { newValue in
                let h24 = (displayHour % 12) + (newValue ? 12 : 0)
                minutesOfDay = h24 * 60 + minute
            }
        )
    }
}

private struct SparkleField: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            sparkle(size: 12, x: 0.88, y: 0.22, delay: 0)
            sparkle(size: 8, x: 0.94, y: 0.75, delay: 0.6)
            sparkle(size: 6, x: 0.78, y: 0.85, delay: 1.2)
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        GeometryReader { geo in
            Image(systemName: "sparkle")
                .font(.system(size: size))
                .foregroundStyle(.yellow.opacity(0.8))
                .scaleEffect(animate ? 1 : 0.4)
                .opacity(animate ? 1 : 0)
                .position(x: geo.size.width * x, y: geo.size.height * y)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(delay),
                    value: animate
                )
        }
    }
}

private struct LegalTextView: View {
    let title: LocalizedStringKey
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
