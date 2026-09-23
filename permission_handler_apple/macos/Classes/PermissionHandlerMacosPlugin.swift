import Cocoa
import FlutterMacOS
import UserNotifications

public final class PermissionHandlerMacosPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter.baseflow.com/permissions/methods"
    private let permissionHandler = NotificationPermissionHandler(center: MacOSNotificationCenter())
    private let settingsNavigator = NotificationSettingsNavigator(
        opener: WorkspaceSettingsURLOpener(),
        bundleIdentifier: Bundle.main.bundleIdentifier
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        let instance = PermissionHandlerMacosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let responder = MainThreadResponder(result: result)
        switch call.method {
        case "checkPermissionStatus":
            guard let permission = call.arguments as? Int else {
                responder.send(invalidArguments())
                return
            }
            permissionHandler.check(permission: permission) { result in
                responder.send(result)
            }
        case "requestPermissions":
            guard let permissions = call.arguments as? [Int] else {
                responder.send(invalidArguments())
                return
            }
            permissionHandler.request(permissions: permissions) { result in
                responder.send(self.flutterResult(from: result))
            }
        case "checkServiceStatus":
            guard (call.arguments as? Int) != nil else {
                responder.send(invalidArguments())
                return
            }
            responder.send(Int(ServiceStatus.notApplicable.rawValue))
        case "shouldShowRequestPermissionRationale":
            guard (call.arguments as? Int) != nil else {
                responder.send(invalidArguments())
                return
            }
            responder.send(false)
        case "openAppSettings":
            guard call.arguments == nil else {
                responder.send(invalidArguments())
                return
            }
            responder.send(settingsNavigator.open())
        default:
            responder.send(FlutterMethodNotImplemented)
        }
    }

    private func invalidArguments() -> FlutterError {
        FlutterError(
            code: "invalid_arguments",
            message: "Permission call arguments have an invalid format.",
            details: nil
        )
    }

    private func flutterResult<T>(from result: Result<T, Error>) -> Any? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            return FlutterError(
                code: "system_error",
                message: error.localizedDescription,
                details: nil
            )
        }
    }
}

private final class MacOSNotificationCenter: NotificationCenterClient {
    func notificationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        UNUserNotificationCenter.current().requestAuthorization(options: options) { _, error in
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
    }
}

private final class WorkspaceSettingsURLOpener: SettingsURLOpening {
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

private final class MainThreadResponder {
    private let result: FlutterResult

    init(result: @escaping FlutterResult) {
        self.result = result
    }

    func send(_ value: Any?) {
        DispatchQueue.main.async { [result] in
            result(value)
        }
    }
}
