import Foundation
import SwiftData

// Datamodellen er lavet, så den senere kan synkroniseres via iCloud/CloudKit
// og deles med et team: alle felter har standardværdier, relationer er
// valgfrie, og der er ingen unikke krav (det kræver CloudKit).

@Model
final class TaskItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date = Date()
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var isDone: Bool = false
    var priorityRaw: Int = 1
    /// Mærkater gemt som kommasepareret tekst (virker også med iCloud senere).
    var tagsRaw: String = ""
    /// Klar til deling senere: hvem opgaven er tildelt.
    var assignee: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SubTask.parent)
    var subtasks: [SubTask]? = []

    init(title: String,
         notes: String = "",
         dueDate: Date,
         priority: Priority = .normal,
         createdAt: Date = Date()) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
    }
}

@Model
final class SubTask {
    var uuid: UUID = UUID()
    var title: String = ""
    var dueDate: Date = Date()
    var createdAt: Date = Date()
    var isDone: Bool = false
    var completedAt: Date? = nil
    var priorityRaw: Int = 1
    /// Klar til deling senere: hvem underopgaven er tildelt.
    var assignee: String = ""
    var parent: TaskItem? = nil

    init(title: String, dueDate: Date, priority: Priority = .normal) {
        self.title = title
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
    }
}

extension SubTask {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var urgency: Urgency { Urgency(dueDate: dueDate, isDone: isDone) }

    /// Over tid, i dag eller inden for 7 dage.
    var isSoon: Bool { !isDone && urgency.rawValue <= Urgency.thisWeek.rawValue }
}

enum Priority: Int, CaseIterable, Identifiable {
    case low = 0
    case normal = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Lav"
        case .normal: return "Normal"
        case .high: return "Høj"
        }
    }
}

extension TaskItem {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            tagsRaw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue.joined(separator: ",")
        }
    }

    /// Åbne underopgaver først, derefter efter termin.
    var sortedSubtasks: [SubTask] {
        (subtasks ?? []).sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            return a.dueDate < b.dueDate
        }
    }

    var totalCount: Int { subtasks?.count ?? 0 }

    var doneCount: Int { (subtasks ?? []).filter { $0.isDone }.count }

    /// 0...1. Uden underopgaver er den enten 0 eller 1.
    var progress: Double {
        if isDone { return 1 }
        guard totalCount > 0 else { return 0 }
        return Double(doneCount) / Double(totalCount)
    }

    /// Hvor stor en del af perioden fra oprettelse til deadline, der er gået.
    var timeProgress: Double {
        let total = dueDate.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        return min(max(Date().timeIntervalSince(createdAt) / total, 0), 1)
    }

    var nextOpenSubtask: SubTask? {
        (subtasks ?? []).filter { !$0.isDone }.min { $0.dueDate < $1.dueDate }
    }

    var urgency: Urgency { Urgency(dueDate: dueDate, isDone: isDone) }

    /// Åbne underopgaver, der er over tid eller forfalder inden for 7 dage.
    var soonSubtasks: [SubTask] {
        (subtasks ?? []).filter { $0.isSoon }.sorted { $0.dueDate < $1.dueDate }
    }

    /// Den mest presserende farve for opgaven, inkl. dens åbne underopgaver.
    var effectiveUrgency: Urgency {
        guard !isDone else { return .done }
        let subtaskUrgencies = (subtasks ?? []).filter { !$0.isDone }.map(\.urgency)
        return ([urgency] + subtaskUrgencies).min { $0.rawValue < $1.rawValue } ?? urgency
    }

    var hasOverdueSubtask: Bool {
        (subtasks ?? []).contains { Urgency(dueDate: $0.dueDate, isDone: $0.isDone) == .overdue }
    }

    func addSubtask(_ subtask: SubTask) {
        if subtasks == nil { subtasks = [] }
        subtasks?.append(subtask)
    }

    func removeSubtask(_ subtask: SubTask) {
        subtasks?.removeAll { $0.persistentModelID == subtask.persistentModelID }
    }

    /// Skifter en underopgave. Returnerer true, hvis hele opgaven dermed blev færdig.
    @discardableResult
    func toggleSubtask(_ subtask: SubTask) -> Bool {
        subtask.isDone.toggle()
        subtask.completedAt = subtask.isDone ? Date() : nil
        let all = subtasks ?? []
        if !all.isEmpty && all.allSatisfy({ $0.isDone }) {
            if !isDone {
                isDone = true
                completedAt = Date()
                return true
            }
        } else if isDone {
            isDone = false
            completedAt = nil
        }
        return false
    }

    /// Markerer hele opgaven (og alle underopgaver) som færdig, eller genåbner den.
    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? Date() : nil
        if done {
            for subtask in subtasks ?? [] where !subtask.isDone {
                subtask.isDone = true
                subtask.completedAt = Date()
            }
        }
    }

    func matches(search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return true }
        if title.localizedCaseInsensitiveContains(query) { return true }
        if notes.localizedCaseInsensitiveContains(query) { return true }
        if tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        return (subtasks ?? []).contains { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

extension Date {
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
}
