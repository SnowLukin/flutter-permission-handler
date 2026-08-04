import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'src/permissions/permission_handlers.dart';
import 'src/pigeon/apple_permissions.g.dart';
import 'src/proxies/apple_permissions_proxy.dart';

/// Platform implementation of [permission_handler] for Apple platforms (iOS).
///
/// Orchestrates permission checks, requests, and app-settings navigation by
/// delegating to [PermissionHandlers] and Pigeon ProxyApi types.
class PermissionHandlerApple extends PermissionHandlerPlatform {
  /// Creates an Apple platform implementation.
  ///
  /// [proxy] and [handlers] are injectable for tests.
  factory PermissionHandlerApple({
    ApplePermissionsProxy? proxy,
    PermissionHandlers? handlers,
  }) {
    if (handlers != null) {
      return PermissionHandlerApple._(handlers);
    }

    final resolvedProxy = proxy ?? ApplePermissionsProxy();
    return PermissionHandlerApple._(
      PermissionHandlers(
        proxy: resolvedProxy,
        isEnabled: (permission) => resolvedProxy
            .compileFlagsHostApi()
            .isPermissionGroupEnabled(permission.value),
      ),
    );
  }

  PermissionHandlerApple._(this._handlers);

  /// Registers the Apple platform implementation.
  static void registerWith() {
    PermissionHandlerPlatform.instance = PermissionHandlerApple();
  }

  final PermissionHandlers _handlers;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) {
    if (!_handlers.supports(permission)) {
      return Future.value(PermissionStatus.denied);
    }
    return _handlers.checkPermissionStatus(permission);
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) {
    return _handlers.checkServiceStatus(permission);
  }

  @override
  Future<bool> openAppSettings() {
    return UIApplication.shared.openSettingsURL();
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    if (permissions.isEmpty) {
      return {};
    }

    final statuses = await Future.wait(
      permissions.map(_handlers.requestPermission),
    );

    return Map<Permission, PermissionStatus>.fromIterables(
      permissions,
      statuses,
    );
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async {
    return false;
  }
}
