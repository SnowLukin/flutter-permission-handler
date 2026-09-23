import Foundation
import UserNotifications
#if SWIFT_PACKAGE
import PermissionHandlerAppleTypes
#endif

protocol NotificationCenterClient: Sendable {
    func notificationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws
}

enum PermissionRequestError: Error {
    case alreadyRequesting
}

actor NotificationPermissionHandler {
    private static let notificationPermission = Int(PermissionGroup.PermissionGroupNotification.rawValue)
    private let center: NotificationCenterClient
    private var isRequesting = false

    init(center: NotificationCenterClient) {
        self.center = center
    }

    func check(permission: Int) async -> Int {
        guard permission == Self.notificationPermission else {
            return Int(PermissionStatus.denied.rawValue)
        }
        let status = await center.notificationStatus()
        return Int(Self.permissionStatus(for: status).rawValue)
    }

    func request(permissions: [Int]) async throws -> [Int: Int] {
        guard !isRequesting else {
            throw PermissionRequestError.alreadyRequesting
        }
        isRequesting = true
        defer { isRequesting = false }

        var results = Dictionary(uniqueKeysWithValues: Set(permissions).map {
            ($0, Int(PermissionStatus.denied.rawValue))
        })
        guard permissions.contains(Self.notificationPermission) else {
            return results
        }
        var status = await center.notificationStatus()
        if status == .notDetermined {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationStatus()
        }
        results[Self.notificationPermission] = Int(Self.permissionStatus(for: status).rawValue)
        return results
    }

    private static func permissionStatus(for status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .denied
        case .denied: return .permanentlyDenied
        case .authorized: return .granted
        case .provisional: return .provisional
        @unknown default: return .restricted
        }
    }
}

protocol SettingsURLOpening: AnyObject {
    func open(_ url: URL) -> Bool
}

final class NotificationSettingsNavigator {
    private let opener: SettingsURLOpening
    private let bundleIdentifier: String?
    private let macOSMajorVersion: Int

    init(
        opener: SettingsURLOpening,
        bundleIdentifier: String?,
        macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) {
        self.opener = opener
        self.bundleIdentifier = bundleIdentifier
        self.macOSMajorVersion = macOSMajorVersion
    }

    func open() -> Bool {
        settingsURLs.contains { opener.open($0) }
    }

    private var settingsURLs: [URL] {
        var urls: [URL] = []
        if macOSMajorVersion < 13 {
            urls.append(URL(fileURLWithPath: "/System/Library/PreferencePanes/Notifications.prefPane"))
        } else if let bundleIdentifier, !bundleIdentifier.isEmpty,
           let bundleURL = URL(
               string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)"
           ) {
            urls.append(bundleURL)
        }
        if let notificationsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.notifications"
        ) {
            urls.append(notificationsURL)
        }
        return urls
    }
}
