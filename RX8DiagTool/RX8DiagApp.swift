import SwiftUI

// MARK: - App Principal RX-8 Diagnostic Tool

@main
struct RX8DiagApp: App {
    @StateObject private var connectionManager = OBDConnectionManager()
    @StateObject private var engineMonitor = EngineMonitor()
    @StateObject private var diagnosticMode = DiagnosticMode()
    @StateObject private var fuelTracker = FuelConsumptionTracker()
    @StateObject private var blackBoxRecorder = BlackBoxRecorder()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(connectionManager)
                .environmentObject(engineMonitor)
                .environmentObject(diagnosticMode)
                .environmentObject(fuelTracker)
                .environmentObject(blackBoxRecorder)
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

            // Tab 5: Caja Negra
            BlackBoxView()
                .tabItem {
                    Label("Caja Negra", systemImage: "externaldrive.fill")
                }
                .tag(4)

            // Tab 6: Configuración
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(5)
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
// Sistema centralizado de monitoreo en tiempo real - 200-300ms refresh

public class EngineMonitor: ObservableObject {
    @Published public var currentState = RotaryEngineState()
    @Published public var activeAlerts: [EngineAlert] = []
    @Published public var isMonitoring = false
    @Published public var updateRate: Double = 0 // Hz
    @Published public var lastUpdateTime: Date?

    private var monitoringTask: Task<Void, Never>?
    private var connectionManager: OBDConnectionManager?
    private var fuelTracker: FuelConsumptionTracker?
    private var blackBoxRecorder: BlackBoxRecorder?

    private var updateInterval: UInt64 = 100_000_000 // 100ms = 10 Hz - Muy rápido
    private var lastUpdateTimestamp: Date = Date()
    private var updateCount: Int = 0

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

                if let runtime = try? await cm.readRuntimeSinceStart() {
                    fuelTracker?.updateOBDData(runtime: runtime, distanceSinceClear: 0)
                }

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

        activeAlerts = newAlerts
    }
}
