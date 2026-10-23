import XCTest

final class TrailheadUITests: XCTestCase {
    @MainActor func testNoahPracticeAndParentProfile() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(app.buttons["profile.noah"].waitForExistence(timeout: 10))
        capture("01-profiles")
        app.buttons["profile.noah"].tap()
        XCTAssertTrue(app.staticTexts["Your next step, Noah."].waitForExistence(timeout: 5))
        capture("02-noah-today")
        app.buttons["nav.Math"].tap()
        let prompt = app.staticTexts["math.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        let numbers = prompt.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(numbers.count, 2)
        let answer = numbers[0] * numbers[1]
        for digit in String(answer) { app.buttons["key.\(digit)"].tap() }
        app.buttons["math.check"].tap()
        XCTAssertTrue(app.staticTexts["That's it. Keep going."].waitForExistence(timeout: 5))
        capture("03-math-feedback")
        app.buttons["nav.Spelling"].tap()
        XCTAssertTrue(app.buttons["Hide & spell"].waitForExistence(timeout: 5))
        app.buttons["Hide & spell"].tap()
        let spelling = app.textFields["spelling.answer"]
        XCTAssertTrue(spelling.waitForExistence(timeout: 5))
        spelling.tap(); spelling.typeText("rain")
        app.buttons["Check spelling"].tap()
        XCTAssertTrue(app.buttons["Next word"].waitForExistence(timeout: 5))
        app.buttons["nav.Handwriting"].tap()
        XCTAssertTrue(app.staticTexts["Make your mark."].waitForExistence(timeout: 5))
        capture("04-handwriting")
        app.buttons["Switch profile"].tap()
        app.buttons["profile.parent"].tap()
        let fields = app.secureTextFields
        XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 5))
        fields.element(boundBy: 0).tap(); fields.element(boundBy: 0).typeText("581924")
        if fields.count == 2 {
            fields.element(boundBy: 1).tap(); fields.element(boundBy: 1).typeText("581924")
            app.buttons["Create parent profile"].tap()
        } else { app.buttons["Unlock"].tap() }
        XCTAssertTrue(app.staticTexts["Steady progress, made visible."].waitForExistence(timeout: 5))
        capture("05-parent-dashboard")
        app.buttons["Learning plan"].tap()
        XCTAssertTrue(app.staticTexts["You set the direction."].waitForExistence(timeout: 5))
        capture("06-learning-plan")
        app.buttons["Lock & switch profile"].tap()
        app.buttons["profile.parent"].tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 5))
        app.secureTextFields.firstMatch.tap(); app.secureTextFields.firstMatch.typeText("000000")
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.staticTexts["That PIN did not match."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Steady progress, made visible."].exists)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
