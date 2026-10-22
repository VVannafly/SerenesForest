// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SerenesParsing",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "SerenesParsing", targets: ["SerenesParsing"])],
    targets: [
        .target(name: "SerenesParsing"),
        .testTarget(name: "SerenesParsingTests", dependencies: ["SerenesParsing"])
    ]
)
