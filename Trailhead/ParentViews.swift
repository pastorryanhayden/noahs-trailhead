import SwiftUI
import UniformTypeIdentifiers

enum ParentPage: String, CaseIterable, Identifiable {
    case overview = "Overview", plan = "Learning plan", quizzes = "Quiz review", samples = "Writing portfolio"
    var id: String { rawValue }
    var icon: String { switch self { case .overview: "chart.bar.xaxis"; case .plan: "slider.horizontal.3"; case .quizzes: "checklist"; case .samples: "doc.richtext" } }
}

struct ParentShell: View {
    let signOut: () -> Void
    @State private var page = ParentPage.overview
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 24) {
                Brand()
                Label("PARENT PROFILE", systemImage: "lock.shield").font(.caption.bold()).foregroundStyle(TrailTheme.gold).padding(.horizontal, 24)
                ForEach(ParentPage.allCases) { item in
                    Button { page = item } label: {
                        Label(item.rawValue, systemImage: item.icon).font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(16).foregroundStyle(page == item ? TrailTheme.mint : .white).background(page == item ? TrailTheme.mint.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).padding(.horizontal, 12)
                }
                Spacer()
                Text("Noah's progress belongs to your family. All records are stored on this iPad.").font(.footnote).foregroundStyle(TrailTheme.muted).padding(.horizontal, 24)
                Button("Lock & switch profile", systemImage: "lock") { signOut() }.padding(24)
            }.padding(.top, 24).background(TrailTheme.background).navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 290)
        } detail: {
            Group {
                switch page {
                case .overview: ParentOverview()
                case .plan: LearningPlanView()
                case .quizzes: QuizReviewList()
                case .samples: WritingPortfolio()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(TrailTheme.background)
        }.navigationSplitViewStyle(.balanced)
    }
}

struct ParentOverview: View {
    @EnvironmentObject var store: AppStore
    @State private var export = false
    private var recentDays: [PracticeDay] {
        (0..<7).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key = DateKeys.day(date)
            return store.data.days[key] ?? PracticeDay(id: key)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Parent dashboard", title: "Steady progress, made visible.", detail: "See the practice behind the scores, then choose what comes next.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 16) {
                    metric("Today", "\(store.today.total / 60) min", "Active practice")
                    metric("Math", "\(store.masteredFacts)", "Facts recalled correctly 3×")
                    metric("Portfolio", "\(store.data.samples.count)", "Saved writing samples")
                    metric("To review", "\(store.data.quizzes.filter { $0.submitted != nil && $0.rubric == nil }.count)", "Handwriting quizzes")
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("The last seven days").font(.title3.bold())
                        ForEach(recentDays) { day in
                            HStack(spacing: 14) {
                                Text(String(day.id.suffix(5))).font(.system(.caption, design: .monospaced)).frame(width: 50, alignment: .leading)
                                ProgressView(value: min(Double(day.total) / Double(store.data.settings.targetPerSubject * 3), 1)).tint(TrailTheme.mint)
                                Text("\(day.total / 60)m").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                                Image(systemName: day.completionRewarded ? "checkmark.circle.fill" : "circle").foregroundStyle(day.completionRewarded ? TrailTheme.mint : TrailTheme.muted)
                            }
                        }
                        Text("Empty days stay empty; they do not reduce earned rewards. The chart uses the current daily target.").font(.footnote).foregroundStyle(TrailTheme.muted)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Facts needing attention").font(.title3.bold())
                        let facts = Fact.catalog(store.data.settings.operation).filter { let s = store.data.skills[$0.id]; return s != nil && !(s?.mastered ?? false) }.sorted { (store.data.skills[$0.id]?.streak ?? 0) < (store.data.skills[$1.id]?.streak ?? 0) }
                        if facts.isEmpty { Text("After Noah practices, his developing facts will appear here.").foregroundStyle(TrailTheme.muted) }
                        ForEach(Array(facts.prefix(8))) { fact in
                            let skill = store.data.skills[fact.id]!
                            HStack {
                                Text(fact.prompt).font(.headline.monospacedDigit())
                                Spacer()
                                Text("\(skill.correct)/\(skill.attempts) correct · last \(skill.latency, specifier: "%.1f")s").foregroundStyle(TrailTheme.muted).font(.subheadline)
                            }
                        }
                        Text("Recall mastery = 3 consecutive correct answers. Automaticity = 3 consecutive correct answers within 3 seconds. These are app indicators you can interpret alongside his work.").font(.footnote).foregroundStyle(TrailTheme.muted)
                    }
                }
                Button("Export progress report", systemImage: "square.and.arrow.up") { export = true }
                Text("Active quiz work contributes to each subject's daily target. Spelling placement and handwriting progression are parent-directed in this first version.").font(.footnote).foregroundStyle(TrailTheme.muted)
            }.padding(32).frame(maxWidth: 1100)
        }.fileExporter(isPresented: $export, document: ProgressReport(data: store.data), contentType: .commaSeparatedText, defaultFilename: "Noah-progress-\(DateKeys.day())") { result in
            if case .failure(let error) = result { store.error = error.localizedDescription }
        }
    }
    private func metric(_ name: String, _ value: String, _ caption: String) -> some View {
        Panel { VStack(alignment: .leading, spacing: 10) { Text(name).foregroundStyle(TrailTheme.muted); Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(TrailTheme.mint); Text(caption).font(.caption).foregroundStyle(TrailTheme.muted) } }
    }
}

struct LearningPlanView: View {
    @EnvironmentObject var store: AppStore
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinMessage = ""
    @State private var customLesson = false
    private func binding<T>(_ key: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { store.data.settings[keyPath: key] }, set: { value in store.settings { $0[keyPath: key] = value } })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Learning plan", title: "You set the direction.", detail: "Change the challenge without changing Noah's earned progress. Changes save immediately.")
                Panel {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Daily rhythm").font(.title2.bold())
                        Stepper("Weekday practice: \(store.data.settings.dailyMinutes) minutes", value: binding(\.dailyMinutes), in: 30...60, step: 3)
                        Toggle("Recovery mode · 10 minutes total", isOn: binding(\.recoveryMode))
                        Text("The target is divided equally among the three subjects. Recovery mode stays on until you turn it off. Missed days never become zeros.").foregroundStyle(TrailTheme.muted).font(.footnote)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Math focus").font(.title2.bold())
                        Picker("Operation", selection: binding(\.operation)) { ForEach(Operation.allCases) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
                        Text("Facts use operands 0–12. Subtraction stays nonnegative; division uses exact quotients and never divides by zero. Previously practiced facts in this operation return for review.").font(.footnote).foregroundStyle(TrailTheme.muted)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Spelling placement").font(.title2.bold())
                        if store.data.settings.customSpelling != nil {
                            Label("Your lesson · \(store.unit.title)", systemImage: "person.crop.circle.badge.checkmark").foregroundStyle(TrailTheme.mint)
                            Button("Return to starter library") { store.settings { $0.customSpelling = nil } }
                        } else {
                            Picker("Lesson", selection: binding(\.spellingUnit)) { ForEach(Curriculum.spelling) { Text("Grade \($0.level) · \($0.title)").tag($0.id) } }
                        }
                        Button(store.data.settings.customSpelling == nil ? "Create my own spelling lesson" : "Edit my spelling lesson", systemImage: "square.and.pencil") { customLesson = true }
                        Text(store.unit.rule).foregroundStyle(TrailTheme.muted)
                        Text(store.unit.words.joined(separator: " · ")).font(.headline)
                        Text("Eight starter lessons cover selected patterns across grades 3–6. This is an initial content library, not a complete grade-level curriculum. Advance after reviewing independent recall and transfer.").font(.footnote).foregroundStyle(TrailTheme.gold)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Handwriting progression").font(.title2.bold())
                        Picker("Stage", selection: binding(\.writingStage)) { ForEach(WritingStages.all, id: \.self) { Text($0).tag($0) } }
                        Picker("Passage", selection: binding(\.verseIndex)) { ForEach(Curriculum.verses.indices, id: \.self) { Text(Curriculum.verses[$0].reference).tag($0) } }
                        Text(store.verse.text).font(.title3).lineSpacing(6)
                        Text("Cursive models use a system script font. Stroke-order animations and automatic letter scoring are not included. Choose the stage using his saved samples and your judgment.").font(.footnote).foregroundStyle(TrailTheme.muted)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Change parent PIN").font(.title2.bold())
                        SecureField("New six-digit PIN", text: $newPIN).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        SecureField("Confirm new PIN", text: $confirmPIN).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        Button("Save new PIN") {
                            guard newPIN == confirmPIN else { pinMessage = "The PINs do not match."; return }
                            if ParentPIN.set(newPIN) { pinMessage = "PIN updated."; newPIN = ""; confirmPIN = "" } else { pinMessage = "Use exactly six digits." }
                        }.disabled(newPIN.isEmpty)
                        if !pinMessage.isEmpty { Text(pinMessage).foregroundStyle(TrailTheme.gold) }
                    }
                }
            }.padding(32).frame(maxWidth: 1100)
        }.sheet(isPresented: $customLesson) { CustomLessonEditor() }
    }
}

struct CustomLessonEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var rule = ""
    @State private var words = ""
    @State private var transfer = ""
    private var lesson: CustomSpellingLesson {
        let entries = words.components(separatedBy: CharacterSet(charactersIn: ",\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        return CustomSpellingLesson(title: title.trimmingCharacters(in: .whitespacesAndNewlines), rule: rule.trimmingCharacters(in: .whitespacesAndNewlines), words: entries, transfer: transfer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("The lesson") {
                    TextField("Lesson title", text: $title)
                    TextField("Explain the spelling pattern", text: $rule, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    TextEditor(text: $words).frame(minHeight: 180).textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Practice words") } footer: { Text("Enter 4–24 unique words, one per line or separated by commas. These replace the starter lesson while your custom lesson is active.") }
                Section {
                    TextField("An unfamiliar word using the same pattern", text: $transfer).textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Quiz transfer word") } footer: { Text("Choose a word outside the practice list. It checks whether Noah can apply the pattern to a new word. Changes apply to new quizzes; an existing quiz keeps its original words.") }
            }.navigationTitle("Your spelling lesson")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Use lesson") { store.settings { $0.customSpelling = lesson }; dismiss() }.disabled(!lesson.valid) }
                }
        }.onAppear {
            if let existing = store.data.settings.customSpelling {
                title = existing.title; rule = existing.rule; words = existing.words.joined(separator: "\n"); transfer = existing.transfer
            }
        }
    }
}

struct QuizReviewList: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Quiz review", title: "The whole picture.", detail: "Accuracy is automatic. Handwriting grades come from you. Each subject has equal weight.")
                if store.data.quizzes.isEmpty { EmptyPanel(icon: "flag.checkered", title: "No checkpoints yet", detail: "Noah can begin a weekly checkpoint from his profile. Unfinished quizzes stay saved.") }
                ForEach(store.data.quizzes) { quiz in
                    if quiz.submitted != nil { QuizGradeCard(quizID: quiz.id) }
                    else { Panel { Label("Week of \(quiz.week) · In progress (\(quiz.questions.filter { $0.answer != nil }.count)/13 answers saved)", systemImage: "clock").foregroundStyle(TrailTheme.muted) } }
                }
            }.padding(32).frame(maxWidth: 1100)
        }
    }
}

struct QuizGradeCard: View {
    @EnvironmentObject var store: AppStore
    let quizID: UUID
    @State private var rubric = [0, 0, 0, 0]
    @State private var note = ""
    @State private var saved = false
    private let criteria = ["Letter formation", "Consistent size", "Word & letter spacing", "Line alignment"]
    private var quiz: WeeklyQuiz? { store.data.quizzes.first { $0.id == quizID } }
    var body: some View {
        if let quiz {
            Panel {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Week of \(quiz.week)").font(.title2.bold())
                    QuizResults(quiz: quiz)
                    DisclosureGroup("Inspect answers & response times") {
                        VStack(spacing: 12) {
                            ForEach(quiz.questions) { question in
                                HStack(alignment: .top) {
                                    Image(systemName: question.correct == true ? "checkmark.circle" : "xmark.circle").foregroundStyle(question.correct == true ? TrailTheme.mint : TrailTheme.gold)
                                    Text(question.fact?.prompt ?? question.word ?? "")
                                    Spacer()
                                    Text(question.answer ?? "—").bold()
                                    if question.correct == false { Text("→ \(question.fact.map { String($0.answer) } ?? question.word ?? "")").foregroundStyle(TrailTheme.gold) }
                                    if question.subject == .math { Text("\(question.seconds ?? 0, specifier: "%.1f")s").foregroundStyle(TrailTheme.muted).frame(width: 65, alignment: .trailing) }
                                }.font(.subheadline)
                            }
                        }.padding(.top, 16)
                    }
                    if let file = quiz.writingFile { DrawingPreview(file: file) }
                    Text(quiz.reference).font(.caption).foregroundStyle(TrailTheme.muted)
                    Text(quiz.passage).font(.subheadline).foregroundStyle(TrailTheme.muted)
                    Text("Handwriting rubric").font(.title3.bold())
                    Text("1 = needs guidance · 2 = developing · 3 = mostly clear · 4 = consistent\nFour criteria, 16 points total. Change scores later if needed.").font(.footnote).foregroundStyle(TrailTheme.muted)
                    ForEach(0..<4, id: \.self) { i in
                        HStack {
                            Text(criteria[i]); Spacer()
                            Picker(criteria[i], selection: $rubric[i]) {
                                Text("—").tag(0)
                                ForEach(1...4, id: \.self) { Text(String($0)).tag($0) }
                            }.pickerStyle(.segmented).frame(maxWidth: 260)
                        }
                    }
                    TextField("Feedback for Noah", text: $note, axis: .vertical).lineLimit(3...6).padding().background(TrailTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    ActionButton(title: saved ? "Grade saved" : "Save grade & feedback", icon: "checkmark") { store.gradeQuiz(id: quizID, rubric: rubric, note: note); saved = true }.disabled(rubric.contains(0))
                }
            }.onAppear { rubric = quiz.rubric ?? [0,0,0,0]; note = quiz.note }
                .onChange(of: rubric) { _, _ in saved = false }.onChange(of: note) { _, _ in saved = false }
        }
    }
}

struct WritingPortfolio: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Writing portfolio", title: "Keep the evidence of growth.", detail: "Samples appear newest first. Compare letter formation, spacing, size, and alignment over time.")
                if store.data.samples.isEmpty { EmptyPanel(icon: "pencil.tip.crop.circle", title: "The first page is ahead", detail: "Saved handwriting practice will appear here. Quiz samples are in Quiz review.") }
                ForEach(store.data.samples) { sample in
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack { Text(sample.date.formatted(date: .abbreviated, time: .shortened)).bold(); Spacer(); Text(sample.stage).foregroundStyle(TrailTheme.gold) }
                            DrawingPreview(file: sample.file)
                            Text(sample.reference).font(.caption).foregroundStyle(TrailTheme.muted)
                            Text(sample.text).font(.footnote).foregroundStyle(TrailTheme.muted)
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1100)
        }
    }
}

struct EmptyPanel: View {
    var icon: String; var title: String; var detail: String
    var body: some View {
        Panel { VStack(alignment: .leading, spacing: 16) { Image(systemName: icon).font(.largeTitle).foregroundStyle(TrailTheme.mint); Text(title).font(.title2.bold()); Text(detail).foregroundStyle(TrailTheme.muted) } }
    }
}

struct ProgressReport: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(data: AppData) {
        var rows = ["record,date,math_minutes,spelling_minutes,handwriting_minutes,math_percent,spelling_percent,handwriting_percent,overall_percent"]
        for day in data.days.values.sorted(by: { $0.id < $1.id }) {
            rows.append("practice,\(day.id),\(Double(day.seconds["math", default: 0])/60),\(Double(day.seconds["spelling", default: 0])/60),\(Double(day.seconds["handwriting", default: 0])/60),,,,")
        }
        for quiz in data.quizzes where quiz.submitted != nil {
            rows.append("quiz,\(quiz.week),,,,\(quiz.score(.math)),\(quiz.score(.spelling)),\(quiz.handwritingScore.map(String.init) ?? ""),\(quiz.overall.map(String.init) ?? "")")
        }
        text = rows.joined(separator: "\n")
    }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
