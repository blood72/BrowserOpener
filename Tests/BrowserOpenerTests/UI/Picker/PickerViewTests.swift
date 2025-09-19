import XCTest
import SwiftUI
import AppKit
@testable import BrowserOpener
import ViewInspector

final class PickerViewTests: XCTestCase {
    // MARK: - Header & Section Labels

    func test_header_showsTitle() throws {
        let manager = BrowserManager()
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let hasTitle = sut.findAll(textWhere: { $0 == "브라우저 선택" }).isEmpty == false
        XCTAssertTrue(hasTitle)
    }

    func test_browserSelectionLabel_isAlwaysVisible() throws {
        let manager = BrowserManager()
        manager.installedBrowsers = []
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sutEmpty = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)
        let hasLabelEmpty = sutEmpty.findAll(textWhere: { $0 == "브라우저 선택:" }).isEmpty == false
        XCTAssertTrue(hasLabelEmpty)

        let manager2 = BrowserManager()
        manager2.installedBrowsers = [stubBrowser(name: "X", bundleIdentifier: "x")]
        let sutList = PickerView()
            .environmentObject(manager2)
            .environmentObject(rulesStore)
        let hasLabelList = sutList.findAll(textWhere: { $0 == "브라우저 선택:" }).isEmpty == false
        XCTAssertTrue(hasLabelList)
    }
    func test_urlSection_isHidden_whenCurrentURLIsEmpty() throws {
        let manager = BrowserManager()
        manager.updateURL("")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        // urlDisplayView는 조건부로 렌더링됨. 비어있으면 해당 텍스트가 없어야 함.
        let hasLabel = sut.findAll(textWhere: { $0.contains("열려는 URL:") }).isEmpty == false
        XCTAssertFalse(hasLabel)
    }

    func test_urlSection_isVisible_whenCurrentURLIsNotEmpty() throws {
        let manager = BrowserManager()
        manager.updateURL("https://example.com")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let hasLabel = sut.findAll(textWhere: { $0.contains("열려는 URL:") }).isEmpty == false
        XCTAssertTrue(hasLabel)
    }

    func test_copyButton_isHidden_whenCurrentURLEmpty() throws {
        let manager = BrowserManager()
        manager.updateURL("")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let hasCopy = sut.findAll(textWhere: { $0 == "URL 복사" }).isEmpty == false
        XCTAssertFalse(hasCopy)
    }

    func test_copyButton_isVisible_whenCurrentURLNotEmpty() throws {
        let manager = BrowserManager()
        manager.updateURL("https://example.com")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let hasCopy = sut.findAll(textWhere: { $0 == "URL 복사" }).isEmpty == false
        XCTAssertTrue(hasCopy)
    }

    @MainActor
    func test_copyURLButton_copiesToPasteboard() throws {
        let manager = BrowserManager()
        manager.updateURL("https://example.com")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        let copyButton = try XCTUnwrap(buttons.first(where: { button in
            let texts: [String]
            if let label = try? button.labelView() {
                texts = label.findAll(ViewType.Text.self).compactMap { try? $0.string() }
            } else {
                texts = []
            }
            return texts.contains("URL 복사")
        }))

        NSPasteboard.general.clearContents()
        try copyButton.tap()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "https://example.com")
    }

    func test_draggableURLView_isVisible_whenCurrentURLNotEmpty() throws {
        let manager = BrowserManager()
        manager.updateURL("https://example.com")
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let views = try sut.inspect().findAll(ViewType.View<DraggableURLView>.self)
        XCTAssertEqual(views.count, 1)
    }

    func test_emptyState_isVisible_whenNoInstalledBrowsers() throws {
        // 강제로 빈 목록 상태 만들기 위해 manager를 생성한 뒤 목록을 비움
        let manager = BrowserManager()
        manager.installedBrowsers = []
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let emptyTextExists = sut.findAll(textWhere: { $0.contains("설치된 브라우저가 없습니다") }).isEmpty == false
        XCTAssertTrue(emptyTextExists)
    }

    func test_emptyState_isHidden_whenBrowsersExist() throws {
        let manager = BrowserManager()
        manager.installedBrowsers = [stubBrowser(name: "X", bundleIdentifier: "x")]
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let emptyTextExists = sut.findAll(textWhere: { $0.contains("설치된 브라우저가 없습니다") }).isEmpty == false
        XCTAssertFalse(emptyTextExists)
    }

    func test_browserRows_countMatchesInstalledBrowsers() throws {
        let manager = BrowserManager()
        manager.installedBrowsers = [
            stubBrowser(name: "A", bundleIdentifier: "a"),
            stubBrowser(name: "B", bundleIdentifier: "b"),
            stubBrowser(name: "C", bundleIdentifier: "c")
        ]
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        // BrowserRowView 개수 확인
        let rows = try sut.inspect().findAll(ViewType.View<BrowserRowView>.self)
        XCTAssertEqual(rows.count, 3)
    }

    func test_browserRows_showNames() throws {
        let manager = BrowserManager()
        manager.installedBrowsers = [
            stubBrowser(name: "A", bundleIdentifier: "a"),
            stubBrowser(name: "B", bundleIdentifier: "b")
        ]
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let texts = sut.findAll(textWhere: { _ in true })
        XCTAssertTrue(texts.contains("A"))
        XCTAssertTrue(texts.contains("B"))
    }

    // MARK: - Row Actions

    @MainActor
    func test_tappingBrowserRow_callsOpenAndClosesWindow() throws {
        let spyOpener: SpyBrowserOpener = SpyBrowserOpener()

        let manager = BrowserManager(opener: spyOpener)
        manager.updateURL("https://example.com")
        manager.installedBrowsers = [
            stubBrowser(name: "TestBrowser", bundleIdentifier: "com.example.testbrowser")
        ]
        let win = SpyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        manager.onComplete = { [weak win] in
            win?.close()
        }

        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let row = try sut.inspect().find(ViewType.View<BrowserRowView>.self)
        let rowButton = try row.find(ViewType.Button.self)
        try rowButton.tap()

        XCTAssertEqual(spyOpener.openCalls.count, 1)
        XCTAssertEqual(spyOpener.openCalls.first?.0, "https://example.com")
        XCTAssertEqual(spyOpener.openCalls.first?.1.name, "TestBrowser")
        XCTAssertTrue(win.didClose)
    }

    // MARK: - Footer

    func test_footer_escHint_isVisible() throws {
        let manager = BrowserManager()
        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)

        let hasHint = sut.findAll(textWhere: { $0 == "ESC로 취소" }).isEmpty == false
        XCTAssertTrue(hasHint)
    }

    @MainActor
    func test_cancelButton_closesWindow() throws {
        let manager = BrowserManager()
        let win = SpyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        manager.onComplete = { [weak win] in
            win?.close()
        }

        let rulesStore = RulesStore(userDefaults: UserDefaults(suiteName: "UITests")!)
        let sut = PickerView()
            .environmentObject(manager)
            .environmentObject(rulesStore)
        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        let cancelButton = try XCTUnwrap(buttons.first(where: { button in
            let texts: [String]
            if let label = try? button.labelView() {
                texts = label.findAll(ViewType.Text.self).compactMap { try? $0.string() }
            } else {
                texts = []
            }
            return texts.contains("취소")
        }))

        try cancelButton.tap()
        XCTAssertTrue(win.didClose)
    }
}

private func stubBrowser(name: String, bundleIdentifier: String, isInstalled: Bool = true) -> Browser {
    Browser(
        id: UUID().uuidString,
        name: name,
        bundleIdentifier: bundleIdentifier,
        iconName: "app",
        kind: .custom,
        isInstalled: isInstalled
    )
}

final class SpyWindow: NSWindow {
    var didClose = false
    override func close() {
        didClose = true
        // super.close()는 헤드리스 환경에서 AppKit 상호작용을 유발할 수 있어 생략
    }
}

final class SpyBrowserOpener: BrowserOpening {
    var openCalls: [(String, Browser, BrowserProfile?)] = []
    func open(url: String, with browser: Browser, profile: BrowserProfile?, completionHandler: (() -> Void)? = nil) {
        openCalls.append((url, browser, profile))
        completionHandler?();
    }
}

private extension View {
    func findAll(textWhere predicate: (String) -> Bool) -> [String] {
        (try? self.inspect().findAll(ViewType.Text.self).compactMap { view in
            (try? view.string())
        }.filter { text in
            predicate(text)
        }) ?? []
    }
}
