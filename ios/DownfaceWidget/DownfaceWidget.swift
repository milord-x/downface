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

struct DownfaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActivityEntry

    private let daysPerWeek = 7

    private var weeks: Int {
        family == .systemMedium ? 15 : 7
    }

    private var maxReps: Int {
        entry.snapshot.repsPerDay.values.max() ?? 1
    }

    private func intensity(for reps: Int) -> Color {
        guard reps > 0 else { return Color.white.opacity(0.08) }
        let ratio = Double(reps) / Double(max(maxReps, 1))
        return Color.white.opacity(0.25 + ratio * 0.75)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let totalDays = weeks * daysPerWeek
        let start = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today
        let weekdayOfStart = calendar.component(.weekday, from: start)
        let daysToMonday = (weekdayOfStart + 5) % 7
        let firstMonday = calendar.date(byAdding: .day, value: -daysToMonday, to: start) ?? start

        return ZStack {
            ContainerRelativeShape().fill(Color.black)

            VStack(spacing: 6) {
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

                GeometryReader { geo in
                    let spacing: CGFloat = 3
                    let widthPerCell = (geo.size.width - spacing * CGFloat(weeks - 1)) / CGFloat(weeks)
                    let heightPerCell = (geo.size.height - spacing * CGFloat(daysPerWeek - 1)) / CGFloat(daysPerWeek)
                    let cellSize = min(widthPerCell, heightPerCell)

                    HStack(spacing: spacing) {
                        Spacer(minLength: 0)
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: spacing) {
                                ForEach(0..<daysPerWeek, id: \.self) { day in
                                    let date = calendar.date(byAdding: .day, value: week * daysPerWeek + day, to: firstMonday) ?? firstMonday
                                    let isFuture = date > today
                                    let reps = entry.snapshot.reps(on: date)

                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(isFuture ? Color.clear : intensity(for: reps))
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
