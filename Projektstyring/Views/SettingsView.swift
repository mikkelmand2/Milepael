import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.showTagsOnCards) private var showTags = true
    @AppStorage(SettingsKey.showNotesOnCards) private var showNotes = false
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = true
    @AppStorage(SettingsKey.reminderHour) private var reminderHour = 9

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tema", selection: $appearance.animation(.easeInOut)) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .themedRow()
                } header: {
                    Text("Udseende")
                } footer: {
                    Text("Automatisk følger din iPhones indstilling.")
                }

                Section {
                    Toggle("Vis mærkater", isOn: $showTags.animation(.snappy))
                        .themedRow()
                    Toggle("Vis noter", isOn: $showNotes.animation(.snappy))
                        .themedRow()
                } header: {
                    Text("Forsiden")
                } footer: {
                    Text("Slå fra for et renere overblik. Noter og mærkater kan altid ses inde i opgaven.")
                }

                Section {
                    Toggle("Påmindelser", isOn: $remindersEnabled.animation(.snappy))
                        .themedRow()
                    if remindersEnabled {
                        Picker("Tidspunkt", selection: $reminderHour) {
                            ForEach(6..<22, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .themedRow()
                    }
                } header: {
                    Text("Påmindelser")
                } footer: {
                    Text("Opgaver: 3 dage før og på dagen. Underopgaver: dagen før og på dagen.")
                }
            }
            .themedListBackground()
            .tint(Theme.accent)
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .onChange(of: remindersEnabled) { _, enabled in
                if enabled {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge])
                        ReminderScheduler.reschedule(context: context)
                    }
                } else {
                    ReminderScheduler.reschedule(context: context)
                }
            }
            .onChange(of: reminderHour) { _, _ in
                ReminderScheduler.reschedule(context: context)
            }
        }
        .presentationBackground(Theme.background)
    }
}
