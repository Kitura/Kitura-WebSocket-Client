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

import Foundation
import KituraWebSocket
import XCTest
import NIO
import NIOWebSocket
import NIOHTTP1
@testable import KituraWebSocketClient
import NIOFoundationCompat

class DelegateTests: WebSocketClientTests {

    static var allTests: [(String, (DelegateTests) -> () throws -> Void)] {
        return [
            ("testTextCallBackDelegate", testTextCallBackDelegate),
            ("testBinaryCallBackDelegate", testBinaryCallBackDelegate),
            ("testCloseCallBackDelegate", testCloseCallBackDelegate),
            ("testPongCallBackDelegate", testPongCallBackDelegate),
            ("testErrorCallBackDelegate", testErrorCallBackDelegate),
            ("testOnBinaryDelegatePriority", testOnBinaryDelegatePriority),
            ("testOnTextDelegatePriority", testOnTextDelegatePriority),
            ("testOnPongDelegatePriority", testOnPongDelegatePriority),
            ("testOnCloseDelegatePriority", testOnCloseDelegatePriority),
        ]
    }

    let uint8Code: Data = Data([UInt8(WebSocketCloseReasonCode.normal.code() >> 8),
                                     UInt8(WebSocketCloseReasonCode.normal.code() & 0xff)])

    func testTextCallBackDelegate() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let text = "\u{00}"
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: text.data(using: .utf8)!, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }
    }

    func testBinaryCallBackDelegate() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let binaryPayload = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e])
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: binaryPayload, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(binaryPayload)
        }
    }

    func testCloseCallBackDelegate() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: self.uint8Code, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close(data: Data())
        }
    }

    func testPongCallBackDelegate() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: Data(), expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.ping(data: Data())
        }
    }

    func testErrorCallBackDelegate() {
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: Data(), expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.ping()
        }
    }

    func testOnBinaryDelegatePriority() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: Data(), expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(Data())
            client.onBinary { _ in
                XCTFail("Delegates must have highest priority")
                expectation.fulfill()
            }
        }
    }

    func testOnTextDelegatePriority() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: "".data(using: .utf8)!, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText("")
            client.onText { _ in
                XCTFail("Delegates must have highest priority")
                expectation.fulfill()
            }
        }
    }

    func testOnPongDelegatePriority() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: "".data(using: .utf8)!, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.ping()
            client.onPong { _,_  in
                XCTFail("Delegates must have highest priority")
                expectation.fulfill()
            }
        }
    }

    func testOnCloseDelegatePriority() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.delegate = WSClientDelegate(client: client, expectedPayload: self.uint8Code, expectation: expectation)
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close()
            client.onClose { _,_  in
                XCTFail("Delegates must have highest priority")
                expectation.fulfill()
            }
        }
    }
}

// Implements WebSocketClient Callback functions referenced by protocol `WebSocketClientDelegate`
class WSClientDelegate: WebSocketClientDelegate {
    weak var client: WebSocketClient?
    let expectedPayload: Data
    let expectation: XCTestExpectation

    init(client: WebSocketClient, expectedPayload: Data, expectation: XCTestExpectation){
        self.client = client
        self.expectedPayload = expectedPayload
        self.expectation = expectation
    }

    func onPing(data: Data) {
        client?.pong(data: data)
    }

    func onPong(data: Data) {
        XCTAssertEqual(data, expectedPayload, "Payloads not equal")
        expectation.fulfill()
    }

    func onBinary(data: Data) {
        XCTAssertEqual(data, expectedPayload, "Payloads not equal")
        expectation.fulfill()
    }

    func onText(text: String) {
        XCTAssertEqual(text, String(data: expectedPayload, encoding: .utf8), "Payloads not equal")
        expectation.fulfill()
    }

    func onClose(channel: Channel, data: Data) {
        XCTAssertEqual(data, expectedPayload, "Payloads not equal")
        expectation.fulfill()
    }

    func onError(error: Error?, status: HTTPResponseStatus?) {
        XCTAssertEqual(error as! WebSocketClientError, WebSocketClientError.webSocketUrlNotRegistered, "Invalid Error")
        XCTAssertEqual(status, HTTPResponseStatus.notFound, "Status not equal")
        expectation.fulfill()
    }
}
