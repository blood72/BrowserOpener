import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var browserManagers: [BrowserManager] = []
    var settingsWindow: NSWindow?
    let rulesStore = RulesStore()
    let browserStore = BrowserStore()
    private let urlInterceptor = URLInterceptor()
    private lazy var windowManager = WindowManager(browserStore: browserStore, rulesStore: rulesStore)

    private var shouldUseRulesForAutomaticOpening: Bool {
        let key = "useRulesForAutomaticOpening"
        let defaults = UserDefaults.standard
        // 기본값: true (규칙 우선 사용)
        if defaults.object(forKey: key) == nil {
            return true
        }
        return defaults.bool(forKey: key)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        urlInterceptor.start() { [weak self] url, sourceAppBundleID in
            self?.handleURL(url, sourceAppBundleID: sourceAppBundleID)
        }
    }

    private func handleURL(_ url: URL, sourceAppBundleID: String?) {
        // 사전에 정의된 규칙으로 브라우저 자동 선택 시도
        let installedBrowsers = browserStore.enabledRuleBrowsers
        if shouldUseRulesForAutomaticOpening,
           let (targetBrowser, profile) = RuleEngine.pickBrowser(
               for: url,
               rules: rulesStore.rules,
               installedBrowsers: installedBrowsers,
               sourceAppBundleID: sourceAppBundleID
           ) {
            let opener = WorkspaceBrowserOpener()
            opener.open(url: url.absoluteString, with: targetBrowser, profile: profile, completionHandler: nil)
            return
        }

        // 규칙에 없으면 브라우저 선택 창 열기
        windowManager.showPicker(for: url, sourceAppBundleID: sourceAppBundleID)
    }

    func openSettings() {
        windowManager.showSettings()
    }
}
