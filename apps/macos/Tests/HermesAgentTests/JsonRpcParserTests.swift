import Testing
import Foundation
@testable import HermesAgentCore

@Suite("JsonRpcParser")
struct JsonRpcParserTests {

    // MARK: - parseJsonRpcLine

    @Test("parses a notification (no id)")
    func parseNotification() {
        let json = #"{"jsonrpc":"2.0","method":"update","params":{"x":1}}"#
        let data = Data(json.utf8)
        guard case .notification(let method, let params) = parseJsonRpcLine(data) else {
            Issue.record("Expected notification"); return
        }
        #expect(method == "update")
        let obj = try? JSONSerialization.jsonObject(with: params) as? [String: Any]
        #expect(obj?["x"] as? Int == 1)
    }

    @Test("parses a request (has id)")
    func parseRequest() {
        let json = #"{"jsonrpc":"2.0","id":42,"method":"ping","params":{}}"#
        guard case .request(let id, let method, _) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected request"); return
        }
        #expect(id == .int(42))
        #expect(method == "ping")
    }

    @Test("parses a string-id request")
    func parseStringIdRequest() {
        let json = #"{"jsonrpc":"2.0","id":"abc","method":"foo","params":{}}"#
        guard case .request(let id, _, _) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected request"); return
        }
        #expect(id == .string("abc"))
    }

    @Test("parses a success response")
    func parseResponse() {
        let json = #"{"jsonrpc":"2.0","id":1,"result":{"ok":true}}"#
        guard case .response(let id, let result) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected response"); return
        }
        #expect(id == .int(1))
        let obj = try? JSONSerialization.jsonObject(with: result) as? [String: Any]
        #expect(obj?["ok"] as? Bool == true)
    }

    @Test("parses an error response")
    func parseErrorResponse() {
        let json = #"{"jsonrpc":"2.0","id":2,"error":{"code":-32600,"message":"Invalid Request"}}"#
        guard case .remoteError(let id, let code, let message) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected remoteError"); return
        }
        #expect(id == .int(2))
        #expect(code == -32600)
        #expect(message == "Invalid Request")
    }

    @Test("returns malformed for garbage input")
    func parseMalformed() {
        let data = Data("not json at all".utf8)
        guard case .malformed = parseJsonRpcLine(data) else {
            Issue.record("Expected malformed"); return
        }
    }

    @Test("returns malformed for empty data")
    func parseEmptyData() {
        guard case .malformed = parseJsonRpcLine(Data()) else {
            Issue.record("Expected malformed"); return
        }
    }

    @Test("returns missingResult when result key absent")
    func parseMissingResult() {
        let json = #"{"jsonrpc":"2.0","id":3}"#
        guard case .missingResult(let id) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected missingResult"); return
        }
        #expect(id == .int(3))
    }

    @Test("notification with missing params defaults to empty object")
    func notificationMissingParams() {
        let json = #"{"jsonrpc":"2.0","method":"heartbeat"}"#
        guard case .notification(let method, let params) = parseJsonRpcLine(Data(json.utf8)) else {
            Issue.record("Expected notification"); return
        }
        #expect(method == "heartbeat")
        let obj = try? JSONSerialization.jsonObject(with: params) as? [String: Any]
        #expect(obj != nil)
    }

    // MARK: - splitNewlineDelimited

    @Test("splits single complete line")
    func splitSingleLine() {
        var buf = Data()
        let lines = splitNewlineDelimited(buffer: &buf, chunk: Data("hello\n".utf8))
        #expect(lines.count == 1)
        #expect(String(data: lines[0], encoding: .utf8) == "hello")
        #expect(buf.isEmpty)
    }

    @Test("splits multiple lines in one chunk")
    func splitMultipleLines() {
        var buf = Data()
        let lines = splitNewlineDelimited(buffer: &buf, chunk: Data("a\nb\nc\n".utf8))
        #expect(lines.count == 3)
    }

    @Test("buffers incomplete line across chunks")
    func splitAcrossChunks() {
        var buf = Data()
        let first = splitNewlineDelimited(buffer: &buf, chunk: Data("hel".utf8))
        #expect(first.isEmpty)
        let second = splitNewlineDelimited(buffer: &buf, chunk: Data("lo\n".utf8))
        #expect(second.count == 1)
        #expect(String(data: second[0], encoding: .utf8) == "hello")
    }

    @Test("ignores empty lines")
    func splitIgnoresEmptyLines() {
        var buf = Data()
        let lines = splitNewlineDelimited(buffer: &buf, chunk: Data("\n\nhello\n\n".utf8))
        #expect(lines.count == 1)
    }
}
