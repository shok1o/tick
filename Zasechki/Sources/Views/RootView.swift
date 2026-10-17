import SwiftUI

enum Route: Hashable {
    case history
    case day(Date)
    case tag(String)
    case appearance
}

struct RootView: View {
    @AppStorage("theme") private var theme: AppTheme = .auto
    @EnvironmentObject private var clock: DayClock
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = Demo.initialPath
    @State private var showSplash = !Demo.skipSplash

    var body: some View {
        ZStack {
            main
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
                .zIndex(1)
            }
        }
        .environment(\.palette, theme.palette)
        .tint(theme.palette.ink)
        .background(theme.palette.paper)
        .preferredColorScheme(theme.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: theme)
    }

    private var main: some View {
        NavigationStack(path: $path) {
            TodayView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history: HistoryView()
                    case .day(let date): HistoryDayView(date: date)
                    case .tag(let tag): TagView(tag: tag)
                    case .appearance: AppearanceView()
                    }
                }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let tag = Tags.tag(from: url) {
                if path.last != .tag(tag) { path.append(.tag(tag)) }
                return .handled
            }
            return .systemAction
        })
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clock.refresh() }
        }
    }
}
