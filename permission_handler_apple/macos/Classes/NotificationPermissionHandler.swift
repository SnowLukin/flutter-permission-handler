import Foundation
import UserNotifications

actor NotificationPermissionHandler {
    enum RequestError: Error {
        case alreadyRequesting
    }

    private static let notificationPermission = Int(PermissionGroup.PermissionGroupNotification.rawValue)
    private let center = UNUserNotificationCenter.current()
    private var isRequesting = false

    func check(permission: Int) async -> Int {
        guard permission == Self.notificationPermission else {
            return Int(PermissionStatus.denied.rawValue)
        }
        let status = await center.notificationSettings().authorizationStatus
        return Int(permissionStatus(for: status).rawValue)
    }

    func request(permissions: [Int]) async throws -> [Int: Int] {
        guard !isRequesting else {
            throw RequestError.alreadyRequesting
        }
        isRequesting = true
        defer { isRequesting = false }

        var results = Dictionary(uniqueKeysWithValues: Set(permissions).map {
            ($0, Int(PermissionStatus.denied.rawValue))
        })
        guard permissions.contains(Self.notificationPermission) else {
            return results
        }
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        results[Self.notificationPermission] = Int(permissionStatus(for: status).rawValue)
        return results
    }

    private func permissionStatus(for status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .denied
        case .denied: return .permanentlyDenied
        case .authorized: return .granted
        case .provisional: return .provisional
        @unknown default: return .restricted
        }
    }
}
