import SwiftUI

struct ShareCardView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var cardFileURL: URL?

    private var snapshot: AppSnapshot { bridge.snapshot }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                StatCard(snapshot: snapshot)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, DFSpacing.screenPadding)

                Spacer()

                if let cardFileURL {
                    // The message: parameter is deliberately omitted – several
                    // share targets (Telegram among them) send it as a
                    // separate text message instead of an image caption, so
                    // the recipient gets two messages instead of one. Sharing
                    // only the rendered image (which already carries all the
                    // stats as pixels) avoids that split entirely.
                    ShareLink(
                        item: cardFileURL,
                        preview: SharePreview("Downface stats", image: Image(uiImage: UIImage(contentsOfFile: cardFileURL.path) ?? UIImage()))
                    ) {
                        Text("share")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .dfPrimaryButtonStyle()
                    .padding(.horizontal, DFSpacing.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle("share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear(perform: renderCard)
            .onChange(of: themeManager.theme) { _, _ in renderCard() }
        }
    }

    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(content:
            StatCard(snapshot: snapshot)
                .frame(width: 400, height: 400)
                .environment(\.colorScheme, themeManager.theme.colorScheme)
        )
        renderer.scale = 3
        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("downface_stats.png")
        try? pngData.write(to: url)
        cardFileURL = url
    }
}

private struct StatCard: View {
    let snapshot: AppSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var bg: Color { isDark ? .black : .white }
    private var dim: Color { fg.opacity(0.45) }

    private var avgRepSeconds: Double {
        let durations = snapshot.workouts.flatMap { $0.sets }.flatMap { $0.repDurationsMs }
        guard !durations.isEmpty else { return 0 }
        return (Double(durations.reduce(0, +)) / Double(durations.count)) / 1000
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DOWNFACE")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(fg)
                .kerning(2)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.repsAllTime)")
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundStyle(fg)
                Text("total push-ups")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(dim)
            }

            Spacer(minLength: 16)

            MiniActivityGrid(snapshot: snapshot, fg: fg)
                .frame(height: 64)

            Spacer(minLength: 20)

            HStack(alignment: .top, spacing: 0) {
                statColumn(value: "\(snapshot.streak.current)d", label: "streak")
                statColumn(value: "\(snapshot.streak.longest)d", label: "best streak")
                statColumn(value: "\(snapshot.workouts.count)", label: "workouts")
                statColumn(value: avgRepSeconds > 0 ? String(format: "%.1fs", avgRepSeconds) : "\u{2013}", label: "avg rep")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
        .overlay(
            Rectangle()
                .strokeBorder(fg.opacity(0.12), lineWidth: 1)
        )
    }

    private func statColumn(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(fg)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact, non-interactive 12-week activity grid for the share card –
/// same "highest point stays anchored on today" week math as the full
/// StatsView grid, just fewer weeks and no tap handling.
private struct MiniActivityGrid: View {
    let snapshot: AppSnapshot
    let fg: Color
    private let weeks = 12

    private var maxReps: Int {
        max(snapshot.workouts.map { $0.totalReps }.max() ?? 1, 1)
    }

    private func intensity(for reps: Int) -> Color {
        guard reps > 0 else { return fg.opacity(0.08) }
        let ratio = Double(reps) / Double(maxReps)
        return fg.opacity(0.3 + ratio * 0.7)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayOfToday + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let firstMonday = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: lastMonday) ?? lastMonday

        return HStack(spacing: 3) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { day in
                        let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstMonday) ?? firstMonday
                        let isFuture = date > today
                        let reps = snapshot.reps(on: date)

                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(isFuture ? Color.clear : intensity(for: reps))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
