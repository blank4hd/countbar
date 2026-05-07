import Foundation
import SwiftData

/// Computes analytics for a counter from its daily entries.
/// Pure data — no UI dependencies. Safe to call from anywhere on the main actor.
@MainActor
struct CounterAnalytics {
    let counter: Counter
    let now: Date

    init(counter: Counter, now: Date = Date()) {
        self.counter = counter
        self.now = now
    }

    // MARK: - Time-window sums

    /// Sum of values over the last N days (inclusive of today).
    /// `days = 7` returns last week, `days = 30` returns last month, etc.
    func sum(lastDays days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return counter.entries
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + $1.value }
    }

    var allTimeSum: Int {
        counter.entries.reduce(0) { $0 + $1.value }
    }

    // MARK: - Daily statistics

    /// Average value per tracked day (i.e., averaged over days that have entries,
    /// not over all calendar days). Returns 0 if there are no entries.
    var dailyAverage: Double {
        let entries = counter.entries.filter { $0.value > 0 }
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.value }
        return Double(total) / Double(entries.count)
    }

    /// Highest single-day value across all history.
    var bestDay: (date: Date, value: Int)? {
        guard let max = counter.entries.max(by: { $0.value < $1.value }) else { return nil }
        return (max.date, max.value)
    }

    /// Lowest non-zero day value. Zero days are excluded since they're not
    /// meaningful as a "low" — they're just untracked or reset days.
    var lowestActiveDay: (date: Date, value: Int)? {
        guard let min = counter.entries
            .filter({ $0.value > 0 })
            .min(by: { $0.value < $1.value })
        else { return nil }
        return (min.date, min.value)
    }

    // MARK: - Streaks (only meaningful for goaled counters)

    /// Current streak: number of consecutive days, ending yesterday or today,
    /// where the counter hit its goal. Untracked days count as misses.
    var currentStreak: Int {
        guard counter.goal > 0 else { return 0 }
        let cal = Calendar.current

        // Walk backwards from today. If today doesn't yet meet goal, start
        // from yesterday so a partial-progress day doesn't break a streak.
        var cursor = cal.startOfDay(for: now)
        if !didHitGoal(on: cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var count = 0
        while didHitGoal(on: cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Longest streak ever recorded. Walks all entries grouped by day.
    var longestStreak: Int {
        guard counter.goal > 0, !counter.entries.isEmpty else { return 0 }
        let cal = Calendar.current

        // Build a set of "days where goal was hit" for fast lookup.
        let hitDays: Set<Date> = Set(
            counter.entries
                .filter { $0.value >= counter.goal }
                .map { cal.startOfDay(for: $0.date) }
        )
        guard !hitDays.isEmpty else { return 0 }

        // Walk every hit day, count consecutive runs.
        let sortedDays = hitDays.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let prev = sortedDays[i - 1]
            let curr = sortedDays[i]
            if let next = cal.date(byAdding: .day, value: 1, to: prev),
               cal.isDate(next, inSameDayAs: curr) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// Percentage of tracked days where goal was hit (0...1).
    /// Only meaningful for goaled counters.
    var goalHitRate: Double {
        guard counter.goal > 0 else { return 0 }
        let trackedDays = counter.entries.filter { $0.value > 0 }
        guard !trackedDays.isEmpty else { return 0 }
        let hits = trackedDays.filter { $0.value >= counter.goal }.count
        return Double(hits) / Double(trackedDays.count)
    }

    // MARK: - Daily series for charts

    /// Returns daily values for the last `days` days, with zeros filled in
    /// for days that have no entry. Useful for line charts and heatmaps.
    func dailySeries(lastDays days: Int) -> [(date: Date, value: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        // Index entries by start-of-day for O(1) lookup
        let entryByDay: [Date: Int] = Dictionary(
            uniqueKeysWithValues: counter.entries.map {
                (cal.startOfDay(for: $0.date), $0.value)
            }
        )

        var result: [(date: Date, value: Int)] = []
        for offset in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append((day, entryByDay[day] ?? 0))
        }
        return result
    }

    // MARK: - Helpers

    private func didHitGoal(on day: Date) -> Bool {
        guard counter.goal > 0 else { return false }
        let cal = Calendar.current
        let normalized = cal.startOfDay(for: day)
        return counter.entries.contains { entry in
            cal.isDate(entry.date, inSameDayAs: normalized) && entry.value >= counter.goal
        }
    }
}
