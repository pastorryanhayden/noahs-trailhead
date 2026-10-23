import SwiftUI
import PencilKit

struct QuizView: View {
    @EnvironmentObject var store: AppStore
    @State private var answer = ""
    @State private var start = Date()
    @State private var drawing = PKDrawing()
    @State private var confirmSubmit = false
    @StateObject private var clock = ActivityClock()
    @FocusState private var focused: Bool
    private var question: QuizQuestion? { store.currentQuiz?.questions.first { $0.answer == nil } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Weekly checkpoint", title: "See how far you've come.", detail: "Work independently. Take a break if you need one. Your place is saved.")
                if let quiz = store.currentQuiz {
                    if quiz.submitted != nil {
                        QuizResults(quiz: quiz)
                    } else if let question {
                        Panel {
                            VStack(spacing: 24) {
                                Text("QUESTION \(quiz.questions.filter { $0.answer != nil }.count + 1) OF \(quiz.questions.count) · \(question.subject.title.uppercased())").font(.caption.bold()).tracking(2).foregroundStyle(TrailTheme.gold)
                                ProgressView(value: Double(quiz.questions.filter { $0.answer != nil }.count), total: Double(quiz.questions.count + 1))
                                if let fact = question.fact {
                                    Text("\(fact.prompt) = ?").font(.system(size: 58, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                                    Text(answer.isEmpty ? "…" : answer).font(.largeTitle).frame(width: 220, height: 70).background(TrailTheme.background, in: RoundedRectangle(cornerRadius: 12))
                                    NumberPad(answer: $answer, touch: clock.touch)
                                } else {
                                    Text("Listen, then spell the word.").font(.title2.bold())
                                    Button("Hear the word", systemImage: "speaker.wave.2.fill") { clock.touch(); store.speak(question.word ?? "") }.font(.title3).padding()
                                    TextField("Your spelling", text: $answer).font(.largeTitle).multilineTextAlignment(.center).padding().background(TrailTheme.background, in: RoundedRectangle(cornerRadius: 12))
                                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable).focused($focused)
                                }
                                ActionButton(title: "Save answer & continue") {
                                    clock.touch()
                                    store.answerQuiz(id: quiz.id, question: question.id, answer: answer.trimmingCharacters(in: .whitespacesAndNewlines), seconds: Date().timeIntervalSince(start))
                                    answer = ""; focused = false; start = Date(); store.stopSpeaking()
                                }.disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Text("Answers are checked after you finish the whole checkpoint.").font(.footnote).foregroundStyle(TrailTheme.muted)
                            }.frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                    } else {
                        Panel {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("FINAL MISSION · HANDWRITING", systemImage: "pencil.tip").font(.caption.bold()).foregroundStyle(TrailTheme.gold)
                                Text("Copy the passage in your current writing style. Your parent will review it.").foregroundStyle(TrailTheme.muted)
                                Text(quiz.passage).font(.title2).lineSpacing(8)
                                Text(quiz.reference).font(.caption).foregroundStyle(TrailTheme.muted)
                            }
                        }
                        WritingBoard(drawing: $drawing, touch: clock.touch)
                            .onAppear { drawing = store.drawing(quiz.writingFile) }
                            .onChange(of: drawing) { _, value in store.saveQuizInk(id: quiz.id, drawing: value) }
                        ActionButton(title: "Finish checkpoint", icon: "flag.checkered") { confirmSubmit = true }.disabled(drawing.strokes.isEmpty)
                    }
                } else {
                    Panel {
                        VStack(alignment: .leading, spacing: 20) {
                            Image(systemName: "flag.checkered").font(.system(size: 48)).foregroundStyle(TrailTheme.gold)
                            Text("One checkpoint. Three skills.").font(.title.bold())
                            Text("8 math facts · 5 spelling words · 1 writing sample").font(.title3)
                            Text("The spelling section includes a word with a pattern you've learned, even if you haven't practiced that word. Finish to earn 40 supplies, whatever your score.").foregroundStyle(TrailTheme.muted).lineSpacing(5)
                            Text("Aim for Friday. You can complete it another day when needed.").font(.footnote).foregroundStyle(TrailTheme.muted)
                            ActionButton(title: "Begin this week's checkpoint", icon: "flag.checkered") { clock.touch(); store.beginQuiz(); start = Date() }
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1050)
        }
        .modifier(PracticeTracking(subject: question?.subject ?? .handwriting, clock: clock, enabled: store.currentQuiz != nil && store.currentQuiz?.submitted == nil))
        .onChange(of: answer) { _, _ in clock.touch() }
        .onDisappear { store.stopSpeaking(); store.save() }
        .confirmationDialog("Submit your checkpoint? Your answers will be final.", isPresented: $confirmSubmit, titleVisibility: .visible) {
            Button("Submit checkpoint") { if let quiz = store.currentQuiz { store.submitQuiz(id: quiz.id, drawing: drawing) } }
        }
    }
}

struct QuizResults: View {
    var quiz: WeeklyQuiz
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 22) {
                Label("CHECKPOINT COMPLETE", systemImage: "checkmark.seal").font(.caption.bold()).foregroundStyle(TrailTheme.mint)
                Text(quiz.overall.map { "\($0)% overall" } ?? "Your handwriting is ready for review.").font(.title.bold())
                ViewThatFits {
                    HStack(spacing: 32) { scores }
                    VStack(alignment: .leading, spacing: 20) { scores }
                }
                Text("Each subject contributes equally to the overall grade. Math response time is tracked separately from accuracy.").font(.footnote).foregroundStyle(TrailTheme.muted)
                if !quiz.note.isEmpty {
                    Divider()
                    Text("FROM YOUR PARENT").font(.caption.bold()).foregroundStyle(TrailTheme.gold)
                    Text(quiz.note)
                }
                Text("40 supplies earned for finishing. Your review practice now includes the skills from this checkpoint.").foregroundStyle(TrailTheme.muted)
            }
        }
    }
    private var scores: some View {
        Group {
            score("Math", "\(quiz.score(.math))%")
            score("Spelling", "\(quiz.score(.spelling))%")
            score("Handwriting", quiz.handwritingScore.map { "\($0)%" } ?? "Pending")
        }
    }
    private func score(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(value).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(TrailTheme.mint); Text(title).foregroundStyle(TrailTheme.muted) }
    }
}
