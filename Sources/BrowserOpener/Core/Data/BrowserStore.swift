import Foundation
import Combine

struct BrowserPreference: Codable {
    var isEnabled: Bool
    var isHidden: Bool
    var displayName: String?
    var profiles: [BrowserProfile]?
    var defaultProfileID: String?
}

final class BrowserStore: ObservableObject {
    @Published private(set) var browsers: [Browser] = []

    private let userDefaults: UserDefaults
    private let customBrowsersKey = "CustomBrowsers"
    private let preferencesKey = "BrowserPreferences"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func load() {
        let presets = Browser.presetBrowsers()
        let customs = loadCustomBrowsers()
        let preferences = loadPreferences()

        var merged = (presets + customs).map { browser -> Browser in
            var updated = browser
            if let preference = preferences[browser.id] {
                updated.isEnabled = preference.isEnabled && browser.isInstalled
                updated.isHidden = preference.isHidden
                if let displayName = preference.displayName, !displayName.isEmpty {
                    updated.name = displayName
                }
                if let storedProfiles = preference.profiles, !storedProfiles.isEmpty {
                    updated.profiles = storedProfiles
                }
                if let storedDefaultProfileID = preference.defaultProfileID {
                    updated.defaultProfileID = storedDefaultProfileID
                }
            } else {
                updated.isEnabled = browser.isInstalled
                updated.isHidden = false
            }

            if !updated.isInstalled {
                updated.isEnabled = false
            }

            normalizeProfiles(for: &updated)

            return updated
        }

        merged.sort(by: Browser.sortingRule)
        browsers = merged
        persistCustomBrowsers()
        persistPreferences()
    }

    func refreshInstallationStatus() {
        browsers = browsers.map { browser in
            var updated = browser
            updated.isInstalled = Browser.isAppInstalled(bundleId: browser.bundleIdentifier)
            if !updated.isInstalled {
                updated.isEnabled = false
            }
            return updated
        }

        persistPreferences()
    }

    func addCustomBrowser(name: String, bundleIdentifier: String) {
        let alreadyExists = browsers.contains { $0.bundleIdentifier == bundleIdentifier }
        guard !alreadyExists else {
            refreshInstallationStatus()
            return
        }

        let browser = Browser(
            id: UUID().uuidString,
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: "app.fill",
            kind: .custom,
            isInstalled: Browser.isAppInstalled(bundleId: bundleIdentifier),
            isEnabled: Browser.isAppInstalled(bundleId: bundleIdentifier),
            isHidden: false
        )

        browsers.append(browser)
        sortAndPersist()
    }

    func removeCustomBrowser(id: String) {
        guard let browser = browsers.first(where: { $0.id == id }), browser.isCustom else {
            return
        }

        browsers.removeAll { $0.id == id }
        sortAndPersist()
    }

    func setEnabled(_ isEnabled: Bool, for id: String) {
        updateBrowser(id) { browser in
            guard browser.isInstalled else {
                browser.isEnabled = false
                return
            }
            browser.isEnabled = isEnabled
        }
    }

    func setHidden(_ hidden: Bool, for id: String) {
        updateBrowser(id) { browser in
            guard browser.isPreset else { return }
            browser.isHidden = hidden
            if hidden {
                browser.isEnabled = false
            }
        }
    }

    func updateBrowserMetadata(
        id: String,
        displayName: String,
        bundleIdentifier: String?,
        profiles: [BrowserProfile],
        defaultProfileID: String?
    ) {
        updateBrowser(id) { browser in
            browser.name = displayName

            if browser.isCustom, let bundleIdentifier, !bundleIdentifier.isEmpty {
                if browser.bundleIdentifier != bundleIdentifier {
                    browser.bundleIdentifier = bundleIdentifier
                    browser.isInstalled = Browser.isAppInstalled(bundleId: bundleIdentifier)
                    if !browser.isInstalled {
                        browser.isEnabled = false
                    }
                } else {
                    browser.bundleIdentifier = bundleIdentifier
                }
            }

            browser.profiles = profiles
            browser.defaultProfileID = defaultProfileID
        }
    }

    func browser(withID id: String) -> Browser? {
        browsers.first { $0.id == id }
    }

    var installedBrowsers: [Browser] {
        browsers.filter { $0.isInstalled }
    }

    var enabledRuleBrowsers: [Browser] {
        browsers.filter { $0.isInstalled && $0.isEnabled && !$0.isHidden }
    }

    private func loadCustomBrowsers() -> [Browser] {
        guard let data = userDefaults.data(forKey: customBrowsersKey) else {
            return []
        }

        guard let decoded = try? JSONDecoder().decode([Browser].self, from: data) else {
            return []
        }

        return decoded.map { browser in
            var updated = browser
            updated.kind = .custom
            if updated.id.isEmpty {
                updated.id = UUID().uuidString
            }
            updated.isInstalled = Browser.isAppInstalled(bundleId: browser.bundleIdentifier)
            if updated.profiles.isEmpty {
                updated.profiles = BrowserProfileCatalog.profiles(
                    forBundleIdentifier: updated.bundleIdentifier,
                    displayName: updated.name
                )
            }
            if updated.defaultProfileID == nil {
                updated.defaultProfileID = updated.profiles.first(where: { $0.isDefault })?.id ?? updated.profiles.first?.id
            }
            return updated
        }
    }

    private func loadPreferences() -> [String: BrowserPreference] {
        guard let data = userDefaults.data(forKey: preferencesKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: BrowserPreference].self, from: data)) ?? [:]
    }

    private func persistCustomBrowsers() {
        let customBrowsers = browsers.filter { $0.isCustom }
        guard let data = try? JSONEncoder().encode(customBrowsers) else { return }
        userDefaults.set(data, forKey: customBrowsersKey)
    }

    private func persistPreferences() {
        let preferences = browsers.reduce(into: [String: BrowserPreference]()) { partialResult, browser in
            partialResult[browser.id] = BrowserPreference(
                isEnabled: browser.isEnabled,
                isHidden: browser.isHidden,
                displayName: browser.name,
                profiles: browser.profiles,
                defaultProfileID: browser.defaultProfileID
            )
        }

        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: preferencesKey)
    }

    private func updateBrowser(_ id: String, update: (inout Browser) -> Void) {
        guard let index = browsers.firstIndex(where: { $0.id == id }) else {
            return
        }

        update(&browsers[index])
        normalizeProfiles(for: &browsers[index])
        sortAndPersist()
    }

    private func sortAndPersist() {
        browsers.sort(by: Browser.sortingRule)
        persistCustomBrowsers()
        persistPreferences()
    }

    private func normalizeProfiles(for browser: inout Browser) {
        if browser.profiles.isEmpty {
            browser.profiles = BrowserProfileCatalog.profiles(
                forBundleIdentifier: browser.bundleIdentifier,
                displayName: browser.name
            )
        }

        if let defaultProfileID = browser.defaultProfileID,
           browser.profiles.contains(where: { $0.id == defaultProfileID }) {
            return
        }

        browser.defaultProfileID = browser.profiles.first(where: { $0.isDefault })?.id ?? browser.profiles.first?.id
    }
}

