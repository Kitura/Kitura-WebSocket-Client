// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
* Copyright IBM Corporation 2019
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import PackageDescription

let package = Package(
    name: "KituraWebSocketClient",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KituraWebSocketClient",
            targets: ["KituraWebSocketClient"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-WebSocket-NIO", .branch("master")),
        .package(url: "https://github.com/IBM-Swift/Kitura-NIO.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.3.1"),
        .package(url: "https://github.com/IBM-Swift/Kitura-WebSocket-Compression.git", from: "0.1.0"),
        .package(url: "https://github.com/IBM-Swift/LoggerAPI.git", from: "1.7.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "KituraWebSocketClient",
            dependencies: ["NIO", "NIOFoundationCompat", "NIOHTTP1", "NIOSSL", "NIOWebSocket", "NIOConcurrencyHelpers", "NIOExtras", "WebSocketCompression", "Kitura-WebSocket",]),
        .target(
            name: "TestWebSocketClient",
            dependencies: ["KituraWebSocketClient"]),
        .testTarget(
            name: "WebSocketClientTests",
            dependencies: ["KituraWebSocketClient", "Kitura-WebSocket", "KituraNet", "LoggerAPI"]),
    ]
)
