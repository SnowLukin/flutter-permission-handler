import Foundation
import UserNotifications
import XCTest
@testable import PermissionHandlerMacosCore

final class NotificationPermissionHandlerTests: XCTestCase {
    func testMapsEveryNotificationAuthorizationStatus() async {
        let cases: [(UNAuthorizationStatus, Int)] = [
            (.notDetermined, 0), (.denied, 4), (.authorized, 1), (.provisional, 5),
        ]
        for (status, expected) in cases {
            let center = FakeNotificationCenter(statuses: [status])
            let handler = NotificationPermissionHandler(center: center)

            let result = await handler.check(permission: 17)
            let statusRequestCount = await center.statusRequestCount()

            XCTAssertEqual(result, expected)
            XCTAssertEqual(statusRequestCount, 1)
        }
    }

    func testRejectsUnsupportedPermissionWithoutConsultingTheSystem() async {
        let center = FakeNotificationCenter(statuses: [])
        let handler = NotificationPermissionHandler(center: center)

        let result = await handler.check(permission: 1)
        let statusRequestCount = await center.statusRequestCount()

        XCTAssertEqual(result, 0)
        XCTAssertEqual(statusRequestCount, 0)
    }

    func testReturnsGrantedWhenTheSystemAcceptsTheRequest() async throws {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined, .authorized]
        )
        let handler = NotificationPermissionHandler(center: center)

        let result = try await handler.request(permissions: [17])
        let requestCount = await center.requestCount()
        let requestedOptions = await center.requestedOptions()

        XCTAssertEqual(result, [17: 1])
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(requestedOptions, [.alert, .sound, .badge])
    }

    func testReturnsPermanentlyDeniedWhenTheSystemRejectsTheRequest() async throws {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined, .denied]
        )
        let handler = NotificationPermissionHandler(center: center)

        let result = try await handler.request(permissions: [17])
        let requestCount = await center.requestCount()

        XCTAssertEqual(result, [17: 4])
        XCTAssertEqual(requestCount, 1)
    }

    func testKeepsProvisionalStatusWithoutAnotherRequest() async throws {
        let center = FakeNotificationCenter(statuses: [.provisional])
        let handler = NotificationPermissionHandler(center: center)

        let result = try await handler.request(permissions: [17])
        let requestCount = await center.requestCount()

        XCTAssertEqual(result, [17: 5])
        XCTAssertEqual(requestCount, 0)
    }

    func testDoesNotRequestAgainAfterTheUserHasAnswered() async throws {
        let center = FakeNotificationCenter(statuses: [.denied])
        let handler = NotificationPermissionHandler(center: center)

        let result = try await handler.request(permissions: [17])
        let requestCount = await center.requestCount()

        XCTAssertEqual(result, [17: 4])
        XCTAssertEqual(requestCount, 0)
    }

    func testHandlesEmptyMixedAndDuplicatePermissionLists() async throws {
        let center = FakeNotificationCenter(statuses: [.authorized])
        let handler = NotificationPermissionHandler(center: center)

        let empty = try await handler.request(permissions: [])
        let emptyStatusRequestCount = await center.statusRequestCount()

        XCTAssertEqual(empty, [:])
        XCTAssertEqual(emptyStatusRequestCount, 0)

        let mixed = try await handler.request(permissions: [17, 1, 17, 1])
        let mixedStatusRequestCount = await center.statusRequestCount()
        let requestCount = await center.requestCount()

        XCTAssertEqual(mixed, [17: 1, 1: 0])
        XCTAssertEqual(mixedStatusRequestCount, 1)
        XCTAssertEqual(requestCount, 0)
    }

    func testPropagatesRequestError() async {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined],
            requestOutcomes: [.failure]
        )
        let handler = NotificationPermissionHandler(center: center)

        do {
            _ = try await handler.request(permissions: [17])
            XCTFail("Expected the authorization error to propagate")
        } catch let error as FakeError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("Received an unexpected error")
        }
    }

    func testAllowsANewRequestAfterAnAuthorizationError() async throws {
        let center = FakeNotificationCenter(
            statuses: [.notDetermined, .notDetermined, .authorized],
            requestOutcomes: [.failure, .success]
        )
        let handler = NotificationPermissionHandler(center: center)

        do {
            _ = try await handler.request(permissions: [17])
            XCTFail("Expected the first authorization request to fail")
        } catch let error as FakeError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("Received an unexpected error")
        }

        let result = try await handler.request(permissions: [17])
        let requestCount = await center.requestCount()

        XCTAssertEqual(result, [17: 1])
        XCTAssertEqual(requestCount, 2)
    }

    func testReadsTheCurrentStatusForEveryCheck() async {
        let center = FakeNotificationCenter(statuses: [.authorized, .denied])
        let handler = NotificationPermissionHandler(center: center)

        let initialResult = await handler.check(permission: 17)
        let updatedResult = await handler.check(permission: 17)
        let statusRequestCount = await center.statusRequestCount()

        XCTAssertEqual(initialResult, 1)
        XCTAssertEqual(updatedResult, 4)
        XCTAssertEqual(statusRequestCount, 2)
    }

    func testRejectsAConcurrentRequestWhileTheSystemRequestIsInFlight() async throws {
        let center = BlockingNotificationCenter()
        let handler = NotificationPermissionHandler(center: center)
        let firstRequest = Task {
            try await handler.request(permissions: [17])
        }

        await center.waitUntilRequestStarts()

        do {
            _ = try await handler.request(permissions: [17])
            XCTFail("Expected the concurrent authorization request to be rejected")
        } catch PermissionRequestError.alreadyRequesting {
        } catch {
            XCTFail("Received an unexpected error")
        }

        let requestCountWhileFirstIsPending = await center.requestCount()
        XCTAssertEqual(requestCountWhileFirstIsPending, 1)

        await center.releaseFirstRequest()

        let firstResult = try await firstRequest.value
        let finalRequestCount = await center.requestCount()

        XCTAssertEqual(firstResult, [17: 1])
        XCTAssertEqual(finalRequestCount, 1)
    }

    func testOpensEachFlavorWithoutFallingBackAfterSuccess() {
        for bundleIdentifier in ["com.example.permissionhandler", "com.example.permissionhandler.beta"] {
            let opener = FakeSettingsURLOpener(results: [true])
            let navigator = NotificationSettingsNavigator(
                opener: opener,
                bundleIdentifier: bundleIdentifier,
                macOSMajorVersion: 13
            )

            let didOpen = navigator.open()
            let urls = opener.urls

            XCTAssertTrue(didOpen)
            XCTAssertEqual(urls.count, 1)
            XCTAssertTrue(urls[0].absoluteString.contains(bundleIdentifier))
        }
    }

    func testReturnsFalseWhenSettingsCannotBeOpened() {
        let opener = FakeSettingsURLOpener(results: [false])
        let navigator = NotificationSettingsNavigator(
            opener: opener,
            bundleIdentifier: nil,
            macOSMajorVersion: 13
        )

        let didOpen = navigator.open()
        let urls = opener.urls

        XCTAssertFalse(didOpen)
        XCTAssertEqual(urls.count, 1)
    }

    func testFallsBackToTheNotificationPreferencePaneOnMacOS13OrLater() {
        let opener = FakeSettingsURLOpener(results: [false, true])
        let navigator = NotificationSettingsNavigator(
            opener: opener,
            bundleIdentifier: "com.example.permissionhandler",
            macOSMajorVersion: 13
        )

        let didOpen = navigator.open()
        let urls = opener.urls

        XCTAssertTrue(didOpen)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(
            urls.first?.absoluteString,
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.example.permissionhandler"
        )
        XCTAssertEqual(
            urls.last?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.notifications"
        )
    }

    func testOpensTheNotificationsPreferencePaneFirstOnMacOS12() {
        let opener = FakeSettingsURLOpener(results: [true])
        let navigator = NotificationSettingsNavigator(
            opener: opener,
            bundleIdentifier: "com.example.permissionhandler",
            macOSMajorVersion: 12
        )

        let didOpen = navigator.open()
        let urls = opener.urls

        XCTAssertTrue(didOpen)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(
            urls.first?.path,
            "/System/Library/PreferencePanes/Notifications.prefPane"
        )
    }

    func testFallsBackToTheGeneralNotificationSettingsOnMacOS12() {
        let opener = FakeSettingsURLOpener(results: [false, true])
        let navigator = NotificationSettingsNavigator(
            opener: opener,
            bundleIdentifier: "com.example.permissionhandler",
            macOSMajorVersion: 12
        )

        let didOpen = navigator.open()
        let urls = opener.urls

        XCTAssertTrue(didOpen)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(
            urls.first?.path,
            "/System/Library/PreferencePanes/Notifications.prefPane"
        )
        XCTAssertEqual(
            urls.last?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.notifications"
        )
    }
}

private actor FakeNotificationCenter: NotificationCenterClient {
    private var statuses: [UNAuthorizationStatus]
    private var requestOutcomes: [RequestOutcome]
    private var statusRequests = 0
    private var requests = 0
    private var options: UNAuthorizationOptions = []

    init(
        statuses: [UNAuthorizationStatus],
        requestOutcomes: [RequestOutcome] = [.success]
    ) {
        self.statuses = statuses
        self.requestOutcomes = requestOutcomes
    }

    func notificationStatus() async -> UNAuthorizationStatus {
        statusRequests += 1
        return statuses.removeFirst()
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws {
        requests += 1
        self.options = options

        switch requestOutcomes.removeFirst() {
        case .success:
            return
        case .failure:
            throw FakeError.failed
        }
    }

    func statusRequestCount() -> Int {
        statusRequests
    }

    func requestCount() -> Int {
        requests
    }

    func requestedOptions() -> UNAuthorizationOptions {
        options
    }
}

private actor BlockingNotificationCenter: NotificationCenterClient {
    private var isReleased = false
    private var requests = 0
    private var requestStartWaiter: CheckedContinuation<Void, Never>?
    private var requestReleaseWaiter: CheckedContinuation<Void, Never>?

    func notificationStatus() async -> UNAuthorizationStatus {
        isReleased ? .authorized : .notDetermined
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws {
        requests += 1
        guard requests == 1 else {
            throw FakeError.unexpectedSecondRequest
        }

        requestStartWaiter?.resume()
        requestStartWaiter = nil

        await withCheckedContinuation { continuation in
            requestReleaseWaiter = continuation
        }
    }

    func waitUntilRequestStarts() async {
        guard requests == 0 else {
            return
        }
        await withCheckedContinuation { continuation in
            requestStartWaiter = continuation
        }
    }

    func releaseFirstRequest() {
        isReleased = true
        requestReleaseWaiter?.resume()
        requestReleaseWaiter = nil
    }

    func requestCount() -> Int {
        requests
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

private enum RequestOutcome: Sendable {
    case success
    case failure
}

private enum FakeError: Error, Equatable {
    case failed
    case unexpectedSecondRequest
}
