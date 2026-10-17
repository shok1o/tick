import Foundation
import SwiftData

enum Day {
    static var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    static func start(of date: Date) -> Date { calendar.startOfDay(for: date) }

    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: start(of: from), to: start(of: to)).day ?? 0
    }

    static func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(of: date)) ?? date
    }

    /// «Суббота»
    static func weekday(_ date: Date) -> String {
        let s = date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ru_RU")))
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// «17 октября»
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU")))
    }

    /// «Суббота, 17 октября»
    static func title(_ date: Date) -> String {
        let s = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "ru_RU")))
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// «17 октября 2026» для старых дат, «Вчера» для вчерашней.
    static func shortTitle(_ date: Date, today: Date) -> String {
        switch daysBetween(date, today) {
        case 0: return "Сегодня"
        case 1: return "Вчера"
        default: return title(date)
        }
    }
}

extension TodoItem {
    func isVisible(on day: Date) -> Bool {
        if let deleted = deletedDay, deleted <= day { return false }
        return self.day <= day
    }

    /// Задача в списке «Сегодня»: открытые и выполненные сегодня.
    func isInToday(_ today: Date) -> Bool {
        guard isVisible(on: today) else { return false }
        guard let done = completedDay else { return true }
        return done == today
    }

    /// Сколько раз задача переносилась (число засечек) к указанному дню.
    func marks(asOf date: Date) -> Int {
        max(0, Day.daysBetween(day, completedDay.map { min($0, date) } ?? date))
    }

    /// Состояние задачи на конец прошедшего дня, или nil, если её в тот день не было.
    enum PastState { case done, carried }

    func state(onPast date: Date) -> PastState? {
        guard isVisible(on: date) else { return nil }
        if let done = completedDay {
            if done == date { return .done }
            if done < date { return nil }
        }
        return .carried
    }
}

enum Tags {
    private static let regex = try! NSRegularExpression(pattern: "#[\\p{L}\\p{N}_]+")

    static func ranges(in text: String) -> [Range<String.Index>] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Range($0.range, in: text) }
    }

    /// Теги без «#», в нижнем регистре.
    static func of(_ text: String) -> [String] {
        ranges(in: text).map { String(text[$0].dropFirst()).lowercased() }
    }

    static let urlScheme = "zasechki-tag"

    static func url(for tag: String) -> URL? {
        var c = URLComponents()
        c.scheme = urlScheme
        c.host = "tag"
        c.queryItems = [URLQueryItem(name: "t", value: tag)]
        return c.url
    }

    static func tag(from url: URL) -> String? {
        guard url.scheme == urlScheme else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "t" }?.value
    }
}

enum RussianPlural {
    /// plural(3, "задача", "задачи", "задач") → «3 задачи»
    static func format(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10, mod100 = n % 100
        let word: String
        if mod10 == 1 && mod100 != 11 { word = one }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = few }
        else { word = many }
        return "\(n) \(word)"
    }
}

enum Store {
    static func addTask(_ text: String, today: Date, in context: ModelContext, existing: [TodoItem]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (existing.map(\.sortOrder).max() ?? 0) + 1
        context.insert(TodoItem(text: trimmed, day: today, sortOrder: order))
    }

    static func toggle(_ item: TodoItem, today: Date) {
        if item.isDone {
            item.completedDay = nil
            item.completedAt = nil
        } else {
            item.completedDay = today
            item.completedAt = Date()
        }
    }

    /// Задачу, которой ещё нет в истории, удаляем полностью; иначе — помечаем.
    static func delete(_ item: TodoItem, today: Date, in context: ModelContext) {
        if item.day >= today {
            context.delete(item)
        } else {
            item.deletedDay = today
        }
    }

    static func promote(_ thought: Thought, today: Date, in context: ModelContext, existing: [TodoItem]) {
        addTask(thought.text, today: today, in: context, existing: existing)
        context.delete(thought)
    }
}
