import SwiftUI

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
