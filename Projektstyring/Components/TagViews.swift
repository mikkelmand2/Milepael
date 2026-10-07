import SwiftUI

enum TagStyle {
    private static let palette: [Color] = [
        Color(light: 0x6A4FC4, dark: 0xA992EE),
        Color(light: 0x2F80C8, dark: 0x72B2EE),
        Color(light: 0x1F9488, dark: 0x5ECBBB),
        Color(light: 0x2E9A5C, dark: 0x6BCB8D),
        Color(light: 0xC97A2A, dark: 0xF0A860),
        Color(light: 0xB8506E, dark: 0xE38AA3)
    ]

    /// Samme mærkat får altid samme farve.
    static func color(for tag: String) -> Color {
        let sum = tag.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

/// Lille farvet "pille" med et mærkat.
struct TagChip: View {
    let tag: String
    var compact = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let color = TagStyle.color(for: tag)
        HStack(spacing: 4) {
            Text(tag)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Fjern \(tag)")
            }
        }
        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(color.opacity(0.16), in: Capsule())
    }
}

/// Placerer elementer på rækker og bryder automatisk til næste linje.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Tilføj og fjern mærkater på en opgave.
struct TagEditor: View {
    @Binding var tags: [String]
    var suggestions: [String]

    @State private var newTag = ""

    private var unusedSuggestions: [String] {
        suggestions.filter { suggestion in
            !tags.contains { $0.caseInsensitiveCompare(suggestion) == .orderedSame }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, onRemove: {
                            withAnimation(.snappy) {
                                tags.removeAll { $0 == tag }
                            }
                        })
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("Nyt mærkat, fx Kunde A", text: $newTag)
                    .submitLabel(.done)
                    .onSubmit(add)
                if !newTag.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Tilføj", action: add)
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                }
            }

            if !unusedSuggestions.isEmpty {
                Text("Tidligere brugt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout {
                    ForEach(unusedSuggestions, id: \.self) { suggestion in
                        Button {
                            withAnimation(.snappy) { tags.append(suggestion) }
                        } label: {
                            TagChip(tag: "+ \(suggestion)")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func add() {
        let cleaned = newTag
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
            withAnimation(.snappy) { tags.append(cleaned) }
        }
        newTag = ""
    }
}

/// Lille rødt flag-mærke for høj prioritet.
struct PriorityBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flag.fill")
            if !compact { Text("Høj") }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Theme.priorityHigh)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(Theme.priorityHigh.opacity(0.14), in: Capsule())
        .accessibilityLabel("Høj prioritet")
    }
}

/// Farvet pille med en underopgaves termin. Tydelig når den er tæt på.
struct SubtaskDuePill: View {
    let subtask: SubTask

    var body: some View {
        let urgency = subtask.urgency
        let soon = subtask.isSoon
        HStack(spacing: 4) {
            if soon { Image(systemName: urgency.icon) }
            Text(subtask.isDone ? "Færdig" : DeadlineText.relative(to: subtask.dueDate))
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(subtask.isDone ? Color.secondary : urgency.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background((subtask.isDone ? Color.secondary : urgency.color).opacity(soon ? 0.16 : 0.08), in: Capsule())
    }
}
