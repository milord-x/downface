import SwiftUI

struct StatsView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showShareCard = false

    private var snapshot: AppSnapshot { bridge.snapshot }

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

    var body: some View {
        NavigationStack {
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
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle("stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showShareCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
            ActivityGrid(activeDayTimestamps: snapshot.activeDayTimestamps)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DFSpacing.cardPadding)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
    let activeDayTimestamps: [Double]
    private let weeks = 20

    private var activeDays: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(activeDayTimestamps.map { ts in
            calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: ts / 1000))
        })
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today) ?? today
        let weekdayOfStart = calendar.component(.weekday, from: start)
        let daysToMonday = (weekdayOfStart + 5) % 7
        let firstMonday = calendar.date(byAdding: .day, value: -daysToMonday, to: start) ?? start

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstMonday) ?? firstMonday
                            let comps = calendar.dateComponents([.year, .month, .day], from: date)
                            let isFuture = date > today
                            let active = activeDays.contains(comps)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(isFuture ? Color.clear : (active ? DFColor.textPrimary : Color.white.opacity(0.1)))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
        }
        .defaultScrollAnchor(.trailing)
    }
}
