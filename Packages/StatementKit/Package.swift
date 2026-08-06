// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatementKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "StatementParsing", targets: ["StatementParsing"]),
        .library(name: "StatementParsingPDFKit", targets: ["StatementParsingPDFKit"]),
    ],
    targets: [
        .target(
            name: "StatementParsing",
            resources: [.copy("Resources/BankProfiles")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "StatementParsingPDFKit",
            dependencies: ["StatementParsing"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StatementParsingTests",
            dependencies: ["StatementParsing"],
            resources: [.process("Fixtures")]
        ),
    ]
)
