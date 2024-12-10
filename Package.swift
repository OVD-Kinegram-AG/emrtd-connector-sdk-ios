// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "Kinegram eMRTD Connector",
    platforms: [.iOS(.v13)],
    products: [.library(name: "KinegramEmrtdConnector", targets: ["KinegramEmrtdConnector"])],
    targets: [.target(name: "KinegramEmrtdConnector")],
    swiftLanguageVersions: [.v5]
)
