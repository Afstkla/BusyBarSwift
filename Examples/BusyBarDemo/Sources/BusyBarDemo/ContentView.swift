import BusyBar
import SwiftUI

struct ContentView: View {
    @State private var bar = BarController()
    @State private var accessKey = ""

    var body: some View {
        NavigationSplitView {
            DiscoverySidebar(bar: bar, accessKey: $accessKey)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260)
        } detail: {
            switch bar.connection {
            case .connected:
                ControlPanel(bar: bar)
            case .connecting:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting…")
                        .foregroundStyle(.secondary)
                    Text("If the bar has not been paired with this Mac before, accept the pairing request.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            case .disconnected:
                ContentUnavailableView(
                    "No bar connected",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Scan for a BUSY Bar, then pick one to connect.")
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let error = bar.lastError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        bar.lastError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .frame(maxWidth: 520, alignment: .leading)
                .background(.red.opacity(0.15), in: .rect(cornerRadius: 8))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: bar.lastError)
        .task { await bar.scan() }
    }
}

private struct DiscoverySidebar: View {
    let bar: BarController
    @Binding var accessKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Devices").font(.headline)
                Spacer()
                Button {
                    Task { await bar.scan() }
                } label: {
                    if bar.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(bar.isScanning)
            }

            if bar.candidates.isEmpty && !bar.isScanning {
                Text("Nothing found. Make sure the bar is awake, and that Bluetooth is enabled on it under Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List(bar.candidates) { candidate in
                Button {
                    Task { await bar.connect(to: candidate, accessKey: accessKey) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.name)
                        Text(candidate.routeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 4) {
                Text("Access key").font(.caption).foregroundStyle(.secondary)
                SecureField("Only if the bar requires one", text: $accessKey)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()
            ManualConnect(bar: bar, accessKey: accessKey)

            if case let .connected(via) = bar.connection {
                Divider()
                Label("Connected over \(via)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Button("Disconnect") { bar.disconnect() }
                    .controlSize(.small)
            }
        }
        .padding(12)
    }
}

/// Discovery only finds a bar on the same network. These two routes reach one that isn't.
private struct ManualConnect: View {
    let bar: BarController
    let accessKey: String

    private enum Route: String, CaseIterable {
        case address = "Address"
        case cloud = "Cloud"
    }

    @State private var route: Route = .address
    @State private var host = "10.0.4.20"
    @State private var token = ProcessInfo.processInfo.environment["BUSYBAR_TOKEN"] ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connect over HTTP").font(.caption).foregroundStyle(.secondary)

            Picker("", selection: $route) {
                ForEach(Route.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch route {
            case .address:
                TextField("10.0.4.20", text: $host)
                    .textFieldStyle(.roundedBorder)
                Button("Connect") {
                    Task { await bar.connect(toHost: host, accessKey: accessKey) }
                }
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            case .cloud:
                SecureField("BAR-scope token", text: $token)
                    .textFieldStyle(.roundedBorder)
                Text("Set BUSYBAR_TOKEN to prefill this.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button("Connect") {
                    Task { await bar.connectToCloud(token: token) }
                }
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

private struct ControlPanel: View {
    let bar: BarController

    @State private var message = "Hello"
    @State private var color = BusyColor.white
    @State private var font: BusyFont = .normal
    @State private var screen: Screen = .front

    private let palette: [(String, BusyColor)] = [
        ("White", .white), ("Red", .red), ("Green", .green),
        ("Blue", .blue), ("Yellow", .yellow), ("Orange", .orange),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatusHeader(bar: bar)
                ScreenPreview(bar: bar)

                GroupBox("Draw") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Message", text: $message)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Picker("Font", selection: $font) {
                                ForEach(fonts, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            Picker("Screen", selection: $screen) {
                                Text("Front").tag(Screen.front)
                                Text("Back").tag(Screen.back)
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack {
                            ForEach(palette, id: \.0) { name, swatch in
                                Button {
                                    color = swatch
                                } label: {
                                    Circle()
                                        .fill(Color(swatch))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().strokeBorder(
                                                color == swatch ? Color.accentColor : .secondary.opacity(0.4),
                                                lineWidth: color == swatch ? 3 : 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(name)
                            }
                            Spacer()
                            Button("Clear") { Task { await bar.clear() } }
                            Button("Draw") {
                                Task { await bar.draw(text: message, color: color, font: font, screen: screen) }
                            }
                            .keyboardShortcut(.return)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Brightness").frame(width: 90, alignment: .leading)
                            Toggle("Auto", isOn: Binding(
                                get: { bar.brightness == .auto },
                                set: { isAuto in
                                    Task { await bar.setBrightness(isAuto ? .auto : .level(50)) }
                                }
                            ))
                            .toggleStyle(.switch)

                            if case let .level(value) = bar.brightness {
                                Slider(
                                    value: Binding(
                                        get: { Double(value) },
                                        set: { level in
                                            Task { await bar.setBrightness(.level(Int(level))) }
                                        }
                                    ),
                                    in: 0...100
                                )
                                Text("\(value)%").monospacedDigit().frame(width: 44)
                            }
                        }

                        HStack {
                            Text("Volume").frame(width: 90, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { bar.volume },
                                    set: { level in Task { await bar.setVolume(level) } }
                                ),
                                in: 0...100
                            )
                            Text("\(Int(bar.volume))%").monospacedDigit().frame(width: 44)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Buttons") {
                    HStack {
                        ForEach(InputKey.allCases, id: \.self) { key in
                            Button(key.rawValue) { Task { await bar.press(key) } }
                                .controlSize(.small)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
    }

    private var fonts: [BusyFont] {
        [.tiny, .small, .normal, .condensed, .bold, .large, .extraLarge]
    }
}

/// Shows what is actually on the bar, which is the only way to tell a draw really landed.
private struct ScreenPreview: View {
    let bar: BarController

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Panel(title: "Front · 72×16 colour", frame: bar.frontFrame, scale: 5)
                Panel(title: "Back · 160×80 greyscale", frame: bar.backFrame, scale: 2)
            }
            .padding(8)
        } label: {
            HStack {
                Text("Screen").font(.headline)
                Spacer()
                Toggle("Live", isOn: Binding(
                    get: { bar.isMirroring },
                    set: { _ in bar.toggleMirroring() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                Button("Capture") { Task { await bar.captureScreens() } }
                    .controlSize(.small)
            }
        }
        .task { await bar.captureScreens() }
    }

    private struct Panel: View {
        let title: String
        let frame: ScreenFrame?
        let scale: CGFloat

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Group {
                    if let image = frame?.makeImage() {
                        Image(decorative: image, scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .frame(
                                width: CGFloat(frame!.width) * scale,
                                height: CGFloat(frame!.height) * scale
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.black)
                            .frame(width: 72 * scale, height: 16 * scale)
                            .overlay(Text("no frame").font(.caption2).foregroundStyle(.secondary))
                    }
                }
                .clipShape(.rect(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.3))
                )
            }
        }
    }
}

private struct StatusHeader: View {
    let bar: BarController

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 28) {
                if let power = bar.status?.power {
                    Metric(
                        title: "Battery",
                        value: "\(power.batteryCharge)%",
                        detail: power.state.rawValue
                    )
                }
                if let firmware = bar.status?.firmware {
                    Metric(title: "Firmware", value: firmware.version, detail: firmware.branch)
                }
                if let system = bar.status?.system {
                    Metric(title: "Uptime", value: system.uptime, detail: "API \(system.apiSemver)")
                }
                if let wifi = bar.wifi {
                    Metric(
                        title: "Wi-Fi",
                        value: wifi.ssid ?? wifi.state.rawValue,
                        detail: wifi.rssi.map { "\($0) dBm" } ?? wifi.state.rawValue
                    )
                }
                Spacer()
            }
            .padding(8)
        } label: {
            Text(bar.deviceName.isEmpty ? "BUSY Bar" : bar.deviceName).font(.headline)
        }
    }
}

private struct Metric: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).monospacedDigit()
            Text(detail).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

extension Color {
    init(_ busy: BusyColor) {
        self.init(
            red: Double(busy.red) / 255,
            green: Double(busy.green) / 255,
            blue: Double(busy.blue) / 255,
            opacity: Double(busy.alpha) / 255
        )
    }
}
