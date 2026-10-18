import SwiftUI
import SwiftData

/// Выбор темы: у каждой — миниатюра иконки в её цветах.
struct AppearanceView: View {
    @Environment(\.palette) private var p
    @AppStorage("theme") private var theme: AppTheme = .auto

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Оформление")
                        .font(.screenTitle)
                        .foregroundStyle(p.ink)
                    Text("Тема меняется сразу и запоминается на этом устройстве")
                        .font(.meta)
                        .foregroundStyle(p.inkSoft)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AppTheme.allCases) { option in
                        ThemeCard(option: option, selected: option == theme) {
                            theme = option
                        }
                    }
                }

                BackupSection()
                    .padding(.top, 40)

                Credits()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(p.paper)
        #if os(iOS)
        .toolbarBackground(p.paper, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
        #endif
        .navigationTitle("Оформление")
    }
}

private struct ThemeCard: View {
    @Environment(\.palette) private var p
    let option: AppTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                preview
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text(option.title)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(p.ink)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? p.dot : p.inkFaint)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? p.dot : p.inkFaint.opacity(0.7), lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Миниатюра: черта и точка, как на иконке.
    private var preview: some View {
        swatches
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.inkFaint.opacity(0.6), lineWidth: 1))
    }

    @ViewBuilder private var swatches: some View {
        if option == .auto {
            HStack(spacing: 0) {
                Swatch(palette: .light)
                Swatch(palette: .dark)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Swatch(palette: option.palette)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct Swatch: View {
    let palette: Palette

    var body: some View {
        ZStack {
            palette.paper
            Capsule().fill(palette.ink).frame(width: 6, height: 40)
            Circle().fill(palette.dot).frame(width: 9, height: 9).offset(x: 16, y: -18)
        }
    }
}

/// Подпись внизу: маленький знак, версия и автор.
private struct Credits: View {
    @Environment(\.palette) private var p

    /// Репозиторий с исходным кодом Tick.
    static let repository = URL(string: "https://github.com/shok1o/tick")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Capsule().fill(p.ink).frame(width: 3, height: 18)
                Circle().fill(p.dot).frame(width: 4, height: 4).offset(x: 7, y: -8)
            }
            .frame(width: 20, height: 20)
            Text("Tick \(version)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(p.ink)
            Link(destination: Self.repository) {
                HStack(spacing: 4) {
                    Text("made by shok1o")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(p.inkSoft)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Открыть репозиторий Tick на GitHub")
        }
    }
}

/// Резервная копия: сохранить всё в файл и загрузить обратно (или на другом устройстве).
private struct BackupSection: View {
    @Environment(\.palette) private var p
    @Environment(\.modelContext) private var context
    @Query private var items: [TodoItem]
    @Query private var thoughts: [Thought]

    @State private var exportDocument: BackupDocument?
    @State private var importing = false
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("РЕЗЕРВНАЯ КОПИЯ")
                .font(.label)
                .tracking(2)
                .foregroundStyle(p.inkSoft)
            Text("Все задачи, история и заметки в одном файле. Через него же можно перенести Tick с iPhone на Mac и обратно")
                .font(.meta)
                .foregroundStyle(p.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            row("Сохранить в файл", icon: "square.and.arrow.up") { export() }
            row("Загрузить из файла", icon: "square.and.arrow.down") { importing = true }

            if let status {
                Text(status)
                    .font(.meta)
                    .foregroundStyle(p.dot)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: "Tick \(Date().formatted(.iso8601.year().month().day()))") { result in
            if case .success = result { show("Копия сохранена") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): restore(from: url)
            case .failure: show("Не удалось открыть файл")
            }
        }
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(p.ink)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Capsule().fill(p.inkFaint.opacity(0.3)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try Backup(items: items, thoughts: thoughts).encoded())
        } catch {
            show("Не удалось подготовить копию")
        }
    }

    private func restore(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let backup = try Backup.decode(Data(contentsOf: url))
            let added = backup.merge(into: context, items: items, thoughts: thoughts)
            if added.tasks + added.notes == 0 {
                show("Всё из этого файла уже есть в Tick")
            } else {
                show("Добавлено: " + RussianPlural.format(added.tasks, "задача", "задачи", "задач")
                     + " и " + RussianPlural.format(added.notes, "заметка", "заметки", "заметок"))
            }
        } catch {
            show("Это не похоже на копию Tick")
        }
    }

    private func show(_ text: String) {
        withAnimation { status = text }
    }
}
