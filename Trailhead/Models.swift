import Foundation

enum Subject: String, Codable, CaseIterable, Identifiable {
    case math, spelling, handwriting
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String { switch self { case .math: "function"; case .spelling: "waveform"; case .handwriting: "pencil.tip.crop.circle" } }
}

enum Operation: String, Codable, CaseIterable, Identifiable {
    case addition, subtraction, multiplication, division
    var id: String { rawValue }
    var symbol: String { switch self { case .addition: "+"; case .subtraction: "−"; case .multiplication: "×"; case .division: "÷" } }
}

struct Fact: Codable, Equatable, Identifiable {
    var a: Int
    var b: Int
    var operation: Operation
    var id: String { "\(operation.rawValue)-\(a)-\(b)" }
    var prompt: String { "\(a) \(operation.symbol) \(b)" }
    var answer: Int {
        switch operation { case .addition: a + b; case .subtraction: a - b; case .multiplication: a * b; case .division: a / max(b, 1) }
    }
    var hint: String {
        switch operation {
        case .addition: "Start at \(max(a,b)), then count on \(min(a,b))."
        case .subtraction: "Think: \(b) plus what makes \(a)?"
        case .multiplication: "Think of \(a) groups of \(b). Break the groups into smaller parts you know."
        case .division: "Think: \(b) times what makes \(a)?"
        }
    }
    static func catalog(_ operation: Operation) -> [Fact] {
        let order = [2, 5, 10, 1, 0, 3, 4, 6, 7, 8, 9, 11, 12]
        return order.flatMap { a in order.compactMap { b -> Fact? in
            switch operation {
            case .subtraction: return Fact(a: a + b, b: b, operation: operation)
            case .division: return b == 0 ? nil : Fact(a: a * b, b: b, operation: operation)
            default: return Fact(a: a, b: b, operation: operation)
            }
        } }
    }
}

struct Skill: Codable {
    var attempts = 0
    var correct = 0
    var streak = 0
    var fastStreak = 0
    var lastSeen = Date.distantPast
    var due = Date.distantPast
    var latency: Double = 0
    var mastered: Bool { streak >= 3 }
    var automatic: Bool { fastStreak >= 3 }
    mutating func record(correct success: Bool, seconds: Double, now: Date) {
        attempts += 1
        correct += success ? 1 : 0
        streak = success ? streak + 1 : 0
        fastStreak = success && seconds <= 3 ? fastStreak + 1 : 0
        latency = seconds
        lastSeen = now
        due = now.addingTimeInterval(success ? (streak >= 3 ? 3 * 86400 : 86400) : 60)
    }
}

struct SpellingUnit: Identifiable {
    let id: Int
    let level: Int
    let title: String
    let rule: String
    let words: [String]
    let transfer: String
}

enum Curriculum {
    // Original starter sequences; levels are parent-facing placement guides.
    static let spelling: [SpellingUnit] = [
        .init(id: 0, level: 3, title: "The long-a trail", rule: "The letters ai often spell long a inside a word. The letters ay often spell long a at the end.", words: ["rain", "train", "paint", "chain", "wait", "stay", "play", "today"], transfer: "clay"),
        .init(id: 1, level: 3, title: "Two sounds of c", rule: "C usually says /s/ before e, i, or y. Before a, o, or u, it usually says /k/.", words: ["city", "cent", "fancy", "space", "place", "camp", "coat", "curve"], transfer: "spice"),
        .init(id: 2, level: 4, title: "Change the ending", rule: "Ness forms nouns. In these examples, change a consonant plus y to i before adding ness; otherwise keep the base word.", words: ["happiness", "laziness", "kindness", "darkness", "sadness", "illness", "busyness", "silliness"], transfer: "tidiness"),
        .init(id: 3, level: 4, title: "Double the consonant", rule: "In a one-syllable word ending in one short vowel and one consonant, double the final consonant before adding ing.", words: ["running", "sitting", "hopping", "planning", "swimming", "stopping", "clapping", "grinning"], transfer: "drumming"),
        .init(id: 4, level: 5, title: "A change of direction", rule: "The prefixes un, dis, and re change a base word's meaning. Preserve the spelling of the base word.", words: ["unfair", "unusual", "disagree", "disappear", "rebuild", "rewrite", "reconsider", "disconnect"], transfer: "repaint"),
        .init(id: 5, level: 5, title: "Words with a mission", rule: "The ending tion often sounds like /shun/. Notice the base word and changes at the joining point.", words: ["action", "motion", "invention", "collection", "protection", "selection", "education", "direction"], transfer: "inspection"),
        .init(id: 6, level: 6, title: "Built from roots", rule: "The root struct means build. Find that shared spelling inside each word, then identify its prefix or suffix.", words: ["structure", "construct", "construction", "instruct", "instruction", "reconstruct", "destruction", "structural"], transfer: "reconstruction"),
        .init(id: 7, level: 6, title: "Keep the base", rule: "The suffix ment forms nouns. In these words, the spelling of the base stays the same when ment is added.", words: ["agreement", "development", "enjoyment", "improvement", "movement", "equipment", "achievement", "government"], transfer: "employment")
    ]
    static let verses: [(reference: String, text: String)] = [
        ("Proverbs 3:5 · KJV", "Trust in the LORD with all thine heart; and lean not unto thine own understanding."),
        ("Proverbs 15:1 · KJV", "A soft answer turneth away wrath: but grievous words stir up anger."),
        ("Proverbs 17:17 · KJV", "A friend loveth at all times, and a brother is born for adversity."),
        ("Proverbs 16:3 · KJV", "Commit thy works unto the LORD, and thy thoughts shall be established."),
        ("Proverbs 4:23 · KJV", "Keep thy heart with all diligence; for out of it are the issues of life.")
    ]
}

struct PracticeDay: Codable, Identifiable {
    var id: String
    var seconds: [String: Int] = [:]
    var attempts = 0
    var correct = 0
    var completionRewarded = false
    var total: Int { seconds.values.reduce(0, +) }
}

struct WritingSample: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var reference: String
    var text: String
    var file: String
    var stage: String
}

struct QuizQuestion: Codable, Identifiable {
    var id = UUID()
    var subject: Subject
    var fact: Fact?
    var word: String?
    var answer: String?
    var seconds: Double?
    var correct: Bool? {
        guard let answer else { return nil }
        if let fact { return Int(answer) == fact.answer }
        return answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == word?.lowercased()
    }
}

struct WeeklyQuiz: Codable, Identifiable {
    var id = UUID()
    var week: String
    var created = Date()
    var submitted: Date?
    var questions: [QuizQuestion]
    var writingFile: String?
    var reference: String
    var passage: String
    var rubric: [Int]? // formation, size, spacing, alignment; 1–4 each
    var note = ""
    var completionRewarded = false
    func score(_ subject: Subject) -> Int {
        let items = questions.filter { $0.subject == subject }
        return items.isEmpty ? 0 : Int((Double(items.filter { $0.correct == true }.count) / Double(items.count) * 100).rounded())
    }
    var handwritingScore: Int? { rubric.map { Int((Double($0.reduce(0,+)) / 16 * 100).rounded()) } }
    var overall: Int? { handwritingScore.map { (score(.math) + score(.spelling) + $0) / 3 } }
}

struct Settings: Codable {
    var dailyMinutes = 30
    var recoveryMode = false
    var spellingUnit = 0
    var operation = Operation.multiplication
    var writingStage = "Print · trace & copy"
    var verseIndex = 0
    var customSpelling: CustomSpellingLesson?
    var targetPerSubject: Int { (recoveryMode ? 10 : dailyMinutes) * 60 / 3 }
}

struct AppData: Codable {
    var settings = Settings()
    var days: [String: PracticeDay] = [:]
    var skills: [String: Skill] = [:]
    var samples: [WritingSample] = []
    var quizzes: [WeeklyQuiz] = []
    var xp = 0
    var upgrades: [String] = []
}

struct CustomSpellingLesson: Codable {
    var title: String
    var rule: String
    var words: [String]
    var transfer: String
    var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        words.count >= 4 && words.count <= 24 && Set(words).count == words.count &&
        words.allSatisfy { !$0.isEmpty && $0.count <= 40 } &&
        !transfer.isEmpty && transfer.count <= 40 && !words.contains(transfer)
    }
}

enum DateKeys {
    static func day(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func week(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = .current
        return day(calendar.dateInterval(of: .weekOfYear, for: date)!.start)
    }
}
