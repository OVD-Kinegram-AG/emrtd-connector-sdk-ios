// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Kinegram eMRTD Connector",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "KinegramEmrtdConnector",
            targets: ["KinegramEmrtdConnector"]
        )
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "KinegramEmrtd",
            path: "Framework/KinegramEmrtd.xcframework"
        ),
        .target(
            name: "KinegramEmrtdConnector",
            dependencies: ["KinegramEmrtd"],
            path: "Sources/KinegramEmrtdConnector",
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
