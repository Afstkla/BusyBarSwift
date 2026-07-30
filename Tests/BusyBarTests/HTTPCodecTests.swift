import Foundation
import Testing

@testable import BusyBar

/// The BLE transport stands or falls on this codec: it is the only thing turning a stream of
/// 237-byte indications back into a response.
@Suite("HTTP/1.1 codec")
struct HTTPCodecTests {
    @Test("A request serializes with the headers the firmware's web server needs")
    func serializesRequest() throws {
        let request = BusyRequest(
            method: "POST",
            path: "/api/display/brightness",
            query: ["value": "50"],
            headers: ["X-API-Token": "1234"],
            body: Data("{}".utf8)
        )

        let wire = String(decoding: HTTPCodec.serialize(request, host: "127.0.0.1"), as: UTF8.self)

        #expect(wire.hasPrefix("POST /api/display/brightness?value=50 HTTP/1.1\r\n"))
        #expect(wire.contains("Host: 127.0.0.1\r\n"))
        #expect(wire.contains("Connection: close\r\n"))
        #expect(wire.contains("Content-Length: 2\r\n"))
        #expect(wire.contains("X-API-Token: 1234\r\n"))
        #expect(wire.hasSuffix("\r\n\r\n{}"))
    }

    @Test("A content-length response parses once the body is complete")
    func parsesContentLengthResponse() throws {
        let body = #"{"api_semver":"25.0.0"}"#
        let raw = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)".utf8)

        let response = try #require(try HTTPCodec.parse(raw))

        #expect(response.status == 200)
        #expect(response.headers["content-type"] == "application/json")
        #expect(String(decoding: response.body, as: UTF8.self) == body)
    }

    @Test("A half-arrived response yields nil so the transport keeps waiting")
    func waitsForIncompleteResponses() throws {
        let headerOnly = Data("HTTP/1.1 200 OK\r\nContent-Length: 20\r\n\r\n".utf8)
        #expect(try HTTPCodec.parse(headerOnly) == nil)

        let split = Data("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n12345".utf8)
        #expect(try HTTPCodec.parse(split) == nil)
    }

    @Test("A response split across BLE indications reassembles")
    func reassemblesChunkedIndications() throws {
        let body = String(repeating: "a", count: 500)
        let whole = Data("HTTP/1.1 200 OK\r\nContent-Length: 500\r\n\r\n\(body)".utf8)

        var buffer = Data()
        var parsed: BusyResponse?
        // Same splitting the BLE transport does, so this stays honest if that changes.
        for chunk in whole.chunks(of: 237) {
            #expect(parsed == nil)
            buffer.append(chunk)
            parsed = try HTTPCodec.parse(buffer)
        }

        let response = try #require(parsed)
        #expect(response.status == 200)
        #expect(response.body.count == 500)
    }

    @Test("Chunked transfer-encoding parses and needs its terminating chunk")
    func parsesChunkedEncoding() throws {
        let head = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
        #expect(try HTTPCodec.parse(Data("\(head)5\r\nhello\r\n".utf8)) == nil)

        let complete = Data("\(head)5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n".utf8)
        let response = try #require(try HTTPCodec.parse(complete))

        #expect(response.status == 200)
        #expect(String(decoding: response.body, as: UTF8.self) == "hello world")
    }

    @Test("A body with neither length nor chunking is taken as-is")
    func parsesConnectionCloseBody() throws {
        let raw = Data("HTTP/1.1 500 Internal Server Error\r\n\r\nboom".utf8)
        let response = try #require(try HTTPCodec.parse(raw))

        #expect(response.status == 500)
        #expect(String(decoding: response.body, as: UTF8.self) == "boom")
    }

    @Test("A corrupt status line is rejected rather than guessed at")
    func rejectsGarbage() {
        #expect(throws: BusyBarError.self) {
            try HTTPCodec.parse(Data("NOT HTTP AT ALL\r\n\r\n".utf8))
        }
    }

    @Test("Chunking covers the payload exactly, including a ragged final piece")
    func chunksPayload() {
        let payload = Data(repeating: 0xAB, count: 500)
        let chunks = payload.chunks(of: 237)

        #expect(chunks.map(\.count) == [237, 237, 26])
        #expect(chunks.reduce(Data(), +) == payload)
        #expect(Data().chunks(of: 237).isEmpty)
        #expect(Data([1, 2]).chunks(of: 237) == [Data([1, 2])])
    }
}
