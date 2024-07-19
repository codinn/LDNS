// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LDNS",
    products: [
        // ldns.xcframework
        .library(
            name: "libldns",
            targets: ["libldns"]),
        // LDNS libray, can be imported by swift
        .library(
            name: "LDNS",
            targets: ["LDNS", "libldns"]),
    ],
    dependencies: [
    ],
    targets: [
        .binaryTarget(
            name: "libldns",
            url: "https://github.com/codinn/LDNS/releases/download/1.8.3/ldns.xcframework.zip",
            checksum: "9855b0ca0e1d0ec1ed1b7ccb910cc133f9fc23f6aaf13c25879d0d4f9a408dcf"
        ),
        .target(name: "LDNS",
                dependencies: ["libldns"])
    ]
)
