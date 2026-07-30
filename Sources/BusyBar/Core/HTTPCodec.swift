import Foundation

/// Serializes and parses HTTP/1.1 over a plain byte stream.
///
/// The BLE transport needs this because the firmware's `ble_http_repeater` pipes the
/// Nordic UART characteristics straight into the on-device web server over loopback —
/// there is no URL loading system on that path, only bytes.
enum HTTPCodec {
    static let crlf = Data([0x0D, 0x0A])
    static let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A])

    static func serialize(_ request: BusyRequest, host: String) -> Data {
        var headers = request.headers
        headers["Host"] = host
        headers["Connection"] = "close"
        headers["Content-Length"] = String(request.body?.count ?? 0)

        var text = "\(request.method) \(request.pathWithQuery) HTTP/1.1\r\n"
        for key in headers.keys.sorted() {
            text += "\(key): \(headers[key]!)\r\n"
        }
        text += "\r\n"

        var data = Data(text.utf8)
        if let body = request.body { data.append(body) }
        return data
    }

    /// Attempts to parse a complete response from `buffer`.
    ///
    /// Returns `nil` when more bytes are still needed, which is how the BLE transport knows
    /// whether to keep waiting for further indications.
    static func parse(_ buffer: Data) throws -> BusyResponse? {
        guard let headerEnd = buffer.range(of: headerTerminator) else { return nil }

        let headSlice = buffer[buffer.startIndex..<headerEnd.lowerBound]
        guard let head = String(data: headSlice, encoding: .utf8) else {
            throw BusyBarError.malformedResponse("headers are not valid UTF-8")
        }

        var lines = head.components(separatedBy: "\r\n")
        guard !lines.isEmpty else {
            throw BusyBarError.malformedResponse("empty head")
        }

        let statusLine = lines.removeFirst().split(separator: " ", maxSplits: 2).map(String.init)
        guard statusLine.count >= 2, let status = Int(statusLine[1]) else {
            throw BusyBarError.malformedResponse("bad status line")
        }

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name.lowercased()] = value
        }

        let bodyStart = headerEnd.upperBound
        let remainder = buffer[bodyStart...]

        if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            guard let body = try parseChunked(remainder) else { return nil }
            return BusyResponse(status: status, headers: headers, body: body)
        }

        guard let declared = headers["content-length"].flatMap(Int.init) else {
            // No length and no chunking: the firmware closes the connection to signal the end,
            // so whatever has arrived when the pipe drains is the whole body.
            return BusyResponse(status: status, headers: headers, body: Data(remainder))
        }

        guard remainder.count >= declared else { return nil }
        let body = remainder.prefix(declared)
        return BusyResponse(status: status, headers: headers, body: Data(body))
    }

    /// Returns `nil` while the terminating zero-length chunk has not arrived yet.
    private static func parseChunked(_ data: Data) throws -> Data? {
        var body = Data()
        var cursor = data.startIndex

        while true {
            guard let lineEnd = data[cursor...].range(of: crlf) else { return nil }
            let sizeText = String(data: data[cursor..<lineEnd.lowerBound], encoding: .utf8) ?? ""
            let sizeField = sizeText.split(separator: ";").first.map(String.init) ?? sizeText
            guard let size = Int(sizeField.trimmingCharacters(in: .whitespaces), radix: 16) else {
                throw BusyBarError.malformedResponse("bad chunk size '\(sizeText)'")
            }

            if size == 0 { return body }

            let chunkStart = lineEnd.upperBound
            let chunkEnd = chunkStart + size
            guard data.count >= data.distance(from: data.startIndex, to: chunkEnd) + 2 else {
                return nil
            }
            body.append(contentsOf: data[chunkStart..<chunkEnd])
            cursor = chunkEnd + 2
        }
    }
}
