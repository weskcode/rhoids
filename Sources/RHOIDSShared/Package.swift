// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RHOIDSShared",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "RHOIDSShared", targets: ["RHOIDSShared"]),
    ],
    targets: [
        .target(name: "RHOIDSShared"),
    ]
)
