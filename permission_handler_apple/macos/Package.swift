// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PermissionHandlerMacos",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "PermissionHandlerMacosCore",
            targets: ["PermissionHandlerMacosCore"]
        ),
    ],
    targets: [
        .target(
            name: "PermissionHandlerAppleTypes",
            path: "Sources/PermissionHandlerAppleTypes",
            publicHeadersPath: "include"
        ),
        .target(
            name: "PermissionHandlerMacosCore",
            dependencies: ["PermissionHandlerAppleTypes"],
            path: "Sources/PermissionHandlerMacosCore"
        ),
        .testTarget(
            name: "PermissionHandlerMacosCoreTests",
            dependencies: ["PermissionHandlerMacosCore"],
            path: "Tests/PermissionHandlerMacosCoreTests"
        ),
    ]
)
