import Foundation

// Bidirectional newline-delimited JSON-RPC 2.0 over a child process's stdio.
// Both peers may originate requests; responses are correlated by id.

// MARK: - Parsing helpers (internal for testability)

enum JsonRpcParsed {
    case request(id: JsonRpcId, method: String, params: Data)
    case notification(method: String, params: Data)
    case response(id: JsonRpcId, result: Data)
    case remoteError(id: JsonRpcId, code: Int, message: String)
    case missingResult(id: JsonRpcId)
    case malformed
}

func parseJsonRpcLine(_ data: Data) -> JsonRpcParsed {
    guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return .malformed
    }
    let id: JsonRpcId? = {
        switch raw["id"] {
        case let v as Int:    return .int(v)
        case let v as String: return .string(v)
        default:              return nil
        }
    }()
    let serialize: (Any) -> Data = {
        (try? JSONSerialization.data(withJSONObject: $0)) ?? Data("{}".utf8)
    }
    if let method = raw["method"] as? String {
        let params = serialize(raw["params"] ?? [:])
        if let id { return .request(id: id, method: method, params: params) }
        return .notification(method: method, params: params)
    }
    guard let id else { return .malformed }
    if let errorObj = raw["error"] as? [String: Any] {
        let code    = (errorObj["code"]    as? Int)    ?? -1
        let message = (errorObj["message"] as? String) ?? "Unknown error"
        return .remoteError(id: id, code: code, message: message)
    }
    if let result = raw["result"] { return .response(id: id, result: serialize(result)) }
    return .missingResult(id: id)
}

/// Appends `chunk` to `buffer`, splits on newlines, returns complete non-empty lines.
func splitNewlineDelimited(buffer: inout Data, chunk: Data) -> [Data] {
    buffer.append(chunk)
    var lines: [Data] = []
    while let nl = buffer.firstIndex(of: 0x0A) {
        let line = buffer.subdata(in: 0..<nl)
        buffer.removeSubrange(0...nl)
        if !line.isEmpty { lines.append(line) }
    }
    return lines
}

enum JsonRpcTransportError: Error, LocalizedError {
    case processNotRunning
    case processFailedToStart(String)
    case writeFailed
    case decodeFailed(String)
    case remoteError(code: Int, message: String)
    case missingResult
    case cancelled

    var errorDescription: String? {
        switch self {
        case .processNotRunning: return "Hermes runtime process is not running"
        case .processFailedToStart(let m): return "Failed to start Hermes: \(m)"
        case .writeFailed: return "Could not write to Hermes stdin"
        case .decodeFailed(let m): return "Failed to decode Hermes message: \(m)"
        case .remoteError(let code, let message): return "Hermes error \(code): \(message)"
        case .missingResult: return "Hermes response had no result"
        case .cancelled: return "Request was cancelled"
        }
    }
}

enum JsonRpcId: Hashable {
    case int(Int)
    case string(String)
}

actor JsonRpcTransport {
    typealias NotificationHandler = @Sendable (_ method: String, _ params: Data) -> Void
    typealias RequestHandler = @Sendable (_ id: JsonRpcId, _ method: String, _ params: Data) -> Void
    typealias ExitHandler = @Sendable () -> Void

    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe

    private var nextId: Int = 1
    private var pending: [JsonRpcId: CheckedContinuation<Data, Error>] = [:]
    private var notificationHandler: NotificationHandler?
    private var requestHandler: RequestHandler?
    private var exitHandler: ExitHandler?
    private var readBuffer = Data()
    private var isRunning = false

    init(executableURL: URL, arguments: [String], extraEnvironment: [String: String] = [:]) {
        let p = Process()
        p.executableURL = executableURL
        p.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        for (k, v) in extraEnvironment { env[k] = v }
        p.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        p.standardInput = stdinPipe
        p.standardOutput = stdoutPipe
        p.standardError = stderrPipe

        self.process = p
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
    }

    func start(
        onNotification: @escaping NotificationHandler,
        onRequest: @escaping RequestHandler,
        onExit: ExitHandler? = nil
    ) throws {
        notificationHandler = onNotification
        requestHandler = onRequest
        exitHandler = onExit
        do {
            try process.run()
        } catch {
            throw JsonRpcTransportError.processFailedToStart(error.localizedDescription)
        }
        isRunning = true

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        let weakSelf = WeakActorBox(self)

        // readabilityHandler is called by Foundation on its own queue whenever
        // data arrives — no blocking reads, no cooperative-pool starvation.
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                Task { await weakSelf.value?.handleReaderEnded() }
                return
            }
            Task { await weakSelf.value?.processIncoming(data) }
        }

        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let str = String(data: data, encoding: .utf8) {
                NSLog("[hermes-acp] %@", str.trimmingCharacters(in: .newlines))
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        process.terminate()
        let toFail = pending
        pending.removeAll()
        for (_, cont) in toFail { cont.resume(throwing: JsonRpcTransportError.cancelled) }
    }

    deinit {
        if process.isRunning { process.terminate() }
    }

    func sendRequest<Params: Encodable, Result: Decodable>(
        method: String,
        params: Params,
        resultType: Result.Type
    ) async throws -> Result {
        let resultData = try await sendRawRequest(method: method, params: params)
        if Result.self == ACPEmpty.self {
            return ACPEmpty() as! Result
        }
        do {
            return try JSONDecoder().decode(Result.self, from: resultData)
        } catch {
            throw JsonRpcTransportError.decodeFailed("\(method): \(error)")
        }
    }

    func sendNotification<Params: Encodable>(method: String, params: Params) throws {
        let envelope = OutgoingNotification(jsonrpc: "2.0", method: method, params: params)
        try writeEncodable(envelope)
    }

    func sendResponse<Result: Encodable>(id: JsonRpcId, result: Result) throws {
        let envelope = OutgoingResponse(jsonrpc: "2.0", id: AnyJsonValue(id), result: result)
        try writeEncodable(envelope)
    }

    func sendErrorResponse(id: JsonRpcId, code: Int, message: String) throws {
        let envelope = OutgoingErrorResponse(
            jsonrpc: "2.0",
            id: AnyJsonValue(id),
            error: ErrorBody(code: code, message: message)
        )
        try writeEncodable(envelope)
    }

    // MARK: - Internals

    // Called from a Foundation-managed queue via Task; actor serialises access.
    fileprivate func processIncoming(_ data: Data) {
        for line in splitNewlineDelimited(buffer: &readBuffer, chunk: data) {
            handleLine(line)
        }
    }

    fileprivate func handleReaderEnded() {
        let toFail = pending
        pending.removeAll()
        for (_, cont) in toFail { cont.resume(throwing: JsonRpcTransportError.processNotRunning) }
        isRunning = false
        let onExit = exitHandler
        exitHandler = nil
        onExit?()
    }

    private func sendRawRequest<Params: Encodable>(method: String, params: Params) async throws -> Data {
        guard isRunning, process.isRunning else {
            throw JsonRpcTransportError.processNotRunning
        }
        let id = JsonRpcId.int(nextId)
        nextId += 1

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            pending[id] = cont
            let envelope = OutgoingRequest(
                jsonrpc: "2.0",
                id: AnyJsonValue(id),
                method: method,
                params: params
            )
            do {
                try writeEncodable(envelope)
            } catch {
                pending[id] = nil
                cont.resume(throwing: error)
            }
        }
    }

    private func writeEncodable<E: Encodable>(_ envelope: E) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            throw JsonRpcTransportError.writeFailed
        }
        var line = data
        line.append(0x0A)
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: line)
        } catch {
            throw JsonRpcTransportError.writeFailed
        }
    }

    private func handleLine(_ data: Data) {
        switch parseJsonRpcLine(data) {
        case .request(let id, let method, let params):
            requestHandler?(id, method, params)
        case .notification(let method, let params):
            notificationHandler?(method, params)
        case .response(let id, let result):
            pending.removeValue(forKey: id)?.resume(returning: result)
        case .remoteError(let id, let code, let message):
            pending.removeValue(forKey: id)?.resume(
                throwing: JsonRpcTransportError.remoteError(code: code, message: message)
            )
        case .missingResult(let id):
            pending.removeValue(forKey: id)?.resume(
                throwing: JsonRpcTransportError.missingResult
            )
        case .malformed:
            break
        }
    }
}

// MARK: - Wire envelopes

private struct OutgoingRequest<Params: Encodable>: Encodable {
    let jsonrpc: String
    let id: AnyJsonValue
    let method: String
    let params: Params
}

private struct OutgoingNotification<Params: Encodable>: Encodable {
    let jsonrpc: String
    let method: String
    let params: Params
}

private struct OutgoingResponse<Result: Encodable>: Encodable {
    let jsonrpc: String
    let id: AnyJsonValue
    let result: Result
}

private struct OutgoingErrorResponse: Encodable {
    let jsonrpc: String
    let id: AnyJsonValue
    let error: ErrorBody
}

private struct ErrorBody: Encodable {
    let code: Int
    let message: String
}

private final class WeakActorBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

private struct AnyJsonValue: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ id: JsonRpcId) {
        switch id {
        case .int(let v): encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        case .string(let v): encode = { var c = $0.singleValueContainer(); try c.encode(v) }
        }
    }

    func encode(to encoder: Encoder) throws { try encode(encoder) }
}
