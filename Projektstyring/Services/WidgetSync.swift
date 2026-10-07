import Foundation
import SwiftData
import WidgetKit

/// Giver widgetten et frisk udtræk af det, der haster.
enum WidgetSync {
    @MainActor
    static func update(context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let open = tasks.filter { !$0.isDone }
        var items: [WidgetSnapshot.Item] = []
        for task in open {
            items.append(.init(title: task.title, parentTitle: nil,
                               dueDate: task.dueDate, isHighPriority: task.priority == .high))
            for subtask in task.subtasks ?? [] where !subtask.isDone {
                items.append(.init(title: subtask.title, parentTitle: task.title,
                                   dueDate: subtask.dueDate, isHighPriority: subtask.priority == .high))
            }
        }
        items.sort { a, b in
            if a.dueDate != b.dueDate { return a.dueDate < b.dueDate }
            return a.isHighPriority && !b.isHighPriority
        }
        WidgetSnapshot(items: Array(items.prefix(12)), activeCount: open.count, updatedAt: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
