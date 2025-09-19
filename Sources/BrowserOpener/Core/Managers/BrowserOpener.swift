import Foundation
import AppKit

protocol BrowserOpening {
    func open(url: String, with browser: Browser, profile: BrowserProfile?, completionHandler: (() -> Void)?)
}

final class WorkspaceBrowserOpener: BrowserOpening {
    func open(url: String, with browser: Browser, profile: BrowserProfile?, completionHandler: (() -> Void)? = nil) {
        guard
            let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: browser.bundleIdentifier),
            let urlObj = URL(string: url)
        else { return }

        let profileArguments = profile?.launchArguments ?? []
        let shouldForceNewInstance = !profileArguments.isEmpty

        if !shouldForceNewInstance {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                [urlObj], withApplicationAt: appURL, configuration: config) { _, _ in
                    DispatchQueue.main.async {
                        completionHandler?();
                    }
                }
        } else {
            launchUsingOpenCommand(
                appPath: appURL.path,
                url: urlObj.absoluteString,
                profileArguments: profileArguments,
                forceNewInstance: shouldForceNewInstance,
                completionHandler: completionHandler
            )
        }
    }

    private func launchUsingOpenCommand(
        appPath: String,
        url: String,
        profileArguments: [String],
        forceNewInstance: Bool,
        completionHandler: (() -> Void)?
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        process.arguments = OpenCommandArgumentsBuilder.arguments(
            appPath: appPath,
            url: url,
            profileArguments: profileArguments,
            forceNewInstance: forceNewInstance
        )
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                completionHandler?()
            }
        }

        do {
            try process.run()
        } catch {
            // fallback: arguments 없이 기본 방식으로 실행
            NSWorkspace.shared.open(
                [URL(string: url)!], withApplicationAt: URL(fileURLWithPath: appPath), configuration: NSWorkspace.OpenConfiguration()
            )
            DispatchQueue.main.async {
                completionHandler?()
            }
        }
    }
}

struct OpenCommandArgumentsBuilder {
    static func arguments(
        appPath: String,
        url: String,
        profileArguments: [String],
        forceNewInstance: Bool
    ) -> [String] {
        var components: [String] = []

        if forceNewInstance {
            components.append("-n")
        }

        components.append(contentsOf: ["-a", appPath])

        if !profileArguments.isEmpty {
            // URL을 --args 뒤에 배치하여 앱이 명령줄 인자로 직접 받도록 함
            // 예: open -n -a /path/to/app --args --profile-directory=Work https://example.com
            components.append("--args")
            components.append(contentsOf: profileArguments)
            components.append(url)
        } else {
            // 프로필 인자가 없으면 URL을 open 명령의 인자로 전달
            components.append(url)
        }

        return components
    }
}
