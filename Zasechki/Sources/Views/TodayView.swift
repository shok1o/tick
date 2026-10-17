import SwiftUI
import SwiftData

/// Главный экран: сегодняшний день, переключатель «Задачи / Мысли» и строка ввода.
struct TodayView: View {
    enum Tab { case tasks, thoughts }

    @Binding var path: [Route]

    @Environment(\.palette) private var p
    @EnvironmentObject private var clock: DayClock
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.sortOrder) private var allItems: [TodoItem]
    @Query(sort: \Thought.createdAt, order: .reverse) private var thoughts: [Thought]

    @State private var tab: Tab = Demo.startOnThoughts ? .thoughts : .tasks
    @State private var editing: TodoItem?
    @State private var editText = ""
    @Namespace private var segment

    private var today: Date { clock.today }
    private var items: [TodoItem] { allItems.filter { $0.isInToday(today) } }
    private var open: [TodoItem] { items.filter { !$0.isDone } }
    private var done: [TodoItem] {
        items.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            header
            switcher
            stats

            switch tab {
            case .tasks:
                if items.isEmpty {
                    EmptyHint(title: "День чистый",
                              subtitle: "Напишите задачу внизу. Тег — через #, например #дом")
                }
                ForEach(open) { taskRow($0) }
                    .onMove(perform: move)
                ForEach(done) { taskRow($0) }
            case .thoughts:
                if thoughts.isEmpty {
                    EmptyHint(title: "Мыслей пока нет",
                              subtitle: "Здесь живут идеи без галочек и сроков. Любую можно перенести в задачи")
                }
                ForEach(thoughts) { thoughtRow($0) }
            }
        }
        .paperList()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationTitle("Tick")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InputBar(placeholder: tab == .tasks ? "Задача на сегодня" : "Мысль, без сроков") { text in
                withAnimation(.easeOut(duration: 0.2)) { add(text) }
            }
        }
        .alert("Изменить задачу", isPresented: Binding(
            get: { editing != nil }, set: { if !$0 { editing = nil } }
        )) {
            TextField("Текст задачи", text: $editText)
            Button("Сохранить") {
                let t = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let editing, !t.isEmpty { editing.text = t }
                editing = nil
            }
            Button("Отмена", role: .cancel) { editing = nil }
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Day.weekday(today).uppercased()) · СЕГОДНЯ")
                    .font(.label)
                    .tracking(2)
                    .foregroundStyle(p.inkSoft)
                Text(Day.dayMonth(today))
                    .font(.display)
                    .foregroundStyle(p.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 12)
            menu
                .padding(.top, 14)
        }
        .padding(.top, 16)
        .paperRow()
        .moveDisabled(true)
    }

    /// Две круглые кнопки справа сверху: история и оформление.
    private var menu: some View {
        HStack(spacing: 10) {
            roundButton("clock", label: "История", key: "y") { path.append(.history) }
            roundButton("circle.lefthalf.filled", label: "Оформление", key: ",") { path.append(.appearance) }
        }
    }

    private func roundButton(_ icon: String, label: String, key: KeyEquivalent,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(p.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(p.inkFaint.opacity(0.3)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: .command)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Переключатель

    private var switcher: some View {
        HStack(spacing: 2) {
            segmentButton(.tasks, title: "Задачи", count: open.count, key: "1")
            segmentButton(.thoughts, title: "Мысли", count: thoughts.count, key: "2")
        }
        .padding(4)
        .background(Capsule().fill(p.inkFaint.opacity(0.3)))
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
        .paperRow()
        .moveDisabled(true)
    }

    private func segmentButton(_ value: Tab, title: String, count: Int, key: KeyEquivalent) -> some View {
        let selected = tab == value
        return Button {
            withAnimation(.snappy(duration: 0.3)) { tab = value }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(selected ? p.paper.opacity(0.18) : p.inkFaint.opacity(0.45)))
            }
            .foregroundStyle(selected ? p.paper : p.inkSoft)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                if selected {
                    Capsule().fill(p.ink).matchedGeometryEffect(id: "segment", in: segment)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: .command)
    }

    // MARK: Сводка

    private var stats: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if tab == .tasks {
                    Text("\(open.count) открыто · \(done.count) готово")
                } else {
                    Text(RussianPlural.format(thoughts.count, "мысль", "мысли", "мыслей") + " · без сроков")
                }
            }
            .font(.meta)
            .foregroundStyle(p.inkSoft)
            .contentTransition(.numericText())

            ProgressDivider(fraction: tab == .tasks && !items.isEmpty
                            ? CGFloat(done.count) / CGFloat(items.count) : 0)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .paperRow()
        .moveDisabled(true)
    }

    // MARK: Строки

    private func taskRow(_ item: TodoItem) -> some View {
        TaskRow(text: item.text, done: item.isDone, marks: item.marks(asOf: today)) {
            withAnimation(.easeInOut(duration: 0.25)) { Store.toggle(item, today: today) }
        }
        .contextMenu {
            Button("Изменить", systemImage: "pencil") { startEditing(item) }
            Button(item.isDone ? "Вернуть" : "Выполнить", systemImage: "checkmark") {
                withAnimation { Store.toggle(item, today: today) }
            }
            Button("В мысли", systemImage: "lightbulb") { demote(item) }
            Divider()
            Button("Удалить", systemImage: "trash", role: .destructive) { delete(item) }
        }
        .swipeActions(edge: .trailing) {
            Button("Удалить", systemImage: "trash", role: .destructive) { delete(item) }
                .tint(p.danger)
            Button("Изменить", systemImage: "pencil") { startEditing(item) }
                .tint(Color(hex: 0x6E6A63))
        }
        .swipeActions(edge: .leading) {
            Button(item.isDone ? "Вернуть" : "Готово", systemImage: "checkmark") {
                withAnimation { Store.toggle(item, today: today) }
            }
            .tint(p.dot)
        }
    }

    private func thoughtRow(_ thought: Thought) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Capsule()
                .fill(p.inkFaint)
                .frame(width: 3, height: 16)
                .padding(.top, 3)
                .padding(.horizontal, 9.5)
            VStack(alignment: .leading, spacing: 5) {
                TaggedText(text: thought.text)
                Text(Day.dayMonth(thought.createdAt))
                    .font(.meta)
                    .foregroundStyle(p.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                promote(thought)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(p.dot)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(p.dot.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Перенести в задачи на сегодня")
            .accessibilityLabel("Перенести в задачи на сегодня")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { RowSeparator() }
        .contentShape(Rectangle())
        .paperRow()
        .contextMenu {
            Button("В задачи на сегодня", systemImage: "arrow.up.right") { promote(thought) }
            Divider()
            Button("Удалить", systemImage: "trash", role: .destructive) { remove(thought) }
        }
        .swipeActions(edge: .leading) {
            Button("В задачи", systemImage: "arrow.up.right") { promote(thought) }
                .tint(p.dot)
        }
        .swipeActions(edge: .trailing) {
            Button("Удалить", systemImage: "trash", role: .destructive) { remove(thought) }
                .tint(p.danger)
        }
    }

    // MARK: Действия

    private func add(_ text: String) {
        switch tab {
        case .tasks:
            Store.addTask(text, today: today, in: context, existing: allItems)
        case .thoughts:
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            context.insert(Thought(text: t))
        }
    }

    private func startEditing(_ item: TodoItem) {
        editText = item.text
        editing = item
    }

    private func delete(_ item: TodoItem) {
        withAnimation { Store.delete(item, today: today, in: context) }
    }

    /// Задача оказалась пока не задачей — уносим её в мысли.
    private func demote(_ item: TodoItem) {
        withAnimation {
            context.insert(Thought(text: item.text))
            Store.delete(item, today: today, in: context)
        }
    }

    private func promote(_ thought: Thought) {
        withAnimation { Store.promote(thought, today: today, in: context, existing: allItems) }
    }

    private func remove(_ thought: Thought) {
        withAnimation { context.delete(thought) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = open
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.sortOrder = Double(index)
        }
    }
}

/// Линия под сводкой: тонкий разделитель, который заполняется по мере выполнения
/// задач, с точкой на конце — как на иконке.
struct ProgressDivider: View {
    @Environment(\.palette) private var p
    let fraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.inkFaint.opacity(0.6)).frame(height: 2)
                Capsule().fill(p.dot).frame(width: geo.size.width * fraction, height: 2)
                Circle()
                    .fill(p.dot)
                    .frame(width: 7, height: 7)
                    .offset(x: max(0, geo.size.width * fraction - 3.5))
                    .opacity(fraction > 0 ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 7)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: fraction)
    }
}
