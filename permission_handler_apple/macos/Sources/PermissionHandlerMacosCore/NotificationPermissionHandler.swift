import Foundation
import UserNotifications

protocol NotificationCenterClient: AnyObject {
    func notificationStatus(completion: @escaping (UNAuthorizationStatus) -> Void)
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

final class NotificationPermissionHandler {
    private static let notificationPermission = 17
    private let center: NotificationCenterClient

    init(center: NotificationCenterClient) {
        self.center = center
    }

    func check(permission: Int, completion: @escaping (Int) -> Void) {
        guard permission == Self.notificationPermission else {
            completion(0)
            return
        }
        center.notificationStatus { status in
            completion(Self.platformValue(for: status))
        }
    }

    func request(
        permissions: [Int],
        completion: @escaping (Result<[Int: Int], Error>) -> Void
    ) {
        let denied = Dictionary(uniqueKeysWithValues: Set(permissions).map { ($0, 0) })
        guard permissions.contains(Self.notificationPermission) else {
            completion(.success(denied))
            return
        }
        let complete: (UNAuthorizationStatus) -> Void = { status in
            var results = denied
            results[Self.notificationPermission] = Self.platformValue(for: status)
            completion(.success(results))
        }
        center.notificationStatus { status in
            guard status == .notDetermined else {
                complete(status)
                return
            }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success:
                    self.center.notificationStatus(completion: complete)
                }
            }
        }
    }

    private static func platformValue(for status: UNAuthorizationStatus) -> Int {
        switch status {
        case .notDetermined: return 0
        case .denied: return 4
        case .authorized: return 1
        case .provisional: return 5
        @unknown default: return 2
        }
    }
}

protocol SettingsURLOpening: AnyObject {
    func open(_ url: URL) -> Bool
}

final class NotificationSettingsNavigator {
    private let opener: SettingsURLOpening
    private let bundleIdentifier: String?

    init(opener: SettingsURLOpening, bundleIdentifier: String?) {
        self.opener = opener
        self.bundleIdentifier = bundleIdentifier
    }

    func open() -> Bool {
        settingsURLs.contains { opener.open($0) }
    }

    private var settingsURLs: [URL] {
        var urls: [URL] = []
        if let bundleIdentifier, !bundleIdentifier.isEmpty,
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
