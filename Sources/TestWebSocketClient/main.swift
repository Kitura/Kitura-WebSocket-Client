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

import KituraWebSocketClient
import NIO
import Foundation
import NIOHTTP1
import Dispatch

class Delegate: WebSocketClientDelegate {
    weak var client: WebSocketClient?

    init(client: WebSocketClient?) {
        self.client = client
    }

    func onText(text: String) {
        client?.sendText(text)
    }
    
    func onBinary(data: Data) {
        client?.sendBinary(data)
    }
    
    func onPing(data: Data) {
        client?.ping(data: data)
    }
    
    func onPong(data: Data) {
        //
    }
    
    func onClose(channel: Channel, data: Data) {
        client?.close(data: data)
    }
    
    func onError(error: Error?, status: HTTPResponseStatus?) {
        //
    }
}

let client = WebSocketClient("http://localhost:9001")
let wsDelegate = Delegate(client: client)
do {
    try client?.connect()
} catch {
    print(error)
}
dispatchMain()
