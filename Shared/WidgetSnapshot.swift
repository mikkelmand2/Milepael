import Foundation

/// Det lille udtræk af opgaver, som appen gemmer til widgetten.
/// Deles via en App Group, fordi widgetten ikke kan læse appens database direkte.
struct WidgetSnapshot: Codable {
    struct Item: Codable, Hashable {
        var title: String
        /// Opgavens navn, hvis dette er en underopgave.
        var parentTitle: String?
        var dueDate: Date
        var isHighPriority: Bool
    }

    /// De nærmeste åbne opgaver og underopgaver, sorteret efter dato.
    var items: [Item]
    var activeCount: Int
    var updatedAt: Date

    static let appGroup = "group.dk.mikkel.projektstyring"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// Antal dage fra i dag til datoen (negativ = over tid).
    static func days(until date: Date, from now: Date = Date()) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }
}
