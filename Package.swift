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
            url: "https://github.com/codinn/LDNS/releases/download/1.8.3-p1/ldns.xcframework.zip",
            checksum: "4ede5085dbcb1dc0402d58eb42b15db8190810d9a87f1f9017e7c389aff48abc"
        ),
        .target(name: "LDNS",
                dependencies: ["libldns"])
    ]
)
