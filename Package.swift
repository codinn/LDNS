// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LDNS",
    products: [
        // openssl.xcframework
        .library(
            name: "ldns",
            targets: ["ldns"]),
        // LDNS libray, can be imported by swift
        .library(
            name: "LDNS",
            targets: ["LDNS", "ldns"]),
    ],
    dependencies: [
    ],
    targets: [
        .binaryTarget(
            name: "ldns",
            url: "https://codinn.com/download/ldns-1.7.1.xcframework.zip",
            checksum: "44f43e8b5fc9e89f598da9ae4bbc4ec916393f622c57568cfb81d769db88b22c"
        ),
        .target(name: "LDNS",
                dependencies: ["ldns"])
    ]
)

/* 
xcframework successfully written out to: frameworks/ldns.xcframework
44f43e8b5fc9e89f598da9ae4bbc4ec916393f622c57568cfb81d769db88b22c
*/
