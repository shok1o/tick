import Foundation
import SwiftData

// Все поля имеют значения по умолчанию и нет уникальных ограничений —
// это требование CloudKit, чтобы синхронизацию можно было включить позже.

/// Задача. Хранит не «состояние на сегодня», а даты событий,
/// поэтому перенос на следующий день и история вычисляются,
/// а не записываются — две синхронизируемые копии не могут разойтись.
@Model
final class TodoItem {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    /// День, на который задачу добавили (начало суток).
    var day: Date = Date()
    /// День выполнения; nil — задача открыта.
    var completedDay: Date?
    var completedAt: Date?
    /// День удаления; до этого дня задача остаётся в истории.
    var deletedDay: Date?
    var sortOrder: Double = 0

    init(text: String, day: Date, sortOrder: Double) {
        self.text = text
        self.day = day
        self.sortOrder = sortOrder
    }

    var isDone: Bool { completedDay != nil }
}

/// Мысль — то, что ещё не стало задачей.
@Model
final class Thought {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()

    init(text: String) {
        self.text = text
    }
}
