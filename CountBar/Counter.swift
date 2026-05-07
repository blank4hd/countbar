import Foundation
import SwiftData

@Model
final class Counter {
    var id: UUID
    var name: String
    var goal: Int
    var createdAt: Date

    /// Time of day at which this counter resets to zero.
    /// Only the hour and minute components are used (date portion ignored).
    /// `nil` means the counter never auto-resets (it accumulates forever).
    var resetTime: Date?

    /// Daily entries for this counter. Cascade-deleted when the counter is.
    @Relationship(deleteRule: .cascade, inverse: \CounterDailyEntry.counter)
    var entries: [CounterDailyEntry] = []

    init(name: String, goal: Int = 0, resetTime: Date? = defaultResetTime()) {
        self.id = UUID()
        self.name = name
        self.goal = goal
        self.createdAt = Date()
        self.resetTime = resetTime
    }

    /// Default new counters reset at midnight.
    static func defaultResetTime() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

@Model
final class CounterDailyEntry {
    var id: UUID
    var counter: Counter?

    /// The "logical day" this entry belongs to, normalized to midnight in
    /// the user's current timezone. Used as the unique key for (counter, day).
    var date: Date

    var value: Int

    init(counter: Counter, date: Date, value: Int = 0) {
        self.id = UUID()
        self.counter = counter
        self.date = date
        self.value = value
    }
}
