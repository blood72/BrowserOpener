import XCTest
import SwiftUI
import ViewInspector
@testable import BrowserOpener


final class BrowserRowViewTests: XCTestCase {

    func test_init_setsProperties() {
        let browser = stubBrowser(name: "TestBrowser", bundleIdentifier: "com.test.browser")
        let sut = BrowserRowView(
            browser: browser,
            isHovered: false,
            onTap: {},
            onHover: { _ in },
            onProfileTap: { _ in }
        )

        let text = try? sut.inspect().findAll(ViewType.Text.self).first
        XCTAssertNotNil(text)
    }

    func test_body_showsBrowserName() throws {
        let browser = stubBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        let sut = BrowserRowView(
            browser: browser,
            isHovered: false,
            onTap: {},
            onHover: { _ in },
            onProfileTap: { _ in }
        )

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let nameText = texts.first(where: { (try? $0.string()) == "Chrome" })
        XCTAssertNotNil(nameText)
    }

    func test_rowContainsOpenButton() throws {
        let browser = stubBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let sut = BrowserRowView(
            browser: browser,
            isHovered: false,
            onTap: {},
            onHover: { _ in },
            onProfileTap: { _ in }
        )

        // Open 버튼이 존재해야 함
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        XCTAssertFalse(buttons.isEmpty)
    }

    func test_rowContainsExpandChevron() throws {
        let browser = stubBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let sut = BrowserRowView(
            browser: browser,
            isHovered: false,
            onTap: {},
            onHover: { _ in },
            onProfileTap: { _ in }
        )

        // chevron 이미지가 존재해야 함
        let images = try sut.inspect().findAll(ViewType.Image.self)
        let chevron = images.first(where: { (try? $0.actualImage().name()) == "chevron.right" })
        XCTAssertNotNil(chevron)
    }

    // Helper
    private func stubBrowser(name: String, bundleIdentifier: String) -> Browser {
        Browser(
            id: UUID().uuidString,
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: "app",
            kind: .custom,
            isInstalled: true,
            isEnabled: true,
            isHidden: false,
            profiles: [
                BrowserProfile(id: "p1", name: "Default", launchArguments: [], isDefault: true, kind: .standard)
            ]
        )
    }
}
