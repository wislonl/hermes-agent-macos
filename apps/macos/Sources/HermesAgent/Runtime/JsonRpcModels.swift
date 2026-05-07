import Foundation

enum JsonRpcID: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case string(String)
    case integer(Int)
    case null

    init(stringLiteral value: String) {
        self = .string(value)
    }

    init(integerLiteral value: Int) {
        self = .integer(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let integerValue = try? container.decode(Int.self) {
            self = .integer(integerValue)
        } else {
            throw DecodingError.typeMismatch(
                JsonRpcID.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected JSON-RPC id to be a string, integer, or null."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct JsonRpcRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: JsonRpcID
    let method: String
    let params: Params

    init(id: JsonRpcID, method: String, params: Params) {
        self.id = id
        self.method = method
        self.params = params
    }
}

struct JsonRpcResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: JsonRpcID?
    let result: Result?
    let error: JsonRpcError?
}

struct JsonRpcError: Decodable, Equatable {
    let code: Int
    let message: String
    let data: [String: JSONValue]?
}

struct RuntimeHandshakeParams: Encodable {
    let protocolVersion: String
    let client: RuntimeClientInfo
}

struct RuntimeClientInfo: Encodable {
    let name: String
    let version: String
}

struct RuntimeHandshakeResult: Decodable, Equatable {
    let protocolVersion: String
    let runtime: RuntimeInfo
    let capabilities: [String]
}

struct RuntimeInfo: Decodable, Equatable {
    let name: String
    let version: String
}

enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value."
                )
            )
        }
    }
}
