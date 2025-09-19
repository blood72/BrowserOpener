import XCTest
import SwiftUI
import ViewInspector
@testable import BrowserOpener


final class AboutSettingsViewTests: XCTestCase {

    func test_body_showsVersion() throws {
        let sut = AboutSettingsView()

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let versionText = try texts.first(where: { try $0.string().contains("버전") })
        XCTAssertNotNil(versionText)
    }

    func test_body_showsSystemInfo() throws {
        let sut = AboutSettingsView()
        let texts = try sut.inspect().findAll(ViewType.Text.self)
        XCTAssertTrue(texts.contains(where: { (try? $0.string()) == "시스템 정보" }))
    }
}
