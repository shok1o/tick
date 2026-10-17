import SwiftUI

/// Экран загрузки: черта рисуется снизу вверх, сверху падает и пружинит точка,
/// внизу проявляется подпись автора — и всё растворяется в списке дел.
struct SplashView: View {
    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var stroke: CGFloat = 0
    @State private var dotScale: CGFloat = 0
    @State private var dotDrop: CGFloat = -70
    @State private var creditOpacity: Double = 0
    @State private var landed = false

    // Пропорции иконки 100×100, увеличенные в 1,4 раза.
    private let lineHeight: CGFloat = 62
    private let lineWidth: CGFloat = 14
    private let dotSize: CGFloat = 14
    private let dotX: CGFloat = 31
    private let dotY: CGFloat = -28

    var body: some View {
        ZStack {
            p.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    RisingLine()
                        .trim(from: 0, to: stroke)
                        .stroke(p.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: lineWidth, height: lineHeight)

                    Circle()
                        .fill(p.dot)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(dotScale)
                        .offset(x: dotX, y: dotY + dotDrop)
                }
                .frame(width: 120, height: 120)
                .offset(x: -dotX / 2 + dotSize / 4)   // оптический центр знака

            }


            VStack {
                Spacer()
                Text("made by shok1o")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(p.inkSoft.opacity(0.7))
                    .opacity(creditOpacity)
                    .padding(.bottom, 28)
            }
        }
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        #endif
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            stroke = 1; dotScale = 1; dotDrop = 0; creditOpacity = 1
            try? await Task.sleep(for: .milliseconds(500))
            onFinish()
            return
        }

        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.easeOut(duration: 0.45)) { stroke = 1 }

        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.48)) {
            dotScale = 1
            dotDrop = 0
        }
        try? await Task.sleep(for: .milliseconds(160))
        landed = true

        withAnimation(.easeOut(duration: 0.5)) { creditOpacity = 1 }

        if Demo.holdSplash { return }
        try? await Task.sleep(for: .milliseconds(750))
        onFinish()
    }
}

/// Вертикальная линия, которая рисуется снизу вверх.
private struct RisingLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}
