import SwiftUI
import SwiftData
import UserNotifications

@main
struct ProjektstyringApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TaskItem.self, SubTask.self)
        } catch {
            fatalError("Kunne ikke åbne databasen: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "da_DK"))
                .tint(Theme.accent)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                    ReminderScheduler.reschedule(context: container.mainContext)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Påmindelser planlægges, hver gang appen lukkes ned i baggrunden.
            if phase == .background {
                try? container.mainContext.save()
                ReminderScheduler.reschedule(context: container.mainContext)
            }
        }
    }
}
