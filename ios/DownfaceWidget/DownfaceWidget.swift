import WidgetKit
import SwiftUI

struct ActivityEntry: TimelineEntry {
    let date: Date
    let snapshot: ActivitySnapshot
}

struct ActivityProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityEntry {
        ActivityEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (ActivityEntry) -> Void) {
        completion(ActivityEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityEntry>) -> Void) {
        let entry = ActivityEntry(date: Date(), snapshot: .load())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

/// Fills the given content-area size edge-to-edge with a 7-row grid: the
/// cell size is solved from the available height first (7 rows + 6 gaps),
/// then however many whole weeks fit that width are shown – so the grid
/// always reaches every edge of the widget with even, proportional gaps
/// instead of a fixed cell size leaving leftover space on one side.
private struct GridLayout {
    let weeks: Int
    let daysPerWeek = 7
    let cellSize: CGFloat
    let spacing: CGFloat

    static func fitting(weeks maxWeeks: Int, in size: CGSize) -> GridLayout {
        let gapRatio: CGFloat = 0.22
        // Solve cellSize from height: size.height = 7*cell + 6*(cell*gapRatio)
        let cellSize = size.height / (7 + 6 * gapRatio)
        let spacing = cellSize * gapRatio

        let weeksThatFit = Int(((size.width + spacing) / (cellSize + spacing)).rounded(.down))
        let weeks = max(1, min(maxWeeks, weeksThatFit))
        return GridLayout(weeks: weeks, cellSize: cellSize, spacing: spacing)
    }
}

struct DownfaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ActivityEntry

    private var maxWeeks: Int { family == .systemMedium ? 16 : 7 }

    /// iOS 26's tinted/glass home screen mode replaces widget colors with
    /// a system-applied tint – fighting that with hardcoded black/white
    /// (which is what made the whole widget render as a solid white
    /// block) instead of adapting to it. `.accented` / `.vibrant` modes
    /// get the system's own foreground style; only plain `.fullColor`
    /// gets our real black/white palette.
    private var isFullColor: Bool { renderingMode == .fullColor }

    private var maxReps: Int {
        entry.snapshot.repsPerDay.values.max() ?? 1
    }

    /// Linear intensity scale from a dim baseline (no activity) up to full
    /// white for the day with the most reps in the visible window, so a
    /// 40-rep day always reads brighter than a 20-rep day.
    private func intensity(for reps: Int) -> Color {
        guard reps > 0 else { return Color.white.opacity(0.08) }
        let ratio = Double(reps) / Double(max(maxReps, 1))
        return Color.white.opacity(0.22 + ratio * 0.78)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Anchor on today's own week and step back full weeks – anchoring
        // on the range start instead (then shifting it to its Monday)
        // shrinks the range by that shift, so the last cell always landed
        // a few days before today.
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayOfToday + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let firstMonday = calendar.date(byAdding: .day, value: -(maxWeeks - 1) * 7, to: lastMonday) ?? lastMonday

        return GeometryReader { geo in
            // Fixed HIG-standard inset (matches Apple's own widgets) on
            // every side instead of a proportional one – a flat constant
            // reads as consistent padding across widget sizes the way a
            // ratio of the shortest side doesn't.
            let inset: CGFloat = 16
            let contentSize = CGSize(width: geo.size.width - inset * 2, height: geo.size.height - inset * 2)
            let grid = GridLayout.fitting(weeks: maxWeeks, in: contentSize)
            // The visible weeks are always the most recent ones – if fewer
            // weeks fit than maxWeeks, skip past the older ones instead of
            // showing the oldest slice of the requested range.
            let weekOffset = maxWeeks - grid.weeks
            let gridWidth = CGFloat(grid.weeks) * grid.cellSize + CGFloat(grid.weeks - 1) * grid.spacing

            HStack(spacing: grid.spacing) {
                ForEach(0..<grid.weeks, id: \.self) { week in
                    VStack(spacing: grid.spacing) {
                        ForEach(0..<grid.daysPerWeek, id: \.self) { day in
                            let date = calendar.date(byAdding: .day, value: (week + weekOffset) * grid.daysPerWeek + day, to: firstMonday) ?? firstMonday
                            let isFuture = date > today
                            let reps = entry.snapshot.reps(on: date)
                            let baseRadius = grid.cellSize * 0.25
                            let outerRadius = grid.cellSize * 0.55
                            let isFirstWeek = week == 0
                            let isLastWeek = week == grid.weeks - 1
                            let isFirstDay = day == 0
                            let isLastDay = day == grid.daysPerWeek - 1

                            // Only the corner of each outermost cell that
                            // actually faces the widget's own rounded edge
                            // opens up to echo that curve – rounding every
                            // corner of the cell turned it into a circle
                            // instead of a square with one softened corner.
                            UnevenRoundedRectangle(
                                topLeadingRadius: (isFirstWeek && isFirstDay) ? outerRadius : baseRadius,
                                bottomLeadingRadius: (isFirstWeek && isLastDay) ? outerRadius : baseRadius,
                                bottomTrailingRadius: (isLastWeek && isLastDay) ? outerRadius : baseRadius,
                                topTrailingRadius: (isLastWeek && isFirstDay) ? outerRadius : baseRadius,
                                style: .continuous
                            )
                                .fill(isFuture ? Color.clear : intensity(for: reps))
                                .frame(width: grid.cellSize, height: grid.cellSize)
                        }
                    }
                }
            }
            .widgetAccentable(!isFullColor)
            // Sized to the grid's own footprint (not the full widget) so
            // centering can't smuggle back the leftover space that
            // rounding-down the week count leaves on the width axis –
            // that leftover used to widen the side inset past the
            // top/bottom one instead of splitting evenly.
            .frame(width: gridWidth, height: geo.size.height - inset * 2, alignment: .top)
            // Pinned to the top instead of centered vertically: iOS reserves
            // a bit of extra room below the visible widget surface (for the
            // system's own shelf/shadow), which GeometryReader's size still
            // includes – centering split that slack evenly, so it silently
            // widened the bottom inset past the top one instead of leaving
            // both equal.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .padding(.top, inset)
        }
        .containerBackground(for: .widget) {
            if isFullColor {
                Color.black
            }
        }
    }
}

struct DownfaceWidget: Widget {
    let kind = "DownfaceActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActivityProvider()) { entry in
            DownfaceWidgetView(entry: entry)
        }
        .configurationDisplayName("Downface Activity")
        .description("Your push-up streak, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct DownfaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownfaceWidget()
    }
}
