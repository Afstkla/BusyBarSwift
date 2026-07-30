import Foundation
import Testing

@testable import BusyBar

@Suite("Wire format")
struct EncodingTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try BusyBarClient.encoder.encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("Element payloads flatten alongside the discriminator the API expects")
    func flattensElementPayload() throws {
        let request = DrawRequest(
            applicationName: "my_app",
            elements: [
                .text("Hi", id: "0", font: .bold, color: .red, x: 36, y: 10, align: .center, timeout: 10)
            ],
            priority: 60,
            ledNotificationColor: .green
        )

        let object = try json(request)
        #expect(object["application_name"] as? String == "my_app")
        #expect(object["priority"] as? Int == 60)
        #expect(object["led_notification_color"] as? String == "#00FF00FF")

        let elements = try #require(object["elements"] as? [[String: Any]])
        let element = try #require(elements.first)
        #expect(element["type"] as? String == "text")
        #expect(element["text"] as? String == "Hi")
        #expect(element["font"] as? String == "bold")
        #expect(element["color"] as? String == "#FF0000FF")
        #expect(element["align"] as? String == "center")
        #expect(element["timeout"] as? Int == 10)
        #expect(element["x"] as? Int == 36)
    }

    @Test("Optional element fields are omitted rather than sent as null")
    func omitsUnsetFields() throws {
        let request = DrawRequest(applicationName: "app", elements: [.text("Hi")])
        let elements = try #require(try json(request)["elements"] as? [[String: Any]])
        let element = try #require(elements.first)

        #expect(element["color"] == nil)
        #expect(element["scroll_rate"] == nil)
        #expect(element["display_until"] == nil)
    }

    @Test("Rectangle fields keep their snake_case names")
    func encodesRectangle() throws {
        let element = DisplayElement(
            id: "box",
            content: .rectangle(
                .init(width: 20, height: 10, fill: .gradientHorizontal, fillColors: [.red, .clear], borderWidth: 2)
            )
        )
        let object = try json(DrawRequest(applicationName: "app", elements: [element]))
        let encoded = try #require((object["elements"] as? [[String: Any]])?.first)

        #expect(encoded["type"] as? String == "rectangle")
        #expect(encoded["fill"] as? String == "gradient_h")
        #expect(encoded["border_width"] as? Int == 2)
        #expect(encoded["fill_colors"] as? [String] == ["#FF0000FF", "#00000000"])
    }

    @Test("Timer snapshots survive a decode/encode round trip")
    func roundTripsIntervalSnapshot() throws {
        let payload = Data("""
        {
          "snapshot": {
            "type": "INTERVAL",
            "card_id": "00000000-0000-0000-0000-000000000000",
            "current_interval": 1,
            "current_interval_time_total_ms": 60000,
            "current_interval_time_left_ms": 42690,
            "is_paused": false,
            "interval_settings": {
              "type": "INTERVAL",
              "interval_work_ms": 120000,
              "interval_rest_ms": 60000,
              "interval_work_cycles_count": 3,
              "is_autostart_enabled": false
            },
            "busy_bar_settings": {
              "theme": "on_air",
              "show_work_phase_only": false,
              "trigger_smart_home": true
            }
          },
          "snapshot_timestamp_ms": 1761582532251
        }
        """.utf8)

        let snapshot = try BusyBarClient.decoder.decode(BusySnapshot.self, from: payload)

        guard case let .interval(cardID, current, total, left, isPaused, settings) = snapshot.snapshot.state else {
            Issue.record("expected an interval snapshot")
            return
        }
        #expect(cardID == "00000000-0000-0000-0000-000000000000")
        #expect(current == 1)
        #expect(total == 60000)
        #expect(left == 42690)
        #expect(isPaused == false)
        #expect(settings.intervalWorkMs == 120000)
        #expect(snapshot.snapshot.busyBarSettings.theme == "on_air")

        let reencoded = try json(snapshot)
        let inner = try #require(reencoded["snapshot"] as? [String: Any])
        #expect(inner["type"] as? String == "INTERVAL")
        #expect(inner["card_id"] as? String == cardID)
        #expect(inner["current_interval_time_left_ms"] as? Int == 42690)
        #expect(inner["busy_bar_settings"] != nil)
    }

    @Test("A not-started snapshot carries only its type")
    func decodesNotStarted() throws {
        let payload = Data("""
        {"snapshot":{"type":"NOT_STARTED","busy_bar_settings":{"theme":"on_air","show_work_phase_only":false,"trigger_smart_home":true}},"snapshot_timestamp_ms":1}
        """.utf8)

        let snapshot = try BusyBarClient.decoder.decode(BusySnapshot.self, from: payload)
        #expect(snapshot.snapshot.state.isPaused == false)
        guard case .notStarted = snapshot.snapshot.state else {
            Issue.record("expected NOT_STARTED")
            return
        }
    }

    @Test("Anchors land where the name says on the 72×16 front display")
    func placesAnchors() {
        #expect(Align.topLeft.anchor(on: .front) == (0, 0))
        #expect(Align.center.anchor(on: .front) == (36, 8))
        #expect(Align.bottomRight.anchor(on: .front) == (72, 16))
        #expect(Align.topMid.anchor(on: .front) == (36, 0))
        #expect(Align.midLeft.anchor(on: .front) == (0, 8))
        #expect(Align.center.anchor(on: .back) == (20, 20))
    }

    @Test("Centred text is positioned at the middle, not hung off the corner")
    func centresText() async throws {
        let transport = FakeTransport()
        let client = BusyBarClient(transport: transport, applicationName: "demo")

        try await client.draw(text: "Hello")

        let body = try #require(await transport.requests.first?.body)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let element = try #require((object["elements"] as? [[String: Any]])?.first)

        #expect(element["align"] as? String == "center")
        #expect(element["x"] as? Int == 36)
        #expect(element["y"] as? Int == 8)
    }

    @Test("Colours parse from every hex shorthand")
    func parsesColours() throws {
        #expect(BusyColor(hex: "#FF0000FF")?.hexString == "#FF0000FF")
        #expect(BusyColor(hex: "00FF00")?.hexString == "#00FF00FF")
        #expect(BusyColor(hex: "#F00")?.hexString == "#FF0000FF")
        #expect(BusyColor(hex: "nope") == nil)
    }
}
