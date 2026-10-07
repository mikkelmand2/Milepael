import Foundation
import SwiftData
import UserNotifications

/// Lokale påmindelser (standard kl. 9:00) – gratis og uden server.
/// Opgaver: 3 dage før og på dagen. Underopgaver: dagen før og på dagen.
enum ReminderScheduler {
    private struct Reminder {
        let id: String
        let fireDate: Date
        let title: String
        let body: String
    }

    /// iOS tillader højst 64 ventende påmindelser, så vi tager de 60 nærmeste.
    private static let maxReminders = 60

    @MainActor
    static func reschedule(context: ModelContext) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: SettingsKey.remindersEnabled) as? Bool ?? true
        let hour = defaults.object(forKey: SettingsKey.reminderHour) as? Int ?? 9
        let center = UNUserNotificationCenter.current()

        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []

        guard enabled else {
            center.removeAllPendingNotificationRequests()
            center.setBadgeCount(0)
            return
        }

        // Tallet på app-ikonet: opgaver og underopgaver der er over tid eller skal laves i dag.
        let badge = tasks.filter { !$0.isDone }.reduce(0) { count, task in
            let own = task.urgency.rawValue <= Urgency.today.rawValue ? 1 : 0
            let subs = (task.subtasks ?? []).filter {
                !$0.isDone && $0.urgency.rawValue <= Urgency.today.rawValue
            }.count
            return count + own + subs
        }
        center.setBadgeCount(badge)
        let now = Date()
        var reminders: [Reminder] = []

        for task in tasks where !task.isDone {
            if let date = fireDate(for: task.dueDate, daysBefore: 3, hour: hour) {
                reminders.append(Reminder(id: "\(task.uuid)-3", fireDate: date,
                                          title: "Deadline om 3 dage", body: task.title))
            }
            if let date = fireDate(for: task.dueDate, daysBefore: 0, hour: hour) {
                reminders.append(Reminder(id: "\(task.uuid)-0", fireDate: date,
                                          title: "Deadline i dag", body: task.title))
            }
            for subtask in task.subtasks ?? [] where !subtask.isDone {
                if let date = fireDate(for: subtask.dueDate, daysBefore: 1, hour: hour) {
                    reminders.append(Reminder(id: "\(subtask.uuid)-1", fireDate: date,
                                              title: "I morgen: \(subtask.title)",
                                              body: "Underopgave i \(task.title)"))
                }
                if let date = fireDate(for: subtask.dueDate, daysBefore: 0, hour: hour) {
                    reminders.append(Reminder(id: "\(subtask.uuid)-0", fireDate: date,
                                              title: "I dag: \(subtask.title)",
                                              body: "Underopgave i \(task.title)"))
                }
            }
        }

        let upcoming = reminders
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxReminders)

        center.removeAllPendingNotificationRequests()
        let calendar = Calendar.current

        for reminder in upcoming {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                     from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            center.add(request) { _ in }
        }
    }

    private static func fireDate(for due: Date, daysBefore: Int, hour: Int) -> Date? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: -daysBefore,
                                      to: calendar.startOfDay(for: due)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }
}
