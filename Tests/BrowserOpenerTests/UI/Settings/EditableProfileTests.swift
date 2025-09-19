import XCTest
@testable import BrowserOpener

final class EditableProfileTests: XCTestCase {
    func testArgumentParsingWithQuotes() {
        let input = "--profile-directory=\"Profile 1\""
        let parsed = EditableProfile.arguments(from: input)

        // Expected behavior: "--profile-directory=Profile 1" (quotes stripped by shell-like parsing)
        // Note: The current implementation strips quotes but keeps the content together if quoted.
        // Let's verify what the current implementation actually does.
        // If input is `--profile-directory="Profile 1"`,
        // split by space respects quotes? The current logic does toggle `insideQuotes`.
        // So it should return one argument: `--profile-directory=Profile 1` (without quotes around Profile 1?)
        // Actually, the current logic skips the quote char: `if char == "\"" { continue }`
        // So `--profile-directory="Profile 1"` becomes `--profile-directory=Profile 1`.

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first, "--profile-directory=Profile 1")
    }

    func testDuplicateQuotedValues() {
        // Case: Multiple occurrences of the same value with spaces
        let input = "--first-arg=\"Profile 1\" --second-arg=\"Profile 1\""
        let parsed = EditableProfile.arguments(from: input)

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0], "--first-arg=Profile 1")
        XCTAssertEqual(parsed[1], "--second-arg=Profile 1")

        let stringified = EditableProfile.argumentString(from: parsed)
        XCTAssertTrue(stringified.contains("\"--first-arg=Profile 1\""))
        XCTAssertTrue(stringified.contains("\"--second-arg=Profile 1\""))

        // Round trip
        let reparsed = EditableProfile.arguments(from: stringified)
        XCTAssertEqual(reparsed, parsed)
    }

    func testMultipleArgumentsWithQuotes() {
        // Case: Mixed normal args and quoted args with spaces
        let input = "--incognito --profile-directory=\"Profile 1\" --debug"
        let parsed = EditableProfile.arguments(from: input)

        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0], "--incognito")
        XCTAssertEqual(parsed[1], "--profile-directory=Profile 1")
        XCTAssertEqual(parsed[2], "--debug")

        let stringified = EditableProfile.argumentString(from: parsed)
        // Note: The order might be preserved, but quotes should be added back to the one with spaces

        XCTAssertTrue(stringified.contains("--incognito"))
        XCTAssertTrue(stringified.contains("--debug"))
        // Check if the one with spaces is quoted
        XCTAssertTrue(stringified.contains("\"--profile-directory=Profile 1\""))

        // Round trip check
        let reparsed = EditableProfile.arguments(from: stringified)
        XCTAssertEqual(reparsed, parsed)
    }
}

