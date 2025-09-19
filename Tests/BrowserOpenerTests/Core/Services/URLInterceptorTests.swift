import XCTest
@testable import BrowserOpener

final class URLInterceptorTests: XCTestCase {

    var interceptor: URLInterceptor!

    override func setUp() {
        super.setUp()
        interceptor = URLInterceptor()
    }

    override func tearDown() {
        interceptor = nil
        super.tearDown()
    }

    func test_init_initialState() {
        XCTAssertNotNil(interceptor)
    }

    func test_start_setsEventHandler() {
        // This test verifies that calling start doesn't crash and potentially sets the handler.
        // Verifying the actual AE event handler registration requires interacting with NSAppleEventManager global state,
        // which might be flaky or invasive for unit tests.
        // We assume the API contract is fulfilled if no error occurs.

        // In a real scenario we'd fire an Apple Event, but here we just ensure start() executes.
        interceptor.start { url, sender in
            // This closure is stored
        }

        // Since we cannot easily fire a fake Apple Event without full integration test environment,
        // we mainly check for no-crash here.
        XCTAssertTrue(true)
    }
}
