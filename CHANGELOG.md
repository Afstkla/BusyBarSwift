# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `BusyBarClient` covering the full BUSY Bar HTTP API (OpenAPI 25.0.0): display, audio,
  assets, BUSY timer, storage, settings, input, system, time, Wi-Fi, BLE, smart home,
  updater, and account.
- `BLETransport`, carrying the HTTP API over the firmware's Nordic UART bridge.
- `HTTPTransport` for USB, Wi-Fi, and the BUSY Cloud proxy.
- `FallbackTransport`, so a bar out of Bluetooth range is still reachable over IP.
- Device discovery over both Bluetooth (`BusyBarClient.scan`) and Bonjour
  (`BonjourDiscovery.scan`).
- A SwiftUI example app under `Examples/BusyBarDemo`.

### Known limitations

- The `/api/status/ws` streaming endpoint is not implemented; its frames are protobuf and
  would pull in a code-generation dependency. Poll `status()` in the meantime.
