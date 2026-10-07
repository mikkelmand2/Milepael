import SwiftUI

/// Farvekodning efter hvor tæt deadline er.
enum Urgency: Int, CaseIterable, Identifiable {
    case overdue = 0
    case today = 1
    case thisWeek = 2
    case thisMonth = 3
    case later = 4
    case done = 5

    var id: Int { rawValue }

    init(dueDate: Date, isDone: Bool, now: Date = Date()) {
        if isDone {
            self = .done
            return
        }
        let days = Urgency.daysBetween(now, and: dueDate)
        switch days {
        case ..<0: self = .overdue
        case 0: self = .today
        case 1...7: self = .thisWeek
        case 8...31: self = .thisMonth
        default: self = .later
        }
    }

    static func daysBetween(_ from: Date, and to: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// De fem grupper, en aktiv opgave kan ligge i.
    static let activeCases: [Urgency] = [.overdue, .today, .thisWeek, .thisMonth, .later]

    /// Rige, men ikke neon farver. Lidt lysere i mørk tilstand så de kan læses på #2E2E2E.
    var color: Color {
        switch self {
        case .overdue: return Color(light: 0xD2453F, dark: 0xF2766C)
        case .today: return Color(light: 0xE0702A, dark: 0xF59A55)
        case .thisWeek: return Color(light: 0xC9951A, dark: 0xF0C350)
        case .thisMonth: return Color(light: 0x1F9488, dark: 0x5ECBBB)
        case .later: return Color(light: 0x2F80C8, dark: 0x72B2EE)
        case .done: return Color(light: 0x2E9A5C, dark: 0x6BCB8D)
        }
    }

    var shortTitle: String {
        switch self {
        case .overdue: return "Over tid"
        case .today: return "I dag"
        case .thisWeek: return "7 dage"
        case .thisMonth: return "30 dage"
        case .later: return "Senere"
        case .done: return "Færdige"
        }
    }

    var icon: String {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .today: return "flame.fill"
        case .thisWeek: return "clock.fill"
        case .thisMonth: return "calendar"
        case .later: return "calendar.badge.clock"
        case .done: return "checkmark.seal.fill"
        }
    }

    var sectionTitle: String {
        switch self {
        case .overdue: return "Over tid"
        case .today: return "I dag"
        case .thisWeek: return "Næste 7 dage"
        case .thisMonth: return "Næste 30 dage"
        case .later: return "Senere"
        case .done: return "Færdige"
        }
    }
}

enum DeadlineText {
    /// Fx "I morgen", "Om 5 dage", "Om 3 uger", "Om 4 mdr.", "2 dage over tid".
    static func relative(to date: Date, now: Date = Date()) -> String {
        let days = Urgency.daysBetween(now, and: date)
        switch days {
        case ..<(-1): return "\(-days) dage over tid"
        case -1: return "1 dag over tid"
        case 0: return "I dag"
        case 1: return "I morgen"
        case 2..<14: return "Om \(days) dage"
        case 14..<60: return "Om \(days / 7) uger"
        case 60..<365: return "Om \(days / 30) mdr."
        default:
            let years = days / 365
            return years == 1 ? "Om 1 år" : "Om \(years) år"
        }
    }
}
