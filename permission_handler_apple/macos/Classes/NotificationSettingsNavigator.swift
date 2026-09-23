import AppKit

@MainActor
final class NotificationSettingsNavigator {
    func open() -> Bool {
        if #available(macOS 13, *) {
            if let bundleIdentifier = Bundle.main.bundleIdentifier,
               let url = URL(
                   string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)"
               ), NSWorkspace.shared.open(url) {
                return true
            }
        } else {
            let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Notifications.prefPane")
            if NSWorkspace.shared.open(url) {
                return true
            }
        }

        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
