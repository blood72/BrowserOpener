import Foundation
import AppKit
import Combine

class BrowserManager: ObservableObject {
    @Published var installedBrowsers: [Browser] = []
    @Published var allBrowsers: [Browser] = []
    @Published var currentURL: String = ""
    @Published var sourceAppBundleID: String? = nil

    var onComplete: (() -> Void)?

    private let opener: BrowserOpening
    private let browserStore: BrowserStore
    private var cancellables: Set<AnyCancellable> = []

    init(browserStore: BrowserStore = BrowserStore(), opener: BrowserOpening = WorkspaceBrowserOpener()) {
        self.browserStore = browserStore
        self.opener = opener
        bindToStore()
    }

    private func bindToStore() {
        updateBrowsers(browserStore.browsers)

        browserStore.$browsers
            .receive(on: RunLoop.main)
            .sink { [weak self] browsers in
                self?.updateBrowsers(browsers)
            }
            .store(in: &cancellables)
    }

    private func updateBrowsers(_ browsers: [Browser]) {
        allBrowsers = browsers
        installedBrowsers = browsers.filter { $0.isInstalled && !$0.isHidden }
    }

    func loadInstalledBrowsers() {
        browserStore.refreshInstallationStatus()
    }

    func addCustomBrowser(name: String, bundleIdentifier: String) {
        browserStore.addCustomBrowser(name: name, bundleIdentifier: bundleIdentifier)
    }

    func removeCustomBrowser(_ browser: Browser) {
        browserStore.removeCustomBrowser(id: browser.id)
    }

    func updateURL(_ url: String, sourceAppBundleID: String? = nil) {
        self.currentURL = url
        self.sourceAppBundleID = sourceAppBundleID
    }

    func openURL(_ url: String, with browser: Browser, profile: BrowserProfile? = nil) {
        let targetProfile = profile ?? browser.defaultProfile
        opener.open(url: url, with: browser, profile: targetProfile, completionHandler: {
            // URL 열기 완료 후 창 닫기
            self.close()
        })
    }

    func close() {
        onComplete?()
    }
}
