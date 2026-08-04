import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_apple/next/permission_handler_apple.dart';
import 'package:permission_handler_apple/next/src/permissions/permission_handlers.dart';
import 'package:permission_handler_apple/next/src/proxies/apple_permissions_proxy.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakePermissionHandlers extends PermissionHandlers {
  _FakePermissionHandlers()
      : super(
          proxy: ApplePermissionsProxy(),
          isEnabled: (_) async => true,
        );

  @override
  bool supports(Permission permission) => true;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) {
    return Future.value(PermissionStatus.granted);
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) {
    return Future.value(ServiceStatus.enabled);
  }

  @override
  Future<PermissionStatus> requestPermission(Permission permission) {
    return Future.value(PermissionStatus.granted);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionHandlerApple', () {
    test('shouldShowRequestPermissionRationale always returns false', () async {
      final handler = PermissionHandlerApple(
        handlers: _FakePermissionHandlers(),
      );
      expect(
        await handler.shouldShowRequestPermissionRationale(Permission.camera),
        isFalse,
      );
    });

    test('requestPermissions returns empty map for empty input', () async {
      final handler = PermissionHandlerApple(
        handlers: _FakePermissionHandlers(),
      );

      expect(await handler.requestPermissions([]), isEmpty);
    });

    test('checkPermissionStatus returns denied for unsupported permission',
        () async {
      final handler = PermissionHandlerApple(
        handlers: PermissionHandlers(
          proxy: ApplePermissionsProxy(),
          isEnabled: (_) async => true,
        ),
      );

      expect(
        await handler.checkPermissionStatus(Permission.sms),
        PermissionStatus.denied,
      );
    });

    test('requestPermissions returns statuses for each permission', () async {
      final handler = PermissionHandlerApple(
        handlers: _FakePermissionHandlers(),
      );

      expect(
        await handler.requestPermissions([
          Permission.camera,
          Permission.microphone,
        ]),
        {
          Permission.camera: PermissionStatus.granted,
          Permission.microphone: PermissionStatus.granted,
        },
      );
    });
  });
}
