import Foundation
import Testing

@testable import BusyBar

/// Records what the client asked for and replies with whatever the test wants.
actor FakeTransport: BusyTransport {
    private(set) var requests: [BusyRequest] = []
    private let respond: @Sendable (BusyRequest) -> BusyResponse

    init(respond: @escaping @Sendable (BusyRequest) -> BusyResponse) {
        self.respond = respond
    }

    init(status: Int = 200, json: String = #"{"result":"OK"}"#) {
        self.init { _ in BusyResponse(status: status, body: Data(json.utf8)) }
    }

    func send(_ request: BusyRequest) async throws -> BusyResponse {
        requests.append(request)
        return respond(request)
    }
}

/// A transport that never reaches the bar, standing in for BLE being out of range.
struct UnreachableTransport: BusyTransport {
    func send(_ request: BusyRequest) async throws -> BusyResponse {
        throw BusyBarError.notConnected
    }
}

@Suite("Client")
struct ClientTests {
    @Test("Query parameters and the version header reach the transport")
    func buildsRequests() async throws {
        let transport = FakeTransport()
        let client = BusyBarClient(transport: transport, applicationName: "demo")

        try await client.setBrightness(.level(42))

        let request = try #require(await transport.requests.first)
        #expect(request.method == "POST")
        #expect(request.path == "/display/brightness")
        #expect(request.query["value"] == "42")
        #expect(request.headers["X-Busy-Api-Version"] == "25.0.0")
    }

    @Test("Brightness clamps out-of-range levels instead of letting the bar reject them")
    func clampsBrightness() {
        #expect(Brightness.level(150).wireValue == "100")
        #expect(Brightness.level(-5).wireValue == "0")
        #expect(Brightness.auto.wireValue == "auto")
    }

    @Test("Clearing the display scopes itself to this client's application")
    func scopesClearToApplication() async throws {
        let transport = FakeTransport()
        let client = BusyBarClient(transport: transport, applicationName: "demo")

        try await client.clearDisplay()

        let request = try #require(await transport.requests.first)
        #expect(request.method == "DELETE")
        #expect(request.query["application_name"] == "demo")
    }

    @Test("An error body becomes a readable error, not a decode failure")
    func surfacesAPIErrors() async throws {
        let transport = FakeTransport(
            status: 409,
            json: #"{"error":"Priority too low","code":409}"#
        )
        let client = BusyBarClient(transport: transport)

        await #expect(throws: BusyBarError.self) {
            try await client.draw(text: "Hi")
        }

        do {
            try await client.draw(text: "Hi")
        } catch let BusyBarError.api(status, message, code) {
            #expect(status == 409)
            #expect(message == "Priority too low")
            #expect(code == 409)
        }
    }

    @Test("Volume is sent as an integer and can suppress the confirmation blip")
    func sendsVolume() async throws {
        let transport = FakeTransport()
        let client = BusyBarClient(transport: transport)

        try await client.setVolume(43.6, silent: true)

        let request = try #require(await transport.requests.first)
        #expect(request.query["volume"] == "44")
        #expect(request.query["silent"] == "1")
    }

    @Test("Fallback moves to the next transport and stays there")
    func fallsBackBetweenTransports() async throws {
        let working = FakeTransport(json: #"{"api_semver":"25.0.0"}"#)
        let client = BusyBarClient(transport: FallbackTransport([UnreachableTransport(), working]))

        #expect(try await client.version().apiSemver == "25.0.0")
        #expect(try await client.version().apiSemver == "25.0.0")
        #expect(await working.requests.count == 2)
    }

    @Test("A refusal from the bar is not treated as a dead transport")
    func doesNotFallBackOnAPIErrors() async throws {
        let refusing = FakeTransport(status: 409, json: #"{"error":"busy","code":409}"#)
        let other = FakeTransport(json: #"{"api_semver":"25.0.0"}"#)
        let client = BusyBarClient(transport: FallbackTransport([refusing, other]))

        await #expect(throws: BusyBarError.self) {
            try await client.version()
        }
        #expect(await other.requests.isEmpty)
    }
}
