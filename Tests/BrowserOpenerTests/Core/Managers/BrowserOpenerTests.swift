import XCTest
@testable import BrowserOpener

final class BrowserOpenerTests: XCTestCase {

    func test_arguments_withProfileArguments_urlPlacedAfterArgs() {
        // 프로필 인자가 있으면 URL을 --args 뒤에 배치하여
        // 브라우저가 명령줄 인자로 직접 받도록 함
        let result = OpenCommandArgumentsBuilder.arguments(
            appPath: "/Applications/Google Chrome.app",
            url: "https://example.com",
            profileArguments: ["--incognito"],
            forceNewInstance: false
        )

        XCTAssertEqual(
            result,
            ["-a", "/Applications/Google Chrome.app", "--args", "--incognito", "https://example.com"]
        )
    }

    func test_arguments_withForceNewInstance_includesDashN() {
        let result = OpenCommandArgumentsBuilder.arguments(
            appPath: "/Applications/Google Chrome.app",
            url: "https://example.com",
            profileArguments: ["--incognito", "--profile-directory=Work"],
            forceNewInstance: true
        )

        XCTAssertEqual(
            result,
            [
                "-n",
                "-a",
                "/Applications/Google Chrome.app",
                "--args",
                "--incognito",
                "--profile-directory=Work",
                "https://example.com"
            ]
        )
    }

    func test_arguments_withoutProfileArguments_urlBeforeArgs() {
        // 프로필 인자가 없으면 URL을 open 명령의 인자로 전달
        let result = OpenCommandArgumentsBuilder.arguments(
            appPath: "/Applications/Safari.app",
            url: "https://example.com",
            profileArguments: [],
            forceNewInstance: true
        )

        XCTAssertEqual(
            result,
            ["-n", "-a", "/Applications/Safari.app", "https://example.com"]
        )
    }
}
