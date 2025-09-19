import XCTest
import SwiftUI
import ViewInspector
@testable import BrowserOpener


final class DraggableURLViewTests: XCTestCase {

    func test_body_showsURL() throws {
        let url = "https://example.com"
        let sut = DraggableURLView(url: url)

        // DraggableURLView contains ReadonlyTextView which wraps NSTextView.
        // ViewInspector might not traverse into NSViewRepresentable easily without setup,
        // but we can check if the struct is created with correct props.

        let textView = try sut.inspect().find(ReadonlyTextView.self)
        XCTAssertEqual(try textView.actualView().text, url)
    }
}
