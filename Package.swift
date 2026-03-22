// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FormFlowing",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FormFlowing", targets: ["FormFlowing"])
    ],
    targets: [
        .target(
            name: "FormFlowing",
            path: "FormFlowing/Sources"
        )
    ]
)
