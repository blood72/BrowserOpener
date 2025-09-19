import XCTest
@testable import BrowserOpener

final class AppDelegateTests: XCTestCase {

    func test_applicationWillFinishLaunching() {
        // Basic lifecycle test
        let appDelegate = AppDelegate()
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        // Verify no crash
        appDelegate.applicationWillFinishLaunching(notification)
        XCTAssertTrue(true)
    }
}
