import SwiftUI
import PencilKit
import CryptoKit
import Security
import AVFoundation

@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData
    @Published var error: String?
    let directory: URL
    private var writable = true
    private let voice = AVSpeechSynthesizer()

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Trailhead", isDirectory: true)
        data = AppData()
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let file = self.directory.appendingPathComponent("progress.json")
            if FileManager.default.fileExists(atPath: file.path) {
                data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: file))
                let stages = ["Print · copy": "Print · trace & copy", "Print · trace": "Print · trace & copy", "Words · copy": "Words · trace & copy", "Cursive · trace": "Cursive · trace & copy"]
                if let updated = stages[data.settings.writingStage] { data.settings.writingStage = updated }
            }
        } catch {
            writable = false
            self.error = "Your saved progress could not be opened. It has been preserved. Close the app and check the progress file before continuing. \(error.localizedDescription)"
        }
    }
    var today: PracticeDay { data.days[DateKeys.day()] ?? PracticeDay(id: DateKeys.day()) }
    var unit: SpellingUnit {
        if let custom = data.settings.customSpelling, custom.valid {
            return SpellingUnit(id: -1, level: 0, title: custom.title, rule: custom.rule, words: custom.words, transfer: custom.transfer)
        }
        return Curriculum.spelling[min(max(data.settings.spellingUnit, 0), Curriculum.spelling.count - 1)]
    }
    var verse: (reference: String, text: String) { Curriculum.verses[min(max(data.settings.verseIndex, 0), Curriculum.verses.count - 1)] }
    var currentQuiz: WeeklyQuiz? { data.quizzes.first { $0.week == DateKeys.week() } }
    var masteredFacts: Int { data.skills.filter { !$0.key.hasPrefix("word:") && $0.value.mastered }.count }
    func save() {
        guard writable else { return }
        do { try JSONEncoder().encode(data).write(to: directory.appendingPathComponent("progress.json"), options: .atomic) }
        catch { self.error = "Progress could not be saved: \(error.localizedDescription)" }
    }
    func settings(_ change: (inout Settings) -> Void) { change(&data.settings); save() }
    func addSecond(_ subject: Subject) {
        let key = DateKeys.day()
        var day = data.days[key] ?? PracticeDay(id: key)
        day.seconds[subject.rawValue, default: 0] += 1
        if !day.completionRewarded && Subject.allCases.allSatisfy({ day.seconds[$0.rawValue, default: 0] >= data.settings.targetPerSubject }) {
            day.completionRewarded = true; data.xp += 50
        }
        data.days[key] = day
        if day.total.isMultiple(of: 5) { save() }
    }
    func record(_ key: String, success: Bool, seconds: Double) {
        var skill = data.skills[key] ?? Skill()
        skill.record(correct: success, seconds: seconds, now: Date())
        data.skills[key] = skill
        let dayKey = DateKeys.day()
        var day = data.days[dayKey] ?? PracticeDay(id: dayKey)
        day.attempts += 1; day.correct += success ? 1 : 0
        data.days[dayKey] = day
        data.xp += success ? 3 : 1
        save()
    }
    func nextFact(excluding: String? = nil) -> Fact {
        let catalog = Fact.catalog(data.settings.operation)
        // Introduce only a small set at a time, then retain review of learned facts.
        let seen = catalog.filter { data.skills[$0.id] != nil }
        let developingCount = seen.filter { !(data.skills[$0.id]?.mastered ?? false) }.count
        let new = Array(catalog.filter { data.skills[$0.id] == nil }.prefix(max(0, 8 - developingCount)))
        let pool = seen + new
        let due = pool.filter { (data.skills[$0.id]?.due ?? .distantPast) <= Date() }
        let eligible = (due.isEmpty ? pool : due).filter { $0.id != excluding }
        let candidates = eligible.isEmpty ? pool.filter { $0.id != excluding } : eligible
        return candidates.min { lhs, rhs in
            let a = data.skills[lhs.id]; let b = data.skills[rhs.id]
            if (a?.streak ?? 0) != (b?.streak ?? 0) { return (a?.streak ?? 0) < (b?.streak ?? 0) }
            return (a?.lastSeen ?? .distantPast) < (b?.lastSeen ?? .distantPast)
        } ?? catalog[0]
    }
    func nextWord(excluding: String? = nil) -> String {
        let candidates = unit.words.filter { $0 != excluding }
        return candidates.min {
            let a = data.skills["word:\($0)"]; let b = data.skills["word:\($1)"]
            let adue = (a?.due ?? .distantPast) <= Date(), bdue = (b?.due ?? .distantPast) <= Date()
            if adue != bdue { return adue }
            if (a?.streak ?? 0) != (b?.streak ?? 0) { return (a?.streak ?? 0) < (b?.streak ?? 0) }
            return (a?.lastSeen ?? .distantPast) < (b?.lastSeen ?? .distantPast)
        } ?? unit.words[0]
    }
    func speak(_ text: String) {
        voice.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.40
        voice.speak(utterance)
    }
    func stopSpeaking() { voice.stopSpeaking(at: .immediate) }
    func writeDrawing(_ drawing: PKDrawing, name: String) -> String? {
        guard writable else { return nil }
        do { try drawing.dataRepresentation().write(to: directory.appendingPathComponent(name), options: .atomic); return name }
        catch { self.error = "Writing could not be saved: \(error.localizedDescription)"; return nil }
    }
    func drawing(_ name: String?) -> PKDrawing {
        guard let name, let bytes = try? Data(contentsOf: directory.appendingPathComponent(name)), let drawing = try? PKDrawing(data: bytes) else { return PKDrawing() }
        return drawing
    }
    func saveSample(_ drawing: PKDrawing, reference: String? = nil, text: String? = nil) -> Bool {
        guard !drawing.strokes.isEmpty else { return false }
        let sampleID = UUID()
        guard let file = writeDrawing(drawing, name: "writing-\(sampleID).pencil") else { return false }
        data.samples.insert(WritingSample(id: sampleID, reference: reference ?? verse.reference, text: text ?? verse.text, file: file, stage: data.settings.writingStage), at: 0)
        save(); return true
    }
    func beginQuiz() {
        guard currentQuiz == nil else { return }
        let practiced = Operation.allCases.flatMap { Fact.catalog($0) }.filter { data.skills[$0.id] != nil }.shuffled()
        let fallback = Fact.catalog(data.settings.operation).shuffled()
        var facts: [Fact] = []
        for fact in practiced + fallback where !facts.contains(where: { $0.id == fact.id }) {
            facts.append(fact); if facts.count == 8 { break }
        }
        let review = data.skills.keys.filter { $0.hasPrefix("word:") }.map { String($0.dropFirst(5)) }.filter { !unit.words.contains($0) }.shuffled()
        let words = Array(unit.words.shuffled().prefix(3)) + [review.first ?? unit.words[3], unit.transfer]
        let questions = facts.map { QuizQuestion(subject: .math, fact: $0) } + words.map { QuizQuestion(subject: .spelling, word: $0) }
        data.quizzes.insert(WeeklyQuiz(week: DateKeys.week(), questions: questions, reference: verse.reference, passage: verse.text), at: 0)
        save()
    }
    func answerQuiz(id: UUID, question: UUID, answer: String, seconds: Double) {
        guard let i = data.quizzes.firstIndex(where: { $0.id == id }), data.quizzes[i].submitted == nil,
              let q = data.quizzes[i].questions.firstIndex(where: { $0.id == question }), data.quizzes[i].questions[q].answer == nil else { return }
        data.quizzes[i].questions[q].answer = answer
        data.quizzes[i].questions[q].seconds = seconds
        save()
    }
    func saveQuizInk(id: UUID, drawing: PKDrawing) {
        guard let i = data.quizzes.firstIndex(where: { $0.id == id }), data.quizzes[i].submitted == nil else { return }
        if let file = writeDrawing(drawing, name: "quiz-\(id).pencil") { data.quizzes[i].writingFile = file; save() }
    }
    func submitQuiz(id: UUID, drawing: PKDrawing) {
        guard !drawing.strokes.isEmpty, let i = data.quizzes.firstIndex(where: { $0.id == id }),
              data.quizzes[i].submitted == nil, data.quizzes[i].questions.allSatisfy({ $0.answer != nil }) else { return }
        saveQuizInk(id: id, drawing: drawing)
        guard data.quizzes[i].writingFile != nil else { return }
        data.quizzes[i].submitted = Date()
        for question in data.quizzes[i].questions {
            let key = question.fact?.id ?? "word:\(question.word ?? "")"
            record(key, success: question.correct == true, seconds: question.seconds ?? 60)
        }
        if !data.quizzes[i].completionRewarded { data.xp += 40; data.quizzes[i].completionRewarded = true }
        save()
    }
    func gradeQuiz(id: UUID, rubric: [Int], note: String) {
        guard rubric.count == 4, rubric.allSatisfy({ (1...4).contains($0) }), let i = data.quizzes.firstIndex(where: { $0.id == id }), data.quizzes[i].submitted != nil else { return }
        data.quizzes[i].rubric = rubric; data.quizzes[i].note = note; save()
    }
    func purchase(_ upgrade: Upgrade) {
        guard !data.upgrades.contains(upgrade.id), data.xp >= upgrade.cost else { return }
        data.xp -= upgrade.cost; data.upgrades.append(upgrade.id); save()
    }
}

struct Upgrade: Identifiable {
    var id: String; var title: String; var icon: String; var cost: Int; var detail: String
    static let all: [Upgrade] = [
        .init(id: "tent", title: "Expedition tent", icon: "tent.fill", cost: 60, detail: "A home for the next adventure."),
        .init(id: "fire", title: "Campfire", icon: "flame.fill", cost: 100, detail: "Light up your base camp."),
        .init(id: "scope", title: "Lookout station", icon: "binoculars.fill", cost: 160, detail: "Find your next destination."),
        .init(id: "flag", title: "Summit flag", icon: "flag.fill", cost: 240, detail: "Make your mark on the mountain.")
    ]
}

enum ParentPIN {
    private static let service = "com.hayden.trailhead.parent"
    private static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "parent-pin"] }
    static var configured: Bool { credential() != nil }
    private static func credential() -> String? {
        var q = query; q[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private static func hash(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func verify(_ pin: String) -> Bool {
        guard let parts = credential()?.split(separator: ":"), parts.count == 2 else { return false }
        return hash(String(parts[0]) + pin) == parts[1]
    }
    static func set(_ pin: String) -> Bool {
        guard pin.count == 6, pin.allSatisfy({ $0.isNumber && $0.isASCII }) else { return false }
        let salt = UUID().uuidString
        let bytes = Data("\(salt):\(hash(salt + pin))".utf8)
        var q = query
        q[kSecValueData as String] = bytes
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        if status == errSecDuplicateItem { return SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary) == errSecSuccess }
        return status == errSecSuccess
    }
}
