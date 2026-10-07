import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let task: TaskItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditor = false
    @State private var showingNewSubtask = false
    @State private var editingSubtask: SubTask?
    @State private var confirmDelete = false
    @State private var celebrate = 0

    var body: some View {
        let urgency = task.urgency

        List {
            Section {
                DetailHeader(task: task)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                ForEach(task.sortedSubtasks) { subtask in
                    SubtaskRow(subtask: subtask,
                               onToggle: { toggle(subtask) },
                               onEdit: { editingSubtask = subtask })
                        .listRowBackground(Theme.surface)
                }
                .onDelete(perform: deleteSubtasks)

                Button {
                    showingNewSubtask = true
                } label: {
                    Label("Tilføj underopgave", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
                .listRowBackground(Theme.surface)
            } header: {
                Text("Underopgaver")
            } footer: {
                if task.totalCount == 0 {
                    Text("Del opgaven op i mindre skridt – hver med sin egen termin.")
                } else {
                    Text("Tryk på en underopgave for at rette den. Stryg til venstre for at slette.")
                }
            }

            Section {
                Button {
                    toggleTask()
                } label: {
                    Label(task.isDone ? "Genåbn opgaven" : "Markér hele opgaven som færdig",
                          systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.seal.fill")
                        .foregroundStyle(task.isDone ? Color.orange : Urgency.done.color)
                }
                .listRowBackground(Theme.surface)
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Slet opgave", systemImage: "trash")
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AnimatedBackground(tint: urgency.color))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Redigér") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditor(task: task)
        }
        .sheet(isPresented: $showingNewSubtask) {
            SubtaskEditor(parent: task, subtask: nil)
        }
        .sheet(item: $editingSubtask) { subtask in
            SubtaskEditor(parent: task, subtask: subtask)
        }
        .overlay {
            ConfettiView(trigger: celebrate)
        }
        .sensoryFeedback(.success, trigger: celebrate)
        .confirmationDialog("Slet „\(task.title)“?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Slet opgave og underopgaver", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Det kan ikke fortrydes.")
        }
    }

    private func toggle(_ subtask: SubTask) {
        let completedTask = withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            task.toggleSubtask(subtask)
        }
        if completedTask { celebrate += 1 }
    }

    private func toggleTask() {
        let wasDone = task.isDone
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            task.setDone(!wasDone)
        }
        if !wasDone { celebrate += 1 }
    }

    private func deleteSubtasks(at offsets: IndexSet) {
        let current = task.sortedSubtasks
        withAnimation {
            for index in offsets {
                let subtask = current[index]
                task.removeSubtask(subtask)
                context.delete(subtask)
            }
        }
    }

    private func deleteTask() {
        let taskToDelete = task
        let modelContext = context
        dismiss()
        // Vent til skærmen er lukket, før opgaven slettes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            modelContext.delete(taskToDelete)
        }
    }
}

// MARK: - Toppen af detaljeskærmen

struct DetailHeader: View {
    let task: TaskItem

    var body: some View {
        let urgency = task.urgency

        VStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: task.progress, color: urgency.color, lineWidth: 14)
                VStack(spacing: 2) {
                    Text(task.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: task.progress))
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            Text(task.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 8) {
                DeadlineBadge(date: task.dueDate, isDone: task.isDone)
                if task.priority == .high {
                    Label("Høj prioritet", systemImage: "flag.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceRaised, in: Capsule())
                }
            }

            if !task.tags.isEmpty {
                FlowLayout {
                    ForEach(task.tags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
                .padding(.horizontal, 24)
            }

            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if task.totalCount > 0 && !task.isDone {
                PaceView(task: task, color: urgency.color)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String {
        if task.totalCount == 0 { return task.isDone ? "Færdig" : "Ingen underopgaver" }
        return "\(task.doneCount) af \(task.totalCount)"
    }
}

struct DeadlineBadge: View {
    let date: Date
    let isDone: Bool

    var body: some View {
        let urgency = Urgency(dueDate: date, isDone: isDone)
        HStack(spacing: 6) {
            Image(systemName: urgency.icon)
            Text(isDone ? "Færdig" : DeadlineText.relative(to: date))
            Text("·")
            Text(date, format: .dateTime.day().month(.wide).year())
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(urgency.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(urgency.color.opacity(0.14), in: Capsule())
    }
}

/// Sammenligner hvor meget af tiden der er gået med hvor meget der er lavet.
struct PaceView: View {
    let task: TaskItem
    let color: Color

    var body: some View {
        let work = task.progress
        let time = task.timeProgress
        let difference = work - time

        VStack(alignment: .leading, spacing: 12) {
            ProgressBar(title: "Arbejde udført", value: work, color: color)
            ProgressBar(title: "Tid gået", value: time, color: .gray)
            Label {
                Text(difference >= 0.1 ? "Du er foran planen – flot!"
                     : difference >= -0.1 ? "Du er på sporet."
                     : "Du er lidt bagud – tag næste skridt.")
            } icon: {
                Image(systemName: difference >= -0.1 ? "hare.fill" : "tortoise.fill")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(difference >= -0.1 ? Urgency.done.color : Urgency.thisWeek.color)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Underopgave-række

struct SubtaskRow: View {
    let subtask: SubTask
    var onToggle: () -> Void
    var onEdit: () -> Void

    var body: some View {
        let urgency = Urgency(dueDate: subtask.dueDate, isDone: subtask.isDone)

        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(urgency.color)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: subtask.isDone)
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(.selection, trigger: subtask.isDone)
            .accessibilityLabel(subtask.isDone ? "Markér som ikke færdig" : "Markér som færdig")

            VStack(alignment: .leading, spacing: 3) {
                Text(subtask.title)
                    .foregroundStyle(subtask.isDone ? .secondary : .primary)
                    .strikethrough(subtask.isDone)
                HStack(spacing: 4) {
                    Text(subtask.isDone ? "Færdig" : DeadlineText.relative(to: subtask.dueDate))
                    Text("·")
                    Text(subtask.dueDate, format: .dateTime.day().month(.wide).year())
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(subtask.isDone ? Color.secondary : urgency.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
        .padding(.vertical, 4)
    }
}
