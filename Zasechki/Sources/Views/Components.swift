import SwiftUI

/// Засечки: по четыре вертикальные черты, пятая перечёркивает группу.
struct TallyMarks: View {
    @Environment(\.palette) private var p
    let count: Int
    private let lineHeight: CGFloat = 12
    private let step: CGFloat = 4
    private let groupGap: CGFloat = 6

    var body: some View {
        if count > 0 {
            let shown = min(count, 20)
            Canvas { ctx, size in
                let color = p.inkSoft
                let style = StrokeStyle(lineWidth: 1.6, lineCap: .round)
                var x: CGFloat = 3
                var remaining = shown
                while remaining > 0 {
                    let inGroup = min(remaining, 5)
                    let groupStart = x
                    for i in 0..<min(inGroup, 4) {
                        var line = Path()
                        let lx = groupStart + CGFloat(i) * step
                        line.move(to: CGPoint(x: lx, y: 0))
                        line.addLine(to: CGPoint(x: lx, y: lineHeight))
                        ctx.stroke(line, with: .color(color), style: style)
                    }
                    if inGroup == 5 {
                        var line = Path()
                        line.move(to: CGPoint(x: groupStart - 2, y: lineHeight - 2))
                        line.addLine(to: CGPoint(x: groupStart + 3 * step + 2, y: 2))
                        ctx.stroke(line, with: .color(color), style: style)
                    }
                    x = groupStart + 4 * step + groupGap
                    remaining -= inGroup
                }
            }
            .frame(width: Self.width(for: shown, step: step, gap: groupGap), height: lineHeight)
            .overlay(alignment: .trailing) {
                if count > 20 {
                    Text("+\(count - 20)").font(.caption2).foregroundStyle(p.inkSoft).offset(x: 22)
                }
            }
            .accessibilityLabel("Перенесено " + RussianPlural.format(count, "раз", "раза", "раз"))
        }
    }

    private static func width(for n: Int, step: CGFloat, gap: CGFloat) -> CGFloat {
        let groups = CGFloat((n + 4) / 5)
        return groups * (4 * step + gap) - gap - step + 6
    }
}

/// Кружок-отметка: при выполнении заливается чернилами, и галочка прорисовывается штрихом.
struct CheckCircle: View {
    @Environment(\.palette) private var p
    let done: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(p.inkFaint, lineWidth: 1.5)
                .opacity(done ? 0 : 1)
            Circle()
                .fill(p.ink)
                .scaleEffect(done ? 1 : 0.3)
                .opacity(done ? 1 : 0)
            CheckShape()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(p.paper, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 8)
                .animation(.easeOut(duration: 0.22).delay(done ? 0.08 : 0), value: done)
        }
        .frame(width: 22, height: 22)
        .contentShape(Circle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Текст задачи с кликабельными #тегами.
struct TaggedText: View {
    @Environment(\.palette) private var p
    let text: String
    var done: Bool = false

    var body: some View {
        Text(attributed)
            .font(.task)
            .foregroundStyle(done ? p.inkSoft : p.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        for range in Tags.ranges(in: text) {
            let tag = String(text[range].dropFirst()).lowercased()
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].link = Tags.url(for: tag)
            result[lower..<upper].foregroundColor = done ? p.inkSoft : p.dot
        }
        if done {
            result.strikethroughStyle = Text.LineStyle(pattern: .solid, color: p.inkSoft)
        }
        return result
    }
}

/// Строка задачи. `onToggle == nil` — только для чтения (история).
struct TaskRow: View {
    @Environment(\.palette) private var p
    let text: String
    let done: Bool
    var marks: Int = 0
    var trailingNote: String?
    var onToggle: (() -> Void)?
    /// Задача переносится слишком долго — предложить её отпустить.
    var onLetGo: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let onToggle {
                    Button(action: onToggle) { CheckCircle(done: done) }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: done)
                        #endif
                        .accessibilityLabel(done ? "Отметить невыполненной" : "Выполнить")
                } else {
                    CheckCircle(done: done)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                TaggedText(text: text, done: done)
                if let onLetGo, !done {
                    Button(action: onLetGo) {
                        Text(RussianPlural.format(marks, "перенос", "переноса", "переносов") + " · отпустить?")
                            .font(.meta)
                            .foregroundStyle(p.dot)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if marks > 0 {
                TallyMarks(count: marks)
                    .padding(.top, 5)
            }
            if let trailingNote {
                Text(trailingNote).font(.meta).foregroundStyle(p.inkSoft).padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { RowSeparator() }
        .contentShape(Rectangle())
        .paperRow()
    }
}

/// Тонкий разделитель строк, начинается от текста, а не от кружка.
struct RowSeparator: View {
    @Environment(\.palette) private var p

    var body: some View {
        Rectangle()
            .fill(p.inkFaint.opacity(0.45))
            .frame(height: 0.5)
            .padding(.leading, 36)
    }
}

/// Строка ввода внизу: поле-капсула и круглая кнопка «+».
struct InputBar: View {
    @Environment(\.palette) private var p
    let placeholder: String
    let onSubmit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                // Маленькая черта, как на иконке: загорается оранжевым, когда поле активно.
                Capsule()
                    .fill(focused ? p.dot : p.inkFaint)
                    .frame(width: 3, height: 18)
                    .animation(.easeOut(duration: 0.2), value: focused)
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(p.inkSoft))
                    .textFieldStyle(.plain)
                    .font(.task)
                    .foregroundStyle(p.ink)
                    .focused($focused)
                    .onSubmit(submit)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(Capsule().fill(p.inkFaint.opacity(0.3)))
            .contentShape(Capsule())
            .onTapGesture { focused = true }

            Button {
                if isEmpty { focused = true } else { submit() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isEmpty ? p.ink : p.paper)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(isEmpty ? p.inkFaint.opacity(0.3) : p.ink))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(.snappy(duration: 0.2), value: isEmpty)
            .accessibilityLabel("Добавить")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(p.paper)
    }

    private func submit() {
        guard !isEmpty else { return }
        onSubmit(text)
        text = ""
        focused = true
    }
}

struct EmptyHint: View {
    @Environment(\.palette) private var p
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule().fill(p.inkFaint).frame(width: 3, height: 22)
                .padding(.bottom, 6)
            Text(title).font(.system(size: 17, weight: .medium, design: .monospaced)).foregroundStyle(p.ink)
            Text(subtitle).font(.meta).foregroundStyle(p.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
        .paperRow()
    }
}
