import SwiftUI
import PencilKit
import Combine
import CoreText

@MainActor
final class ActivityClock: ObservableObject {
    var lastInteraction = Date.distantPast
    var lastTick = Date()
    func touch() { lastInteraction = Date() }
}

struct PracticeTracking: ViewModifier {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) var scenePhase
    var subject: Subject
    @ObservedObject var clock: ActivityClock
    var enabled = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    func body(content: Content) -> some View {
        content.onAppear { clock.touch(); clock.lastTick = Date() }
            .onReceive(timer) { now in
                let gap = now.timeIntervalSince(clock.lastTick)
                clock.lastTick = now
                guard enabled, scenePhase == .active, gap < 2, now.timeIntervalSince(clock.lastInteraction) < 20 else { return }
                store.addSecond(subject)
            }
            .onChange(of: scenePhase) { _, _ in clock.lastInteraction = .distantPast; clock.lastTick = Date() }
            .onDisappear { store.save(); store.stopSpeaking() }
    }
}

struct PracticeMeter: View {
    @EnvironmentObject var store: AppStore
    let subject: Subject
    var body: some View {
        let seconds = store.today.seconds[subject.rawValue, default: 0]
        HStack(spacing: 16) {
            Label("\(seconds / 60):\(String(format: "%02d", seconds % 60))", systemImage: "clock").monospacedDigit().font(.subheadline.bold())
            ProgressView(value: min(Double(seconds) / Double(store.data.settings.targetPerSubject), 1)).frame(maxWidth: 180)
            Text(seconds >= store.data.settings.targetPerSubject ? "Target reached" : "\(store.data.settings.targetPerSubject / 60) min target").font(.caption).foregroundStyle(TrailTheme.muted)
        }.foregroundStyle(TrailTheme.mint).accessibilityElement(children: .combine)
    }
}

struct MathPracticeView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var clock = ActivityClock()
    @State private var fact: Fact?
    @State private var answer = ""
    @State private var feedback: Bool?
    @State private var start = Date()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Mission 01 · Recall", title: "Find your rhythm.", detail: "Accuracy first. Speed grows with practice.")
                PracticeMeter(subject: .math)
                if let fact {
                    Panel {
                        VStack(spacing: 26) {
                            Text(store.data.settings.operation.rawValue.uppercased()).font(.caption.bold()).tracking(3).foregroundStyle(TrailTheme.muted)
                            Text("\(fact.prompt) = ?").font(.system(size: 64, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).accessibilityIdentifier("math.prompt")
                            Text(answer.isEmpty ? "…" : answer).font(.system(size: 44, weight: .medium, design: .rounded)).frame(width: 230, height: 76).background(TrailTheme.background, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("math.answer")
                            if let feedback {
                                VStack(spacing: 10) {
                                    Label(feedback ? "That's it. Keep going." : "Let's work through it.", systemImage: feedback ? "checkmark.circle" : "lightbulb").font(.headline).foregroundStyle(feedback ? TrailTheme.mint : TrailTheme.gold)
                                    if !feedback {
                                        Text("\(fact.prompt) = \(fact.answer)").font(.title2.bold())
                                        Text(fact.hint).foregroundStyle(TrailTheme.muted).multilineTextAlignment(.center)
                                    }
                                    ActionButton(title: "Next fact") { clock.touch(); next() }.accessibilityIdentifier("math.next")
                                }
                            } else {
                                NumberPad(answer: $answer, touch: clock.touch)
                                ActionButton(title: "Check answer", icon: "checkmark") {
                                    clock.touch()
                                    let success = Int(answer) == fact.answer
                                    store.record(fact.id, success: success, seconds: Date().timeIntervalSince(start))
                                    feedback = success
                                }.disabled(answer.isEmpty).accessibilityIdentifier("math.check")
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
                Text("Short pauses are fine. The activity clock pauses after 20 seconds without input, or whenever the app is in the background.").font(.footnote).foregroundStyle(TrailTheme.muted)
            }.padding(32).frame(maxWidth: 1000)
        }.onAppear { next() }.modifier(PracticeTracking(subject: .math, clock: clock))
    }
    private func next() { fact = store.nextFact(excluding: fact?.id); answer = ""; feedback = nil; start = Date() }
}

struct NumberPad: View {
    @Binding var answer: String
    var touch: () -> Void
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "⌫"]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(keys, id: \.self) { key in
                Button {
                    touch()
                    if key == "Clear" { answer = "" }
                    else if key == "⌫" { if !answer.isEmpty { answer.removeLast() } }
                    else if answer.count < 3 { answer += key }
                } label: {
                    Text(key).font(key.count > 1 ? .headline : .title2.bold()).frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.white).background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityLabel(key == "⌫" ? "Delete last digit" : key).accessibilityIdentifier("key.\(key)")
            }
        }.frame(maxWidth: 360)
    }
}

struct SpellingPracticeView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var clock = ActivityClock()
    @State private var word = ""
    @State private var answer = ""
    @State private var studied = false
    @State private var feedback: Bool?
    @State private var start = Date()
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Mission 02 · Wordcraft", title: store.unit.title, detail: "Learn the pattern, then bring the word back from memory.")
                PracticeMeter(subject: .spelling)
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("THE PATTERN", systemImage: "lightbulb").font(.caption.bold()).foregroundStyle(TrailTheme.gold)
                        Text(store.unit.rule).font(.title3).lineSpacing(6)
                        Button("Read the pattern aloud", systemImage: "speaker.wave.2") { clock.touch(); store.speak(store.unit.rule) }
                    }
                }
                Panel {
                    VStack(spacing: 24) {
                        Button { clock.touch(); store.speak(word) } label: { Label("Hear the word", systemImage: "speaker.wave.2.fill").font(.title3.bold()).padding(18) }
                            .accessibilityIdentifier("spelling.hear")
                        if !studied {
                            Text(word).font(.system(size: 50, weight: .semibold, design: .rounded)).tracking(3)
                            Text("Look at its parts. Say the sounds. Notice the spelling pattern.").foregroundStyle(TrailTheme.muted).multilineTextAlignment(.center)
                            ActionButton(title: "Hide & spell") { clock.touch(); studied = true; start = Date(); focused = true; store.speak(word) }
                        } else {
                            TextField("Spell the word", text: $answer).font(.system(size: 34, weight: .medium, design: .rounded)).multilineTextAlignment(.center).padding(20).background(TrailTheme.background, in: RoundedRectangle(cornerRadius: 16))
                                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable).focused($focused)
                                .disabled(feedback != nil).onChange(of: answer) { _, _ in clock.touch() }.accessibilityIdentifier("spelling.answer")
                            if let feedback {
                                Label(feedback ? "You remembered it." : "Compare the letters, then try it again later.", systemImage: feedback ? "checkmark.circle" : "lightbulb").foregroundStyle(feedback ? TrailTheme.mint : TrailTheme.gold)
                                if !feedback { Text(word).font(.largeTitle.bold()).tracking(3) }
                                ActionButton(title: "Next word") { clock.touch(); next() }
                            } else {
                                ActionButton(title: "Check spelling", icon: "checkmark") { check() }.disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                Text("Use the keyboard for recall practice. Handwriting has its own mission, so letter formation does not change your spelling score.").font(.footnote).foregroundStyle(TrailTheme.muted)
            }.padding(32).frame(maxWidth: 1000)
        }.onAppear { next() }.modifier(PracticeTracking(subject: .spelling, clock: clock))
    }
    private func next() { word = store.nextWord(excluding: word); answer = ""; studied = false; feedback = nil; focused = false }
    private func check() {
        guard feedback == nil else { return }
        clock.touch(); focused = false
        let success = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == word
        store.record("word:\(word)", success: success, seconds: Date().timeIntervalSince(start)); feedback = success
    }
}

enum WritingStages {
    static let all = ["Print · trace & copy", "Words · trace & copy", "Proverbs · print", "Cursive · trace & copy", "Proverbs · cursive"]
}

struct WritingPracticeView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var clock = ActivityClock()
    @State private var drawing = PKDrawing()
    @State private var saved = false
    @State private var confirmClear = false
    @State private var letterIndex = 0
    private let families = ["c o a d g q", "i l t u j y", "r n m h b p", "v w x z k s f", "A B C D E F G", "H I J K L M N", "O P Q R S T U", "V W X Y Z"]
    private var stage: String { store.data.settings.writingStage }
    private var model: String {
        if stage.hasPrefix("Words") { return store.unit.words.prefix(4).joined(separator: "   ") }
        if stage.contains("Proverbs") { return store.verse.text }
        return families[letterIndex % families.count]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Mission 03 · The scribe", title: "Make your mark.", detail: "Trace the gray letters first. Then write them yourself on the blank lines below.")
                PracticeMeter(subject: .handwriting)
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(stage.contains("Proverbs") ? store.verse.reference : "YOUR MODEL").font(.caption.bold()).foregroundStyle(TrailTheme.gold)
                            Spacer()
                            Button("Hear it", systemImage: "speaker.wave.2") { clock.touch(); store.speak(model) }
                        }
                        Text(model).font(.custom(stage.localizedCaseInsensitiveContains("cursive") ? "SnellRoundhand" : "ChalkboardSE-Regular", size: 34)).lineSpacing(10)
                        if !stage.contains("Proverbs") && !stage.hasPrefix("Words") {
                            Button("Next letter group", systemImage: "arrow.right") { clock.touch(); letterIndex += 1 }
                        }
                    }
                }
                Label("TRACE FIRST · THEN WRITE YOUR OWN", systemImage: "pencil.and.outline").font(.caption.bold()).tracking(1).foregroundStyle(TrailTheme.gold)
                WritingBoard(drawing: $drawing, trace: model, cursive: stage.localizedCaseInsensitiveContains("cursive"), touch: { clock.touch(); saved = false })
                HStack(spacing: 18) {
                    ActionButton(title: saved ? "Sample saved" : "Save practice sample", icon: saved ? "checkmark" : "tray.and.arrow.down") {
                        clock.touch(); saved = store.saveSample(drawing, reference: stage.contains("Proverbs") ? store.verse.reference : "Practice model", text: model)
                    }.disabled(drawing.strokes.isEmpty || saved)
                    Button("New sheet", systemImage: "doc.badge.plus") { confirmClear = true }.font(.headline)
                }
                Text("Samples go to your parent for review. This app does not automatically grade your letter shapes. Use New sheet after saving to start a fresh sample.").font(.footnote).foregroundStyle(TrailTheme.muted)
            }.padding(32).frame(maxWidth: 1100)
        }
        .modifier(PracticeTracking(subject: .handwriting, clock: clock))
        .onAppear { drawing = store.drawing("practice-draft.pencil") }
        .onDisappear { if !drawing.strokes.isEmpty { _ = store.writeDrawing(drawing, name: "practice-draft.pencil") } }
        .onChange(of: drawing) { _, value in _ = store.writeDrawing(value, name: "practice-draft.pencil") }
        .confirmationDialog("Start a fresh sheet? Save this sample first if you want to keep it.", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Start fresh", role: .destructive) { clock.touch(); drawing = PKDrawing(); saved = false }
        }
    }
}

struct WritingBoard: View {
    @Binding var drawing: PKDrawing
    var trace: String? = nil
    var cursive = false
    var touch: () -> Void
    @State private var boardWidth: CGFloat = 600
    private var traceFont: UIFont {
        UIFont(name: cursive ? "SnellRoundhand" : "ChalkboardSE-Regular", size: 48) ?? .systemFont(ofSize: 48)
    }
    private var traceLines: [String] {
        guard let trace, !trace.isEmpty else { return [] }
        let text = NSAttributedString(string: trace, attributes: [.font: traceFont])
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var lines: [String] = [], offset = 0
        while offset < text.length {
            let count = max(1, CTTypesetterSuggestLineBreak(typesetter, offset, max(60, boardWidth - 60)))
            lines.append((trace as NSString).substring(with: NSRange(location: offset, length: min(count, text.length - offset))).trimmingCharacters(in: .whitespacesAndNewlines))
            offset += count
        }
        // Short letter groups get two tracing passes before independent writing.
        return lines.count == 1 ? lines + lines : lines
    }
    private var boardHeight: CGFloat { max(380, CGFloat(traceLines.count + max(2, traceLines.count)) * 74 + 28) }
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.97, green: 0.96, blue: 0.91)
            Canvas { context, size in
                for y in stride(from: 74.0, to: size.height, by: 74.0) {
                    var baseline = Path(); baseline.move(to: CGPoint(x: 20, y: y)); baseline.addLine(to: CGPoint(x: size.width - 20, y: y))
                    context.stroke(baseline, with: .color(.gray.opacity(0.50)), lineWidth: 1)
                    var midline = Path(); midline.move(to: CGPoint(x: 20, y: y - 28)); midline.addLine(to: CGPoint(x: size.width - 20, y: y - 28))
                    context.stroke(midline, with: .color(.gray.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                for (index, line) in traceLines.enumerated() {
                    let text = NSAttributedString(string: line, attributes: [.font: traceFont, .foregroundColor: UIColor.black.withAlphaComponent(0.45)])
                    let glyphs = CTLineCreateWithAttributedString(text)
                    context.withCGContext { cg in
                        cg.saveGState()
                        cg.translateBy(x: 30, y: CGFloat(index + 1) * 74)
                        cg.scaleBy(x: 1, y: -1)
                        cg.textPosition = .zero
                        CTLineDraw(glyphs, cg)
                        cg.restoreGState()
                    }
                }
            }.allowsHitTesting(false)
            PencilCanvas(drawing: $drawing, touch: touch)
        }.frame(height: boardHeight).clipShape(RoundedRectangle(cornerRadius: 18))
            .background(GeometryReader { geometry in
                Color.clear.onAppear { boardWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in boardWidth = width }
            })
            .overlay(alignment: .bottomTrailing) { Text("APPLE PENCIL · OR FINGER").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(.black.opacity(0.4)).padding(12).allowsHitTesting(false) }
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var touch: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.delegate = context.coordinator
        // The paper is always light, even though the surrounding app is dark.
        // Keep PencilKit from adapting dark ink into pale ink for dark mode.
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = .clear; view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.monoline, color: .black, width: 3.5)
        view.isScrollEnabled = false
        view.drawing = drawing
        return view
    }
    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if view.drawing != drawing { view.drawing = drawing }
    }
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { parent.drawing = canvasView.drawing; parent.touch() }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) { parent.touch() }
    }
}

struct DrawingPreview: View {
    @EnvironmentObject var store: AppStore
    var file: String
    var body: some View {
        let drawing = store.drawing(file)
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 600, height: 300) : drawing.bounds.insetBy(dx: -20, dy: -20)
        let preview: UIImage = {
            var image = UIImage()
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                image = drawing.image(from: bounds, scale: 2)
            }
            return image
        }()
        Image(uiImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity, minHeight: 140, maxHeight: 300).padding(16).background(Color(red: 0.97, green: 0.96, blue: 0.91), in: RoundedRectangle(cornerRadius: 14))
    }
}
