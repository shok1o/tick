import SwiftUI
import SwiftData

/// Главный экран: сегодняшний день, вкладки «Сегодня / На полях» и строка ввода.
struct TodayView: View {
    enum Tab { case tasks, margins }

    @Binding var path: [Route]

    @Environment(\.palette) private var p
    @EnvironmentObject private var clock: DayClock
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.sortOrder) private var allItems: [TodoItem]
    @Query(sort: \Thought.createdAt, order: .reverse) private var thoughts: [Thought]

    @State private var tab: Tab = Demo.startOnMargins ? .margins : .tasks
    // Сам объект держим отдельно от флага показа: окно закрывается раньше,
    // чем срабатывает кнопка, и без этого действие получило бы nil.
    @State private var editing: TodoItem?
    @State private var isEditing = false
    @State private var editText = ""
    @State private var lettingGo: TodoItem?
    @State private var isLettingGo = false
    /// День, когда итог дня закрыли крестиком (секунды с 1970 года).
    @AppStorage("summaryDismissedDay") private var summaryDismissedDay: Double = 0
    @Namespace private var tabs

    /// После скольких переносов Tick предлагает отпустить задачу — полная «пятёрка».
    static let letGoThreshold = 5

    private var today: Date { clock.today }
    private var items: [TodoItem] { allItems.filter { $0.isInToday(today) } }
    private var open: [TodoItem] { items.filter { !$0.isDone } }
    private var done: [TodoItem] {
        items.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// Итог дня показываем вечером, если в дне что-то было и его не закрыли.
    private var showsSummary: Bool {
        let evening = Calendar.current.component(.hour, from: Date()) >= 18 || Demo.forceEvening
        return tab == .tasks && evening && !items.isEmpty
            && summaryDismissedDay != today.timeIntervalSince1970
    }

    var body: some View {
        List {
            header
            tabBar
            stats

            switch tab {
            case .tasks:
                if showsSummary { summary }
                if items.isEmpty {
                    EmptyHint(title: "День чистый",
                              subtitle: "Напишите задачу внизу. Тег — через #, например #дом")
                }
                ForEach(open) { taskRow($0) }
                    .onMove(perform: move)
                ForEach(done) { taskRow($0) }
            case .margins:
                if thoughts.isEmpty {
                    EmptyHint(title: "На полях пусто",
                              subtitle: "Записывайте сюда то, что ещё не стало задачей. Без галочек и сроков")
                }
                ForEach(thoughts) { noteRow($0) }
            }
        }
        .paperList()
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationTitle("Tick")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InputBar(placeholder: tab == .tasks ? "Задача на сегодня" : "Заметка на полях") { text in
                withAnimation(.easeOut(duration: 0.2)) { add(text) }
            }
        }
        .alert("Изменить задачу", isPresented: $isEditing, presenting: editing) { item in
            TextField("Текст задачи", text: $editText)
            Button("Сохранить") {
                let t = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { item.text = t }
            }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog(letGoTitle, isPresented: $isLettingGo, titleVisibility: .visible,
                            presenting: lettingGo) { item in
            Button("Унести на поля") { moveToMargins(item) }
            Button("Отпустить и удалить", role: .destructive) { delete(item) }
            Button("Оставить ещё", role: .cancel) {}
        } message: { _ in
            Text("Иногда задача просто не нужна. Её можно отпустить или унести на поля — без чувства вины.")
        }
    }

    private var letGoTitle: String {
        guard let item = lettingGo else { return "" }
        return "Переносится уже " + RussianPlural.format(item.marks(asOf: today), "день", "дня", "дней")
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
            HStack(spacing: 10) {
                roundButton("clock", label: "История", key: "y") { path.append(.history) }
                roundButton("circle.lefthalf.filled", label: "Оформление", key: ",") { path.append(.appearance) }
            }
            .padding(.top, 14)
        }
        .padding(.top, 16)
        .paperRow()
        .moveDisabled(true)
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

    // MARK: Вкладки — слова с точкой под активной, как точка на иконке

    private var tabBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 26) {
            tabButton(.tasks, title: "Сегодня", count: open.count, key: "1")
            tabButton(.margins, title: "На полях", count: thoughts.count, key: "2")
            Spacer()
        }
        .padding(.top, 26)
        .paperRow()
        .moveDisabled(true)
    }

    private func tabButton(_ value: Tab, title: String, count: Int, key: KeyEquivalent) -> some View {
        let selected = tab == value
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { tab = value }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: selected ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(selected ? p.ink : p.inkSoft)
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(selected ? p.dot : p.inkSoft)
                        .contentTransition(.numericText())
                        .baselineOffset(8)
                }
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: 8, height: 8)
                    if selected {
                        Circle()
                            .fill(p.dot)
                            .frame(width: 8, height: 8)
                            .matchedGeometryEffect(id: "tabDot", in: tabs)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: .command)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Сводка

    private var stats: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if tab == .tasks {
                    Text("\(open.count) открыто · \(done.count) готово")
                } else {
                    Text(RussianPlural.format(thoughts.count, "заметка", "заметки", "заметок") + " · без сроков")
                }
            }
            .font(.meta)
            .foregroundStyle(p.inkSoft)
            .contentTransition(.numericText())

            ProgressDivider(fraction: tab == .tasks && !items.isEmpty
                            ? CGFloat(done.count) / CGFloat(items.count) : 0)
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
        .paperRow()
        .moveDisabled(true)
    }

    /// Вечерняя карточка: что закрыто и что переедет на завтра.
    private var summary: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ИТОГ ДНЯ")
                    .font(.label)
                    .tracking(2)
                    .foregroundStyle(p.dot)
                Text(summaryText)
                    .font(.task)
                    .foregroundStyle(p.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.easeOut(duration: 0.25)) { summaryDismissedDay = today.timeIntervalSince1970 }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(p.inkSoft)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(p.inkFaint.opacity(0.3)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Скрыть итог дня")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(p.inkFaint.opacity(0.22)))
        .padding(.vertical, 10)
        .paperRow()
        .moveDisabled(true)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var summaryText: String {
        if open.isEmpty {
            return "Закрыто всё — " + RussianPlural.format(done.count, "задача", "задачи", "задач")
                + ". Завтра начнём с чистого листа."
        }
        let closed = done.isEmpty
            ? "Сегодня пока ничего не закрыто."
            : "Закрыто " + RussianPlural.format(done.count, "задача", "задачи", "задач") + "."
        let moving = open.count == 1 || (open.count % 10 == 1 && open.count % 100 != 11)
            ? RussianPlural.format(open.count, "задача", "задачи", "задач") + " переедет на завтра и получит засечку."
            : RussianPlural.format(open.count, "задача", "задачи", "задач") + " переедут на завтра и получат по засечке."
        return closed + " " + moving
    }

    // MARK: Строки

    private func taskRow(_ item: TodoItem) -> some View {
        let marks = item.marks(asOf: today)
        return TaskRow(
            text: item.text, done: item.isDone, marks: marks,
            onToggle: { withAnimation(.easeInOut(duration: 0.25)) { Store.toggle(item, today: today) } },
            onLetGo: marks >= Self.letGoThreshold ? { lettingGo = item; isLettingGo = true } : nil
        )
        .contextMenu {
            Button("Изменить", systemImage: "pencil") { startEditing(item) }
            Button(item.isDone ? "Вернуть" : "Выполнить", systemImage: "checkmark") {
                withAnimation { Store.toggle(item, today: today) }
            }
            Button("На поля", systemImage: "text.alignleft") { moveToMargins(item) }
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

    private func noteRow(_ thought: Thought) -> some View {
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
            .help("Сделать задачей на сегодня")
            .accessibilityLabel("Сделать задачей на сегодня")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { RowSeparator() }
        .contentShape(Rectangle())
        .paperRow()
        .contextMenu {
            Button("Сделать задачей на сегодня", systemImage: "arrow.up.right") { promote(thought) }
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
        case .margins:
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            context.insert(Thought(text: t))
        }
    }

    private func startEditing(_ item: TodoItem) {
        editText = item.text
        editing = item
        isEditing = true
    }

    private func delete(_ item: TodoItem) {
        withAnimation { Store.delete(item, today: today, in: context) }
    }

    /// Задача оказалась пока не задачей — уносим её на поля.
    private func moveToMargins(_ item: TodoItem) {
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
