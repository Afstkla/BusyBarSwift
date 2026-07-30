import Foundation

extension BusyBarClient {
    /// Draws elements on the bar.
    ///
    /// - Throws: ``BusyBarError/api(status:message:code:)`` with status 409 when a
    ///   higher-priority app owns the screen — an active BUSY session sits at priority 90.
    public func draw(_ request: DrawRequest) async throws {
        try await send("POST", "/display/draw", json: request)
    }

    public func draw(
        _ elements: [DisplayElement],
        priority: Int? = nil,
        ledNotificationColor: BusyColor? = nil
    ) async throws {
        try await draw(
            DrawRequest(
                applicationName: applicationName,
                elements: elements,
                priority: priority,
                ledNotificationColor: ledNotificationColor
            )
        )
    }

    public func draw(
        text: String,
        font: BusyFont = .normal,
        color: BusyColor? = nil,
        align: Align? = .center,
        display: Screen = .front,
        timeout: Int? = nil,
        priority: Int? = nil
    ) async throws {
        try await draw(
            [
                .text(
                    text,
                    font: font,
                    color: color,
                    display: display,
                    align: align,
                    timeout: timeout
                )
            ],
            priority: priority
        )
    }

    /// Removes the elements drawn by `application`, defaulting to this client's own app.
    public func clearDisplay(application: String? = nil) async throws {
        try await perform(
            "DELETE",
            "/display/draw",
            query: ["application_name": application ?? applicationName]
        )
    }

    /// Removes every element the Canvas application is showing, whichever app drew it.
    public func clearAllDisplays() async throws {
        try await perform("DELETE", "/display/draw")
    }

    public func brightness() async throws -> Brightness {
        let info = try await decode(BrightnessInfo.self, "GET", "/display/brightness")
        return Brightness(wireValue: info.value)
    }

    public func setBrightness(_ brightness: Brightness) async throws {
        try await perform("POST", "/display/brightness", query: ["value": brightness.wireValue])
    }

    /// Grabs a single frame as BMP data.
    public func screenshot(of display: Screen = .front) async throws -> Data {
        try await perform("GET", "/screen", query: ["display": String(display.wireIndex)]).body
    }
}
