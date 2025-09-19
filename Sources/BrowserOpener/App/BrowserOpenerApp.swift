import AppKit
import SwiftUI

@main
struct BrowserOpenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 숨겨진 메뉴바 앱으로 변경
        MenuBarExtra("BrowserOpener", systemImage: "globe") {
            Button("설정...") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
}
