// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SerenesParsing",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SerenesParsing", targets: ["SerenesParsing"])],
    targets: [
        .target(name: "SerenesParsing"),
        .testTarget(name: "SerenesParsingTests", dependencies: ["SerenesParsing"])
    ]
)
