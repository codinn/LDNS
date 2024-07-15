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
            checksum: "efa73c7475273e9019bbe71399b0e05e1f2b6a3e18589ea807c33689c05fb196"
        ),
        .target(name: "LDNS",
                dependencies: ["libldns"])
    ]
)
