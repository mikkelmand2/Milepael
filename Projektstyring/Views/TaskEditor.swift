import SwiftUI
import SwiftData

/// Hurtige knapper til at vælge en lang termin.
enum QuickDate: String, CaseIterable, Identifiable {
    case week = "+1 uge"
    case month = "+1 md."
    case threeMonths = "+3 mdr."
    case sixMonths = "+6 mdr."
    case year = "+1 år"

    var id: String { rawValue }

    var date: Date {
        let now = Date()
        switch self {
        case .week: return now.adding(days: 7)
        case .month: return now.adding(months: 1)
        case .threeMonths: return now.adding(months: 3)
        case .sixMonths: return now.adding(months: 6)
        case .year: return now.adding(months: 12)
        }
    }
}

/// Opret eller redigér en opgave.
struct TaskEditor: View {
    let task: TaskItem?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TaskItem]

    @State private var title = ""
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var showExtras = false
    @State private var dueDate = Date().adding(months: 1)
    @State private var priority: Priority = .normal
    @State private var drafts: [DraftSubtask] = []
    @State private var didLoad = false
    @FocusState private var titleFocused: Bool

    struct DraftSubtask: Identifiable {
        let id = UUID()
        var title: String = ""
        var dueDate: Date
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hvad skal laves?", text: $title)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .themedRow()
                }

                // Noter og mærkater er valgfrie og ligger foldet sammen.
                Section {
                    DisclosureGroup(isExpanded: $showExtras.animation(.snappy)) {
                        TextField("Noter", text: $notes, axis: .vertical)
                            .lineLimit(2...6)
                            .padding(.vertical, 4)
                            .themedRow()
                        TagEditor(tags: $tags, suggestions: tagSuggestions)
                            .themedRow()
                    } label: {
                        HStack {
                            Label("Noter og mærkater", systemImage: "tag")
                            Spacer()
                            if !showExtras && (!notes.isEmpty || !tags.isEmpty) {
                                Text(extrasSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .themedRow()
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickDate.allCases) { quick in
                                Button(quick.rawValue) {
                                    withAnimation(.snappy) { dueDate = quick.date }
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(Theme.accent)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .themedRow()
                    DatePicker("Deadline", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Theme.accent)
                        .themedRow()
                } header: {
                    Text("Termin")
                } footer: {
                    Text(DeadlineText.relative(to: dueDate))
                }

                Section("Prioritet") {
                    Picker("Prioritet", selection: $priority) {
                        ForEach(Priority.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .themedRow()
                }

                if task == nil {
                    Section {
                        ForEach($drafts) { $draft in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Underopgave", text: $draft.title)
                                DatePicker("Termin", selection: $draft.dueDate, displayedComponents: .date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .themedRow()
                        }
                        .onDelete { offsets in
                            drafts.remove(atOffsets: offsets)
                        }

                        Button {
                            withAnimation(.snappy) {
                                drafts.append(DraftSubtask(dueDate: min(dueDate, Date().adding(days: 7))))
                            }
                        } label: {
                            Label("Tilføj underopgave", systemImage: "plus.circle.fill")
                        }
                        .themedRow()
                    } header: {
                        Text("Underopgaver")
                    } footer: {
                        Text("Du kan også tilføje underopgaver senere.")
                    }
                }
            }
            .themedListBackground()
            .tint(Theme.accent)
            .navigationTitle(task == nil ? "Ny opgave" : "Redigér opgave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullér") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .presentationBackground(Theme.background)
    }

    /// Mærkater brugt på andre opgaver.
    private var tagSuggestions: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for other in allTasks {
            for tag in other.tags where !seen.contains(tag.lowercased()) {
                seen.insert(tag.lowercased())
                result.append(tag)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var extrasSummary: String {
        var parts: [String] = []
        if !notes.isEmpty { parts.append("Note") }
        if tags.count == 1 { parts.append("1 mærkat") }
        if tags.count > 1 { parts.append("\(tags.count) mærkater") }
        return parts.joined(separator: " · ")
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let task {
            title = task.title
            notes = task.notes
            tags = task.tags
            showExtras = !task.notes.isEmpty || !task.tags.isEmpty
            dueDate = task.dueDate
            priority = task.priority
        } else {
            titleFocused = true
        }
    }

    private func save() {
        if let task {
            task.title = trimmedTitle
            task.notes = notes
            task.tags = tags
            task.dueDate = dueDate
            task.priority = priority
        } else {
            let newTask = TaskItem(title: trimmedTitle, notes: notes, dueDate: dueDate, priority: priority)
            newTask.tags = tags
            context.insert(newTask)
            for draft in drafts {
                let draftTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !draftTitle.isEmpty else { continue }
                let subtask = SubTask(title: draftTitle, dueDate: draft.dueDate)
                context.insert(subtask)
                newTask.addSubtask(subtask)
            }
        }
        dismiss()
    }
}

/// Opret eller redigér en underopgave.
struct SubtaskEditor: View {
    let parent: TaskItem
    let subtask: SubTask?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var didLoad = false
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAfterParentDeadline: Bool {
        Urgency.daysBetween(parent.dueDate, and: dueDate) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hvad er næste skridt?", text: $title)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                        .themedRow()
                }

                Section {
                    DatePicker("Termin", selection: $dueDate, displayedComponents: .date)
                        .tint(Theme.accent)
                        .themedRow()
                    if isAfterParentDeadline {
                        Label {
                            Text("Ligger efter opgavens deadline (\(parent.dueDate, format: .dateTime.day().month(.wide))).")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.footnote)
                        .foregroundStyle(Urgency.thisWeek.color)
                        .themedRow()
                    }
                } header: {
                    Text("Termin")
                } footer: {
                    Text(DeadlineText.relative(to: dueDate))
                }

                if let subtask {
                    Section {
                        Button(role: .destructive) {
                            parent.removeSubtask(subtask)
                            context.delete(subtask)
                            dismiss()
                        } label: {
                            Label("Slet underopgave", systemImage: "trash")
                        }
                        .themedRow()
                    }
                }
            }
            .themedListBackground()
            .tint(Theme.accent)
            .animation(.snappy, value: isAfterParentDeadline)
            .navigationTitle(subtask == nil ? "Ny underopgave" : "Redigér underopgave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullér") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let subtask {
            title = subtask.title
            dueDate = subtask.dueDate
        } else {
            dueDate = min(parent.dueDate, Date().adding(days: 7))
            titleFocused = true
        }
    }

    private func save() {
        if let subtask {
            subtask.title = trimmedTitle
            subtask.dueDate = dueDate
        } else {
            let newSubtask = SubTask(title: trimmedTitle, dueDate: dueDate)
            context.insert(newSubtask)
            withAnimation(.snappy) {
                parent.addSubtask(newSubtask)
                // En ny underopgave betyder, at opgaven ikke længere er færdig.
                if parent.isDone { parent.setDone(false) }
            }
        }
        dismiss()
    }
}
