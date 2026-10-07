import SwiftUI
import WidgetKit

// MARK: - Data

struct MilepaelEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct MilepaelProvider: TimelineProvider {
    func placeholder(in context: Context) -> MilepaelEntry {
        MilepaelEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MilepaelEntry) -> Void) {
        completion(MilepaelEntry(date: Date(), snapshot: context.isPreview ? .preview : WidgetSnapshot.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MilepaelEntry>) -> Void) {
        // Opdateres når appen lukkes, og ellers ved midnat, så "i dag"/"over tid" passer.
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400 + 60)
        let snapshot = WidgetSnapshot.load()
        completion(Timeline(entries: [MilepaelEntry(date: now, snapshot: snapshot),
                                      MilepaelEntry(date: midnight, snapshot: snapshot)],
                            policy: .after(midnight)))
    }
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(items: [
        .init(title: "Nye billeder", parentTitle: "Opdatere hjemmesiden", dueDate: Date().addingTimeInterval(-86_400), isHighPriority: true),
        .init(title: "Booke lokale", parentTitle: nil, dueDate: Date(), isHighPriority: false),
        .init(title: "Første udkast", parentTitle: "Årsrapport", dueDate: Date().addingTimeInterval(4 * 86_400), isHighPriority: false),
    ], activeCount: 3, updatedAt: Date())
}

// MARK: - Farver (samme palet som appen)

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

private enum WidgetColors {
    static func urgency(days: Int, dark: Bool) -> Color {
        switch days {
        case ..<0: return Color(hex: dark ? 0xF2766C : 0xD2453F)
        case 0: return Color(hex: dark ? 0xF59A55 : 0xE0702A)
        case 1...7: return Color(hex: dark ? 0xF0C350 : 0xC9951A)
        case 8...31: return Color(hex: dark ? 0x5ECBBB : 0x1F9488)
        default: return Color(hex: dark ? 0x72B2EE : 0x2F80C8)
        }
    }
    static func accent(dark: Bool) -> Color { Color(hex: dark ? 0x8A98F5 : 0x4256D0) }
    static func priority(dark: Bool) -> Color { Color(hex: dark ? 0xF2766C : 0xD2453F) }
    static func background(dark: Bool) -> Color { Color(hex: dark ? 0x2E2E2E : 0xF2F2F7) }
}

private func relativeText(_ days: Int) -> String {
    switch days {
    case ..<(-1): return "\(-days) dage over"
    case -1: return "1 dag over"
    case 0: return "I dag"
    case 1: return "I morgen"
    case 2..<14: return "Om \(days) dage"
    case 14..<60: return "Om \(days / 7) uger"
    default: return "Om \(days / 30) mdr."
    }
}

// MARK: - Visning

struct MilepaelWidgetView: View {
    let entry: MilepaelEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        let items = entry.snapshot?.items ?? []
        let overdue = items.filter { WidgetSnapshot.days(until: $0.dueDate, from: entry.date) < 0 }.count
        let today = items.filter { WidgetSnapshot.days(until: $0.dueDate, from: entry.date) == 0 }.count
        let rows = family == .systemSmall ? 2 : (family == .systemLarge ? 8 : 3)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flag.pattern.checkered")
                    .foregroundStyle(WidgetColors.accent(dark: dark))
                Text("Milepæl")
                    .font(.headline)
                Spacer(minLength: 0)
                if family == .systemSmall {
                    // Lille widget: kun et tal, så overskriften ikke bliver klippet.
                    if overdue > 0 {
                        badge("\(overdue)", color: WidgetColors.urgency(days: -1, dark: dark))
                    }
                } else if overdue > 0 {
                    badge("\(overdue) over tid", color: WidgetColors.urgency(days: -1, dark: dark))
                } else if today > 0 {
                    badge("\(today) i dag", color: WidgetColors.urgency(days: 0, dark: dark))
                }
            }

            if items.isEmpty {
                Spacer(minLength: 0)
                Text(entry.snapshot == nil ? "Åbn appen én gang for at komme i gang." : "Intet der haster. Flot!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(items.prefix(rows), id: \.self) { item in
                    row(item)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(WidgetColors.background(dark: dark), for: .widget)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .lineLimit(1)
    }

    private func row(_ item: WidgetSnapshot.Item) -> some View {
        let days = WidgetSnapshot.days(until: item.dueDate, from: entry.date)
        let color = WidgetColors.urgency(days: days, dark: dark)
        return HStack(spacing: 8) {
            Capsule()
                .fill(color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if item.isHighPriority {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(WidgetColors.priority(dark: dark))
                    }
                }
                HStack(spacing: 4) {
                    Text(relativeText(days))
                        .foregroundStyle(color)
                        .fontWeight(.semibold)
                    if let parent = item.parentTitle, family != .systemSmall {
                        Text("· \(parent)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Widget

struct MilepaelWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MilepaelWidget", provider: MilepaelProvider()) { entry in
            MilepaelWidgetView(entry: entry)
        }
        .configurationDisplayName("Det der haster")
        .description("De næste deadlines og hvor mange der er over tid.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct MilepaelWidgetBundle: WidgetBundle {
    var body: some Widget {
        MilepaelWidget()
    }
}

#Preview(as: .systemMedium) {
    MilepaelWidget()
} timeline: {
    MilepaelEntry(date: Date(), snapshot: .preview)
}
