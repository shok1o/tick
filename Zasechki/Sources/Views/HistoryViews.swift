import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.palette) private var p
    @EnvironmentObject private var clock: DayClock
    @Query private var allItems: [TodoItem]

    private struct DaySummary: Identifiable {
        let date: Date
        let done: Int
        let carried: Int
        var id: Date { date }
    }

    /// Прошедшие дни, в которых что-то было, от новых к старым.
    private var days: [DaySummary] {
        let today = clock.today
        guard let earliest = allItems.map(\.day).min(), earliest < today else { return [] }
        var result: [DaySummary] = []
        var date = Day.adding(-1, to: today)
        while date >= earliest {
            var done = 0, carried = 0
            for item in allItems {
                switch item.state(onPast: date) {
                case .done: done += 1
                case .carried: carried += 1
                case nil: break
                }
            }
            if done + carried > 0 {
                result.append(DaySummary(date: date, done: done, carried: carried))
            }
            date = Day.adding(-1, to: date)
        }
        return result
    }

    var body: some View {
        List {
            ScreenHeader(title: "История", subtitle: "Прошедшие дни — такими, какими вы их оставили")

            if days.isEmpty {
                EmptyHint(title: "Истории пока нет", subtitle: "Завтра здесь появится сегодняшний день")
            }
            ForEach(days) { day in
                NavigationLink(value: Route.day(day.date)) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Day.shortTitle(day.date, today: clock.today))
                                .font(.system(size: 17, design: .monospaced))
                                .foregroundStyle(p.ink)
                            Text(summary(day))
                                .font(.meta)
                                .foregroundStyle(p.inkSoft)
                        }
                        Spacer()
                        DayBar(done: day.done, carried: day.carried)
                    }
                    .padding(.vertical, 10)
                }
                .paperRow()
            }
        }
        .paperList()
        .navigationTitle("История")
    }

    private func summary(_ day: DaySummary) -> String {
        var parts: [String] = []
        if day.done > 0 { parts.append("выполнено \(day.done)") }
        if day.carried > 0 { parts.append("перенесено \(day.carried)") }
        return parts.joined(separator: " · ")
    }
}

/// Мини-полоска дня: чернила — выполнено, оранжевый — перенесено.
private struct DayBar: View {
    @Environment(\.palette) private var p
    let done: Int
    let carried: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(done, 8), id: \.self) { _ in
                Capsule().fill(p.ink).frame(width: 3, height: 14)
            }
            ForEach(0..<min(carried, 8), id: \.self) { _ in
                Capsule().fill(p.dot).frame(width: 3, height: 14)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Прошедший день, только для чтения.
struct HistoryDayView: View {
    let date: Date
    @EnvironmentObject private var clock: DayClock
    @Query(sort: \TodoItem.sortOrder) private var allItems: [TodoItem]

    private var done: [TodoItem] { allItems.filter { $0.state(onPast: date) == .done } }
    private var carried: [TodoItem] { allItems.filter { $0.state(onPast: date) == .carried } }

    var body: some View {
        List {
            ScreenHeader(title: Day.shortTitle(date, today: clock.today),
                         subtitle: Day.daysBetween(date, clock.today) <= 1 ? Day.title(date) : nil)

            if !done.isEmpty {
                SectionLabel(text: "Выполнено")
                ForEach(done) { item in
                    TaskRow(text: item.text, done: true)
                }
            }
            if !carried.isEmpty {
                SectionLabel(text: "Перенесено дальше")
                ForEach(carried) { item in
                    TaskRow(text: item.text, done: false, marks: item.marks(asOf: date) + 1)
                }
            }
        }
        .paperList()
        .navigationTitle(Day.shortTitle(date, today: clock.today))
    }
}

/// Все задачи с тегом: сначала открытые.
struct TagView: View {
    let tag: String
    @EnvironmentObject private var clock: DayClock
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var allItems: [TodoItem]

    private var tagged: [TodoItem] {
        allItems.filter { $0.deletedDay == nil && Tags.of($0.text).contains(tag) }
    }
    private var open: [TodoItem] { tagged.filter { !$0.isDone } }
    private var done: [TodoItem] { tagged.filter(\.isDone) }

    var body: some View {
        List {
            ScreenHeader(title: "#\(tag)",
                         subtitle: RussianPlural.format(tagged.count, "задача", "задачи", "задач"))

            if tagged.isEmpty {
                EmptyHint(title: "Задач с этим тегом нет", subtitle: "Тег исчезает вместе с последней задачей")
            }
            if !open.isEmpty {
                SectionLabel(text: "Открытые")
                ForEach(open) { item in
                    TaskRow(text: item.text, done: false, marks: item.marks(asOf: clock.today)) {
                        withAnimation { Store.toggle(item, today: clock.today) }
                    }
                }
            }
            if !done.isEmpty {
                SectionLabel(text: "Выполненные")
                ForEach(done) { item in
                    TaskRow(text: item.text, done: true,
                            trailingNote: item.completedDay.map { Day.shortTitle($0, today: clock.today) })
                }
            }
        }
        .paperList()
        .navigationTitle("#\(tag)")
    }
}
