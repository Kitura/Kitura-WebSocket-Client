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

class BasicTests: WebSocketClientTests {

    static var allTests: [(String, (BasicTests) -> () throws -> Void)] {
        return [
            ("testTextMessage", testTextMessage),
            ("testDataMessage", testDataMessage),
            ("testBinaryLongMessage", testBinaryLongMessage),
            ("testBinaryMediumMessage", testBinaryMediumMessage),
            ("testBinaryShortMessage", testBinaryShortMessage),
            ("testClientInitWithURL", testClientInitWithURL),
            ("testPingWithText", testPingWithText),
            ("testSuccessfulRemove", testSuccessfulRemove),
            ("testTextLongMessage", testTextLongMessage),
            ("testTextMediumMessage", testTextMediumMessage),
            ("testTextShortMessage", testTextShortMessage),
            ("testSendCodableType",testSendCodableType),
            ("testNullCharacter", testNullCharacter),
            ("testUserDefinedCloseCode", testUserDefinedCloseCode),
            ("testUserCloseMessage", testUserCloseMessage)
        ]
    }

    func testTextMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest{ expectation in
            let textToSend = "Hi"
            let client = WebSocketClient(host: "localhost", port: 8080,
                                         uri: self.servicePath, requestKey: "test")
            do {
                try client?.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client?.onText({ text in
                XCTAssertEqual(text, textToSend, "\(text) not equal to \(textToSend)")
                expectation.fulfill()
            })
            client?.sendText(textToSend)
        }
    }

    func testDataMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest{ expectation in
            let dataToSend = Data.init([99,100])
            let client = WebSocketClient(host: "localhost", port: 8080,
                                         uri: self.servicePath, requestKey: "test")
            do {
                try client?.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client?.onBinary({ (data) in
                XCTAssertEqual(data, dataToSend, "\(data) not equal to \(dataToSend)")
                expectation.fulfill()
            })
            client?.sendBinary(dataToSend)
        }
    }

    func testClientInitWithURL() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest{ expectation in
            let dataToSend = Data.init([99,100])
            let client = WebSocketClient("http://localhost:8080/wstester")
            do {
                try client?.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client?.onBinary({ (data) in
                XCTAssertEqual(data, dataToSend, "\(data) not equal to \(dataToSend)")
                expectation.fulfill()
            })
            client?.sendBinary(dataToSend)
        }
    }

    func testBinaryLongMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        var bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
        repeat {
            bytes.append(contentsOf: bytes)
        } while bytes.count < 100000
        let payload = Data(bytes)
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            client.sendBinary(payload)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            client.sendBinary(payload)
        }, { expectation in
           let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            client.sendBinary(payload, compressed: true)
        })
    }

    func testBinaryMediumMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        var bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
        repeat {
            bytes.append(contentsOf: bytes)
        } while bytes.count < 1000
        let payload = Data(bytes)
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload)
        }, { expectation in
           let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload, compressed: true)
        })
    }

    func testBinaryShortMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
        let payload = Data(bytes)
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload)
        }, { expectation in
           let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onBinary { receivedData in
                XCTAssertEqual(receivedData, payload, "The received payload \(receivedData) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendBinary(payload, compressed: true)
        })
    }

    func testPingWithText() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            var payloadBuffer = ByteBufferAllocator().buffer(capacity: 8)
            payloadBuffer.writeString("Testing, testing 1,2,3")
            let payload = Data(payloadBuffer.getBytes(at: 0, length: payloadBuffer.readableBytes)!)
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.ping(data: payload)
            client.onPong { code, data in
                XCTAssertEqual(code, WebSocketOpcode.pong, "Recieved opcode \(code) is not equal to expected \(WebSocketOpcode.pong)")
                XCTAssertEqual(data, payload, "The received payload \(data) is not equal to the expected payload \(payload).")
                expectation.fulfill()
            }
        }
    }

    func testSuccessfulRemove() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client1 = WebSocketClient("http://localhost:8080/wstester") else {
                   XCTFail("Unable to create client")
                   return
               }
            do {
                try client1.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            XCTAssertTrue(client1.isConnected, "Client not connected")
            WebSocket.unregister(path: self.servicePath)
            guard let client2 = WebSocketClient(host: "localhost", port: 8080, uri: self.servicePath, requestKey: "test") else { return }
            client2.onError { _, status in
                XCTAssertEqual(status, HTTPResponseStatus.badRequest,
                               "Status \(String(describing: status)) returned from server is not equal to \(HTTPResponseStatus.badRequest)" )
                expectation.fulfill()
            }
            do {
                try client2.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
        }
    }

    func testTextLongMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        var text = "Testing, testing 1, 2, 3."
        repeat {
            text += " " + text
        } while text.count < 100000
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
           let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text, compressed: true)
        })
    }

    func testTextMediumMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        var text = "Testing, testing 1, 2, 3."
        repeat {
            text += " " + text
        } while text.count < 1000
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
           let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text, compressed: true)
        })
    }

    func testTextShortMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        let text = "Testing, testing 1, 2, 3."
        performServerTest(asyncTasks: { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text)
        }, { expectation in
            let options = WebSocketCompressionConfiguration()
            guard let client = WebSocketClient("http://localhost:8080/wstester", config: options) else {
                XCTFail("Unable to create client")
                return
            }
            client.onText { receivedData in
                XCTAssertEqual(receivedData, text, "The received payload \(receivedData) is not equal to the expected payload \(text).")
                expectation.fulfill()
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText(text, compressed: true)
        })
    }

    func testSendCodableType() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest(asyncTasks: { expectation in
            struct Details: Codable, Equatable {
                var name: String = ""
                var age: Int = 0
            }
            var textPayload = Details()
            textPayload.name = "Hello"
            textPayload.age = 12
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.send(model: textPayload)
            client.onText { recieved in
                let jsonDecoder = JSONDecoder()
                do {
                    let recievedDetails = try jsonDecoder.decode(Details.self, from: recieved.data(using: .utf8)!)
                    XCTAssertEqual(recievedDetails, textPayload, "The received payload \(recievedDetails) is not equal to the expected payload \(textPayload).")
                    expectation.fulfill()
                } catch {
                    print(error)
                }
            }
        })
    }

    func testNullCharacter() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.sendText("\u{00}")
            client.onText { recievedText in
                XCTAssertEqual(recievedText, "\u{00}", "The recieve payload \(String(describing: recievedText)) is not Equal to expected payload \u{00}")
                expectation.fulfill()
            }
        }
    }

    func testUserDefinedCloseCode() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let data = Data([255,255])
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close(data: data)
            client.onClose { _, dataRecieved in
                           XCTAssertEqual(data, dataRecieved, "The payload recieved \(dataRecieved) is not equal to expected payload \(data))")
                           expectation.fulfill()
                       }
        }
    }

    func testUserCloseMessage() {
        let echoDelegate = EchoService()
        WebSocket.register(service: echoDelegate, onPath: self.servicePath)
        performServerTest { expectation in
            let testString = "Testing, 1,2,3"
            var payloadBuffer = ByteBufferAllocator().buffer(capacity: 4)
            payloadBuffer.writeInteger(WebSocketCloseReasonCode.normal.code())
            payloadBuffer.writeString(testString)
            let payload =  Data(payloadBuffer.getBytes(at: 0, length: payloadBuffer.readableBytes)!)
            guard let client = WebSocketClient("http://localhost:8080/wstester") else {
                XCTFail("Unable to create client")
                return
            }
            do {
                try client.connect()
            } catch {
                XCTFail("Client connection failed with error \(error)")
            }
            client.close(data: payload)
            client.onClose { _, data in
                XCTAssertEqual(data, payload, "The payload recieved \(data) is not equal to expected payload \(payload)")
                expectation.fulfill()
            }
        }
    }
}
