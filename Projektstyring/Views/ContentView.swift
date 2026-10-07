import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]

    @AppStorage("didSeedExamples") private var didSeedExamples = false
    @AppStorage(SettingsKey.showTagsOnCards) private var showTags = true
    @State private var filter: Filter = .active
    @State private var selectedTag: String?
    @State private var onlyHighPriority = false
    @State private var searchText = ""
    @State private var path: [TaskItem] = []
    @State private var showingNewTask = false
    @State private var showingSettings = false
    @State private var celebrate = 0
    @Namespace private var zoom

    enum Filter: String, CaseIterable, Identifiable {
        case active = "Aktive"
        case done = "Færdige"
        case all = "Alle"
        var id: String { rawValue }
    }

    struct TaskSection: Identifiable {
        let urgency: Urgency
        let tasks: [TaskItem]
        var id: Int { urgency.rawValue }
    }

    /// Alle mærkater i brug, sorteret alfabetisk.
    private var allTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for task in tasks {
            for tag in task.tags where !seen.contains(tag.lowercased()) {
                seen.insert(tag.lowercased())
                result.append(tag)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredTasks: [TaskItem] {
        tasks.filter { task in
            let passesFilter: Bool
            switch filter {
            case .active: passesFilter = !task.isDone
            case .done: passesFilter = task.isDone
            case .all: passesFilter = true
            }
            let passesTag = selectedTag.map { tag in
                task.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            } ?? true
            let passesPriority = !onlyHighPriority || task.priority == .high
                || (task.subtasks ?? []).contains { $0.priority == .high && !$0.isDone }
            return passesFilter && passesTag && passesPriority && task.matches(search: searchText)
        }
    }

    private var sections: [TaskSection] {
        let groups = Dictionary(grouping: filteredTasks) { $0.urgency }
        return Urgency.allCases.compactMap { urgency in
            guard let items = groups[urgency], !items.isEmpty else { return nil }
            // Høj prioritet øverst i hver gruppe, derefter efter deadline.
            return TaskSection(urgency: urgency, tasks: items.sorted { a, b in
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                return a.dueDate < b.dueDate
            })
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                List {
                    SummaryHeader(tasks: tasks) { urgency in
                        jump(to: urgency, proxy: proxy)
                    }
                    .plainRow(top: 8, bottom: 8)

                    if filter != .done && searchText.isEmpty {
                        FocusCard(tasks: tasks, onOpen: { path.append($0) }, onToggle: toggleSubtask)
                            .plainRow(top: 4, bottom: 8)
                    }

                    Picker("Vis", selection: $filter.animation(.snappy)) {
                        ForEach(Filter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .plainRow(top: 4, bottom: 4)

                    if (showTags && !allTags.isEmpty) || hasHighPriority {
                        tagFilter
                            .plainRow(top: 2, bottom: 2, horizontal: 0)
                    }

                    if sections.isEmpty {
                        emptyState
                            .plainRow(top: 0, bottom: 0)
                    }

                    ForEach(sections) { section in
                        SectionHeaderView(urgency: section.urgency, count: section.tasks.count)
                            .id(sectionAnchor(section.urgency))
                            .plainRow(top: 14, bottom: 2)

                        ForEach(section.tasks) { task in
                            taskRow(task)
                        }
                    }

                    // Plads til den runde "+"-knap nederst.
                    Color.clear
                        .frame(height: 90)
                        .plainRow(top: 0, bottom: 0)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AnimatedBackground())
            }
            .navigationTitle("Milepæl")
            .searchable(text: $searchText, prompt: "Søg i opgaver og mærkater")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Indstillinger")
                }
            }
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
                    .navigationTransition(.zoom(sourceID: task.persistentModelID, in: zoom))
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .overlay {
                ConfettiView(trigger: celebrate)
            }
            .sensoryFeedback(.success, trigger: celebrate)
            .sheet(isPresented: $showingNewTask) {
                TaskEditor(task: nil)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                seedExamplesIfNeeded()
            }
            .onChange(of: allTags) { _, tags in
                if let selectedTag, !tags.contains(selectedTag) {
                    self.selectedTag = nil
                }
            }
        }
    }

    // MARK: - Rækker

    private func sectionAnchor(_ urgency: Urgency) -> String {
        "section-\(urgency.rawValue)"
    }

    /// Tryk på en haster-gruppe i toppen hopper ned til gruppen.
    private func jump(to urgency: Urgency, proxy: ScrollViewProxy) {
        if filter == .done { filter = .active }
        if selectedTag != nil || !searchText.isEmpty {
            selectedTag = nil
            searchText = ""
        }
        DispatchQueue.main.async {
            withAnimation(.snappy) {
                proxy.scrollTo(sectionAnchor(urgency), anchor: .top)
            }
        }
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if hasHighPriority {
                    Button {
                        withAnimation(.snappy) { onlyHighPriority.toggle() }
                    } label: {
                        Label("Høj prioritet", systemImage: "flag.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(onlyHighPriority ? Color(hex: 0xFBFAFC) : Theme.priorityHigh)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(onlyHighPriority ? Theme.priorityHigh : Theme.priorityHigh.opacity(0.14),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: onlyHighPriority)
                }
                ForEach(showTags ? allTags : [], id: \.self) { tag in
                    let isSelected = selectedTag == tag
                    Button {
                        withAnimation(.snappy) {
                            selectedTag = isSelected ? nil : tag
                        }
                    } label: {
                        TagChip(tag: tag)
                            .overlay(
                                Capsule()
                                    .strokeBorder(TagStyle.color(for: tag), lineWidth: isSelected ? 1.5 : 0)
                            )
                            .scaleEffect(isSelected ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            path.append(task)
        } label: {
            TaskCard(task: task)
                .matchedTransitionSource(id: task.persistentModelID, in: zoom)
        }
        .buttonStyle(PressableButtonStyle())
        .plainRow(top: 5, bottom: 5)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleDone(task)
            } label: {
                Label(task.isDone ? "Genåbn" : "Færdig",
                      systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isDone ? Color.orange : Urgency.done.color)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Slet", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                toggleDone(task)
            } label: {
                Label(task.isDone ? "Genåbn" : "Markér som færdig",
                      systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark.circle")
            }
            if !task.isDone {
                Menu {
                    Button("1 dag") { postpone(task, days: 1) }
                    Button("1 uge") { postpone(task, days: 7) }
                    Button("1 måned") { postpone(task, days: 30) }
                } label: {
                    Label("Udsæt deadline", systemImage: "calendar.badge.clock")
                }
            }
            Button {
                withAnimation(.snappy) {
                    task.priority = task.priority == .high ? .normal : .high
                }
            } label: {
                Label(task.priority == .high ? "Fjern høj prioritet" : "Giv høj prioritet",
                      systemImage: task.priority == .high ? "flag.slash" : "flag.fill")
            }
            Button {
                duplicate(task)
            } label: {
                Label("Duplikér", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Slet", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty || selectedTag != nil {
            EmptyStateView(icon: "magnifyingglass",
                           title: "Ingen resultater",
                           message: "Prøv et andet søgeord eller mærkat.",
                           buttonTitle: nil,
                           action: {})
        } else if filter == .done {
            EmptyStateView(icon: "trophy.fill",
                           title: "Intet færdigt endnu",
                           message: "Når du gør en opgave færdig, havner den her.",
                           buttonTitle: nil,
                           action: {})
        } else {
            EmptyStateView(icon: "flag.fill",
                           title: "Ingen aktive opgaver",
                           message: "Tryk på + for at oprette din første opgave.",
                           buttonTitle: "Opret opgave",
                           action: { showingNewTask = true })
        }
    }

    private var addButton: some View {
        Button {
            showingNewTask = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(hex: 0xFBFAFC))
                .frame(width: 62, height: 62)
                // Liquid Glass (iOS 26+) tonet i appens primærfarve. Glasset reagerer selv på tryk.
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: showingNewTask)
        .padding(.trailing, 22)
        .padding(.bottom, 12)
        .accessibilityLabel("Ny opgave")
    }

    // MARK: - Handlinger

    private func toggleDone(_ task: TaskItem) {
        let wasDone = task.isDone
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            task.setDone(!wasDone)
        }
        if !wasDone { celebrate += 1 }
    }

    private func toggleSubtask(_ subtask: SubTask) {
        guard let parent = subtask.parent else { return }
        let completedTask = withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            parent.toggleSubtask(subtask)
        }
        if completedTask { celebrate += 1 }
    }

    private var hasHighPriority: Bool {
        tasks.contains { !$0.isDone && ($0.priority == .high
            || ($0.subtasks ?? []).contains { $0.priority == .high && !$0.isDone }) }
    }

    /// Skubber deadline (og åbne underopgaver) frem.
    private func postpone(_ task: TaskItem, days: Int) {
        withAnimation(.snappy) {
            task.dueDate = task.dueDate.adding(days: days)
            for subtask in task.subtasks ?? [] where !subtask.isDone {
                subtask.dueDate = subtask.dueDate.adding(days: days)
            }
        }
    }

    /// Laver en kopi med åbne underopgaver, fx til tilbagevendende projekter.
    private func duplicate(_ task: TaskItem) {
        let copy = TaskItem(title: "\(task.title) (kopi)",
                            notes: task.notes,
                            dueDate: task.dueDate,
                            priority: task.priority)
        copy.tags = task.tags
        withAnimation(.snappy) {
            context.insert(copy)
            for subtask in task.sortedSubtasks {
                let newSubtask = SubTask(title: subtask.title, dueDate: subtask.dueDate, priority: subtask.priority)
                context.insert(newSubtask)
                copy.addSubtask(newSubtask)
            }
        }
    }

    private func delete(_ task: TaskItem) {
        withAnimation(.snappy) {
            context.delete(task)
        }
    }

    /// Lægger et par eksempler ind første gang, så man kan se, hvordan det ser ud.
    private func seedExamplesIfNeeded() {
        guard !didSeedExamples else { return }
        didSeedExamples = true
        guard tasks.isEmpty else { return }

        let now = Date()

        let report = TaskItem(title: "Årsrapport 2026",
                              notes: "Eksempel – slet mig, når du er klar. Stryg til venstre på et kort for at slette.",
                              dueDate: now.adding(days: 75),
                              priority: .high,
                              createdAt: now.adding(days: -30))
        report.tags = ["Økonomi"]
        context.insert(report)
        for (title, days, done) in [("Indsamle tal fra afdelingerne", -5, true),
                                    ("Første udkast", 20, false),
                                    ("Gennemlæsning med chefen", 55, false),
                                    ("Endelig aflevering", 75, false)] {
            let subtask = SubTask(title: title, dueDate: now.adding(days: days))
            subtask.isDone = done
            context.insert(subtask)
            report.addSubtask(subtask)
        }

        let website = TaskItem(title: "Opdatere hjemmesiden",
                               notes: "Eksempel.",
                               dueDate: now.adding(days: 21),
                               createdAt: now.adding(days: -10))
        website.tags = ["Marketing"]
        context.insert(website)
        for (title, days) in [("Nye billeder", 4), ("Tekster til forsiden", 12)] {
            let subtask = SubTask(title: title, dueDate: now.adding(days: days))
            context.insert(subtask)
            website.addSubtask(subtask)
        }

        let teamDay = TaskItem(title: "Booke lokale til teamdag",
                               notes: "Eksempel.",
                               dueDate: now.adding(days: 3),
                               createdAt: now.adding(days: -7))
        context.insert(teamDay)
    }
}

private extension View {
    /// En listerække uden baggrund og streger, så kortene "svæver".
    func plainRow(top: CGFloat, bottom: CGFloat, horizontal: CGFloat = 16) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Overblik øverst

struct SummaryHeader: View {
    let tasks: [TaskItem]
    var onSelect: (Urgency) -> Void = { _ in }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return "God morgen"
        case 10..<12: return "God formiddag"
        case 12..<18: return "God eftermiddag"
        default: return "God aften"
        }
    }

    var body: some View {
        let active = tasks.filter { !$0.isDone }
        let counts = Dictionary(grouping: active) { $0.urgency }.mapValues { $0.count }
        let overall: Double = active.isEmpty
            ? (tasks.isEmpty ? 0 : 1)
            : active.map { $0.progress }.reduce(0, +) / Double(active.count)
        let next = active.min { $0.dueDate < $1.dueDate }

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: overall, color: Color.primary.opacity(0.75), lineWidth: 10)
                    Text(overall, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .contentTransition(.numericText(value: overall))
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(active.count == 1 ? "1 aktiv opgave" : "\(active.count) aktive opgaver")
                        .font(.title3.weight(.bold))
                        .contentTransition(.numericText())
                    if let next {
                        Text("Næste: \(next.title) · \(DeadlineText.relative(to: next.dueDate).lowercased())")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(next.urgency.color)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            UrgencyBar(counts: counts)

            WeekStatsLine(tasks: tasks)

            HStack(spacing: 6) {
                ForEach(Urgency.activeCases) { urgency in
                    let count = counts[urgency] ?? 0
                    Button {
                        onSelect(urgency)
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(count)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(count > 0 ? urgency.color : Color.secondary)
                                .contentTransition(.numericText(value: Double(count)))
                            Text(urgency.shortTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            urgency.color.opacity(count > 0 ? 0.13 : 0.05),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.93))
                    .disabled(count == 0)
                }
            }
            .animation(.snappy, value: counts)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Én vandret bjælke delt op efter hvor meget opgaverne haster.
struct UrgencyBar: View {
    let counts: [Urgency: Int]

    var body: some View {
        let visible = Urgency.activeCases.filter { (counts[$0] ?? 0) > 0 }
        let total = visible.reduce(0) { $0 + (counts[$1] ?? 0) }

        GeometryReader { geo in
            let gaps = CGFloat(max(visible.count - 1, 0)) * 3
            let usable = max(geo.size.width - gaps, 0)
            HStack(spacing: 3) {
                if total == 0 {
                    Capsule().fill(Theme.surfaceRaised)
                } else {
                    ForEach(visible) { urgency in
                        Capsule()
                            .fill(urgency.color.gradient)
                            .frame(width: usable * CGFloat(counts[urgency] ?? 0) / CGFloat(total))
                    }
                }
            }
        }
        .frame(height: 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: counts)
        .accessibilityHidden(true)
    }
}

/// "Denne uge: 2 opgaver og 5 underopgaver færdige".
struct WeekStatsLine: View {
    let tasks: [TaskItem]

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let doneTasks = tasks.filter { ($0.completedAt ?? .distantPast) >= start }.count
        let doneSubtasks = tasks.flatMap { $0.subtasks ?? [] }
            .filter { $0.isDone && ($0.completedAt ?? .distantPast) >= start }.count

        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(Theme.accent)
            Text("Denne uge:")
                .foregroundStyle(.secondary)
            Text("\(doneTasks) \(doneTasks == 1 ? "opgave" : "opgaver") og \(doneSubtasks) \(doneSubtasks == 1 ? "underopgave" : "underopgaver") færdige")
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// "Haster nu": underopgaver der er over tid eller forfalder inden for 7 dage.
struct FocusCard: View {
    let tasks: [TaskItem]
    var onOpen: (TaskItem) -> Void
    var onToggle: (SubTask) -> Void

    private let maxRows = 4

    var body: some View {
        let items = tasks.filter { !$0.isDone }
            .flatMap { $0.soonSubtasks }
            .sorted { a, b in
                if a.urgency != b.urgency { return a.urgency.rawValue < b.urgency.rawValue }
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                return a.dueDate < b.dueDate
            }

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(items[0].urgency.color)
                    Text("Haster nu")
                        .font(.headline)
                    Text("\(items.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(items[0].urgency.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(items[0].urgency.color.opacity(0.15), in: Capsule())
                    Spacer()
                    Text("Underopgaver")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                ForEach(items.prefix(maxRows)) { subtask in
                    HStack(spacing: 12) {
                        Button {
                            onToggle(subtask)
                        } label: {
                            Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(subtask.urgency.color)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: subtask.isDone)
                        .accessibilityLabel("Markér \(subtask.title) som færdig")

                        Button {
                            if let parent = subtask.parent { onOpen(parent) }
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(subtask.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if subtask.priority == .high {
                                            PriorityBadge(compact: true)
                                        }
                                    }
                                    Text(subtask.parent?.title ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                SubtaskDuePill(subtask: subtask)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if items.count > maxRows {
                    Text("+ \(items.count - maxRows) flere")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(items[0].urgency.color.gradient)
                    .frame(width: 4)
                    .padding(.vertical, 16)
                    .padding(.leading, 6)
            }
        }
    }
}

struct SectionHeaderView: View {
    let urgency: Urgency
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: urgency.icon)
                .foregroundStyle(urgency.color)
            Text(urgency.sectionTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(urgency.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(urgency.color.opacity(0.15), in: Capsule())
            Spacer()
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    @State private var bounce = 0

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: bounce)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onAppear { bounce += 1 }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, SubTask.self], inMemory: true)
        .environment(\.locale, Locale(identifier: "da_DK"))
}
