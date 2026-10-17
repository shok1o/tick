import SwiftUI

/// Тема оформления, выбирается в настройках.
enum AppTheme: String, CaseIterable, Identifiable {
    case auto, light, dark, pastel
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Как в системе"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        case .pastel: return "Пастельная"
        }
    }

    var palette: Palette {
        switch self {
        case .auto: return .auto
        case .light: return .light
        case .dark: return .dark
        case .pastel: return .pastel
        }
    }

    /// nil — следовать системе.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light, .pastel: return .light
        case .dark: return .dark
        }
    }
}

/// Палитра повторяет иконку: бумага, чернила и один акцент.
struct Palette {
    var paper: Color
    var ink: Color
    var inkSoft: Color
    var inkFaint: Color
    var dot: Color
    /// Для удаления — приглушённый красный, читается с белым текстом.
    var danger: Color

    static let light = Palette(paper: Color(hex: 0xF5F1E8), ink: Color(hex: 0x1C1C1E),
                               inkSoft: Color(hex: 0x8A867D), inkFaint: Color(hex: 0xC9C3B6),
                               dot: Color(hex: 0xE8590C), danger: Color(hex: 0xC4473D))
    static let dark = Palette(paper: Color(hex: 0x141413), ink: Color(hex: 0xF2EEE6),
                              inkSoft: Color(hex: 0x8E8A82), inkFaint: Color(hex: 0x3A3833),
                              dot: Color(hex: 0xF2783A), danger: Color(hex: 0xC9534A))
    /// Лавандовая бумага, сливовые чернила и персиковый акцент.
    static let pastel = Palette(paper: Color(hex: 0xF4EFF7), ink: Color(hex: 0x4A4060),
                                inkSoft: Color(hex: 0x9F95B3), inkFaint: Color(hex: 0xD8CEE6),
                                dot: Color(hex: 0xE8907E), danger: Color(hex: 0xC7607A))
    static let auto = Palette(paper: Color(light: 0xF5F1E8, dark: 0x141413),
                              ink: Color(light: 0x1C1C1E, dark: 0xF2EEE6),
                              inkSoft: Color(light: 0x8A867D, dark: 0x8E8A82),
                              inkFaint: Color(light: 0xC9C3B6, dark: 0x3A3833),
                              dot: Color(light: 0xE8590C, dark: 0xF2783A),
                              danger: Color(light: 0xC4473D, dark: 0xC9534A))
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.auto
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        #if os(iOS)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
        #endif
    }
}

#if os(iOS)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif

extension Font {
    /// Всё приложение набрано моноширинным шрифтом — как на пишущей машинке.
    static let display = Font.system(size: 38, weight: .bold, design: .monospaced)
    static let screenTitle = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let task = Font.system(size: 16, design: .monospaced)
    static let meta = Font.system(size: 13, design: .monospaced)
    static let label = Font.system(size: 12, weight: .medium, design: .monospaced)
}

/// Общий вид списков: фон-бумага, без системных разделителей и подложек.
struct PaperList: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(p.paper)
            #if os(iOS)
            .toolbarBackground(p.paper, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // Заголовок уже есть крупно в самом экране — в панели он лишний.
            .toolbar { ToolbarItem(placement: .principal) { Text("") } }
            #endif
    }
}

struct PaperRow: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content
            .listRowBackground(p.paper)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
    }
}

extension View {
    func paperList() -> some View { modifier(PaperList()) }
    func paperRow() -> some View { modifier(PaperRow()) }
}

/// Заголовок экрана: крупное слово с засечками и строка-пояснение.
struct ScreenHeader: View {
    @Environment(\.palette) private var p
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(p.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.meta)
                    .foregroundStyle(p.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .paperRow()
    }
}

/// Подпись раздела: мелкие разреженные заглавные.
struct SectionLabel: View {
    @Environment(\.palette) private var p
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.label)
            .tracking(1.4)
            .foregroundStyle(p.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
            .padding(.bottom, 6)
            .paperRow()
    }
}
