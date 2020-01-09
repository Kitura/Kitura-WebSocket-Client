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
import NIO
import NIOHTTP1
import NIOWebSocket
import Dispatch
import WebSocketCompression
import NIOFoundationCompat
import NIOSSL

#if os(Linux)
    import Glibc
#endif

public class WebSocketClient {

    let requestKey: String
    let host: String
    let port: Int
    let uri: String
    var channel: Channel? = nil
    public var maxFrameSize: Int
    var enableSSL: Bool = false

    ///  This semaphore signals when the client successfully recieves the Connection upgrade response from remote server
    ///  Ensures that webSocket frames are sent on channel only after the connection is successfully upgraded to WebSocket Connection

    let upgraded = DispatchSemaphore(value: 0)

    let callBackSync = DispatchQueue(label: "ErrorCallbackSync")

    let compressionConfig: WebSocketCompressionConfiguration?

    /// Create a new `WebSocketClient`.
    ///
    ///
    ///         Example usage:
    ///             let client = WebSocketClient(host: "localhost", port: 8080, uri: "/", requestKey: "test")
    ///
    ///         // See RFC 7692 for to know more about compression negotiation
    ///         Example usage with compression enabled:
    ///             let client = WebSocketClient(host: "localhost", port: 8080, uri: "/", requestKey: "test", negotiateCompression: true)
    ///
    /// - parameters:
    ///     - host: Host name of the remote server
    ///     - port: Port number on which the remote server is listening
    ///     - uri : The "Request-URI" of the GET method, it is used to identify the endpoint of the WebSocket connection
    ///     - requestKey: The requestKey sent by client which server has to include while building it's response. This helps ensure that the server
    ///                   does not accept connections from non-WebSocket clients
    ///     - maxFrameSize : Maximum allowable frame size of WebSocket client is configured using this parameter.
    ///                      Default value is `14`.
    ///     - compressionConfig : compression configuration

    public init?(host: String, port: Int, uri: String, requestKey: String,
                 compressionConfig: WebSocketCompressionConfiguration? = nil, maxFrameSize: Int = 14, enableSSL: Bool = false, onOpen: @escaping (Channel?) -> Void = { _ in }) {
        self.requestKey = requestKey
        self.host = host
        self.port = port
        self.uri = uri
        self.onOpenCallback = onOpen
        self.compressionConfig = compressionConfig
        self.maxFrameSize = maxFrameSize
        self.enableSSL = enableSSL
    }

    /// Create a new `WebSocketClient`.
    ///
    ///
    ///         Example usage:
    ///             let client = WebSocketClient("ws://localhost:8080/chat")
    ///
    ///         // See RFC 7692 for to know more about compression negotiation
    ///         Example usage with compression enabled:
    ///             let client = WebSocketClient(host: "localhost", port: 8080, uri: "/", requestKey: "test", negotiateCompression: true)
    ///
    /// - parameters:
    ///     - url : The "Request-URl" of the GET method, it is used to identify the endpoint of the WebSocket connection
    ///     - compressionConfig : compression configuration

    public init?(_ url: String, config: WebSocketCompressionConfiguration? = nil) {
        self.requestKey = "test"
        let rawUrl = URL(string: url)
        self.host = rawUrl?.host ?? "localhost"
        self.port = rawUrl?.port ?? 8080
        self.uri =  rawUrl?.path ?? "/"
        self.compressionConfig = config
        self.maxFrameSize = 24
        self.enableSSL = (rawUrl?.scheme == "wss" || rawUrl?.scheme == "https") ? true : false
    }

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    public var delegate: WebSocketClientDelegate? = nil

    /// Whether close frame is sent to server
    var closeSent: Bool = false

    /// Whether the client is still alive
    public var isConnected: Bool {
        return self.channel?.isActive ?? false
    }

    public func connect() throws {
        do {
            try makeConnection()
        } catch {
            throw WebSocketClientConnectionError.WebSocketClientConnectionFailed
        }
    }

    ///  Used only for testing
    ///  Decides whether the websocket frame sent has to be masked or not
    public var maskFrame: Bool = true

    /// This function pings to the connected server
    ///
    ///             client.ping()
    ///
    /// - parameters:
    ///     - data: ping frame payload, must be less than 125 bytes

    public func ping(data: Data = Data()) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        send(data: buffer, opcode: .ping, finalFrame: true, compressed: false)

    }

    /// Sends a pong frame to the connected server
    ///
    ///             client.pong()
    ///
    /// - parameters:
    ///     - data: frame payload, must be less than 125 bytes

    public func pong(data: Data = Data()) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        send(data: buffer, opcode: .pong, finalFrame: true, compressed: false)
    }

    /// This function closes the connection
    ///
    ///             client.close()
    ///
    /// - parameters:
    ///     - data: close frame payload, must be less than 125 bytes

    public func close(data: Data = Data()) {
        closeSent = true
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        send(data: buffer, opcode: .connectionClose, finalFrame: true, compressed: false)
    }

    /// This function sends binary-formatted data to the connected server in multiple frames
    ///
    ///             // server recieves [0x11 ,0x12, 0x13] when following is sent
    ///             client.sendBinary(Data([0x11,0x12]), opcode: .binary, finalFrame: false)
    ///             client.sendMessage(Data([0x13]), opcode: .continuation, finalFrame: true)
    ///
    /// - parameters:
    ///     - data: raw binary data to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default compression is disabled

    public func sendBinary(_ binary: Data, opcode: WebSocketOpcode = .binary, finalFrame: Bool = true, compressed: Bool = false) {
        var buffer = ByteBufferAllocator().buffer(capacity: binary.count)
        buffer.writeBytes(binary)
        send(data: buffer, opcode: opcode, finalFrame: finalFrame, compressed: compressed)
    }

    /// This function sends text-formatted data to the connected server in multiple frames
    ///
    ///             // server recieves "Kitura-WebSocket-NIO" when following is sent
    ///             client.sendMessage("Kitura-WebSocket", opcode: .text, finalFrame: false)
    ///             client.sendMessage("-NIO", opcode: .continuation, finalFrame: true)
    ///
    /// - parameters:
    ///     - raw: raw text to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default this set to `false`

    public func sendText(_ string: String, opcode: WebSocketOpcode = .text, finalFrame: Bool = true, compressed: Bool = false) {
        var buffer = ByteBufferAllocator().buffer(capacity: string.count)
        buffer.writeString(string)
        send(data: buffer, opcode: opcode, finalFrame: finalFrame, compressed: compressed)
    }

    public func send<T: Codable>(model: T, opcode: WebSocketOpcode = .text, finalFrame: Bool = true, compressed: Bool = false) {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(model)
            let string = String(data: jsonData, encoding: .utf8)!
            var buffer = ByteBufferAllocator().buffer(capacity: string.count)
            buffer.writeString(string)
            send(data: buffer, opcode: opcode, finalFrame: finalFrame, compressed: compressed)
        } catch let error{
            print(error)
        }
    }

    /// This function sends IOData(ByteBuffer) to the connected server
    ///
    ///             client.sendMessage(data: Data, opcode: opcode)
    ///
    /// - parameters:
    ///     - data: ByteBuffer-formatted to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default this set to `false`

    public func sendMessage(data: Data, opcode: WebSocketOpcode, finalFrame: Bool = true, compressed: Bool = false) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        if opcode == .connectionClose {
            self.closeSent = true
        }
        send(data: buffer, opcode: opcode, finalFrame: finalFrame, compressed: compressed)
    }

    ///  This function generates masking key to mask the payload to be sent on the WebSocketframe
    ///  Data is automatically masked unless specified otherwise by property 'maskFrame'
    func generateMaskingKey() -> WebSocketMaskingKey {
        let mask: [UInt8] = [.random(in: 0..<255), .random(in: 0..<255), .random(in: 0..<255), .random(in: 0..<255)]
        return WebSocketMaskingKey(mask)!
    }

    private func makeConnection() throws {
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)
            .channelInitializer(self.clientChannelInitializer)
        _ = try bootstrap.connect(host: self.host, port: self.port).wait()
        self.upgraded.wait()
    }

    private func clientChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        let httpHandler = HTTPClientHandler(client: self)
        let basicUpgrader = NIOWebClientSocketUpgrader(requestKey: self.requestKey, maxFrameSize: 1 << self.maxFrameSize,
                                                       automaticErrorHandling: false, upgradePipelineHandler: self.upgradePipelineHandler)
        let config: NIOHTTPClientUpgradeConfiguration = (upgraders: [basicUpgrader],
                                                         completionHandler: { context in
            context.channel.pipeline.removeHandler(httpHandler, promise: nil)})
        return channel.pipeline.addHTTPClientHandlers(withClientUpgrade: config).flatMap { _ in
            return channel.pipeline.addHandler(httpHandler).flatMap { _ in
                if self.enableSSL {
                    let tlsConfig = TLSConfiguration.forClient()
                    let sslContext =  try! NIOSSLContext(configuration: tlsConfig)
                    let sslHandler = try! NIOSSLClientHandler(context: sslContext, serverHostname: self.host)
                    return channel.pipeline.addHandler(sslHandler, position: .first)
                } else {
                    return channel.eventLoop.makeSucceededFuture(())
                }
            }
        }
    }

    private func upgradePipelineHandler(channel: Channel, response: HTTPResponseHead) -> EventLoopFuture<Void> {
        self.onOpenCallback(channel)
        let handler = WebSocketMessageHandler(client: self)
        if response.status == .switchingProtocols {
            self.channel = channel
            self.upgraded.signal()
        }
        if self.compressionConfig == nil {
            return channel.pipeline.addHandler(handler)
        }
        let slidingWindowBits = windowSize(header: response.headers)

        let deflater = PermessageDeflateCompressor(noContextTakeOver: (self.compressionConfig?.contextTakeover.clientNoContextTakeover)!,
                                                     maxWindowBits: slidingWindowBits)
        let inflater = PermessageDeflateDecompressor(noContextTakeOver: (self.compressionConfig?.contextTakeover.serverNoContextTakeover)!,
                                                     maxWindowBits: slidingWindowBits)
        return channel.pipeline.addHandlers([WebSocketCompressor(deflater: deflater), WebSocketDecompressor(inflater: inflater), handler])
    }

    private func send(data: ByteBuffer, opcode: WebSocketOpcode, finalFrame: Bool, compressed: Bool) {
        let mask = self.maskFrame ? self.generateMaskingKey(): nil
        let frame = WebSocketFrame(fin: finalFrame, rsv1: compressed, opcode: opcode, maskKey: mask, data: data)
        guard let channel = channel else { return }
        if finalFrame {
            channel.writeAndFlush(frame, promise: nil)
        } else {
            channel.write(frame, promise: nil)
        }
    }

    /// Calculates th LZ77 sliding window size from server response
    private func windowSize(header: HTTPHeaders) -> Int32 {
        return header["Sec-WebSocket-Extensions"].first?.split(separator: ";")
            .dropFirst().first?.split(separator: "=").last.flatMap({ Int32($0)}) ?? self.compressionConfig!.maxWindowBits
    }

    /// Stored callbacks
    // note: setter and getters of callback functions need to be synchronized to avoid TSan errors

    var onOpenCallback: (Channel) -> Void = { _ in }

    var _closeCallback: (Channel, Data) -> Void = { _,_ in }

    var onCloseCallback: (Channel, Data) -> Void {
        get {
            return callBackSync.sync {
                return _closeCallback
            }
        }
        set {
            _ = callBackSync.sync {
                _closeCallback = newValue
            }
        }
    }

    var _textCallback: (String) -> Void = { _ in }

    var onTextCallback: (String) -> Void {
        get {
            return callBackSync.sync {
                return _textCallback
            }
        }
        set {
            _ = callBackSync.sync {
                _textCallback = newValue
            }
        }
    }
    
    var _binaryCallback: (Data) -> Void = { _ in }

    var onBinaryCallback: (Data) -> Void {
        get {
            return callBackSync.sync {
                return _binaryCallback
            }
        }
        set {
            _ = callBackSync.sync {
                _binaryCallback = newValue
            }
        }
    }

    var _pingCallback: (Data) -> Void = { _ in }

    var onPingCallback: (Data) -> Void {
        get {
            return callBackSync.sync {
                return _pingCallback
            }
        }
        set {
            _ = callBackSync.sync {
                _pingCallback = newValue
            }
        }
    }

    var _pongCallback: (WebSocketOpcode, Data) -> Void = { _,_ in}

      var onPongCallback: (WebSocketOpcode, Data) -> Void {
          get {
              return callBackSync.sync {
                  return _pongCallback
              }
          }
          set {
              _ = callBackSync.sync {
                  _pongCallback = newValue
              }
          }
      }

    var _errorCallBack: (Error?, HTTPResponseStatus?) -> Void = { _,_ in }

    var onErrorCallBack: (Error?, HTTPResponseStatus?) -> Void {

        get {
            return callBackSync.sync {
                return _errorCallBack
            }
        }
        set {
            _ = callBackSync.sync {
                _errorCallBack = newValue
            }
        }
    }

    /// callback functions
    /// These functions are called when client gets reply from another endpoint
    ///
    ///     Example usage:
    ///         Consider an endpoint sending data, callback function onMessage is triggered
    ///         and receieved data is available as bytebuffer
    ///
    ///         client.onMessage { recievedText in  // receieved String
    ///                    // do something with recieved String
    ///                 }
    ///
    /// Other callback functions are used similarly.
    ///

    public func onText(_ callback: @escaping (String) -> Void) {
        self.onTextCallback = callback
    }

    public func onBinary(_ callback: @escaping (Data) -> Void) {
        self.onBinaryCallback = callback
    }

    public func onClose(_ callback: @escaping (Channel, Data) -> Void) {
        self.onCloseCallback = callback
    }

    public func onPing(_ callback: @escaping (Data) -> Void) {
        self.onPingCallback = callback
    }

    public func onPong(_ callback: @escaping (WebSocketOpcode, Data) -> Void) {
        self.onPongCallback = callback
        
    }

    public func onError(_ callback: @escaping (Error?, HTTPResponseStatus?) -> Void) {
        self.onErrorCallBack  = callback
    }

}

/// WebSocket Handler which recieves data over WebSocket Connection
class WebSocketMessageHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = WebSocketFrame

    private let client: WebSocketClient

    private var buffer: ByteBuffer

    private var binaryBuffer: Data = Data()

    private var isText: Bool = false

    private var string: String = ""

    public init(client: WebSocketClient) {
        self.client = client
        self.buffer = ByteBufferAllocator().buffer(capacity: 0)
    }

    private func unmaskedData(frame: WebSocketFrame) -> ByteBuffer {
        var frameData = frame.data
        if let maskingKey = frame.maskKey {
            frameData.webSocketUnmask(maskingKey)
        }
        return frameData
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        if client.delegate != nil {
            client.delegate?.onError(error: error, status: nil)
        } else {
            client.onErrorCallBack(error, nil)
        }
        client.close()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        switch frame.opcode {
        case .text:
            let data = unmaskedData(frame: frame)
            if frame.fin {
                guard let text = data.getString(at: 0, length: data.readableBytes) else { return }
                if let delegate = client.delegate {
                    delegate.onText(text: text)
                } else {
                client.onTextCallback(text)
                }
            } else {
                isText = true
                guard let text = data.getString(at: 0, length: data.readableBytes) else { return }
                string = text
            }
        case .binary:
            let data = unmaskedData(frame: frame)
            if frame.fin {
                guard let binaryData = data.getData(at: 0, length: data.readableBytes) else { return }
                if let delegate = client.delegate {
                    delegate.onBinary(data: binaryData)
                } else {
                    client.onBinaryCallback(binaryData)
                }
            } else {
                guard let binaryData = data.getData(at: 0, length: data.readableBytes) else { return }
                binaryBuffer = binaryData
            }
        case .continuation:
            let data = unmaskedData(frame: frame)
            if isText {
                if frame.fin {
                    guard let text = data.getString(at: 0, length: data.readableBytes) else { return }
                    string.append(text)
                    isText = false
                    if let delegate = client.delegate {
                        delegate.onText(text: string)
                    } else {
                        client.onTextCallback(string)
                    }
                } else {
                    guard let text = data.getString(at: 0, length: data.readableBytes) else { return }
                    string.append(text)
                }
            } else {
                if frame.fin {
                    guard let binaryData = data.getData(at: 0, length: data.readableBytes) else { return }
                    binaryBuffer.append(binaryData)
                    if let delegate = client.delegate {
                        delegate.onBinary(data: binaryBuffer)
                    } else {
                        client.onBinaryCallback(binaryBuffer)
                    }
                } else {
                    guard let binaryData = data.getData(at: 0, length: data.readableBytes) else { return }
                    binaryBuffer.append(binaryData)
                }
            }
        case .ping:
            guard frame.fin else { return }
            let frame = unmaskedData(frame: frame)
            let data =  frame.getData(at: 0, length: frame.readableBytes)!
            if let delegate = client.delegate {
                delegate.onPing(data: data)
            } else {
                client.onPingCallback(data)
            }
        case .connectionClose:
            guard frame.fin else { return }
            let data = frame.data
            if !client.closeSent {
                client.close(data: frame.data.getData(at: 0, length: frame.data.readableBytes) ?? Data())
            }
            if let delegate = client.delegate {
                delegate.onClose(channel: context.channel, data: data.getData(at: 0, length: data.readableBytes)!)
            } else {
                client.onCloseCallback(context.channel, data.getData(at: 0, length: data.readableBytes)!)
            }
        case .pong:
            guard frame.fin else { return }
            let data = frame.data
            if let delegate = client.delegate {
                delegate.onPong(data: data.getData(at: 0, length: data.readableBytes)!)
            } else {
                client.onPongCallback(frame.opcode, data.getData(at: 0, length: data.readableBytes)!)
            }
        default:
            break
        }
    }
}

/// This handler is used to send WebSocketUpgrade ugrade request to server
class HTTPClientHandler: ChannelInboundHandler, RemovableChannelHandler {

    typealias InboundIn = HTTPClientResponsePart
    unowned var client: WebSocketClient

    init(client: WebSocketClient) {
        self.client = client
    }

    func channelActive(context: ChannelHandlerContext) {
        var request = HTTPRequestHead(version: HTTPVersion.http11, method: .GET, uri: client.uri)
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: "\(client.host):\(client.port)")
        if client.compressionConfig != nil {
            let value = buildExtensionHeader()
            headers.add(name: "Sec-WebSocket-Extensions", value: value)
        }
        request.headers = headers
        context.channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        context.channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        switch response {
        case .head(let header) :
            upgradeFailure(status: header.status)
        case .body(_):
            break
        case .end(_):
            break
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if client.delegate != nil {
            client.delegate?.onError(error: error, status: nil)
        } else {
            client.onErrorCallBack(error, nil)
        }
    }

    //  Builds extension headers based on the configuration of maxwindowbits ,context takeover
    func buildExtensionHeader() -> String {
        var value = "permessage-deflate"
        let windowBits: Int32
        if let config = client.compressionConfig {
            windowBits = (config.maxWindowBits >= 8 && config.maxWindowBits < 15) ? config.maxWindowBits : 15
            value.append("; " + "client_max_window_bits; server_max_window_bits=" + String(windowBits))
            value.append((config.contextTakeover.header()))
        }
        return value
    }

    func upgradeFailure(status: HTTPResponseStatus) {
        if let delegate = client.delegate {
            switch status {
            case .badRequest:
                delegate.onError(error: WebSocketClientError.badRequest, status: status)
            case .notFound:
                delegate.onError(error: WebSocketClientError.webSocketUrlNotRegistered, status: status)
            default :
                break
            }
        } else {
            switch status {
            case .badRequest:
                client.onErrorCallBack(WebSocketClientError.badRequest, status)
            case .notFound:
                client.onErrorCallBack(WebSocketClientError.webSocketUrlNotRegistered, status)
            default :
                break
            }
        }
    }
}

extension HTTPVersion {
    static let http11 = HTTPVersion(major: 1, minor: 1)
}

///  This enum is used to populate 'Sec-WebSocket-Extension' field of upgrade header with user required ContextTakeover configuration
///  User specifies the the context Takeover configuration when creating the WebSocketClient
///  when not specified both the client and server connections are context takeover enabled

public enum ContextTakeover {
    case none
    case client
    case server
    case both

    func header() -> String {
        switch self {
        case .none: return "; client_no_context_takeover; server_no_context_takeover"
        case .client: return "; server_no_context_takeover"
        case .server: return "; client_no_context_takeover"
        case .both: return ""
        }
    }

    var clientNoContextTakeover: Bool {
        return self != .client && self != .both
    }

    var serverNoContextTakeover: Bool {
        return self != .server && self != .both
    }
}

/// WebSocket Client errors
enum WebSocketClientError: UInt, Error {
    case webSocketUrlNotRegistered = 404
    case badRequest = 400

    func code() -> UInt? {
        switch self {
        case .webSocketUrlNotRegistered :
            return 404
        case .badRequest :
            return 400
        }
    }
}

/// WebSocket connection errors
/// Client throws `WebSocketClientConnectionErrorType` when it is unable to connect to WS endpoint.

public struct WebSocketClientConnectionError: Error, Equatable {

    internal enum WebSocketClientConnectionErrorType: Error {
        case WebSocketClientConnectionFailed
    }

    private var _wsClientError: WebSocketClientConnectionErrorType

    private init(value: WebSocketClientConnectionErrorType) {
        self._wsClientError = value
    }

    public static var WebSocketClientConnectionFailed = WebSocketClientConnectionError(value: .WebSocketClientConnectionFailed)
}

/// Protocol to delegate callbacks. These functions are called when client gets reply from another endpoint
public protocol WebSocketClientDelegate {

    /// Called when message is recieved from server
    func onText(text: String)

    /// Called when message is recieved from server
    func onBinary(data: Data)

    /// Called when ping is recieved from server
    func onPing(data: Data)

    /// Called when pong is recieved from server
    func onPong(data: Data)

    /// Called when close message is recieved from server
    func onClose(channel: Channel, data: Data)

    func onError(error: Error?, status: HTTPResponseStatus?)
}

extension WebSocketClientDelegate {

    /// Called when message is recieved from server
    func onText(text: String) {}

    /// Called when message is recieved from server
    func onBinary(data: Data) {}

    /// Called when server pings the client
    func onPing(data: Data) {}

    /// Called when server replies with pong to clients ping
    func onPong(data: Data) {}

    /// Called when WebSocket connection is closed
    func onClose(channel: Channel, data: Data) {}

    func onError(error: Error?, status: HTTPResponseStatus?) {}
}

/// WebSocket Compression Configuration
/// This structure is used to enable compression in WebSocket Connection
/// - parameters:
///     - contextTakeover: enable or disable context takeover in WebSocket Connection. Both client and server context takeover is enabled by default.
///     - maxWindowBits: Window size of  lz77 sliding window. Default value is 15

public struct WebSocketCompressionConfiguration {

    var contextTakeover: ContextTakeover
    var maxWindowBits: Int32

    init(contextTakeover: ContextTakeover = .both, maxWindowBits: Int32 = 15) {
        self.contextTakeover = contextTakeover
        self.maxWindowBits = maxWindowBits
    }
}
 
