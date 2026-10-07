import SwiftUI

/// Kortet for én opgave på forsiden.
struct TaskCard: View {
    let task: TaskItem

    @AppStorage(SettingsKey.showTagsOnCards) private var showTags = true
    @AppStorage(SettingsKey.showNotesOnCards) private var showNotes = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let urgency = task.urgency
        let isHigh = task.priority == .high && !task.isDone

        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: task.progress, color: urgency.color, lineWidth: 6)
                if task.isDone {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(urgency.color)
                        .transition(.scale.combined(with: .opacity))
                } else if task.totalCount > 0 {
                    Text("\(task.doneCount)/\(task.totalCount)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: urgency.icon)
                        .font(.subheadline)
                        .foregroundStyle(urgency.color)
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                        .strikethrough(task.isDone)
                        .lineLimit(2)
                    if isHigh {
                        PriorityBadge()
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(task.isDone ? "Færdig" : DeadlineText.relative(to: task.dueDate))
                    Text("·")
                    Text(task.dueDate, format: .dateTime.day().month(.abbreviated).year())
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(urgency.color)

                if !task.isDone, let next = task.nextOpenSubtask {
                    nextSubtaskLine(next)
                }

                if showNotes && !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if showTags && !task.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            TagChip(tag: tag, compact: true)
                        }
                        if task.tags.count > 3 {
                            Text("+\(task.tags.count - 3)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .padding(.leading, 4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            // Farvet kant i venstre side viser, hvor meget opgaven haster.
            Capsule()
                .fill(task.effectiveUrgency.color.gradient)
                .frame(width: 4)
                .padding(.vertical, 14)
                .padding(.leading, 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isHigh ? Theme.priorityHigh.opacity(0.55)
                                     : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.05),
                              lineWidth: isHigh ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Næste underopgave. Står med farve og ikon, når den er tæt på.
    @ViewBuilder
    private func nextSubtaskLine(_ next: SubTask) -> some View {
        let soonCount = task.soonSubtasks.count
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .foregroundStyle(.secondary)
            Text(next.title)
                .foregroundStyle(next.isSoon ? .primary : .secondary)
                .fontWeight(next.isSoon ? .semibold : .regular)
                .lineLimit(1)
            if next.priority == .high {
                PriorityBadge(compact: true)
            }
            SubtaskDuePill(subtask: next)
                .layoutPriority(1)
            if soonCount > 1 {
                Text("+\(soonCount - 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(next.urgency.color)
            }
        }
        .font(.caption)
    }
}
