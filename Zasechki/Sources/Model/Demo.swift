import Foundation
import SwiftData

/// Данные-образцы для снимков экрана (только в отладочной сборке, по флагу -demo).
enum Demo {
    static var isOn: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-demo")
        #else
        return false
        #endif
    }

    /// -demoScreen thoughts — открыть вкладку «Мысли».
    static var startOnThoughts: Bool {
        guard isOn, let i = CommandLine.arguments.firstIndex(of: "-demoScreen"),
              i + 1 < CommandLine.arguments.count else { return false }
        return CommandLine.arguments[i + 1] == "thoughts"
    }

    /// -holdSplash — остановить заставку на последнем кадре (для снимка).
    static var holdSplash: Bool { isOn && CommandLine.arguments.contains("-holdSplash") }

    /// В режиме снимков заставку пропускаем, если не просили её показать.
    static var skipSplash: Bool {
        isOn && !CommandLine.arguments.contains("-holdSplash") && !CommandLine.arguments.contains("-splash")
    }

    /// -demoScreen thoughts|history|appearance — открыть сразу нужный экран.
    static var initialPath: [Route] {
        guard isOn, let i = CommandLine.arguments.firstIndex(of: "-demoScreen"),
              i + 1 < CommandLine.arguments.count else { return [] }
        switch CommandLine.arguments[i + 1] {
        case "history": return [.history]
        case "appearance": return [.appearance]
        case "tag": return [.tag("дом")]
        default: return []
        }
    }

    static func seed(_ context: ModelContext) {
        let today = Day.start(of: Date())
        func task(_ text: String, daysAgo: Int, order: Double, doneDaysAgo: Int? = nil) {
            let item = TodoItem(text: text, day: Day.adding(-daysAgo, to: today), sortOrder: order)
            if let d = doneDaysAgo {
                item.completedDay = Day.adding(-d, to: today)
                item.completedAt = Date().addingTimeInterval(Double(-d * 86400) + order)
            }
            context.insert(item)
        }
        task("Позвонить маме", daysAgo: 0, order: 1)
        task("Купить продукты #дом", daysAgo: 2, order: 2)
        task("Дописать главу курсовой #учёба", daysAgo: 7, order: 3)
        task("Записаться к стоматологу", daysAgo: 1, order: 4)
        task("Пробежка 5 км", daysAgo: 0, order: 5, doneDaysAgo: 0)
        task("Оплатить интернет #дом", daysAgo: 0, order: 6, doneDaysAgo: 0)
        task("Вынести мусор #дом", daysAgo: 1, order: 7, doneDaysAgo: 1)
        task("Прочитать статью", daysAgo: 2, order: 8, doneDaysAgo: 2)
        task("Сдать книги в библиотеку", daysAgo: 3, order: 9, doneDaysAgo: 2)
        context.insert(Thought(text: "Сделать себе полку для книг"))
        context.insert(Thought(text: "Выучить пару аккордов на гитаре #хобби"))
        context.insert(Thought(text: "Поездка в Карелию летом?"))
    }
}
