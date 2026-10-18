import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Резервная копия всех задач и заметок в одном JSON-файле.
/// Подходит и для страховки, и для переноса между iPhone и Mac.
struct Backup: Codable {
    struct Task: Codable {
        var id: UUID
        var text: String
        var createdAt: Date
        var day: Date
        var completedDay: Date?
        var completedAt: Date?
        var deletedDay: Date?
        var sortOrder: Double
    }

    struct Note: Codable {
        var id: UUID
        var text: String
        var createdAt: Date
    }

    var app = "Tick"
    var version = 1
    var exportedAt = Date()
    var tasks: [Task]
    var notes: [Note]

    init(items: [TodoItem], thoughts: [Thought]) {
        tasks = items.map {
            Task(id: $0.id, text: $0.text, createdAt: $0.createdAt, day: $0.day,
                 completedDay: $0.completedDay, completedAt: $0.completedAt,
                 deletedDay: $0.deletedDay, sortOrder: $0.sortOrder)
        }
        notes = thoughts.map { Note(id: $0.id, text: $0.text, createdAt: $0.createdAt) }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data)
    }

    /// Добавляет из копии то, чего ещё нет. Существующие записи не трогаем,
    /// поэтому импорт можно повторять без дублей.
    func merge(into context: ModelContext, items: [TodoItem], thoughts: [Thought]) -> (tasks: Int, notes: Int) {
        let knownTasks = Set(items.map(\.id))
        let knownNotes = Set(thoughts.map(\.id))
        var addedTasks = 0, addedNotes = 0
        for t in tasks where !knownTasks.contains(t.id) {
            let item = TodoItem(text: t.text, day: t.day, sortOrder: t.sortOrder)
            item.id = t.id
            item.createdAt = t.createdAt
            item.completedDay = t.completedDay
            item.completedAt = t.completedAt
            item.deletedDay = t.deletedDay
            context.insert(item)
            addedTasks += 1
        }
        for n in notes where !knownNotes.contains(n.id) {
            let thought = Thought(text: n.text)
            thought.id = n.id
            thought.createdAt = n.createdAt
            context.insert(thought)
            addedNotes += 1
        }
        return (addedTasks, addedNotes)
    }
}

/// Обёртка для системного окна сохранения файла.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
