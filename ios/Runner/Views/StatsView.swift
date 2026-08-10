import Charts
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

    var body: some View {
        ZStack(alignment: .top) {
            DFColor.background.ignoresSafeArea()

            // A blurred fog over the status bar, fading to nothing by the
            // time content starts – on a black background a flat color fade
            // is invisible, so this needs an actual material to read as fog
            // rather than a hard-clipped edge.
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 120)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            Group {
                if hasWorkouts {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Clears the floating back/share buttons – the
                            // card's own background still runs up under the
                            // status bar (the fog above), only its text
                            // content needs to start below the buttons.
                            Color.clear.frame(height: 56)

                            // Paged instead of stacked: activity already
                            // scrolls sideways on its own (twenty weeks
                            // wide), and progress needs horizontal drags to
                            // pick a week. Either one living inside the
                            // screen's vertical scroll meant a side-swipe
                            // starting on the chart or the grid could be
                            // read as "scroll the page" first – dropping
                            // reps or dragging past the intended week. A
                            // full-bleed page per card removes that fight
                            // entirely: a swipe here can only mean "next
                            // card". The TabView itself spans edge-to-edge
                            // (no outer horizontal padding) so a swipe
                            // starting near the screen edge still lands on
                            // it; each card pads itself in from there.
                            //
                            // Both pages share one fixed height regardless
                            // of how much detail content they're showing –
                            // each card scrolls its own overflow internally
                            // instead of growing, so the page indicator
                            // dots (sized to the TabView, not to whichever
                            // page is visible) never jump between pages.
                            TabView {
                                activityCard
                                weeklyProgressCard
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .frame(height: 420)

                            HStack(spacing: 12) {
                                MetricCard(label: "avg rep", value: String(format: "%.1fs", avgRepSeconds))
                                MetricCard(label: "avg rest", value: "\(Int(avgRestSeconds))s")
                            }
                            .padding(.horizontal, DFSpacing.screenPadding)
                            HStack(spacing: 12) {
                                MetricCard(label: "longest streak", value: "\(snapshot.streak.longest)d")
                                MetricCard(label: "total workouts", value: "\(snapshot.workouts.count)")
                            }
                            .padding(.horizontal, DFSpacing.screenPadding)
                            HStack(spacing: 12) {
                                MetricCard(label: "best set", value: "\(snapshot.bestSingleSet)")
                                MetricCard(label: "best day", value: "\(snapshot.bestSingleDay)")
                            }
                            .padding(.horizontal, DFSpacing.screenPadding)
                            Color.clear.frame(height: 4)
                        }
                    }
                    .scrollIndicators(.visible)
                } else {
                    EmptyStatsView()
                }
            }

            // A round glass back button standing in for the sheet's usual
            // swipe-down-to-dismiss – that gesture works fine once you know
            // it's there, but nothing on screen hints at it. A control that
            // looks like the back button used everywhere else in the app
            // reads as "there's a way out" without the user having to guess.
            HStack {
                BackButton { dismiss() }
                Spacer()
                if hasWorkouts {
                    ShareButton { showShareCard = true }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, DFSpacing.screenPadding)
        }
        .sheet(isPresented: $showShareCard) { ShareCardView() }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("activity")
                .font(DFType.title)
                .foregroundStyle(DFColor.textPrimary)
            ActivityGrid(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(DFSpacing.cardPadding)
        .padding(.bottom, 32)
        .dfCardSurface(cornerRadius: 28)
        .padding(.horizontal, DFSpacing.screenPadding)
    }

    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("progress by week")
                .font(DFType.title)
                .foregroundStyle(DFColor.textPrimary)
            WeeklyProgressChart(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DFSpacing.cardPadding)
        .padding(.bottom, 32)
        .dfCardSurface(cornerRadius: 28)
        .padding(.horizontal, DFSpacing.screenPadding)
    }
}

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DFColor.textPrimary)
                .frame(width: 40, height: 40)
        }
        .dfCircleButtonStyle()
    }
}

private struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DFColor.textPrimary)
                .frame(width: 40, height: 40)
        }
        .dfCircleButtonStyle()
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
    let label: LocalizedStringKey
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
        .dfCardSurface(cornerRadius: 20)
    }
}

private struct WeeklyProgressChart: View {
    let snapshot: AppSnapshot
    @State private var selectedWeekStart: Date?
    private let weeksShown = 12

    private struct WeekPoint: Identifiable {
        let id: Int
        let weekStart: Date
        let reps: Int
    }

    private var calendar: Calendar { Calendar.current }

    private var points: [WeekPoint] {
        let today = calendar.startOfDay(for: Date())
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayOfToday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today

        return (0..<weeksShown).reversed().map { weeksAgo in
            let weekStart = calendar.date(byAdding: .day, value: -weeksAgo * 7, to: thisMonday) ?? thisMonday
            let total = (0..<7).reduce(0) { sum, dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                return sum + snapshot.reps(on: date)
            }
            return WeekPoint(id: weeksAgo, weekStart: weekStart, reps: total)
        }
    }

    private var averageReps: Double {
        guard !points.isEmpty else { return 0 }
        return Double(points.reduce(0) { $0 + $1.reps }) / Double(points.count)
    }

    /// Falls back to the most recent week so the detail card, and the
    /// highlight it drives in the activity grid above, are never empty.
    private var selectedWeek: WeekPoint? {
        guard let selectedWeekStart else { return points.last }
        return points.first { $0.weekStart == selectedWeekStart } ?? points.last
    }

    private var selectedWeekIndex: Int? {
        guard let selectedWeek else { return nil }
        return points.firstIndex { $0.id == selectedWeek.id }
    }

    private var previousWeek: WeekPoint? {
        guard let index = selectedWeekIndex, index > 0 else { return nil }
        return points[index - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("week", point.weekStart),
                        y: .value("reps", point.reps)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DFColor.textPrimary.opacity(0.25), DFColor.textPrimary.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("week", point.weekStart),
                        y: .value("reps", point.reps)
                    )
                    .foregroundStyle(DFColor.textPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("week", point.weekStart),
                        y: .value("reps", point.reps)
                    )
                    .foregroundStyle(DFColor.textPrimary)
                    .symbolSize(selectedWeek?.id == point.id ? 70 : 0)
                }

                // A flat reference line for the average lets a given week's
                // height mean something ("above/below your normal") instead
                // of being a number with nothing to compare against.
                RuleMark(y: .value("average", averageReps))
                    .foregroundStyle(DFColor.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if let selectedWeek {
                    RuleMark(x: .value("selected week", selectedWeek.weekStart))
                        .foregroundStyle(DFColor.textPrimary.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DFColor.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(DFColor.divider)
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DFColor.textTertiary)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let originX = geo[plotFrame].origin.x
                                    let x = value.location.x - originX
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    if let tapped = points.min(by: {
                                        abs($0.weekStart.timeIntervalSince(date)) < abs($1.weekStart.timeIntervalSince(date))
                                    }) {
                                        selectedWeekStart = tapped.weekStart
                                    }
                                }
                        )
                }
            }
            .frame(height: 140)

            if let selectedWeek {
                weekDetail(week: selectedWeek, previous: previousWeek)
            }
        }
    }

    private func weekRangeText(_ weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return String(
            format: NSLocalizedString("%@ - %@", comment: "week range, e.g. Jul 14 - Jul 20"),
            formatter.string(from: weekStart),
            formatter.string(from: weekEnd)
        )
    }

    private func weekRepsText(_ reps: Int) -> String {
        let key = reps == 1 ? "%lld rep" : "%lld reps"
        return String(format: NSLocalizedString(key, comment: ""), reps)
    }

    private func vsPriorWeekText(change: Int, previousReps: Int) -> String {
        let key = "%@%lld vs %lld prior week"
        return String(format: NSLocalizedString(key, comment: ""), change >= 0 ? "+" : "", change, previousReps)
    }

    private func weekDetail(week: WeekPoint, previous: WeekPoint?) -> some View {
        let change: Int? = previous.map { week.reps - $0.reps }
        let changePercent: Int? = previous.flatMap { prev in
            guard prev.reps > 0 else { return nil }
            return Int((Double(week.reps - prev.reps) / Double(prev.reps) * 100).rounded())
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekRangeText(week.weekStart))
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textSecondary)
                Spacer()
                if let changePercent {
                    Label(
                        "\(changePercent >= 0 ? "+" : "")\(changePercent)%",
                        systemImage: changePercent >= 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(DFType.caption.weight(.semibold))
                    .foregroundStyle(changePercent >= 0 ? DFColor.textPrimary : DFColor.textTertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(weekRepsText(week.reps))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(DFColor.textPrimary)
                if let change, let previous {
                    Text(vsPriorWeekText(change: change, previousReps: previous.reps))
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DFColor.cardFillStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.smooth, value: week.id)
    }
}

private struct ActivityGrid: View {
    let snapshot: AppSnapshot
    private let weeks = 20

    @State private var selectedDate: Date?
    @State private var showFullDay = false

    private var maxReps: Int {
        max(snapshot.workouts.map { $0.totalReps }.max() ?? 1, 1)
    }

    private func intensity(for reps: Int) -> Color {
        guard reps > 0 else { return DFColor.cardFillStrong }
        let ratio = Double(reps) / Double(maxReps)
        return DFColor.textPrimary.opacity(0.35 + ratio * 0.65)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Anchor the grid on today's own week, then step back full weeks –
        // anchoring on the range *start* instead (and shifting it back to
        // its Monday) shrinks the range by however many days that shift
        // was, so the last cell always landed a few days before today.
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayOfToday + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let firstMonday = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: lastMonday) ?? lastMonday
        // Defaults to today so the card never opens on an empty detail row.
        let initialDate = selectedDate ?? today

        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    monthLabels(calendar: calendar, firstMonday: firstMonday)

                    HStack(alignment: .top, spacing: 5) {
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: 5) {
                                ForEach(0..<7, id: \.self) { day in
                                    let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstMonday) ?? firstMonday
                                    let isFuture = date > today
                                    let reps = snapshot.reps(on: date)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isFuture ? Color.clear : intensity(for: reps))
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(DFColor.textPrimary.opacity(calendar.isDate(date, inSameDayAs: initialDate) ? 0.9 : 0), lineWidth: 1.5)
                                        )
                                        .onTapGesture {
                                            guard !isFuture else { return }
                                            selectedDate = date
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)

            // A fixed-height scroll instead of letting the sets list push
            // the card taller – with the page indicator sized to this
            // page's own height, a growing card would either clip under
            // the dots or shove the sibling page's dots around as you
            // swipe. "show all" breaks out to a full sheet for a day with
            // more sets than the card can show at once.
            dayDetail(date: initialDate, reps: snapshot.reps(on: initialDate))
        }
        .sheet(isPresented: $showFullDay) {
            DayDetailSheet(date: initialDate, sets: setsOn(initialDate), reps: snapshot.reps(on: initialDate))
        }
    }

    private func repsText(_ reps: Int) -> String {
        let key = reps == 1 ? "%lld rep" : "%lld reps"
        return String(format: NSLocalizedString(key, comment: ""), reps)
    }

    private func setsCountText(_ count: Int) -> String {
        let key = count == 1 ? "%lld set" : "%lld sets"
        return String(format: NSLocalizedString(key, comment: ""), count)
    }

    private func setLabelText(_ index: Int) -> String {
        String(format: NSLocalizedString("set %lld", comment: ""), index)
    }

    private func restText(_ seconds: Int) -> String {
        String(format: NSLocalizedString("rest %llds", comment: ""), seconds)
    }

    private func setsOn(_ date: Date) -> [WorkoutSetSnapshot] {
        let calendar = Calendar.current
        return snapshot.workouts
            .filter { calendar.isDate(Date(timeIntervalSince1970: $0.startedAt / 1000), inSameDayAs: date) }
            .flatMap { $0.sets }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Sets beyond this count would push the card past its fixed height,
    /// so the list stops here and hands off to `DayDetailSheet` instead.
    private static let inlineSetLimit = 3

    private func dayDetail(date: Date, reps: Int) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let sets = setsOn(date)
        let overflow = sets.count > Self.inlineSetLimit

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(formatter.string(from: date))
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textSecondary)
                Spacer()
                Text(reps > 0 ? repsText(reps) : "no workout")
                    .font(DFType.caption.weight(.semibold))
                    .foregroundStyle(reps > 0 ? DFColor.textPrimary : DFColor.textTertiary)
            }

            if !sets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(setsCountText(sets.count))
                            .font(DFType.caption.weight(.semibold))
                            .foregroundStyle(DFColor.textPrimary)
                        Spacer()
                        if overflow {
                            Button("show all") { showFullDay = true }
                                .font(DFType.caption.weight(.semibold))
                                .foregroundStyle(DFColor.textSecondary)
                        }
                    }

                    ForEach(Array(sets.prefix(Self.inlineSetLimit).enumerated()), id: \.offset) { index, set in
                        setRow(index: index, set: set)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DFColor.cardFillStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func setRow(index: Int, set: WorkoutSetSnapshot) -> some View {
        HStack {
            Text(setLabelText(index + 1))
                .font(DFType.caption)
                .foregroundStyle(DFColor.textTertiary)
            Spacer()
            if set.restBeforeSeconds > 0 {
                Text(restText(set.restBeforeSeconds))
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textTertiary)
            }
            Text(repsText(set.reps))
                .font(DFType.caption.weight(.medium))
                .foregroundStyle(DFColor.textSecondary)
        }
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
                let width = CGFloat(nextWeek - item.week) * 23
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DFColor.textTertiary)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

/// Full, unclipped view of a day's sets – reached from "show all" once a
/// day has more sets than `ActivityGrid`'s fixed-height card can inline.
private struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let sets: [WorkoutSetSnapshot]
    let reps: Int

    private func repsText(_ reps: Int) -> String {
        let key = reps == 1 ? "%lld rep" : "%lld reps"
        return String(format: NSLocalizedString(key, comment: ""), reps)
    }

    private func setLabelText(_ index: Int) -> String {
        String(format: NSLocalizedString("set %lld", comment: ""), index)
    }

    private func restText(_ seconds: Int) -> String {
        String(format: NSLocalizedString("rest %llds", comment: ""), seconds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text(setLabelText(index + 1))
                                .font(DFType.body)
                                .foregroundStyle(DFColor.textTertiary)
                            Spacer()
                            if set.restBeforeSeconds > 0 {
                                Text(restText(set.restBeforeSeconds))
                                    .font(DFType.caption)
                                    .foregroundStyle(DFColor.textTertiary)
                            }
                            Text(repsText(set.reps))
                                .font(DFType.body.weight(.semibold))
                                .foregroundStyle(DFColor.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(DFColor.cardFillStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(DFSpacing.screenPadding)
            }
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle(repsText(reps))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
            }
        }
    }
}
