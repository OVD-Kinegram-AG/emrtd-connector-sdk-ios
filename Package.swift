// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Kinegram eMRTD Connector",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "KinegramEmrtdConnector",
            targets: ["KinegramEmrtdConnector"]
        )
    ],
    dependencies: [],
    targets: [
        // Binary distribution of the Connector
        .binaryTarget(
            name: "KinegramEmrtdConnector",
            path: "Framework/KinegramEmrtdConnector.xcframework"
        )
    ]
)
