import AppKit
import SwiftUI

class WindowManager {
    // 윈도우 관리 상태
    private var browserManagers: [BrowserManager] = []
    private var settingsWindow: NSWindow?

    // 의존성 주입
    private let browserStore: BrowserStore
    private let rulesStore: RulesStore

    init(browserStore: BrowserStore, rulesStore: RulesStore) {
        self.browserStore = browserStore
        self.rulesStore = rulesStore
    }

    // 브라우저 선택 창(PickerView) 열기
    func showPicker(for url: URL, sourceAppBundleID: String?) {
        // 새로운 BrowserManager 인스턴스 생성
        let newBrowserManager = BrowserManager(browserStore: browserStore)
        browserManagers.append(newBrowserManager)

        // 새 창 생성
        let pickerView = PickerView()
            .environmentObject(newBrowserManager)
            .environmentObject(rulesStore)

        let hostingController = NSHostingController(rootView: pickerView)
        let window = NSWindow(contentViewController: hostingController)

        // 윈도우 스타일 설정
        window.title = "브라우저 선택"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.center()

        // 포커스 링 제거
        window.contentView?.focusRingType = .none
        hostingController.view.focusRingType = .none

        window.makeKeyAndOrderFront(nil)

        // BrowserManager 완료 핸들러 설정
        newBrowserManager.onComplete = { [weak window] in window?.close() }

        // URL 설정
        newBrowserManager.updateURL(url.absoluteString, sourceAppBundleID: sourceAppBundleID)

        // 창이 닫힐 때 리소스 정리
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self, weak newBrowserManager] _ in
            guard let self = self, let manager = newBrowserManager else { return }
            if let index = self.browserManagers.firstIndex(where: { $0 === manager }) {
                self.browserManagers.remove(at: index)
            }
        }

        // 앱 활성화
        NSApp.activate(ignoringOtherApps: true)
    }

    // 설정 창(SettingsView) 열기
    func showSettings() {
        // 이미 설정 창이 열려있다면 포커스만 이동
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 새 설정 창 생성
        let settingsView = SettingsView()
            .environmentObject(rulesStore)
            .environmentObject(browserStore)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "설정"
        window.styleMask = [.titled, .closable]
        window.level = .normal
        window.center()

        // 포커스 링 제거
        window.contentView?.focusRingType = .none
        hostingController.view.focusRingType = .none

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)

        // 창이 닫힐 때 참조 제거
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
