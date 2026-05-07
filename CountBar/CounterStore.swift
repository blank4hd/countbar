import Foundation
import SwiftData

@MainActor
struct CounterStore {
    let context: ModelContext

    /// The logical day a counter is "currently in," based on its resetTime.
    /// For a counter that resets at 4am, "today" runs from 4am today to 4am tomorrow.
    func logicalDay(for counter: Counter, at now: Date = Date()) -> Date {
        let cal = Calendar.current

        guard let resetTime = counter.resetTime else {
            // Counter never resets — use a fixed "epoch day" so all activity
            // accumulates into one logical entry.
            return cal.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? .distantPast
        }

        let resetComponents = cal.dateComponents([.hour, .minute], from: resetTime)
        let hour = resetComponents.hour ?? 0
        let minute = resetComponents.minute ?? 0

        // Compute today's reset moment. If now < that moment, we're still in
        // "yesterday's" logical day.
        let startOfToday = cal.startOfDay(for: now)
        guard let todayReset = cal.date(byAdding: .init(hour: hour, minute: minute), to: startOfToday) else {
            return startOfToday
        }

        if now < todayReset {
            return cal.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        }
        return startOfToday
    }

    /// Returns today's entry for the counter, creating it if needed.
    func todayEntry(for counter: Counter, at now: Date = Date()) -> CounterDailyEntry {
        let day = logicalDay(for: counter, at: now)

        if let existing = counter.entries.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }) {
            return existing
        }

        let new = CounterDailyEntry(counter: counter, date: day)
        context.insert(new)
        return new
    }

    /// The count to display "right now" for this counter.
    /// For resetting counters: today's entry value.
    /// For non-resetting counters: sum across all entries.
    func displayValue(for counter: Counter, at now: Date = Date()) -> Int {
        if counter.resetTime == nil {
            return counter.entries.reduce(0) { $0 + $1.value }
        }
        // Don't materialize today's entry just to read it; if no entry exists
        // for today, the value is 0.
        let day = logicalDay(for: counter, at: now)
        let existing = counter.entries.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        })
        return existing?.value ?? 0
    }

    func increment(_ counter: Counter, by amount: Int = 1, at now: Date = Date()) {
        let entry = todayEntry(for: counter, at: now)
        entry.value += amount
    }

    func decrement(_ counter: Counter, at now: Date = Date()) {
        let entry = todayEntry(for: counter, at: now)
        entry.value = max(0, entry.value - 1)   // don't go negative
    }

    func reset(_ counter: Counter, at now: Date = Date()) {
        let entry = todayEntry(for: counter, at: now)
        entry.value = 0
    }
}
