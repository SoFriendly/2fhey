//
//  NotificationServer.swift
//  2FHey
//
//  WebSocket server to receive notifications from Google Messages Pake app
//  Uses WSS (WebSocket Secure) because HTTPS pages block insecure connections to localhost
//

import Foundation
import Network
import CommonCrypto
import Security

class NotificationServer {
    static let shared = NotificationServer()

    private let port: UInt16 = 2847
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var webSocketConnections: Set<ObjectIdentifier> = []

    var onNotificationReceived: ((_ title: String, _ body: String, _ id: String) -> Void)?

    private init() {}

    func start() {
        do {
            // Try to set up TLS, fall back to plain TCP if it fails
            let parameters: NWParameters
            if let tlsParams = createTLSParameters() {
                parameters = tlsParams
                DebugLogger.shared.log("Using TLS for WebSocket server", category: "WS_SERVER")
            } else {
                parameters = NWParameters.tcp
                DebugLogger.shared.log("TLS setup failed, using plain TCP", category: "WS_SERVER")
            }
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DebugLogger.shared.log("NotificationServer started on port \(self?.port ?? 0)", category: "WS_SERVER")
                case .failed(let error):
                    DebugLogger.shared.log("NotificationServer failed: \(error)", category: "WS_SERVER")
                case .cancelled:
                    DebugLogger.shared.log("NotificationServer cancelled", category: "WS_SERVER")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))

        } catch {
            DebugLogger.shared.log("Failed to create NotificationServer: \(error)", category: "WS_SERVER")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        webSocketConnections.removeAll()
        DebugLogger.shared.log("NotificationServer stopped", category: "WS_SERVER")
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection, isWebSocket: false)
            case .failed, .cancelled:
                self?.connections.removeAll { $0 === connection }
                self?.webSocketConnections.remove(ObjectIdentifier(connection))
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func receiveData(from connection: NWConnection, isWebSocket: Bool) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if isWebSocket {
                    self?.processWebSocketFrame(data: data, connection: connection)
                } else {
                    self?.processHTTPRequest(data: data, connection: connection)
                }
            }

            if isComplete || error != nil {
                connection.cancel()
                self?.connections.removeAll { $0 === connection }
                self?.webSocketConnections.remove(ObjectIdentifier(connection))
            }
        }
    }

    private func processHTTPRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }

        // Parse HTTP headers
        let lines = requestString.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).lowercased()] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Check for WebSocket upgrade
        if headers["upgrade"]?.lowercased() == "websocket",
           let wsKey = headers["sec-websocket-key"] {
            handleWebSocketUpgrade(connection: connection, key: wsKey)
            return
        }

        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Handle POST /notification (for backwards compatibility with curl testing)
        if method == "POST" && path == "/notification" {
            if let bodyIndex = requestString.range(of: "\r\n\r\n") {
                let bodyString = String(requestString[bodyIndex.upperBound...])
                handleNotification(body: bodyString)
            }
            sendResponse(connection: connection, statusCode: 200, body: "OK")
        } else if method == "OPTIONS" {
            sendCORSResponse(connection: connection)
        } else if method == "GET" {
            // Could be WebSocket upgrade or regular GET
            sendResponse(connection: connection, statusCode: 200, body: "2FHey Notification Server")
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "Not found")
        }
    }

    private func handleWebSocketUpgrade(connection: NWConnection, key: String) {
        // Generate accept key per RFC 6455
        let magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let acceptString = key + magicString
        let acceptData = acceptString.data(using: .utf8)!

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        acceptData.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(acceptData.count), &hash)
        }
        let acceptKey = Data(hash).base64EncodedString()

        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
            self?.webSocketConnections.insert(ObjectIdentifier(connection))
            DebugLogger.shared.log("WebSocket connection established", category: "WS_SERVER")
            // Continue receiving WebSocket frames
            self?.receiveData(from: connection, isWebSocket: true)
        })
    }

    private func processWebSocketFrame(data: Data, connection: NWConnection) {
        guard data.count >= 2 else { return }

        let firstByte = data[0]
        let secondByte = data[1]

        let opcode = firstByte & 0x0F
        let isMasked = (secondByte & 0x80) != 0
        var payloadLength = UInt64(secondByte & 0x7F)

        var offset = 2

        // Extended payload length
        if payloadLength == 126 {
            guard data.count >= 4 else { return }
            payloadLength = UInt64(data[2]) << 8 | UInt64(data[3])
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else { return }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength |= UInt64(data[2 + i]) << (56 - i * 8)
            }
            offset = 10
        }

        // Masking key
        var maskingKey: [UInt8] = []
        if isMasked {
            guard data.count >= offset + 4 else { return }
            maskingKey = Array(data[offset..<offset+4])
            offset += 4
        }

        // Payload
        guard data.count >= offset + Int(payloadLength) else { return }
        var payload = Array(data[offset..<offset+Int(payloadLength)])

        // Unmask if needed
        if isMasked {
            for i in 0..<payload.count {
                payload[i] ^= maskingKey[i % 4]
            }
        }

        // Handle based on opcode
        switch opcode {
        case 0x01: // Text frame
            if let text = String(bytes: payload, encoding: .utf8) {
                DebugLogger.shared.log("WebSocket message received", category: "WS_SERVER", data: ["length": text.count])
                handleNotification(body: text)
            }
        case 0x08: // Close
            connection.cancel()
            connections.removeAll { $0 === connection }
            webSocketConnections.remove(ObjectIdentifier(connection))
        case 0x09: // Ping
            sendWebSocketPong(connection: connection, payload: payload)
        default:
            break
        }

        // Continue receiving
        receiveData(from: connection, isWebSocket: true)
    }

    private func sendWebSocketPong(connection: NWConnection, payload: [UInt8]) {
        var frame: [UInt8] = [0x8A] // FIN + Pong opcode
        frame.append(UInt8(payload.count))
        frame.append(contentsOf: payload)
        connection.send(content: Data(frame), completion: .contentProcessed { _ in })
    }

    private func handleNotification(body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            DebugLogger.shared.log("Failed to parse notification JSON", category: "WS_SERVER")
            return
        }

        let title = json["title"] as? String ?? ""
        let notificationBody = json["body"] as? String ?? ""
        let id = json["id"] as? String ?? UUID().uuidString

        DebugLogger.shared.log("Received notification", category: "WS_SERVER", data: [
            "title": title,
            "body": String(notificationBody.prefix(50))
        ])

        DispatchQueue.main.async {
            self.onNotificationReceived?(title, notificationBody, id)
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : "Error"
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/plain\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendCORSResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 204 No Content\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Connection: close\r
        \r

        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - TLS Setup

    private func createTLSParameters() -> NWParameters? {
        let certPath = NSHomeDirectory() + "/.2fhey/server.crt"
        let keyPath = NSHomeDirectory() + "/.2fhey/server.key"

        guard FileManager.default.fileExists(atPath: certPath),
              FileManager.default.fileExists(atPath: keyPath) else {
            DebugLogger.shared.log("TLS certificate or key not found", category: "WS_SERVER")
            return nil
        }

        guard let identity = loadIdentity(certPath: certPath, keyPath: keyPath) else {
            DebugLogger.shared.log("Failed to load TLS identity", category: "WS_SERVER")
            return nil
        }

        let tlsOptions = NWProtocolTLS.Options()

        sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, identity)

        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        return parameters
    }

    private func loadIdentity(certPath: String, keyPath: String) -> sec_identity_t? {
        // Try P12 file first (simpler, no keychain needed)
        let p12Path = NSHomeDirectory() + "/.2fhey/server.p12"
        if let p12Data = FileManager.default.contents(atPath: p12Path) {
            let options: [String: Any] = [kSecImportExportPassphrase as String: "2fhey"]
            var items: CFArray?
            let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

            if status == errSecSuccess,
               let itemsArray = items as? [[String: Any]],
               let firstItem = itemsArray.first,
               let identity = firstItem[kSecImportItemIdentity as String] {
                DebugLogger.shared.log("Loaded TLS identity from P12", category: "WS_SERVER")
                return sec_identity_create(identity as! SecIdentity)
            }
            DebugLogger.shared.log("Failed to import P12: \(status)", category: "WS_SERVER")
        }

        DebugLogger.shared.log("P12 file not found at \(p12Path)", category: "WS_SERVER")
        return nil
    }
}
