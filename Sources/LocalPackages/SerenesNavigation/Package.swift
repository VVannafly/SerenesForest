// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SerenesNavigation",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "SerenesNavigation", targets: ["SerenesNavigation"])],
    targets: [.target(name: "SerenesNavigation")]
)
