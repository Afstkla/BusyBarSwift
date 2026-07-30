# Contributing

Thanks for taking a look. Issues and pull requests are both welcome.

## Getting set up

```bash
git clone https://github.com/Afstkla/BusyBarSwift.git
cd BusyBarSwift
swift test
```

The test suite needs no hardware — the transports are behind a protocol, and the HTTP codec
and wire format are tested against fixtures.

To run the example app:

```bash
cd Examples/BusyBarDemo
swift run
```

## Working against a real bar

Copy `.env.example` to `.env` and fill in your device's access key if it has one. `.env` is
gitignored; please keep tokens out of commits.

Bluetooth has to be enabled on the bar before `BLETransport` can reach it. Turn it on from
the device menu, or over USB/Wi-Fi:

```swift
try await BusyBarClient.at("10.0.4.20").enableBLE()
```

## House style

- Code should read without commentary. Reach for a clearer name or a smaller function before
  reaching for a comment; keep the comments that explain *why* something non-obvious is done.
- Public API gets doc comments. Everything else earns its keep by being obvious.
- Anything with a branch, a loop, or a parser gets a test.
- Keep the library dependency-free. The example app is a separate package precisely so that
  nothing leaks into the library's dependency graph.

## Regenerating knowledge about the API

The device's OpenAPI document is the source of truth:

```bash
curl "https://api.busy.app/busybar/openapi.yaml?Name=1.1.1" -o openapi.yaml
```

The BLE details come from [`busy-app/busybar-firmware`](https://github.com/busy-app/busybar-firmware),
under `applications/services/ble`.
