import SwiftUI

// MARK: - App Principal RX-8 Diagnostic Tool

@main
struct RX8DiagApp: App {
    @StateObject private var connectionManager = OBDConnectionManager()
    @StateObject private var engineMonitor = EngineMonitor()
    @StateObject private var diagnosticMode = DiagnosticMode()
    @StateObject private var fuelTracker = FuelConsumptionTracker()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(connectionManager)
                .environmentObject(engineMonitor)
                .environmentObject(diagnosticMode)
                .environmentObject(fuelTracker)
                .preferredColorScheme(.dark) // Tema oscuro por defecto
        }
    }
}

// MARK: - Vista Principal con Tabs

struct MainTabView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(0)

            // Tab 2: Diagnóstico
            DiagnosticView()
                .tabItem {
                    Label("Diagnóstico", systemImage: "stethoscope")
                }
                .tag(1)

            // Tab 3: DTCs
            DTCView()
                .tabItem {
                    Label("Códigos", systemImage: "exclamationmark.triangle")
                }
                .tag(2)

            // Tab 4: Consumo
            FuelConsumptionView()
                .tabItem {
                    Label("Consumo", systemImage: "fuelpump")
                }
                .tag(3)

            // Tab 5: Configuración
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.orange) // Color RX-8
    }
}

// MARK: - Dashboard Principal

struct DashboardView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @State private var showConnectionSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Estado de conexión
                    ConnectionStatusCard(showSheet: $showConnectionSheet)

                    if connectionManager.connectionState == .connectedToVehicle {
                        // Indicadores principales
                        MainGaugesView()

                        // Temperaturas
                        TemperatureGridView()

                        // Estado del motor
                        EngineStatusCard()

                        // Alertas activas
                        ActiveAlertsCard()
                    } else {
                        // Placeholder cuando no está conectado
                        NotConnectedView(showSheet: $showConnectionSheet)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("RX-8 Diag")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showConnectionSheet = true }) {
                        Image(systemName: connectionManager.connectionState.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(connectionManager.connectionState.isConnected ? .green : .gray)
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                ConnectionSheet()
            }
        }
    }
}

// MARK: - Tarjeta de Estado de Conexión

struct ConnectionStatusCard: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Binding var showSheet: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(connectionManager.connectionState.rawValue)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            if let adapter = connectionManager.adapterInfo {
                Text(adapter.chipType)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if let proto = connectionManager.vehicleProtocol {
                Text(proto.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .onTapGesture {
            showSheet = true
        }
    }

    var statusColor: Color {
        switch connectionManager.connectionState {
        case .connectedToVehicle: return .green
        case .connectedToAdapter, .initializing: return .yellow
        case .connecting, .scanning: return .orange
        case .disconnected: return .red
        }
    }
}

// MARK: - Indicadores Principales (RPM, Velocidad, Temp)

struct MainGaugesView: View {
    @EnvironmentObject var engineMonitor: EngineMonitor

    var body: some View {
        HStack(spacing: 16) {
            // RPM
            GaugeCard(
                title: "RPM",
                value: "\(engineMonitor.currentState.rpm)",
                unit: "",
                icon: "engine.combustion",
                color: rpmColor,
                progress: Double(engineMonitor.currentState.rpm) / 9000
            )

            // Velocidad
            GaugeCard(
                title: "Velocidad",
                value: String(format: "%.0f", engineMonitor.currentState.vehicleSpeed),
                unit: "km/h",
                icon: "speedometer",
                color: .blue,
                progress: engineMonitor.currentState.vehicleSpeed / 260
            )
        }

        HStack(spacing: 16) {
            // Temp Refrigerante
            GaugeCard(
                title: "Refrigerante",
                value: String(format: "%.0f", engineMonitor.currentState.coolantTemperature),
                unit: "°C",
                icon: "thermometer.medium",
                color: coolantColor,
                progress: engineMonitor.currentState.coolantTemperature / 120
            )

            // Temp Aceite
            GaugeCard(
                title: "Aceite",
                value: String(format: "%.0f", engineMonitor.currentState.oilTemperature),
                unit: "°C",
                icon: "drop.fill",
                color: oilColor,
                progress: engineMonitor.currentState.oilTemperature / 150
            )
        }
    }

    var rpmColor: Color {
        let rpm = engineMonitor.currentState.rpm
        if rpm > 8500 { return .red }
        if rpm > 7000 { return .orange }
        return .green
    }

    var coolantColor: Color {
        let temp = engineMonitor.currentState.coolantTemperature
        if temp > 100 { return .red }
        if temp > 95 { return .orange }
        if temp < 75 { return .blue }
        return .green
    }

    var oilColor: Color {
        let temp = engineMonitor.currentState.oilTemperature
        if temp > 120 { return .red }
        if temp > 110 { return .orange }
        if temp < 80 { return .blue }
        return .green
    }
}

// MARK: - Tarjeta de Indicador

struct GaugeCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Barra de progreso
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Grid de Temperaturas

struct TemperatureGridView: View {
    @EnvironmentObject var engineMonitor: EngineMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperaturas")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TemperatureItem(
                    name: "Admisión",
                    value: engineMonitor.currentState.intakeAirTemperature,
                    icon: "wind",
                    normalRange: -10...45
                )

                TemperatureItem(
                    name: "Catalizador",
                    value: engineMonitor.currentState.catalystTemperature,
                    icon: "flame",
                    normalRange: 300...800
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct TemperatureItem: View {
    let name: String
    let value: Double
    let icon: String
    let normalRange: ClosedRange<Double>

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isNormal ? .green : .orange)

            VStack(alignment: .leading) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(String(format: "%.0f°C", value))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    var isNormal: Bool {
        normalRange.contains(value)
    }
}

// MARK: - Estado del Motor

struct EngineStatusCard: View {
    @EnvironmentObject var engineMonitor: EngineMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estado del Motor")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 16) {
                StatusIndicator(
                    name: "OMP",
                    status: engineMonitor.currentState.ompStatus == .normal ? .ok : .warning,
                    detail: String(format: "%.0f%%", engineMonitor.currentState.ompPosition)
                )

                StatusIndicator(
                    name: "Voltaje",
                    status: engineMonitor.currentState.batteryVoltage > 13.5 ? .ok : .warning,
                    detail: String(format: "%.1fV", engineMonitor.currentState.batteryVoltage)
                )

                StatusIndicator(
                    name: "Carga",
                    status: .ok,
                    detail: String(format: "%.0f%%", engineMonitor.currentState.throttlePosition)
                )
            }

            // Fuel trims
            HStack {
                VStack(alignment: .leading) {
                    Text("STFT")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%+.1f%%", engineMonitor.currentState.shortTermFuelTrim))
                        .foregroundColor(fuelTrimColor(engineMonitor.currentState.shortTermFuelTrim))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("LTFT")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%+.1f%%", engineMonitor.currentState.longTermFuelTrim))
                        .foregroundColor(fuelTrimColor(engineMonitor.currentState.longTermFuelTrim))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Timing")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f°", engineMonitor.currentState.ignitionTiming))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }

    func fuelTrimColor(_ value: Double) -> Color {
        if abs(value) > 15 { return .red }
        if abs(value) > 10 { return .orange }
        return .green
    }
}

struct StatusIndicator: View {
    let name: String
    let status: Status
    let detail: String

    enum Status {
        case ok, warning, error

        var color: Color {
            switch self {
            case .ok: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    var body: some View {
        VStack {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(detail)
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Alertas Activas

struct ActiveAlertsCard: View {
    @EnvironmentObject var engineMonitor: EngineMonitor

    var body: some View {
        if !engineMonitor.activeAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Alertas Activas")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(engineMonitor.activeAlerts.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                }

                ForEach(engineMonitor.activeAlerts.prefix(3)) { alert in
                    HStack {
                        Circle()
                            .fill(alertColor(alert.severity))
                            .frame(width: 8, height: 8)
                        Text(alert.message)
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .cornerRadius(16)
        }
    }

    func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Vista cuando no está conectado

struct NotConnectedView: View {
    @Binding var showSheet: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.side")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text("No conectado")
                .font(.title2)
                .foregroundColor(.white)

            Text("Conecta un adaptador OBD2 Bluetooth para comenzar el diagnóstico de tu RX-8")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showSheet = true }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Buscar adaptador")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            // Info sobre hardware compatible
            VStack(alignment: .leading, spacing: 8) {
                Text("Hardware compatible:")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("OBDLink MX+ (recomendado)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Veepeak BLE/BLE+")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("vLinker MC+")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Sheet de Conexión

struct ConnectionSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Estado") {
                    HStack {
                        Text("Conexión")
                        Spacer()
                        Text(connectionManager.connectionState.rawValue)
                            .foregroundColor(.gray)
                    }

                    if connectionManager.connectionState == .disconnected {
                        Button("Buscar dispositivos") {
                            connectionManager.startScanning()
                        }
                    }

                    if connectionManager.isScanning {
                        HStack {
                            ProgressView()
                            Text("Buscando...")
                                .foregroundColor(.gray)
                        }
                    }
                }

                if !connectionManager.discoveredDevices.isEmpty {
                    Section("Dispositivos encontrados") {
                        ForEach(connectionManager.discoveredDevices) { device in
                            Button(action: {
                                connectionManager.connect(to: device)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                            .foregroundColor(.white)
                                        Text("Señal: \(device.signalStrength.rawValue)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    SignalBars(strength: device.signalStrength.bars)
                                }
                            }
                        }
                    }
                }

                if let error = connectionManager.lastError {
                    Section("Error") {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Conexión OBD2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SignalBars: View {
    let strength: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < strength ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(8 + i * 4))
            }
        }
    }
}

// MARK: - Engine Monitor (ObservableObject)

public class EngineMonitor: ObservableObject {
    @Published public var currentState = RotaryEngineState()
    @Published public var activeAlerts: [EngineAlert] = []
    @Published public var isMonitoring = false

    public init() {}
}
