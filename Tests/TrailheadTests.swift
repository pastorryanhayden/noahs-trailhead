import XCTest
import PencilKit
@testable import Trailhead

final class TrailheadTests: XCTestCase {
    @MainActor private func store() -> AppStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return AppStore(directory: directory)
    }

    func testAllArithmeticFactsHaveValidAnswers() {
        for operation in Operation.allCases {
            let facts = Fact.catalog(operation)
            XCTAssertEqual(Set(facts.map(\.id)).count, facts.count)
            for fact in facts {
                XCTAssertGreaterThanOrEqual(fact.answer, 0)
                if operation == .division {
                    XCTAssertNotEqual(fact.b, 0)
                    XCTAssertEqual(fact.a % fact.b, 0)
                    XCTAssertLessThanOrEqual(fact.answer, 12)
                }
            }
        }
        XCTAssertEqual(Fact.catalog(.multiplication).count, 169)
        XCTAssertTrue(Fact.catalog(.multiplication).contains { $0.a == 12 && $0.b == 12 && $0.answer == 144 })
    }

    func testErrorsResetRecallAndSpeedSeparately() {
        var skill = Skill()
        let now = Date()
        for _ in 0..<3 { skill.record(correct: true, seconds: 5, now: now) }
        XCTAssertTrue(skill.mastered); XCTAssertFalse(skill.automatic)
        for _ in 0..<3 { skill.record(correct: true, seconds: 2, now: now) }
        XCTAssertTrue(skill.automatic)
        skill.record(correct: false, seconds: 1, now: now)
        XCTAssertFalse(skill.mastered); XCTAssertFalse(skill.automatic)
        XCTAssertEqual(skill.due.timeIntervalSince(now), 60)
    }

    @MainActor func testPracticePersistsAndSchedulesWrongAnswersForReview() {
        let s = store()
        let fact = s.nextFact()
        s.record(fact.id, success: false, seconds: 8)
        s.settings { $0.spellingUnit = 4; $0.writingStage = "Print · copy" }
        s.addSecond(.math); s.save()
        let loaded = AppStore(directory: s.directory)
        XCTAssertEqual(loaded.data.settings.spellingUnit, 4)
        XCTAssertEqual(loaded.data.settings.writingStage, "Print · trace & copy")
        XCTAssertEqual(loaded.data.skills[fact.id]?.attempts, 1)
        XCTAssertEqual(loaded.today.seconds["math"], 1)
        XCTAssertNotEqual(loaded.nextFact(excluding: fact.id).id, fact.id)
    }

    @MainActor func testNewFactsStayWithinSmallDevelopingSet() {
        let s = store()
        var ids = Set<String>()
        var previous: String?
        for _ in 0..<32 {
            let fact = s.nextFact(excluding: previous)
            ids.insert(fact.id)
            s.record(fact.id, success: false, seconds: 4)
            previous = fact.id
        }
        XCTAssertLessThanOrEqual(ids.count, 8)
    }

    @MainActor func testDailyRewardRequiresAllSubjectsAndCannotRepeat() {
        let s = store()
        s.settings { $0.recoveryMode = true }
        for _ in 0..<200 { s.addSecond(.math); s.addSecond(.spelling) }
        XCTAssertEqual(s.data.xp, 0)
        for _ in 0..<200 { s.addSecond(.handwriting) }
        XCTAssertEqual(s.data.xp, 50)
        s.addSecond(.handwriting)
        XCTAssertEqual(s.data.xp, 50)
        s.settings { $0.recoveryMode = false }
        s.addSecond(.math)
        XCTAssertEqual(s.data.xp, 50)
    }

    @MainActor func testQuizResumesLocksAnswersAndNeedsWritingToSubmit() {
        let s = store(); s.beginQuiz()
        let quiz = s.currentQuiz!
        XCTAssertEqual(quiz.questions.filter { $0.subject == .math }.count, 8)
        XCTAssertEqual(quiz.questions.filter { $0.subject == .spelling }.count, 5)
        XCTAssertEqual(Set(quiz.questions.compactMap { $0.fact?.id }).count, 8)
        XCTAssertTrue(quiz.questions.contains { $0.word == s.unit.transfer })
        for q in quiz.questions {
            s.answerQuiz(id: quiz.id, question: q.id, answer: q.fact.map { String($0.answer) } ?? q.word!, seconds: 2)
        }
        let first = quiz.questions[0]
        s.answerQuiz(id: quiz.id, question: first.id, answer: "999", seconds: 1)
        XCTAssertTrue(s.currentQuiz!.questions[0].correct == true)
        s.submitQuiz(id: quiz.id, drawing: PKDrawing())
        XCTAssertNil(s.currentQuiz!.submitted)
        let loaded = AppStore(directory: s.directory)
        XCTAssertTrue(loaded.currentQuiz!.questions.allSatisfy { $0.answer != nil })
        loaded.beginQuiz()
        XCTAssertEqual(loaded.data.quizzes.count, 1)
    }

    @MainActor func testQuizSubmissionGradingAndRewardAreIdempotent() {
        let s = store(); s.beginQuiz()
        let quiz = s.currentQuiz!
        for q in quiz.questions { s.answerQuiz(id: quiz.id, question: q.id, answer: q.fact.map { String($0.answer) } ?? q.word!, seconds: 2) }
        let points = [PKStrokePoint(location: CGPoint(x: 20, y: 20), timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi/2), PKStrokePoint(location: CGPoint(x: 70, y: 70), timeOffset: 1, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi/2)]
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        s.submitQuiz(id: quiz.id, drawing: ink)
        XCTAssertNotNil(s.currentQuiz!.submitted)
        XCTAssertEqual(s.currentQuiz!.score(.math), 100)
        XCTAssertEqual(s.currentQuiz!.score(.spelling), 100)
        let xp = s.data.xp
        s.submitQuiz(id: quiz.id, drawing: ink)
        XCTAssertEqual(s.data.xp, xp)
        s.gradeQuiz(id: quiz.id, rubric: [4, 4, 4, 4], note: "Clear work!")
        XCTAssertEqual(s.currentQuiz!.overall, 100)
        s.gradeQuiz(id: quiz.id, rubric: [0, 4, 4, 4], note: "Invalid")
        XCTAssertEqual(s.currentQuiz!.note, "Clear work!")
    }

    @MainActor func testPurchaseCannotOverspendOrRepeat() {
        let s = store(); let item = Upgrade.all[0]
        s.purchase(item); XCTAssertTrue(s.data.upgrades.isEmpty)
        s.data.xp = item.cost
        s.purchase(item); XCTAssertEqual(s.data.xp, 0)
        s.data.xp = 100; s.purchase(item)
        XCTAssertEqual(s.data.xp, 100); XCTAssertEqual(s.data.upgrades.count, 1)
    }

    @MainActor func testCustomSpellingLessonDrivesPracticeAndNewQuiz() {
        let s = store()
        let lesson = CustomSpellingLesson(title: "Our lesson", rule: "Use ai inside a word.", words: ["rain", "pain", "train", "chain"], transfer: "grain")
        XCTAssertTrue(lesson.valid)
        XCTAssertFalse(CustomSpellingLesson(title: "", rule: "", words: [], transfer: "").valid)
        s.settings { $0.customSpelling = lesson }
        XCTAssertTrue(lesson.words.contains(s.nextWord()))
        s.beginQuiz()
        XCTAssertTrue(s.currentQuiz!.questions.contains { $0.word == "grain" })
        let loaded = AppStore(directory: s.directory)
        XCTAssertEqual(loaded.unit.title, "Our lesson")
        loaded.settings { $0.customSpelling = nil }
        XCTAssertEqual(loaded.unit.id, 0)
    }

    @MainActor func testCorruptProgressIsNeverOverwritten() throws {
        let s = store(); let path = s.directory.appendingPathComponent("progress.json")
        let original = Data("damaged progress".utf8)
        try original.write(to: path)
        let loaded = AppStore(directory: s.directory)
        XCTAssertNotNil(loaded.error)
        loaded.save()
        XCTAssertEqual(try Data(contentsOf: path), original)
    }
}
