<p align="center">
    <a href="http://kitura.io/">
        <img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>

<p align="center">
    <a href="https://travis-ci.org/IBM-Swift/Kitura-WebSocket-Client">
    <img src="https://travis-ci.org/IBM-Swift/Kitura-WebSocket-Client.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# Kitura-WebSocket-Client
A WebSocket compression library based on SwiftNIO

## WebSocket Client
WebSocket Client is a WebSocket endpoint, defined by [RFC6455](https://tools.ietf.org/html/rfc6455) allows to upgrade an existing HTTP connection to WebSocket connection  and communicate.

This document discusses the implementation of WebSocket Client in [Kitura-WebSocket-Client](https://github.com/IBM-Swift/Kitura-WebSocket-Client) API using  [SwiftNIO](https://github.com/apple/swift-nio).

This document assumes the reader is aware of the fundamentals of the [WebSocket protocol](https://tools.ietf.org/html/rfc6455).

### Table of contents
[Usage](README.md#1-usage)

###  Usage

#### Add dependencies

Add the `Kitura-WebSocket-Client` package to the dependencies within your application’s `Package.swift` file. Substitute `"x.x.x"` with the latest `Kitura-WebSocket-Client` [release](https://github.com/IBM-Swift/Kitura-WebSocket-Client/releases).

```swift
.package(url: "https://github.com/IBM-Swift/Kitura-WebSocket-Client.git", from: "x.x.x")
```

Add `Kitura-WebSocket-Client` to your target's dependencies:

```swift
.target(name: "example", dependencies: ["KituraWebSocketClient"]),
```

#### Import package

  ```swift
  import KituraWebSocketClient
  ```

#### Creating a new WebSocket Client

Add a WebSocket Client to your application as follows:

```swift
let client = WebSocketClient(host: "localhost", port: 8989, uri: "/", requestKey: "test")
```
or

```swift
let client = WebSocketClient("ws://localhost:8080")
```
To enable compression the structure `WebSocketCompressionConfiguration` needs to be passed as an argument.

For example :

```swift
let client = WebSocketClient(host: "localhost", port: 8989, uri: "/", requestKey: "test", compressionConfig: WebSocketCompressionConfiguration())
```

#### Sending WebSocket Messages

Using this library makes sending messages, be it binary or text  easier. For example code for sending a text message to WebSocket server:

```swift
client.sendMessage("Kitura-WebSocket")
```
Similarly the apis `sendBinary`, `ping`, `pong`,`close` sends binary data, ping, pong and close frames to server respectively.

#### Recieving Messages

Messages can be recieved on client either by creating `WebSocketClientDelegate` or competion call backs. Delegates are prioritized over completion call backs in this library.

To recieve a simple text message from client, we have :

```swift
client.onMessage { recievedText in  // receieved String
                    // do something with recieved String
               }
```
Similarly we have apis to recieve binary data(`client.onBinary{}`), ping(`client.onPing{}`), etc.

note: Usage of delegates to recieve message can be found [here](https://github.com/harish1992/WebSocketClient/blob/master/Tests/WebSocketClientTests/DelegateTests.swift).
