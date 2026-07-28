import SwiftUI

struct HomeView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showWorkout = false
    @State private var showReminderOnboarding = false
    @State private var appeared = false
    @Namespace private var namespace

    /// These four figures are what's actually on screen. They only catch up
    /// to the live snapshot once the rep-count flight animation lands (see
    /// `pendingRepsFlight`), or immediately if no flight is in progress — so
    /// none of the cards jump to the new totals before the flying number
    /// visually arrives, even though the Dart side already pushed the
    /// updated snapshot the moment the finished-workout screen appeared.
    @State private var frozenStats: FrozenStats?
    @State private var todayCardFrame: CGRect = .zero
    @State private var flight: PendingRepsFlight?
    @State private var flightProgress: CGFloat = 0

    private var snapshot: AppSnapshot { bridge.snapshot }

    private var repsToday: Int { frozenStats?.repsToday ?? snapshot.repsToday }
    private var repsThisWeek: Int { frozenStats?.repsThisWeek ?? snapshot.repsThisWeek }
    private var repsThisMonth: Int { frozenStats?.repsThisMonth ?? snapshot.repsThisMonth }
    private var repsAllTime: Int { frozenStats?.repsAllTime ?? snapshot.repsAllTime }
    private var streakCurrent: Int { frozenStats?.streakCurrent ?? snapshot.streak.current }

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

                TodayCard(reps: repsToday)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                PeriodStatsRow(
                    week: repsThisWeek,
                    month: repsThisMonth,
                    allTime: repsAllTime
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.smooth.delay(0.05), value: appeared)

                WeekStreakCard(
                    streak: streakCurrent,
                    completedWeekdays: weekdayCompleted
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.smooth.delay(0.1), value: appeared)

                Spacer()

                actionBar
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)

            if let flight {
                FlyingRepsNumber(reps: flight.reps, from: flight.startFrame, to: todayCardFrame, progress: flightProgress)
            }
        }
        .onPreferenceChange(TodayCardCirclePreferenceKey.self) { todayCardFrame = $0 }
        .onAppear {
            withAnimation(.smooth) { appeared = true }
        }
        .preferredColorScheme(themeManager.theme.colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
        .fullScreenCover(isPresented: $showWorkout, onDismiss: startFlightIfNeeded) {
            WorkoutView()
                .preferredColorScheme(themeManager.theme.colorScheme)
                .onAppear {
                    if case .finished = bridge.workoutState {
                        bridge.workoutState = .ready(supported: bridge.supported)
                    }
                }
        }
        .fullScreenCover(isPresented: $showReminderOnboarding) {
            ReminderOnboardingView()
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
        .onChange(of: snapshot.remindersAsked, initial: true) { _, asked in
            showReminderOnboarding = !asked
        }
        .onChange(of: showWorkout) { _, opened in
            // Freeze every figure the workout could change for the whole
            // time the sheet is up — the Dart side already pushes the
            // updated snapshot before the finished screen appears, so
            // without this the cards would silently show the new totals
            // behind the sheet and the flight animation would land on
            // numbers that never visibly change.
            if opened {
                frozenStats = FrozenStats(snapshot: snapshot)
            }
        }
    }

    /// Picks up the rep count and screen position stashed by the
    /// finished-workout screen right as the sheet finishes dismissing, and
    /// animates a copy of that number flying into the today card. The real
    /// snapshot (already updated) only becomes visible, card by card, once
    /// the flight lands.
    private func startFlightIfNeeded() {
        guard let pending = bridge.pendingRepsFlight else {
            frozenStats = nil
            return
        }
        bridge.pendingRepsFlight = nil
        flight = pending
        flightProgress = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            flightProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.smooth) {
                frozenStats = nil
                flight = nil
            }
        }
    }

    private var header: some View {
        HStack {
            BrandMark()
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

private struct FrozenStats {
    let repsToday: Int
    let repsThisWeek: Int
    let repsThisMonth: Int
    let repsAllTime: Int
    let streakCurrent: Int

    init(snapshot: AppSnapshot) {
        repsToday = snapshot.repsToday
        repsThisWeek = snapshot.repsThisWeek
        repsThisMonth = snapshot.repsThisMonth
        repsAllTime = snapshot.repsAllTime
        streakCurrent = snapshot.streak.current
    }
}

/// Animates a copy of the just-finished rep count from wherever it sat on
/// the finished-workout screen to the "push-ups today" circle, shrinking
/// and fading as it arrives so it visually merges into the smaller number
/// already living there rather than just teleporting between two states.
private struct FlyingRepsNumber: View {
    let reps: Int
    let from: CGRect
    let to: CGRect
    let progress: CGFloat

    private var currentFrame: CGRect {
        CGRect(
            x: from.minX + (to.midX - from.midX) * progress,
            y: from.minY + (to.midY - from.midY) * progress,
            width: from.width,
            height: from.height
        )
    }

    private var scale: CGFloat {
        let targetScale: CGFloat = 22 / 64
        return 1 + (targetScale - 1) * progress
    }

    var body: some View {
        Text("\(reps)")
            .font(DFType.number)
            .foregroundStyle(DFColor.textPrimary)
            .scaleEffect(scale)
            .opacity(1 - progress * 0.3)
            .position(x: currentFrame.midX, y: currentFrame.midY)
            .allowsHitTesting(false)
    }
}

/// The app wordmark in the top-left corner. Uses a slow, seamless
/// breathing pulse (autoreverse, no easing snap at the loop point) so it
/// reads as ambient life rather than a jarring blink.
private struct BrandMark: View {
    @State private var glowing = false

    var body: some View {
        Text(verbatim: "Downface")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(DFColor.textPrimary)
            .opacity(glowing ? 1 : 0.45)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
    }
}

private struct TodayCardCirclePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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
                        .foregroundStyle(DFColor.background)
                        .contentTransition(.numericText())
                        .animation(.smooth, value: reps)
                }
                .frame(width: 56, height: 56)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TodayCardCirclePreferenceKey.self, value: geo.frame(in: .global))
                    }
                )

                Text("push-ups\ntoday")
                    .font(DFType.title)
                    .foregroundStyle(DFColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DFSpacing.cardPadding)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
    let label: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(DFColor.textPrimary)
                .contentTransition(.numericText())
                .animation(.smooth, value: value)
            Text(label)
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WeekStreakCard: View {
    let streak: Int
    let completedWeekdays: Set<Int>

    private let labels: [LocalizedStringKey] = ["M", "T", "W", "T", "F", "S", "S"]

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
                            Circle().fill(done ? DFColor.textPrimary : DFColor.scrim)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(DFColor.background)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 34, height: 34)
                        .animation(.bouncy, value: done)

                        Text(labels[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DFColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DFSpacing.cardPadding)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
