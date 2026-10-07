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
    @AppStorage(SettingsKey.autoCloseCalendar) private var autoCloseCalendar = true

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupMessage: String?

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
                    Button {
                        exportBackup()
                    } label: {
                        Label("Gem sikkerhedskopi", systemImage: "square.and.arrow.up")
                    }
                    .themedRow()
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Gendan fra sikkerhedskopi", systemImage: "square.and.arrow.down")
                    }
                    .themedRow()
                } header: {
                    Text("Sikkerhedskopi")
                } footer: {
                    Text("Gemmer alle opgaver og underopgaver som én fil, fx i iCloud Drive. Ved gendannelse bliver opgaverne lagt ind igen, og intet bliver slettet.")
                }

                Section {
                    Toggle("Luk kalenderen ved valg af dato", isOn: $autoCloseCalendar)
                        .themedRow()
                } header: {
                    Text("Kalender")
                } footer: {
                    Text("Når den er slået fra, bliver kalenderen stående, til du trykker på datoen igen.")
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
            .fileExporter(isPresented: $showingExporter,
                          document: exportDocument,
                          contentType: .json,
                          defaultFilename: Backup.defaultFilename) { result in
                if case .success = result {
                    backupMessage = "Sikkerhedskopien er gemt."
                } else if case .failure(let error) = result {
                    backupMessage = "Kunne ikke gemme: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .alert("Sikkerhedskopi", isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
        }
        .presentationBackground(Theme.background)
    }

    private func exportBackup() {
        do {
            exportDocument = BackupDocument(data: try Backup.export(context: context))
            showingExporter = true
        } catch {
            backupMessage = "Kunne ikke lave sikkerhedskopien: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let restored = try Backup.restore(data, context: context)
            ReminderScheduler.reschedule(context: context)
            WidgetSync.update(context: context)
            backupMessage = "Gendannet: \(restored.added) nye og \(restored.updated) opdaterede opgaver."
        } catch {
            backupMessage = "Filen kunne ikke læses. Er det en sikkerhedskopi fra Milepæl?"
        }
    }
}
