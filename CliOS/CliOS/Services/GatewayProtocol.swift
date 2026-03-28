import Foundation

// MARK: - Wire Frame Types

/// Outgoing request frame
struct WSRequest: Codable {
    let type: String    // always "req"
    let id: String
    let method: String
    let params: [String: AnyCodable]
    
    init(method: String, params: [String: AnyCodable] = [:]) {
        self.type = "req"
        self.id = UUID().uuidString
        self.method = method
        self.params = params
    }
}

/// Incoming response frame
struct WSResponse: Codable {
    let type: String    // "res"
    let id: String
    let ok: Bool
    let payload: [String: AnyCodable]?
    let error: WSError?
}

/// Incoming event frame
struct WSEvent: Codable {
    let type: String    // "event"
    let event: String
    let payload: [String: AnyCodable]?
    let seq: Int?
}

/// Error inside a response
struct WSError: Codable {
    let message: String?
    let code: String?
    let details: [String: AnyCodable]?
}

/// Incoming frame (discriminated by "type" field)
enum WSFrame {
    case response(WSResponse)
    case event(WSEvent)
    case unknown(Data)
    
    static func parse(_ data: Data) -> WSFrame {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return .unknown(data)
        }
        
        switch type {
        case "res":
            if let res = try? JSONDecoder().decode(WSResponse.self, from: data) {
                return .response(res)
            }
        case "event":
            if let evt = try? JSONDecoder().decode(WSEvent.self, from: data) {
                return .event(evt)
            }
        default:
            break
        }
        return .unknown(data)
    }
}

// MARK: - Connect Handshake

enum GatewayHandshake {
    
    /// Build the connect request for operator role
    static func connectRequest(
        token: String,
        deviceId: String,
        appVersion: String = "1.0.0",
        cardTypes: [String] = []
    ) -> WSRequest {
        var caps: [AnyCodable] = []
        if !cardTypes.isEmpty {
            caps.append(AnyCodable("cards.v1"))
        }
        
        var params: [String: AnyCodable] = [
            "minProtocol": AnyCodable(3),
            "maxProtocol": AnyCodable(3),
            "client": AnyCodable([
                "id": "clios",
                "version": appVersion,
                "platform": "ios",
                "mode": "operator"
            ]),
            "role": AnyCodable("operator"),
            "scopes": AnyCodable(["operator.read", "operator.write"]),
            "caps": AnyCodable(caps.map { $0.value }),
            "commands": AnyCodable([String]()),
            "permissions": AnyCodable([String: Bool]()),
            "auth": AnyCodable(["token": token]),
            "locale": AnyCodable(Locale.current.identifier),
            "userAgent": AnyCodable("CLiOS/\(appVersion)")
        ]
        
        if !cardTypes.isEmpty {
            params["cardTypes"] = AnyCodable(cardTypes)
        }
        
        return WSRequest(method: "connect", params: params)
    }
}

// MARK: - Known Event Names

enum GatewayEvent {
    static let connectChallenge = "connect.challenge"
    static let agent = "agent"
    static let agentStream = "agent.stream"
    static let presence = "presence"
    static let tick = "tick"
    static let health = "health"
    static let heartbeat = "heartbeat"
    static let cron = "cron"
    static let execApproval = "exec.approval.requested"
    static let shutdown = "shutdown"
}

// MARK: - Known Methods

enum GatewayMethod {
    static let connect = "connect"
    static let health = "health"
    static let status = "status"
    static let chatSend = "chat.send"
    static let agent = "agent"
    static let cronList = "cron.list"
    static let cronUpdate = "cron.update"
    static let cronRun = "cron.run"
    static let execApprovalResolve = "exec.approval.resolve"
}

// MARK: - AnyCodable (type-erased Codable wrapper)

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
