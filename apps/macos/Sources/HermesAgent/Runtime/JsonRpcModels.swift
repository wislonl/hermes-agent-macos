import Foundation

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private func validateNoUnknownKeys<Key: CodingKey & CaseIterable>(
    in decoder: Decoder,
    allowedBy _: Key.Type,
    debugDescription: String
) throws {
    let rawContainer = try decoder.container(keyedBy: AnyCodingKey.self)
    let allowedKeys = Set(Key.allCases.map(\.stringValue))
    let unknownKeys = rawContainer.allKeys.filter { !allowedKeys.contains($0.stringValue) }

    guard unknownKeys.isEmpty else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: debugDescription
            )
        )
    }
}

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

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }

    init(id: JsonRpcID, method: String, params: Params) {
        self.id = id
        self.method = method
        self.params = params
    }

    func encode(to encoder: Encoder) throws {
        guard id != .null else {
            throw EncodingError.invalidValue(
                id,
                EncodingError.Context(
                    codingPath: encoder.codingPath + [CodingKeys.id],
                    debugDescription: "JSON-RPC requests must use a string or integer id."
                )
            )
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        try container.encode(params, forKey: .params)
    }
}

struct JsonRpcResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: JsonRpcID
    let result: Result?
    let error: JsonRpcError?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case jsonrpc
        case id
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "JSON-RPC response contains unknown top-level keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        id = try container.decode(JsonRpcID.self, forKey: .id)

        guard jsonrpc == "2.0" else {
            throw DecodingError.dataCorruptedError(
                forKey: .jsonrpc,
                in: container,
                debugDescription: "JSON-RPC response version must be exactly 2.0."
            )
        }

        let hasResult = container.contains(.result)
        let hasError = container.contains(.error)

        guard hasResult != hasError else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "JSON-RPC response must contain exactly one of result or error."
                )
            )
        }

        if hasResult {
            guard id != .null else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: container,
                    debugDescription: "Successful JSON-RPC responses must not use a null id."
                )
            }

            result = try container.decode(Result.self, forKey: .result)
            error = nil
        } else {
            result = nil
            error = try container.decode(JsonRpcError.self, forKey: .error)
        }
    }
}

struct JsonRpcError: Decodable, Equatable {
    let code: Int
    let message: String
    let data: [String: JSONValue]?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case code
        case message
        case data
    }

    init(code: Int, message: String, data: [String: JSONValue]?) {
        self.code = code
        self.message = message
        self.data = data
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "JSON-RPC error contains unknown keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decodeIfPresent([String: JSONValue].self, forKey: .data)
    }
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

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case runtime
        case capabilities
    }

    init(protocolVersion: String, runtime: RuntimeInfo, capabilities: [String]) {
        self.protocolVersion = protocolVersion
        self.runtime = runtime
        self.capabilities = capabilities
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "runtime.handshake result contains unknown keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(String.self, forKey: .protocolVersion)
        runtime = try container.decode(RuntimeInfo.self, forKey: .runtime)
        capabilities = try container.decode([String].self, forKey: .capabilities)
    }
}

struct RuntimeInfo: Decodable, Equatable {
    let name: String
    let version: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case name
        case version
    }

    init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "runtime info contains unknown keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
    }
}

struct ProviderTestParams: Encodable {}

struct ProviderTestResult: Decodable, Equatable {
    let status: String
    let provider: String
    let model: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case provider
        case model
    }

    init(status: String, provider: String, model: String) {
        self.status = status
        self.provider = provider
        self.model = model
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "provider.test result contains unknown keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        provider = try container.decode(String.self, forKey: .provider)
        model = try container.decode(String.self, forKey: .model)
    }
}

struct RunCreateParams: Encodable {
    let sessionId: String
    let agentProfileId: String
    let input: RunInput
    let history: [RunHistoryMessage]
    let workspace: Workspace
}

struct RunInput: Encodable {
    let type: String
    let text: String
}

struct RunHistoryMessage: Encodable, Equatable {
    let role: String
    let content: String
}

struct Workspace: Encodable {
    let path: String
}

struct RunCreateResult: Decodable, Equatable {
    let runId: String
    let status: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case runId
        case status
    }

    init(runId: String, status: String) {
        self.runId = runId
        self.status = status
    }

    init(from decoder: Decoder) throws {
        try validateNoUnknownKeys(
            in: decoder,
            allowedBy: CodingKeys.self,
            debugDescription: "run.create result contains unknown keys."
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        runId = try container.decode(String.self, forKey: .runId)
        status = try container.decode(String.self, forKey: .status)

        guard status == "running" else {
            throw DecodingError.dataCorruptedError(
                forKey: .status,
                in: container,
                debugDescription: "run.create result status must be running."
            )
        }
    }
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
