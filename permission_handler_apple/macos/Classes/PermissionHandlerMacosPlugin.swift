import Cocoa
import FlutterMacOS

public final class PermissionHandlerMacosPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter.baseflow.com/permissions/methods"
    private let permissionHandler = NotificationPermissionHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        let instance = PermissionHandlerMacosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task { @MainActor in
            do {
                result(try await handle(call))
            } catch NotificationPermissionHandler.RequestError.alreadyRequesting {
                result(FlutterError(
                    code: "ERROR_ALREADY_REQUESTING_PERMISSIONS",
                    message: "A request for permissions is already running, please wait for it to finish before doing another request (note that you can request multiple permissions at the same time).",
                    details: nil
                ))
            } catch {
                result(FlutterError(code: "system_error", message: error.localizedDescription, details: nil))
            }
        }
    }

    @MainActor
    private func handle(_ call: FlutterMethodCall) async throws -> Any? {
        switch call.method {
        case "checkPermissionStatus":
            guard let permission = call.arguments as? Int else {
                return invalidArguments()
            }
            return await permissionHandler.check(permission: permission)
        case "requestPermissions":
            guard let permissions = call.arguments as? [Int] else {
                return invalidArguments()
            }
            return try await permissionHandler.request(permissions: permissions)
        case "checkServiceStatus":
            guard (call.arguments as? Int) != nil else {
                return invalidArguments()
            }
            return Int(ServiceStatus.notApplicable.rawValue)
        case "shouldShowRequestPermissionRationale":
            guard (call.arguments as? Int) != nil else {
                return invalidArguments()
            }
            return false
        case "openAppSettings":
            guard call.arguments == nil else {
                return invalidArguments()
            }
            return NotificationSettingsNavigator().open()
        default:
            return FlutterMethodNotImplemented
        }
    }

    private func invalidArguments() -> FlutterError {
        FlutterError(
            code: "invalid_arguments",
            message: "Permission call arguments have an invalid format.",
            details: nil
        )
    }
}
