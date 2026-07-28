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

/// Grid geometry, hand-tuned per widget family against the standard iOS
/// system widget content-area sizes (small 155x155pt, medium 329x155pt)
/// so cells and gaps line up pixel-perfectly instead of being derived from
/// GeometryReader at render time.
private struct GridLayout {
    let weeks: Int
    let daysPerWeek = 7
    let cellSize: CGFloat
    let spacing: CGFloat

    static let small = GridLayout(weeks: 7, cellSize: 12, spacing: 2.5)
    static let medium = GridLayout(weeks: 16, cellSize: 12, spacing: 2.5)

    static func forFamily(_ family: WidgetFamily) -> GridLayout {
        family == .systemMedium ? .medium : .small
    }

    var gridWidth: CGFloat { CGFloat(weeks) * cellSize + CGFloat(weeks - 1) * spacing }
    var gridHeight: CGFloat { CGFloat(daysPerWeek) * cellSize + CGFloat(daysPerWeek - 1) * spacing }
}

struct DownfaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActivityEntry

    private var layout: GridLayout { .forFamily(family) }

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
        // Anchor on today's own week and step back full weeks — anchoring
        // on the range start instead (then shifting it to its Monday)
        // shrinks the range by that shift, so the last cell always landed
        // a few days before today.
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayOfToday + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let firstMonday = calendar.date(byAdding: .day, value: -(layout.weeks - 1) * 7, to: lastMonday) ?? lastMonday

        return ZStack {
            ContainerRelativeShape().fill(Color.black)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DOWNFACE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .kerning(1.5)
                    Spacer()
                    Text("\(entry.snapshot.currentStreak)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                HStack(spacing: layout.spacing) {
                    ForEach(0..<layout.weeks, id: \.self) { week in
                        VStack(spacing: layout.spacing) {
                            ForEach(0..<layout.daysPerWeek, id: \.self) { day in
                                let date = calendar.date(byAdding: .day, value: week * layout.daysPerWeek + day, to: firstMonday) ?? firstMonday
                                let isFuture = date > today
                                let reps = entry.snapshot.reps(on: date)

                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isFuture ? Color.clear : intensity(for: reps))
                                    .frame(width: layout.cellSize, height: layout.cellSize)
                            }
                        }
                    }
                }
                .frame(width: layout.gridWidth, height: layout.gridHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: family == .systemMedium ? .trailing : .center)

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

struct DownfaceWidget: Widget {
    let kind = "DownfaceActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActivityProvider()) { entry in
            DownfaceWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Downface Activity")
        .description("Your push-up streak, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DownfaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownfaceWidget()
    }
}
