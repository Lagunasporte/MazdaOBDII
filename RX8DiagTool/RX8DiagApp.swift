import SwiftUI
import UIKit
import AudioToolbox

// MARK: - App Principal - Renesis Monitor RX8

@main
struct RX8DiagApp: App {
    @StateObject private var connectionManager = OBDConnectionManager()
    @StateObject private var engineMonitor = EngineMonitor()
    @StateObject private var diagnosticMode = DiagnosticMode()
    @StateObject private var fuelTracker = FuelConsumptionTracker()
    @StateObject private var blackBoxRecorder = BlackBoxRecorder()
    @StateObject private var radarManager = SpeedCameraManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(connectionManager)
                .environmentObject(engineMonitor)
                .environmentObject(diagnosticMode)
                .environmentObject(fuelTracker)
                .environmentObject(blackBoxRecorder)
                .environmentObject(radarManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Configurar el monitor con todas las dependencias
                    engineMonitor.configure(
                        connectionManager: connectionManager,
                        fuelTracker: fuelTracker,
                        blackBoxRecorder: blackBoxRecorder
                    )
                    // Intervalo de 250ms (4 Hz)
                    engineMonitor.setUpdateInterval(milliseconds: 250)

                    // Solicitar permisos de ubicación para radares
                    radarManager.requestLocationPermission()
                }
                .onChange(of: connectionManager.connectionState) { oldState, newState in
                    // Auto-iniciar monitoreo al conectar al vehículo
                    if newState == .connectedToVehicle && !engineMonitor.isMonitoring {
                        engineMonitor.startMonitoring()
                    }
                    // Detener al desconectar
                    if newState == .disconnected && engineMonitor.isMonitoring {
                        engineMonitor.stopMonitoring()
                    }
                }
        }
    }
}

// MARK: - Vista Principal con Tabs

struct MainTabView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @EnvironmentObject var radarManager: SpeedCameraManager
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .top) {
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

            // Tab 5: Avisador Radares
            RadarView()
                .tabItem {
                    Label("Radares", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(4)

            // Tab 6: Caja Negra
            BlackBoxView()
                .tabItem {
                    Label("Caja Negra", systemImage: "externaldrive.fill")
                }
                .tag(5)

            // Tab 7: Configuración
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(6)
            }
            .tint(.orange) // Color RX-8

            // Banner de alerta superpuesto
            if engineMonitor.showAlertBanner, let message = engineMonitor.alertBannerMessage {
                AlertBannerView(
                    message: message,
                    severity: engineMonitor.alertBannerSeverity,
                    onDismiss: { engineMonitor.dismissAlertBanner() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Banner de Alerta Visual

struct AlertBannerView: View {
    let message: String
    let severity: AlertSeverity
    let onDismiss: () -> Void

    @State private var timeRemaining: Int = 15

    var backgroundColor: Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var icon: String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icono animado
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)

                // Mensaje
                VStack(alignment: .leading, spacing: 2) {
                    Text(severity == .critical ? "¡ALERTA CRÍTICA!" : "ALERTA")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))

                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }

                Spacer()

                // Contador y botón cerrar
                VStack(spacing: 4) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("\(timeRemaining)s")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [backgroundColor, backgroundColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Barra de progreso
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: geo.size.width * CGFloat(timeRemaining) / 15.0, height: 3)
                    .animation(.linear(duration: 1), value: timeRemaining)
            }
            .frame(height: 3)
            .background(Color.black.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: backgroundColor.opacity(0.5), radius: 10, y: 5)
        .padding(.horizontal, 12)
        .padding(.top, 50) // Para no tapar la barra de estado
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Dashboard Principal (Responsive: Vertical=Móvil, Horizontal=CarPlay)

struct DashboardView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showConnectionSheet = false

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                // MODO CARPLAY - Layout horizontal
                CarPlayDashboardView(geometry: geometry, showConnectionSheet: $showConnectionSheet)
            } else {
                // MODO MÓVIL - Layout vertical con scroll
                MobileDashboardView(showConnectionSheet: $showConnectionSheet)
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSheet()
        }
    }
}

// MARK: - Dashboard CarPlay (Horizontal)

struct CarPlayDashboardView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    let geometry: GeometryProxy
    @Binding var showConnectionSheet: Bool

    var body: some View {
        if connectionManager.connectionState == .connectedToVehicle {
            HStack(spacing: 12) {
                // Columna izquierda: RPM grande
                VStack(spacing: 4) {
                    Text("RPM")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    Text("\(engineMonitor.currentState.rpm)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(rpmColor)
                        .minimumScaleFactor(0.5)

                    // Barra RPM
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rpmColor)
                                .frame(width: geo.size.width * min(Double(engineMonitor.currentState.rpm) / 9000, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 8)
                }
                .frame(width: geometry.size.width * 0.25)

                // Columna central: Velocidad y temperaturas
                VStack(spacing: 8) {
                    // Velocidad grande
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", engineMonitor.currentState.vehicleSpeed))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("km/h")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Divider().background(Color.gray.opacity(0.5))

                    // Temperaturas en fila
                    HStack(spacing: 16) {
                        CarPlayTempItem(icon: "thermometer.medium", label: "Refr", value: engineMonitor.currentState.coolantTemperature, color: coolantColor)
                        CarPlayTempItem(icon: "drop.fill", label: "Aceite", value: engineMonitor.currentState.oilTemperature, color: oilColor, showDash: engineMonitor.currentState.oilTemperature < 50)
                        CarPlayTempItem(icon: "wind", label: "Adm", value: engineMonitor.currentState.intakeAirTemperature, color: .cyan)
                    }
                }
                .frame(width: geometry.size.width * 0.35)

                // Columna derecha: Estado motor y alertas
                VStack(spacing: 6) {
                    // Voltaje y throttle
                    HStack(spacing: 12) {
                        CarPlayStatBox(label: "Voltaje", value: String(format: "%.1f", engineMonitor.currentState.batteryVoltage), unit: "V", color: engineMonitor.currentState.batteryVoltage > 13.5 ? .green : .orange)
                        CarPlayStatBox(label: "Carga", value: String(format: "%.0f", engineMonitor.currentState.throttlePosition), unit: "%", color: .blue)
                    }

                    // Fuel trims
                    HStack(spacing: 12) {
                        CarPlayStatBox(label: "STFT", value: String(format: "%+.0f", engineMonitor.currentState.shortTermFuelTrim), unit: "%", color: fuelTrimColor(engineMonitor.currentState.shortTermFuelTrim))
                        CarPlayStatBox(label: "LTFT", value: String(format: "%+.0f", engineMonitor.currentState.longTermFuelTrim), unit: "%", color: fuelTrimColor(engineMonitor.currentState.longTermFuelTrim))
                    }

                    // Alertas si hay
                    if !engineMonitor.activeAlerts.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(engineMonitor.activeAlerts.count) alertas")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                    }

                    // Estado conexión
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Conectado")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: geometry.size.width * 0.3)
            }
            .padding(12)
        } else {
            // No conectado - CarPlay
            VStack(spacing: 16) {
                Image(systemName: "car.side")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("No conectado")
                    .font(.title3)
                    .foregroundColor(.white)
                Button(action: { showConnectionSheet = true }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Conectar")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
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
        if temp < 50 { return .gray }
        if temp > 120 { return .red }
        if temp > 110 { return .orange }
        if temp < 80 { return .blue }
        return .green
    }

    func fuelTrimColor(_ value: Double) -> Color {
        if abs(value) > 15 { return .red }
        if abs(value) > 10 { return .orange }
        return .green
    }
}

struct CarPlayTempItem: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    var showDash: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(showDash ? "-" : String(format: "%.0f°", value))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(showDash ? .gray : .white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct CarPlayStatBox: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Dashboard Móvil (Vertical)

struct MobileDashboardView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Binding var showConnectionSheet: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ConnectionStatusCard(showSheet: $showConnectionSheet)

                    if connectionManager.connectionState == .connectedToVehicle {
                        MainGaugesView()
                        TemperatureGridView()
                        EngineStatusCard()
                        ActiveAlertsCard()
                    } else {
                        NotConnectedView(showSheet: $showConnectionSheet)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Renesis Monitor")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showConnectionSheet = true }) {
                        Image(systemName: connectionManager.connectionState.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(connectionManager.connectionState.isConnected ? .green : .gray)
                    }
                }
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

            // Temp Aceite (RX-8 no tiene sensor físico - es calculado por ECU)
            // Mostrar "-" si está por debajo de 50°C (valor no fiable)
            GaugeCard(
                title: "Aceite",
                value: engineMonitor.currentState.oilTemperature >= 50
                    ? String(format: "%.0f", engineMonitor.currentState.oilTemperature)
                    : "-",
                unit: "°C",
                icon: "drop.fill",
                color: oilColor,
                progress: engineMonitor.currentState.oilTemperature >= 50
                    ? engineMonitor.currentState.oilTemperature / 150
                    : 0
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
        // Si está por debajo de 50°C, el valor no es fiable (mostrar gris)
        if temp < 50 { return .gray }
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
// Sistema centralizado de monitoreo en tiempo real - 200-300ms refresh

public class EngineMonitor: ObservableObject {
    @Published public var currentState = RotaryEngineState()
    @Published public var activeAlerts: [EngineAlert] = []
    @Published public var isMonitoring = false
    @Published public var updateRate: Double = 0 // Hz
    @Published public var lastUpdateTime: Date?

    // Sistema de notificación de alertas
    @Published public var alertBannerMessage: String?
    @Published public var alertBannerSeverity: AlertSeverity = .warning
    @Published public var showAlertBanner: Bool = false

    private var monitoringTask: Task<Void, Never>?
    private var connectionManager: OBDConnectionManager?
    private var fuelTracker: FuelConsumptionTracker?
    private var blackBoxRecorder: BlackBoxRecorder?

    private var updateInterval: UInt64 = 100_000_000 // 100ms = 10 Hz - Muy rápido
    private var lastUpdateTimestamp: Date = Date()
    private var updateCount: Int = 0

    // Para evitar repetir sonidos de la misma alerta
    private var previousAlertKeys: Set<String> = []
    private var bannerDismissTask: Task<Void, Never>?

    public init() {}

    // MARK: - Configuración

    public func configure(
        connectionManager: OBDConnectionManager,
        fuelTracker: FuelConsumptionTracker? = nil,
        blackBoxRecorder: BlackBoxRecorder? = nil
    ) {
        self.connectionManager = connectionManager
        self.fuelTracker = fuelTracker
        self.blackBoxRecorder = blackBoxRecorder
    }

    public func setUpdateInterval(milliseconds: Int) {
        updateInterval = UInt64(milliseconds) * 1_000_000
    }

    // MARK: - Control de Monitoreo

    public func startMonitoring() {
        guard !isMonitoring, let cm = connectionManager else { return }

        isMonitoring = true
        updateCount = 0
        lastUpdateTimestamp = Date()

        // Mantener pantalla encendida mientras monitoreamos
        UIApplication.shared.isIdleTimerDisabled = true

        // Iniciar trip en fuel tracker
        fuelTracker?.startTrip()

        // La caja negra ahora detecta automáticamente cuando el motor arranca
        // y gestiona las sesiones automáticamente

        monitoringTask = Task { @MainActor in
            while isMonitoring && cm.connectionState == .connectedToVehicle {
                await readAllSensors()
                // Sin espera adicional - leer lo más rápido posible
                // El límite de velocidad lo impone el adaptador OBD
            }
            isMonitoring = false
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil

        // Permitir que la pantalla se apague cuando no monitoreamos
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Lectura Rápida de Sensores

    private func readAllSensors() async {
        guard let cm = connectionManager else { return }

        let startTime = Date()

        // Leer PIDs en secuencia rápida (sin esperas innecesarias)
        do {
            // PIDs críticos - siempre leer
            async let rpmTask = cm.readRPM()
            async let speedTask = cm.readSpeed()
            async let coolantTask = cm.readCoolantTemp()

            // Esperar los críticos
            let rpm = try await rpmTask
            let speed = try await speedTask
            let coolant = try await coolantTask

            // Actualizar estado
            currentState.rpm = rpm
            currentState.vehicleSpeed = Double(speed)
            currentState.coolantTemperature = Double(coolant)

            // PIDs secundarios - leer en ciclos rotatorios para maximizar velocidad
            // Expandido a 6 ciclos para incluir PIDs de diagnóstico forense
            updateCount += 1
            let cycle = updateCount % 6

            switch cycle {
            case 0:
                // Ciclo 0: throttle, MAF, carga del motor
                if let throttle = try? await cm.readThrottlePosition() {
                    currentState.throttlePosition = throttle
                }
                if let maf = try? await cm.readMAF() {
                    currentState.mafAirFlow = maf
                    // Actualizar consumo de combustible
                    _ = fuelTracker?.calculateInstantConsumption(
                        mafGramsPerSecond: maf,
                        speedKmh: currentState.vehicleSpeed,
                        rpm: rpm
                    )
                }
                if let load = try? await cm.readEngineLoad() {
                    currentState.engineLoad = load
                }

            case 1:
                // Ciclo 1: fuel trims Bank 1
                if let stft = try? await cm.readFuelTrimShort() {
                    currentState.shortTermFuelTrim = stft
                }
                if let ltft = try? await cm.readFuelTrimLong() {
                    currentState.longTermFuelTrim = ltft
                }

            case 2:
                // Ciclo 2: fuel trims Bank 2 (rotor trasero) - crítico para diagnóstico
                if let stftB2 = try? await cm.readFuelTrimShortB2() {
                    currentState.shortTermFuelTrimB2 = stftB2
                }
                if let ltftB2 = try? await cm.readFuelTrimLongB2() {
                    currentState.longTermFuelTrimB2 = ltftB2
                }

            case 3:
                // Ciclo 3: timing, voltaje, MAP
                if let timing = try? await cm.readTimingAdvance() {
                    currentState.ignitionTiming = timing
                }
                if let voltage = try? await cm.readVoltage() {
                    currentState.batteryVoltage = voltage
                }
                if let mapPressure = try? await cm.readMAP() {
                    currentState.manifoldPressure = mapPressure
                }

            case 4:
                // Ciclo 4: sensores O2 - importantes para diagnóstico de mezcla
                if let o2s1 = try? await cm.readO2VoltageB1S1() {
                    currentState.o2SensorBank1Sensor1 = o2s1
                }
                if let o2s2 = try? await cm.readO2VoltageB1S2() {
                    currentState.o2SensorBank1Sensor2 = o2s2
                }
                if let accel = try? await cm.readAcceleratorPosition() {
                    currentState.acceleratorPosition = accel
                }

            case 5:
                // Ciclo 5: temperaturas adicionales (aceite, catalizador, IAT)
                // Primero intentar Mode 22 (Mazda específico) para temp aceite
                // Si falla, intentar PID estándar 0x5C
                if let oilTemp = try? await cm.readOilTempMazda() {
                    currentState.oilTemperature = oilTemp
                } else if let oilTemp = try? await cm.readOilTemp() {
                    currentState.oilTemperature = Double(oilTemp)
                }

                if let catTemp = try? await cm.readCatalystTemp() {
                    currentState.catalystTemperature = catTemp
                }
                if let iat = try? await cm.readIntakeTemp() {
                    currentState.intakeAirTemperature = Double(iat)
                }

                // Leer nivel de combustible con sistema dual de sondas
                // El RX-8 tiene un saddle tank con dos sondas independientes
                if let dualReading = try? await cm.readDualFuelLevel() {
                    // Guardar lecturas individuales de cada sonda
                    currentState.fuelLevelLeftSender = dualReading.leftSender
                    currentState.fuelLevelRightSender = dualReading.rightSender

                    // Usar nivel calculado (compensado si hay sonda defectuosa)
                    currentState.fuelLevel = dualReading.calculatedLevel
                    fuelTracker?.updateFuelLevel(dualReading.calculatedLevel)

                    // Estado y advertencias de las sondas
                    switch dualReading.senderStatus {
                    case .normal:
                        currentState.fuelSenderStatus = "normal"
                        currentState.fuelSenderWarning = nil
                    case .leftUnavailable, .rightUnavailable, .bothUnavailable:
                        currentState.fuelSenderStatus = "unavailable"
                        currentState.fuelSenderWarning = dualReading.warningMessage
                    case .leftSuspect, .rightSuspect, .stuckLeft, .stuckRight:
                        currentState.fuelSenderStatus = "suspect"
                        currentState.fuelSenderWarning = dualReading.warningMessage
                    case .mismatch:
                        currentState.fuelSenderStatus = "mismatch"
                        currentState.fuelSenderWarning = dualReading.warningMessage
                    }
                } else if let fuelLevel = try? await cm.readFuelLevel() {
                    // Fallback a lectura estándar si dual no está disponible
                    currentState.fuelLevel = fuelLevel
                    fuelTracker?.updateFuelLevel(fuelLevel)
                }

                // Leer runtime y odómetro
                let runtime = try? await cm.readRuntimeSinceStart()
                let odometer = try? await cm.readOdometer()
                let distSinceClear = try? await cm.readDistanceSinceDTCClear()

                fuelTracker?.updateOBDData(
                    runtime: runtime ?? 0,
                    distanceSinceClear: distSinceClear ?? 0,
                    odometer: odometer
                )

            default:
                break
            }

            // Calcular tasa de actualización
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                updateRate = 1.0 / elapsed
            }
            lastUpdateTime = Date()

            // Enviar datos a la caja negra
            recordToBlackBox()

            // Verificar alertas
            checkAlerts()

        } catch {
            // Silent fail - continuar monitoreando
        }
    }

    // MARK: - Grabación en Caja Negra

    private func recordToBlackBox() {
        guard let recorder = blackBoxRecorder else { return }

        // El recorder ahora detecta automáticamente si el motor está en marcha
        // y gestiona las sesiones. Solo necesitamos enviar el estado.
        recorder.recordSnapshot(state: currentState)
    }

    // MARK: - Sistema de Alertas

    private func checkAlerts() {
        var newAlerts: [EngineAlert] = []

        // Temperatura de refrigerante
        if currentState.coolantTemperature > 105 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .critical,
                parameter: "Refrigerante",
                value: currentState.coolantTemperature,
                threshold: 105,
                message: "¡Temperatura crítica! \(Int(currentState.coolantTemperature))°C"
            ))
        } else if currentState.coolantTemperature > 98 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .warning,
                parameter: "Refrigerante",
                value: currentState.coolantTemperature,
                threshold: 98,
                message: "Temperatura elevada: \(Int(currentState.coolantTemperature))°C"
            ))
        }

        // Fuel trims
        if abs(currentState.shortTermFuelTrim) > 20 {
            newAlerts.append(EngineAlert(
                type: .fuel,
                severity: .warning,
                parameter: "STFT",
                value: currentState.shortTermFuelTrim,
                threshold: 20,
                message: "STFT anormal: \(String(format: "%+.1f%%", currentState.shortTermFuelTrim))"
            ))
        }

        if abs(currentState.longTermFuelTrim) > 15 {
            newAlerts.append(EngineAlert(
                type: .fuel,
                severity: .warning,
                parameter: "LTFT",
                value: currentState.longTermFuelTrim,
                threshold: 15,
                message: "LTFT fuera de rango: \(String(format: "%+.1f%%", currentState.longTermFuelTrim))"
            ))
        }

        // RPM
        if currentState.rpm > 9000 {
            newAlerts.append(EngineAlert(
                type: .rpm,
                severity: .critical,
                parameter: "RPM",
                value: Double(currentState.rpm),
                threshold: 9000,
                message: "¡RPM en zona roja!"
            ))
        }

        // Voltaje batería
        if currentState.batteryVoltage < 12.0 && currentState.rpm > 800 {
            newAlerts.append(EngineAlert(
                type: .voltage,
                severity: .warning,
                parameter: "Batería",
                value: currentState.batteryVoltage,
                threshold: 12.0,
                message: "Voltaje bajo: \(String(format: "%.1fV", currentState.batteryVoltage))"
            ))
        }

        // Temperatura de aceite
        if currentState.oilTemperature > 130 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .critical,
                parameter: "Aceite",
                value: currentState.oilTemperature,
                threshold: 130,
                message: "¡Aceite crítico! \(Int(currentState.oilTemperature))°C"
            ))
        } else if currentState.oilTemperature > 120 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .warning,
                parameter: "Aceite",
                value: currentState.oilTemperature,
                threshold: 120,
                message: "Aceite caliente: \(Int(currentState.oilTemperature))°C"
            ))
        }

        // Temperatura de catalizador
        if currentState.catalystTemperature > 900 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .critical,
                parameter: "Catalizador",
                value: currentState.catalystTemperature,
                threshold: 900,
                message: "¡Catalizador sobrecalentado! \(Int(currentState.catalystTemperature))°C"
            ))
        } else if currentState.catalystTemperature > 750 {
            newAlerts.append(EngineAlert(
                type: .temperature,
                severity: .warning,
                parameter: "Catalizador",
                value: currentState.catalystTemperature,
                threshold: 750,
                message: "Cat. caliente: \(Int(currentState.catalystTemperature))°C"
            ))
        }

        // Detectar alertas nuevas y mostrar banner con sonido
        let newAlertKeys = Set(newAlerts.map { $0.alertKey })
        let brandNewAlerts = newAlerts.filter { !previousAlertKeys.contains($0.alertKey) }

        if !brandNewAlerts.isEmpty {
            // Encontrar la alerta más crítica
            let mostCritical = brandNewAlerts.max { a, b in
                a.severity.rawValue < b.severity.rawValue
            }

            if let alert = mostCritical {
                // Reproducir sonido de alerta
                playAlertSound(severity: alert.severity)

                // Mostrar banner
                showAlertBanner(message: alert.message, severity: alert.severity)
            }
        }

        previousAlertKeys = newAlertKeys
        activeAlerts = newAlerts
    }

    // MARK: - Sistema de Alertas Visuales y Sonoras

    private func playAlertSound(severity: AlertSeverity) {
        DispatchQueue.main.async {
            switch severity {
            case .critical:
                // Sonido de alerta crítica (3 beeps)
                AudioServicesPlaySystemSound(1521) // Notificación de alerta
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    AudioServicesPlaySystemSound(1521)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    AudioServicesPlaySystemSound(1521)
                }
            case .warning:
                // Sonido de advertencia (1 beep)
                AudioServicesPlaySystemSound(1519) // Notificación estándar
            case .info:
                // Sonido suave
                AudioServicesPlaySystemSound(1057) // Tono suave
            }

            // Vibración en alertas críticas
            if severity == .critical {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    private func showAlertBanner(message: String, severity: AlertSeverity) {
        // Cancelar tarea de dismiss anterior si existe
        bannerDismissTask?.cancel()

        DispatchQueue.main.async {
            self.alertBannerMessage = message
            self.alertBannerSeverity = severity
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showAlertBanner = true
            }
        }

        // Auto-dismiss después de 15 segundos
        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 segundos
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.showAlertBanner = false
                    }
                }
            }
        }
    }

    public func dismissAlertBanner() {
        bannerDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            showAlertBanner = false
        }
    }
}

// Extensión para generar clave única de alerta
extension EngineAlert {
    var alertKey: String {
        "\(type.rawValue)-\(parameter)-\(severity.rawValue)"
    }
}
