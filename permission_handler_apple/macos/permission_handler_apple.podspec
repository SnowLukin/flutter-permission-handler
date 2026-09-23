Pod::Spec.new do |s|
  s.name             = 'permission_handler_apple'
  s.version          = '9.4.10'
  s.summary          = 'Permission plugin for Flutter.'
  s.description      = <<-DESC
Permission plugin for Flutter. This plugin provides a macOS API to request and check permissions.
                       DESC
  s.homepage         = 'https://github.com/baseflowit/flutter-permission-handler'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Baseflow' => 'hello@baseflow.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift', 'Sources/PermissionHandlerMacosCore/**/*.swift', 'Sources/PermissionHandlerAppleTypes/**/*.{h,m}'
  s.osx.deployment_target = '12.0'
  s.dependency 'FlutterMacOS'
  s.swift_version = '5.9'
end
