import SwiftUI

struct StatsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showShareCard = false

    private var snapshot: AppSnapshot { bridge.snapshot }
    private var hasWorkouts: Bool { !snapshot.workouts.isEmpty }

    private var avgRepSeconds: Double {
        let durations = snapshot.workouts.flatMap { $0.sets }.flatMap { $0.repDurationsMs }
        guard !durations.isEmpty else { return 0 }
        return (Double(durations.reduce(0, +)) / Double(durations.count)) / 1000
    }

    private var avgRestSeconds: Double {
        let rests = snapshot.workouts.flatMap { $0.sets }.map { $0.restBeforeSeconds }.filter { $0 > 0 }
        guard !rests.isEmpty else { return 0 }
        return Double(rests.reduce(0, +)) / Double(rests.count)
    }

    private var repsPerDay: [DateComponents: Int] {
        let calendar = Calendar.current
        var totals: [DateComponents: Int] = [:]
        for workout in snapshot.workouts {
            let date = Date(timeIntervalSince1970: workout.startedAt / 1000)
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            totals[comps, default: 0] += workout.totalReps
        }
        return totals
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasWorkouts {
                    ScrollView {
                        VStack(spacing: 16) {
                            activityCard
                            HStack(spacing: 12) {
                                MetricCard(label: "avg rep", value: String(format: "%.1fs", avgRepSeconds))
                                MetricCard(label: "avg rest", value: "\(Int(avgRestSeconds))s")
                            }
                            HStack(spacing: 12) {
                                MetricCard(label: "longest streak", value: "\(snapshot.streak.longest)d")
                                MetricCard(label: "total workouts", value: "\(snapshot.workouts.count)")
                            }
                        }
                        .padding(DFSpacing.screenPadding)
                    }
                } else {
                    EmptyStatsView()
                }
            }
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle("stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if hasWorkouts {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            showShareCard = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareCard) { ShareCardView() }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("activity")
                .font(DFType.title)
                .foregroundStyle(DFColor.textPrimary)
            ActivityGrid(repsPerDay: repsPerDay)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DFSpacing.cardPadding)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct EmptyStatsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(DFColor.textTertiary)
            Text("no workouts yet")
                .font(DFType.title)
                .foregroundStyle(DFColor.textPrimary)
            Text("do your first set to see stats here")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(DFColor.textPrimary)
            Text(label)
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DFSpacing.cardPadding)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ActivityGrid: View {
    let repsPerDay: [DateComponents: Int]
    private let weeks = 20

    private var maxReps: Int {
        repsPerDay.values.max() ?? 1
    }

    private func intensity(for reps: Int) -> Color {
        guard reps > 0 else { return Color.white.opacity(0.08) }
        let ratio = Double(reps) / Double(max(maxReps, 1))
        return DFColor.textPrimary.opacity(0.25 + ratio * 0.75)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today) ?? today
        let weekdayOfStart = calendar.component(.weekday, from: start)
        let daysToMonday = (weekdayOfStart + 5) % 7
        let firstMonday = calendar.date(byAdding: .day, value: -daysToMonday, to: start) ?? start

        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                monthLabels(calendar: calendar, firstMonday: firstMonday)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { day in
                                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstMonday) ?? firstMonday
                                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                                let isFuture = date > today
                                let reps = repsPerDay[comps] ?? 0

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isFuture ? Color.clear : intensity(for: reps))
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
        }
        .defaultScrollAnchor(.trailing)
    }

    private func monthLabels(calendar: Calendar, firstMonday: Date) -> some View {
        var seenMonths: Set<Int> = []
        var labels: [(week: Int, name: String)] = []
        for week in 0..<weeks {
            let date = calendar.date(byAdding: .day, value: week * 7, to: firstMonday) ?? firstMonday
            let month = calendar.component(.month, from: date)
            if !seenMonths.contains(month) {
                seenMonths.insert(month)
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                labels.append((week, formatter.string(from: date)))
            }
        }

        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, item in
                let nextWeek = index + 1 < labels.count ? labels[index + 1].week : weeks
                let width = CGFloat(nextWeek - item.week) * 18
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DFColor.textTertiary)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}
