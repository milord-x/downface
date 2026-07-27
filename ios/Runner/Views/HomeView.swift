import SwiftUI

struct HomeView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showWorkout = false
    @State private var showReminderOnboarding = false
    @Namespace private var namespace

    private var snapshot: AppSnapshot { bridge.snapshot }

    private var weekdayCompleted: Set<Int> {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return [] }

        return Set(snapshot.activeDayTimestamps.compactMap { ts -> Int? in
            let date = Date(timeIntervalSince1970: ts / 1000)
            guard date >= weekStart else { return nil }
            return calendar.component(.weekday, from: date)
        })
    }

    var body: some View {
        ZStack {
            DFColor.background.ignoresSafeArea()

            VStack(spacing: DFSpacing.stackGap) {
                header

                TodayCard(reps: snapshot.repsToday)

                PeriodStatsRow(
                    week: snapshot.repsThisWeek,
                    month: snapshot.repsThisMonth,
                    allTime: snapshot.repsAllTime
                )

                WeekStreakCard(
                    streak: snapshot.streak.current,
                    completedWeekdays: weekdayCompleted
                )

                Spacer()

                actionBar
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showStats) { StatsView() }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutView()
                .onAppear {
                    if case .finished = bridge.workoutState {
                        bridge.workoutState = .ready(supported: bridge.supported)
                    }
                }
        }
        .fullScreenCover(isPresented: $showReminderOnboarding) {
            ReminderOnboardingView()
        }
        .onChange(of: snapshot.remindersAsked, initial: true) { _, asked in
            showReminderOnboarding = !asked
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DFColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    showWorkout = true
                } label: {
                    Text("start workout")
                        .font(DFType.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .glassEffectID("start", in: namespace)

                Button {
                    showStats = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .glassEffectID("stats", in: namespace)
            }
        }
    }
}

private struct TodayCard: View {
    let reps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().fill(DFColor.textPrimary)
                    Text("\(reps)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }
                .frame(width: 56, height: 56)

                Text("push-ups\ntoday")
                    .font(DFType.title)
                    .foregroundStyle(DFColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DFSpacing.cardPadding)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PeriodStatsRow: View {
    let week: Int
    let month: Int
    let allTime: Int

    var body: some View {
        HStack(spacing: 12) {
            StatPill(label: "this week", value: week)
            StatPill(label: "this month", value: month)
            StatPill(label: "so far", value: allTime)
        }
    }
}

private struct StatPill: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(DFColor.textPrimary)
            Text(label)
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WeekStreakCard: View {
    let streak: Int
    let completedWeekdays: Set<Int>

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("this week")
                    .font(DFType.title)
                    .foregroundStyle(DFColor.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(DFColor.textPrimary)
                    Text("\(streak)")
                        .font(DFType.body)
                        .foregroundStyle(DFColor.textPrimary)
                }
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    let weekday = ((index + 1) % 7) + 1
                    let done = completedWeekdays.contains(weekday)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(done ? DFColor.textPrimary : Color.white.opacity(0.1))
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(width: 34, height: 34)

                        Text(labels[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DFColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DFSpacing.cardPadding)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
