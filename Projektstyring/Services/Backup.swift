import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Sikkerhedskopi af alle opgaver som en almindelig JSON-fil.
/// Filen kan gemmes i Filer/iCloud Drive og læses ind igen senere.
enum Backup {
    struct File: Codable {
        var version = 1
        var exportedAt = Date()
        var tasks: [TaskData]
    }

    struct TaskData: Codable {
        var uuid: UUID
        var title: String
        var notes: String
        var dueDate: Date
        var createdAt: Date
        var completedAt: Date?
        var isDone: Bool
        var priorityRaw: Int
        var tagsRaw: String
        var assignee: String
        var subtasks: [SubtaskData]
    }

    struct SubtaskData: Codable {
        var uuid: UUID
        var title: String
        var dueDate: Date
        var createdAt: Date
        var completedAt: Date?
        var isDone: Bool
        var priorityRaw: Int
        var assignee: String
    }

    struct Result {
        var added = 0
        var updated = 0
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var defaultFilename: String {
        let date = Date().formatted(.iso8601.year().month().day())
        return "Milepæl sikkerhedskopi \(date)"
    }

    @MainActor
    static func export(context: ModelContext) throws -> Data {
        let tasks = try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.dueDate)]))
        let file = File(tasks: tasks.map { task in
            TaskData(uuid: task.uuid, title: task.title, notes: task.notes, dueDate: task.dueDate,
                     createdAt: task.createdAt, completedAt: task.completedAt, isDone: task.isDone,
                     priorityRaw: task.priorityRaw, tagsRaw: task.tagsRaw, assignee: task.assignee,
                     subtasks: (task.subtasks ?? []).map { sub in
                         SubtaskData(uuid: sub.uuid, title: sub.title, dueDate: sub.dueDate,
                                     createdAt: sub.createdAt, completedAt: sub.completedAt,
                                     isDone: sub.isDone, priorityRaw: sub.priorityRaw, assignee: sub.assignee)
                     })
        })
        return try encoder().encode(file)
    }

    /// Lægger opgaverne fra filen ind. Findes en opgave allerede (samme id),
    /// bliver den opdateret; ellers bliver den tilføjet. Intet bliver slettet.
    @MainActor
    static func restore(_ data: Data, context: ModelContext) throws -> Result {
        let file = try decoder().decode(File.self, from: data)
        let existing = try context.fetch(FetchDescriptor<TaskItem>())
        var byID = Dictionary(existing.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        var result = Result()

        for data in file.tasks {
            let task: TaskItem
            if let found = byID[data.uuid] {
                task = found
                for subtask in task.subtasks ?? [] {
                    task.removeSubtask(subtask)
                    context.delete(subtask)
                }
                result.updated += 1
            } else {
                task = TaskItem(title: data.title, dueDate: data.dueDate)
                task.uuid = data.uuid
                context.insert(task)
                byID[data.uuid] = task
                result.added += 1
            }
            task.title = data.title
            task.notes = data.notes
            task.dueDate = data.dueDate
            task.createdAt = data.createdAt
            task.completedAt = data.completedAt
            task.isDone = data.isDone
            task.priorityRaw = data.priorityRaw
            task.tagsRaw = data.tagsRaw
            task.assignee = data.assignee

            for sub in data.subtasks {
                let subtask = SubTask(title: sub.title, dueDate: sub.dueDate)
                subtask.uuid = sub.uuid
                subtask.createdAt = sub.createdAt
                subtask.completedAt = sub.completedAt
                subtask.isDone = sub.isDone
                subtask.priorityRaw = sub.priorityRaw
                subtask.assignee = sub.assignee
                context.insert(subtask)
                task.addSubtask(subtask)
            }
        }
        try context.save()
        return result
    }
}

/// Lille dokument-type, så Indstillinger kan gemme filen via Filer.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
