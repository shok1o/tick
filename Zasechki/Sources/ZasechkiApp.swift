import SwiftUI
import SwiftData

@main
struct ZasechkiApp: App {
    /// Включить после подключения платного Apple Developer аккаунта
    /// и добавления возможности iCloud (CloudKit) в проект.
    static let iCloudSyncEnabled = false
    static let iCloudContainer = "iCloud.com.viktorrybnikov.zasechki"

    let container: ModelContainer = {
        let schema = Schema([TodoItem.self, Thought.self])
        #if DEBUG
        // Режим для снимков экрана: данные-образцы в памяти, настоящие задачи не трогаются.
        if Demo.isOn {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let c = try! ModelContainer(for: schema, configurations: memory)
            Demo.seed(c.mainContext)
            return c
        }
        #endif
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: iCloudSyncEnabled ? .private(iCloudContainer) : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Не удалось открыть хранилище: \(error)")
        }
    }()

    @StateObject private var clock = DayClock()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(clock)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 440, height: 680)
        .windowResizability(.contentMinSize)
        #endif
    }
}

/// Текущий день; обновляется в полночь и при возвращении в приложение.
@MainActor
final class DayClock: ObservableObject {
    @Published private(set) var today: Date = Day.start(of: Date())
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let now = Day.start(of: Date())
        if now != today { today = now }
    }
}
