import Foundation
import UserNotifications
import XCTest
@testable import PermissionHandlerMacosCore

final class NotificationPermissionHandlerTests: XCTestCase {
    func testMapsEveryNotificationAuthorizationStatus() {
        let cases: [(UNAuthorizationStatus, Int)] = [
            (.notDetermined, 0), (.denied, 4), (.authorized, 1), (.provisional, 5),
        ]
        for (status, expected) in cases {
            let center = FakeNotificationCenter(statuses: [status])
            let handler = NotificationPermissionHandler(center: center)
            var result: Int?
            handler.check(permission: 17) { result = $0 }
            XCTAssertEqual(result, expected)
            XCTAssertEqual(center.statusRequests, 1)
        }
    }

    func testRejectsUnsupportedPermissionWithoutConsultingTheSystem() {
        let center = FakeNotificationCenter(statuses: [])
        let handler = NotificationPermissionHandler(center: center)
        var result: Int?
        handler.check(permission: 1) { result = $0 }
        XCTAssertEqual(result, 0)
        XCTAssertEqual(center.statusRequests, 0)
    }

    func testReturnsGrantedWhenTheSystemAcceptsTheRequest() {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined, .authorized]
        )
        let handler = NotificationPermissionHandler(center: center)

        var result: Result<[Int: Int], Error>?
        handler.request(permissions: [17]) { result = $0 }

        XCTAssertEqual(try result?.get(), [17: 1])
        XCTAssertEqual(center.requestCount, 1)
        XCTAssertEqual(center.requestedOptions, [.alert, .sound, .badge])
    }

    func testReturnsPermanentlyDeniedWhenTheSystemRejectsTheRequest() {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined, .denied]
        )
        let handler = NotificationPermissionHandler(center: center)

        var result: Result<[Int: Int], Error>?
        handler.request(permissions: [17]) { result = $0 }

        XCTAssertEqual(try result?.get(), [17: 4])
        XCTAssertEqual(center.requestCount, 1)
    }

    func testKeepsProvisionalStatusWithoutAnotherRequest() {
        let center = FakeNotificationCenter(statuses: [.provisional])
        let handler = NotificationPermissionHandler(center: center)

        var result: Result<[Int: Int], Error>?
        handler.request(permissions: [17]) { result = $0 }

        XCTAssertEqual(try result?.get(), [17: 5])
        XCTAssertEqual(center.requestCount, 0)
    }

    func testDoesNotRequestAgainAfterTheUserHasAnswered() {
        let center = FakeNotificationCenter(statuses: [.denied])
        let handler = NotificationPermissionHandler(center: center)

        var result: Result<[Int: Int], Error>?
        handler.request(permissions: [17]) { result = $0 }

        XCTAssertEqual(try result?.get(), [17: 4])
        XCTAssertEqual(center.requestCount, 0)
    }

    func testHandlesEmptyMixedAndDuplicatePermissionLists() {
        let center = FakeNotificationCenter(statuses: [.authorized])
        let handler = NotificationPermissionHandler(center: center)

        var empty: Result<[Int: Int], Error>?
        handler.request(permissions: []) { empty = $0 }
        XCTAssertEqual(try empty?.get(), [:])
        XCTAssertEqual(center.statusRequests, 0)

        var mixed: Result<[Int: Int], Error>?
        handler.request(permissions: [17, 1, 17, 1]) { mixed = $0 }
        XCTAssertEqual(try mixed?.get(), [17: 1, 1: 0])
        XCTAssertEqual(center.statusRequests, 1)
        XCTAssertEqual(center.requestCount, 0)
    }

    func testPropagatesRequestError() {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined],
            requestResult: .failure(FakeError.failed)
        )
        let handler = NotificationPermissionHandler(center: center)

        var result: Result<[Int: Int], Error>?
        handler.request(permissions: [17]) { result = $0 }

        XCTAssertThrowsError(try result?.get())
    }

    func testOpensEachFlavorWithoutFallingBackAfterSuccess() {
        for bundleIdentifier in ["com.example.permissionhandler", "com.example.permissionhandler.beta"] {
            let opener = FakeSettingsURLOpener(results: [true])
            let navigator = NotificationSettingsNavigator(
                opener: opener,
                bundleIdentifier: bundleIdentifier
            )
            XCTAssertTrue(navigator.open())
            XCTAssertEqual(opener.urls.count, 1)
            XCTAssertTrue(opener.urls[0].absoluteString.contains(bundleIdentifier))
        }
    }

    func testReturnsFalseWhenSettingsCannotBeOpened() {
        let opener = FakeSettingsURLOpener(results: [false])
        let navigator = NotificationSettingsNavigator(opener: opener, bundleIdentifier: nil)
        XCTAssertFalse(navigator.open())
        XCTAssertEqual(opener.urls.count, 1)
    }

    func testFallsBackToTheNotificationPreferencePane() {
        let opener = FakeSettingsURLOpener(results: [false, true])
        let navigator = NotificationSettingsNavigator(
            opener: opener,
            bundleIdentifier: "com.example.permissionhandler"
        )

        XCTAssertTrue(navigator.open())
        XCTAssertEqual(opener.urls.count, 2)
        XCTAssertEqual(
            opener.urls.first?.absoluteString,
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.example.permissionhandler"
        )
        XCTAssertEqual(
            opener.urls.last?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.notifications"
        )
    }
}

private final class FakeNotificationCenter: NotificationCenterClient {
    private var statuses: [UNAuthorizationStatus]
    private let requestResult: Result<Void, Error>
    private(set) var statusRequests = 0
    private(set) var requestCount = 0
    private(set) var requestedOptions: UNAuthorizationOptions = []

    init(
        statuses: [UNAuthorizationStatus],
        requestResult: Result<Void, Error> = .success(())
    ) {
        self.statuses = statuses
        self.requestResult = requestResult
    }

    func notificationStatus(
        completion: @escaping (UNAuthorizationStatus) -> Void
    ) {
        statusRequests += 1
        completion(statuses.removeFirst())
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        requestCount += 1
        requestedOptions = options
        completion(requestResult)
    }
}

private final class FakeSettingsURLOpener: SettingsURLOpening {
    private var results: [Bool]
    private(set) var urls: [URL] = []

    init(results: [Bool]) {
        self.results = results
    }

    func open(_ url: URL) -> Bool {
        urls.append(url)
        return results.removeFirst()
    }
}

private enum FakeError: Error {
    case failed
}
