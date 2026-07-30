# BusyBarSwift

A native Swift client for the [BUSY Bar](https://busy.app), talking to it **over Bluetooth
first** and falling back to Wi-Fi or USB.

No dependencies. Full API coverage. Works on macOS, iOS, tvOS, watchOS, and visionOS.

```swift
let bar = BusyBarClient.nearby()

try await bar.draw(text: "shipping it", color: .green)
try await bar.setBrightness(.level(60))

let power = try await bar.powerInfo()
print("battery \(power.batteryCharge)%")
```

## Why Bluetooth works at all

The bar's HTTP API is normally reached over IP. But the firmware also runs a
[`ble_http_repeater`](https://github.com/busy-app/busybar-firmware/blob/main/applications/services/ble/http/ble_http_repeater.c)
that pipes a Nordic UART Service straight into its own web server on `127.0.0.1:80`:

```
CoreBluetooth  ──write──▶  6E400002 (RX)  ─┐
                                           ├─▶  ble_http_repeater  ──▶  127.0.0.1:80
CoreBluetooth  ◀─indicate─  6E400003 (TX)  ─┘
```

So Bluetooth isn't a reduced command set — it's a byte pipe to the same endpoints. This
library writes HTTP/1.1 request bytes into the RX characteristic and reassembles the response
from 237-byte TX indications. Every call below works identically on either transport.

## Installation

```swift
.package(url: "https://github.com/Afstkla/BusyBarSwift.git", from: "0.1.0")
```

```swift
.product(name: "BusyBar", package: "BusyBarSwift")
```

## Connecting

Bluetooth, whichever bar is answering loudest:

```swift
let bar = BusyBarClient.nearby()
```

Discovery looks over Bluetooth and Bonjour at once, so you never hardcode an address:

```swift
let devices = try await BusyBarClient.discover()
for device in devices {
    print(device.name, device.routeDescription)  // "BUSY bar", "Bluetooth · -54 dBm"
}

let bar = BusyBarClient.connect(to: devices[0])
```

Pass a second result as the backstop, and the client fails over between them by itself:

```swift
let bar = BusyBarClient.connect(
    to: devices.first { $0.isBluetooth }!,
    fallback: devices.first { !$0.isBluetooth }
)
```

Straight over IP — `10.0.4.20` is the address the bar exposes over USB:

```swift
let bar = BusyBarClient.at("10.0.4.20", accessKey: "12345678")
```

Through BUSY Cloud, with a BAR-scope token:

```swift
let bar = BusyBarClient.cloud(token: ProcessInfo.processInfo.environment["BUSYBAR_TOKEN"]!)
```

> [!IMPORTANT]
> Bluetooth has to be switched on at the device before `BLETransport` can reach it — from the
> bar's own settings menu, or once over USB/Wi-Fi with `try await bar.enableBLE()`.

## Drawing

The display API is element-based. Each element has an id, a position, and a lifetime:

```swift
try await bar.draw([
    .text("BUILD", id: "label", font: .small, color: .white, y: 2, align: .topMid),
    .countdown(until: .now.addingTimeInterval(600), id: "clock", color: .orange, align: .center),
    DisplayElement(
        id: "bar",
        content: .rectangle(.init(width: 72, height: 4, fill: .gradientHorizontal,
                                  fillColors: [.green, .clear])),
        y: 26
    ),
], ledNotificationColor: .green)
```

### The two displays

| | Resolution | Colour | Frame from `/screen` |
|---|---|---|---|
| `.front` | 72 × 16 | 24-bit RGB | 3456 bytes, 3 per pixel |
| `.back` | 160 × 80 | monochrome OLED, 16 grey levels | 6400 bytes, 4 bits per pixel |

The back packs two pixels per byte — even column in the low nibble, odd in the high one.
`ScreenFrame` unpacks both, so `pixel(x:y:)` and `makeImage()` work the same either way.

`align` names *which point of the element* you are positioning; `x`/`y` still decide where that
point lands, and both default to `0`. `Align.anchor(on:)` gives the coordinate for an anchor —
`.center` is `(36, 8)` on the front and `(80, 40)` on the back — and `draw(text:)` applies it
for you.

Priority decides who wins the screen. Built-in apps sit at 10 and an active BUSY session at
90, so a draw at the default 50 is refused during a work session with HTTP 409:

```swift
do {
    try await bar.draw(text: "hello")
} catch BusyBarError.api(status: 409, _, _) {
    // something more important is on screen
}
```

Assets are per-application. Upload once, then reference by name:

```swift
try await bar.uploadAsset(contentsOf: logoURL, as: "logo.png")
try await bar.draw([.image(path: "logo.png", display: .back)])
```

## What else it does

Everything in the device's OpenAPI document (25.0.0) is covered:

| Area | Calls |
|---|---|
| Display | `draw`, `clearDisplay`, `brightness`, `setBrightness`, `screenshot` |
| Audio | `playAudio`, `playStockAudio`, `stopAudio`, `volume`, `setVolume` |
| Assets | `uploadAsset`, `deleteAssets` |
| BUSY timer | `busySnapshot`, `setBusySnapshot`, `busyProfile`, `setBusyProfile` |
| Storage | `listStorage`, `readFile`, `writeFile`, `removeFile`, `createDirectory`, `moveFile`, `storageStatus` |
| Settings | `name`, `setName`, `httpAccess`, `setHTTPAccess`, `press` |
| System | `version`, `status`, `deviceInfo`, `firmwareInfo`, `systemInfo`, `powerInfo`, `dumpLog` |
| Time | `time`, `setTime`, `timezone`, `setTimezone`, `supportedTimezones` |
| Network | `wifiStatus`, `bleStatus`, `enableBLE`, `disableBLE`, `forgetBLEPairing` |
| Smart home | `smartHomePairingStatus`, `startSmartHomePairing`, `smartHomeSwitch`, `setSmartHomeSwitch` |
| Updater | `checkForUpdate`, `updateStatus`, `updateChangelog`, `installUpdate`, `uploadFirmware`, `autoupdateSettings` |
| Account | `accountInfo`, `accountStatus`, `accountBackend` |

## Example app

A SwiftUI macOS app that discovers bars over both Bluetooth and Bonjour, shows live status,
and drives the display:

```bash
cd Examples/BusyBarDemo
swift run
```

It's a separate package, so it never enters the library's dependency graph.

## Troubleshooting Bluetooth

**The bar shows up in a scan but connecting hangs, then reports a stalled connection.**

It's already bonded to another device — typically a phone running the official app. Once the
firmware has a bonded peer it puts that peer on a hardware acceptlist and advertises with
filter policy `ALLOW_PAIRED`, which drops both scan requests and connection requests from
anyone else. It keeps broadcasting, so it still appears in a scan; it just never answers you.

Clear the pairing on the bar (Settings › Bluetooth), or over USB/Wi-Fi:

```swift
try await BusyBarClient.at("10.0.4.20").forgetBLEPairing()
```

A related tell: if a discovered bar's name comes back as the generic `BUSY Bar`, no scan
response arrived — the same filter policy is why.

**Nothing is found at all.** BLE is switched off at the device. Turn it on from its menu, or
`try await bar.enableBLE()` over USB or Wi-Fi.

**No network route appears.** The bar is only on the network when it's on Wi-Fi or plugged in
over USB — the latter gives it `10.0.4.20`. Check with `ping 10.0.4.20`.

## Not implemented

`/api/status/ws` — the live status and screen-mirroring stream. Its frames are protobuf, which
would mean a code-generation dependency for a library that otherwise has none. Poll `status()`
instead. If you want it, open an issue.

## Related

- [`@busy-app/busy-lib`](https://www.npmjs.com/package/@busy-app/busy-lib) — TypeScript
- [`busylib`](https://pypi.org/project/busylib/) — Python
- [`busybar-firmware`](https://github.com/busy-app/busybar-firmware) — firmware sources
- [HTTP API reference](https://api.busy.app/busybar/docs)

## License

MIT. See [LICENSE](LICENSE).
