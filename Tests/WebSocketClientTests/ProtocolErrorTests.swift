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

class ProtocolError: WebSocketClientTests {

    static var allTests: [(String, (ProtocolError) -> () throws -> Void)] {
        return [
            ("testBinaryAndTextFrames", testBinaryAndTextFrames),
            ("testPingWithOversizedPayload", testPingWithOversizedPayload),
            ("testFragmentedPing", testFragmentedPing),
            ("testCloseWithOversizedPayload", testCloseWithOversizedPayload),
            ("testJustContinuationFrame", testJustContinuationFrame),
            ("testInvalidUTFCloseMessage", testInvalidUTFCloseMessage),
            ("testTextAndBinaryFrames", testTextAndBinaryFrames),
            ("testUnmaskedFrame", testUnmaskedFrame),
            ("testInvalidRSV", testInvalidRSV),
        ]
    }
    
    let uint8Code: Data = Data([UInt8(WebSocketCloseReasonCode.protocolError.code() >> 8),
                                  UInt8(WebSocketCloseReasonCode.protocolError.code() & 0xff)])

    func testBinaryAndTextFrames() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let bytes:[UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
            let textPayload = "testing 1 2 3"
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(Data(bytes), finalFrame: false)
            client.sendText(textPayload, finalFrame: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "A text frame must be the first in the message"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testPingWithOversizedPayload() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let oversizedPayload = [UInt8](repeating: 0x00, count: 126)
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.ping(data: Data(oversizedPayload))
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "Control frames are only allowed to have payload up to and including 125 octets"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testFragmentedPing() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            let text =  "Testing, testing 1, 2, 3. "
            client.sendMessage(data:text.data(using: .utf8)!, opcode: .ping, finalFrame: false)
            client.sendMessage(data: text.data(using: .utf8)!, opcode: .continuation, finalFrame: false)
            client.sendMessage(data: text.data(using: .utf8)!, opcode: .continuation, finalFrame: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "Control frames must not be fragmented"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testCloseWithOversizedPayload() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let oversizedPayload = [UInt8](repeating: 0x00, count: 126)
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close(data: Data(oversizedPayload))
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "Control frames are only allowed to have payload up to and including 125 octets"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testJustContinuationFrame() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            let text =  "Testing, testing 1, 2, 3. "
            client.sendMessage(data:text.data(using: .utf8)!, opcode: .continuation, finalFrame: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "Continuation sent with prior binary or text frame"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testTextAndBinaryFrames() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let bytes:[UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
            let textPayload = "testing 1 2 3"
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(textPayload, finalFrame: false)
            client.sendBinary(Data(bytes), finalFrame: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "A binary frame must be the first in the message"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testUnmaskedFrame() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let bytes:[UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            client.maskFrame = false
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(Data(bytes), finalFrame: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "Received a frame from a client that wasn't masked"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testInvalidRSV() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let bytes:[UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
            guard let client = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: self.secWebKey) else {
                    XCTFail("Unable to create WebSocketClient")
                    return
            }
            client.maskFrame = false
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(Data(bytes), finalFrame: true, compressed: true)
            client.onClose {_, data in
                var expectedData = self.uint8Code
                let text = "RSV1 must be 0 unless negotiated to define meaning for non-zero values"
                expectedData.append(contentsOf: text.data(using: .utf8)!)
                XCTAssertEqual(data, expectedData, "The payload \(data) is not equal to the expected payload \(expectedData).")
                expectation.fulfill()
            }
        }
    }

    func testInvalidUTFCloseMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let testString = "Testing, 1,2,3"
            var payload = ByteBufferAllocator().buffer(capacity: 8)
            payload.writeInteger(WebSocketCloseReasonCode.normal.code())
            payload.writeBytes(testString.data(using: .utf16)!)
            guard let client = WebSocketClient("http://localhost:8080/wstester") else { return }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close(data: payload.getData(at: 0, length: payload.readableBytes)!)
            client.onClose { channel, data in
                var expectedPayload = ByteBufferAllocator().buffer(capacity: 8)
                expectedPayload.writeInteger(WebSocketCloseReasonCode.invalidDataContents.code())
                expectedPayload.writeString("Failed to convert received close message to UTF-8 String")
                let expected = expectedPayload.getData(at: 0, length: expectedPayload.readableBytes)
                XCTAssertEqual(data, expected, "The payload \(data) is not equal to the expected payload \(expected).")
                expectation.fulfill()
            }
        }
    }
}
