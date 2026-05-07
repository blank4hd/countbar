import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Counter.createdAt) private var counters: [Counter]
    @AppStorage("dashboardSelectedCounterID") private var selectedID: String = ""

    private var selectedCounter: Counter? {
        counters.first { $0.id.uuidString == selectedID } ?? counters.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let counter = selectedCounter {
                ScrollView {
                    DashboardContent(counter: counter)
                        .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "No counters yet",
                    systemImage: "number.circle",
                    description: Text("Add a counter from the menu bar to see analytics.")
                )
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            if selectedID.isEmpty, let first = counters.first {
                selectedID = first.id.uuidString
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Dashboard")
                .font(.title2.weight(.semibold))
            Spacer()
            if !counters.isEmpty {
                Picker("Counter", selection: $selectedID) {
                    ForEach(counters) { counter in
                        Text(counter.name).tag(counter.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Content for a selected counter

private struct DashboardContent: View {
    let counter: Counter

    private var analytics: CounterAnalytics { CounterAnalytics(counter: counter) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            statsGrid
            chartSection
            heatmapSection
        }
    }

    // MARK: Stat cards

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatCard(label: "Last 7 days",  value: "\(analytics.sum(lastDays: 7))")
            StatCard(label: "Last 30 days", value: "\(analytics.sum(lastDays: 30))")
            StatCard(label: "All time",     value: "\(analytics.allTimeSum)")
            StatCard(label: "Daily average", value: String(format: "%.1f", analytics.dailyAverage))

            if let best = analytics.bestDay {
                StatCard(label: "Best day", value: "\(best.value)", subtitle: dateString(best.date))
            }
            if let low = analytics.lowestActiveDay {
                StatCard(label: "Lowest active day", value: "\(low.value)", subtitle: dateString(low.date))
            }

            if counter.goal > 0 {
                StatCard(label: "Current streak", value: "\(analytics.currentStreak)", subtitle: "days")
                StatCard(label: "Longest streak", value: "\(analytics.longestStreak)", subtitle: "days")
                StatCard(
                    label: "Goal hit rate",
                    value: "\(Int(analytics.goalHitRate * 100))%",
                    subtitle: "of tracked days"
                )
            }
        }
    }

    // MARK: Daily chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 days")
                .font(.headline)

            let series = analytics.dailySeries(lastDays: 30)

            Chart {
                ForEach(series, id: \.date) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Count", day.value)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                if counter.goal > 0 {
                    RuleMark(y: .value("Goal", counter.goal))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal: \(counter.goal)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }

    // MARK: Heatmap (12 weeks)

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity (12 weeks)")
                .font(.headline)
            HeatmapView(series: analytics.dailySeries(lastDays: 84), goal: counter.goal)
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - HeatmapView

private struct HeatmapView: View {
    let series: [(date: Date, value: Int)]
    let goal: Int

    private let cellSize: CGFloat = 14
    private let spacing: CGFloat = 3

    var body: some View {
        // Group by week. Each column is a week (7 cells), oldest week on the left.
        let columns = weeklyColumns()

        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { dayOfWeek in
                        let entry = week[safe: dayOfWeek] ?? nil
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: entry?.value ?? 0))
                            .frame(width: cellSize, height: cellSize)
                            .help(tooltipText(entry))
                    }
                }
            }
        }
    }

    /// Splits the daily series into chunks of 7, each chunk a week.
    /// Pads the start with `nil` so the first column begins on Sunday.
    private func weeklyColumns() -> [[(date: Date, value: Int)?]] {
        let cal = Calendar.current
        guard let first = series.first?.date else { return [] }
        // Sunday = 1 in Calendar.current by default; offset to align grid.
        let firstWeekday = cal.component(.weekday, from: first) - 1
        var padded: [(date: Date, value: Int)?] = Array(repeating: nil, count: firstWeekday)
        padded.append(contentsOf: series.map { Optional($0) })

        var weeks: [[(date: Date, value: Int)?]] = []
        var current: [(date: Date, value: Int)?] = []
        for cell in padded {
            current.append(cell)
            if current.count == 7 {
                weeks.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            while current.count < 7 { current.append(nil) }
            weeks.append(current)
        }
        return weeks
    }

    private func color(for value: Int) -> Color {
        if value == 0 { return Color.primary.opacity(0.07) }
        // Scale opacity against goal (or max of series if no goal).
        let denom: Double
        if goal > 0 {
            denom = Double(goal)
        } else {
            denom = Double(series.map(\.value).max() ?? 1)
        }
        let intensity = min(max(Double(value) / denom, 0.15), 1.0)
        return Color.accentColor.opacity(intensity)
    }

    private func tooltipText(_ entry: (date: Date, value: Int)?) -> String {
        guard let entry else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return "\(f.string(from: entry.date)): \(entry.value)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
