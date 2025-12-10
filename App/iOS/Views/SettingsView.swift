import SwiftUI
import UIKit

// MARK: - Vista de Configuración

struct SettingsView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @AppStorage("unitSystem") private var unitSystem = UnitSystem.metric
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.celsius
    @AppStorage("alertsEnabled") private var alertsEnabled = true
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("keepScreenOn") private var keepScreenOn = false
    @AppStorage("pollingInterval") private var pollingInterval = 100 // ms
    @AppStorage("dataMode") private var dataMode = DataMode.normal
    @State private var showVehicleInfo = false
    @State private var showAbout = false
    @State private var showAdapterTest = false
    @State private var isTestingAdapter = false
    @State private var adapterTestResults: AdapterTestResults?

    // Color según estado de conexión
    private var connectionStateColor: Color {
        switch connectionManager.connectionState {
        case .connectedToVehicle:
            return .green
        case .connectedToAdapter, .connecting, .initializing:
            return .orange
        case .disconnected:
            return .gray
        case .scanning:
            return .blue
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Información del vehículo
                Section {
                    Button(action: { showVehicleInfo = true }) {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Mazda RX-8")
                                    .foregroundColor(.white)
                                Text("SE3P - 13B-MSP Renesis")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Vehículo")
                }

                // Unidades
                Section {
                    Picker("Sistema de unidades", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system)
                        }
                    }

                    Picker("Temperatura", selection: $temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                } header: {
                    Text("Unidades")
                }

                // Alertas
                Section {
                    Toggle("Alertas activas", isOn: $alertsEnabled)

                    if alertsEnabled {
                        NavigationLink {
                            AlertSettingsView()
                        } label: {
                            Text("Configurar alertas")
                        }
                    }

                    Toggle("Vibración", isOn: $hapticFeedback)
                } header: {
                    Text("Alertas")
                } footer: {
                    Text("Las alertas te avisarán cuando la temperatura o el voltaje estén fuera de rango")
                }

                // Pantalla
                Section {
                    Toggle("Mantener pantalla encendida", isOn: $keepScreenOn)
                        .onChange(of: keepScreenOn) { _, newValue in
                            UIApplication.shared.isIdleTimerDisabled = newValue
                        }
                } header: {
                    Text("Pantalla")
                } footer: {
                    Text("Evita que la pantalla se apague automáticamente mientras usas la app")
                }

                // Rendimiento OBD
                Section {
                    // Modo de datos
                    Picker("Volumen de datos", selection: $dataMode) {
                        ForEach(DataMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    // Descripción del modo seleccionado
                    HStack(spacing: 8) {
                        Image(systemName: dataMode.icon)
                            .foregroundColor(dataMode.color)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dataMode.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(dataMode.pidsPerCycle) PIDs por ciclo")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intervalo de lectura")
                            Spacer()
                            Text("\(pollingInterval) ms")
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        }

                        Slider(value: Binding(
                            get: { Double(pollingInterval) },
                            set: { pollingInterval = Int($0) }
                        ), in: 50...500, step: 25)

                        HStack {
                            Text("Rápido")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Spacer()
                            Text("Estable")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }

                    // Test de velocidad del adaptador
                    Button {
                        runAdapterSpeedTest()
                    } label: {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.orange)
                            Text("Test de velocidad del adaptador")
                            Spacer()
                            if isTestingAdapter {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(connectionManager.connectionState != .connectedToVehicle || isTestingAdapter)

                    if let results = adapterTestResults {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: results.recommendedInterval <= 100 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(results.recommendedInterval <= 100 ? .green : .orange)
                                Text("Intervalo recomendado: \(results.recommendedInterval) ms")
                                    .font(.caption)
                            }
                            Text("Tiempo respuesta: \(String(format: "%.0f", results.avgResponseTime)) ms")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Errores: \(results.errorCount)/\(results.totalTests)")
                                .font(.caption)
                                .foregroundColor(results.errorCount > 0 ? .orange : .gray)

                            // Sugerir modo según velocidad del adaptador
                            if results.recommendedInterval > 150 {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text("Adaptador lento - Modo Esencial recomendado")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }

                            HStack {
                                Button("Aplicar recomendado") {
                                    pollingInterval = results.recommendedInterval
                                    // Auto-ajustar modo de datos si el adaptador es lento
                                    if results.recommendedInterval > 150 {
                                        dataMode = .essential
                                    } else if results.recommendedInterval <= 75 {
                                        dataMode = .full
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Rendimiento OBD")
                } footer: {
                    Text("Adaptadores baratos necesitan modo Esencial (5 PIDs). Carista/OBDLink pueden usar modo Completo (9+ PIDs).")
                }

                // Conexión
                Section {
                    HStack {
                        Text("Estado")
                        Spacer()
                        if connectionManager.isAutoConnecting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Conectando...")
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Text(connectionManager.connectionState.rawValue)
                                .foregroundColor(connectionStateColor)
                        }
                    }

                    if let adapter = connectionManager.adapterInfo {
                        HStack {
                            Text("Adaptador")
                            Spacer()
                            Text(adapter.version)
                                .foregroundColor(.gray)
                        }
                    }

                    if let proto = connectionManager.vehicleProtocol {
                        HStack {
                            Text("Protocolo")
                            Spacer()
                            Text(proto.rawValue)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }

                    NavigationLink {
                        AdapterDiagnosticView()
                    } label: {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.green)
                            Text("Diagnóstico del adaptador")
                        }
                    }
                } header: {
                    Text("Conexión OBD2")
                }

                // Auto-conexión
                Section {
                    Toggle("Conexión automática", isOn: Binding(
                        get: { connectionManager.isAutoConnectEnabled },
                        set: { connectionManager.isAutoConnectEnabled = $0 }
                    ))

                    if let savedName = connectionManager.savedAdapterName {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Adaptador guardado")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(savedName)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            if connectionManager.connectionState == .connectedToVehicle ||
                               connectionManager.connectionState == .connectedToAdapter {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        Button(role: .destructive) {
                            connectionManager.forgetSavedAdapter()
                        } label: {
                            Label("Olvidar adaptador", systemImage: "trash")
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Conecta un adaptador para guardar")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if connectionManager.connectionState == .disconnected && connectionManager.savedAdapterUUID != nil {
                        Button {
                            connectionManager.attemptAutoConnect()
                        } label: {
                            Label("Conectar ahora", systemImage: "bolt.fill")
                        }
                    }
                } header: {
                    Text("Auto-conexión")
                } footer: {
                    Text("La app intentará conectar automáticamente al adaptador guardado al iniciar")
                }

                // Datos
                Section {
                    NavigationLink {
                        DataLoggingSettingsView()
                    } label: {
                        Label("Registro de datos", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Label("Exportar datos", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        // Borrar datos
                    } label: {
                        Label("Borrar historial", systemImage: "trash")
                    }
                } header: {
                    Text("Datos")
                }

                // Sobre la app
                Section {
                    Button(action: { showAbout = true }) {
                        HStack {
                            Text("Acerca de RX-8 Diag")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/rx8club")!) {
                        HStack {
                            Text("Comunidad RX-8")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }

                    Link(destination: URL(string: "https://rx8help.com")!) {
                        HStack {
                            Text("Recursos técnicos")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Información")
                }
            }
            .navigationTitle("Ajustes")
            .sheet(isPresented: $showVehicleInfo) {
                VehicleInfoView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }

    // MARK: - Test de Velocidad del Adaptador

    private func runAdapterSpeedTest() {
        guard connectionManager.connectionState == .connectedToVehicle else { return }

        isTestingAdapter = true
        adapterTestResults = nil

        Task {
            var responseTimes: [Double] = []
            var errorCount = 0
            let totalTests = 20

            for _ in 0..<totalTests {
                let startTime = Date()
                do {
                    // Leer RPM (PID rápido y confiable)
                    _ = try await connectionManager.readRPM()
                    let elapsed = Date().timeIntervalSince(startTime) * 1000 // ms
                    responseTimes.append(elapsed)
                } catch {
                    errorCount += 1
                }
                // Pequeña pausa entre tests
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            }

            let avgTime = responseTimes.isEmpty ? 500.0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
            let maxTime = responseTimes.max() ?? 500.0

            // Calcular intervalo recomendado basado en resultados
            var recommendedInterval: Int
            if errorCount > 5 {
                // Muchos errores - adaptador lento, necesita más tiempo
                recommendedInterval = 300
            } else if avgTime < 50 && errorCount == 0 {
                // Muy rápido - probablemente Carista o STN
                recommendedInterval = 50
            } else if avgTime < 100 && errorCount <= 2 {
                // Rápido - buen adaptador
                recommendedInterval = 75
            } else if avgTime < 150 {
                recommendedInterval = 100
            } else if avgTime < 250 {
                recommendedInterval = 150
            } else {
                // Lento - adaptador barato
                recommendedInterval = Int(maxTime * 1.2)
            }

            await MainActor.run {
                adapterTestResults = AdapterTestResults(
                    avgResponseTime: avgTime,
                    maxResponseTime: maxTime,
                    errorCount: errorCount,
                    totalTests: totalTests,
                    recommendedInterval: recommendedInterval
                )
                isTestingAdapter = false
            }
        }
    }
}

// MARK: - Adapter Test Results

struct AdapterTestResults {
    let avgResponseTime: Double // ms
    let maxResponseTime: Double // ms
    let errorCount: Int
    let totalTests: Int
    let recommendedInterval: Int // ms
}

// MARK: - Enums de Configuración

enum UnitSystem: String, CaseIterable {
    case metric = "Métrico"
    case imperial = "Imperial"
}

enum TemperatureUnit: String, CaseIterable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"
}

// MARK: - Modo de Datos OBD

enum DataMode: String, CaseIterable {
    case essential = "essential"  // Solo PIDs críticos - adaptadores lentos
    case normal = "normal"        // PIDs básicos con rotación reducida
    case full = "full"            // Todos los PIDs con rotación completa

    var displayName: String {
        switch self {
        case .essential: return "Esencial"
        case .normal: return "Normal"
        case .full: return "Completo"
        }
    }

    var description: String {
        switch self {
        case .essential: return "Solo RPM, velocidad, temp y voltaje"
        case .normal: return "Datos básicos + fuel trims"
        case .full: return "Todos los sensores disponibles"
        }
    }

    var icon: String {
        switch self {
        case .essential: return "battery.50"
        case .normal: return "gauge.medium"
        case .full: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .essential: return .green
        case .normal: return .blue
        case .full: return .orange
        }
    }

    var pidsPerCycle: String {
        switch self {
        case .essential: return "3-5"
        case .normal: return "5-7"
        case .full: return "7-10"
        }
    }
}

// MARK: - Vista de Información del Vehículo (Mejorada)

struct VehicleInfoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var vehicleInfo: RX8VehicleInfo?
    @State private var extendedInfo: ExtendedVehicleInfo = ExtendedVehicleInfo()
    @State private var isLoading = false
    @State private var loadingStatus = "Iniciando..."
    @State private var errorMessages: [String] = []

    var body: some View {
        NavigationStack {
            List {
                // Estado de carga
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            VStack(alignment: .leading) {
                                Text("Leyendo datos del vehículo...")
                                    .foregroundColor(.white)
                                Text(loadingStatus)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                // Errores si los hay
                if !errorMessages.isEmpty && !isLoading {
                    Section("Datos no disponibles") {
                        ForEach(errorMessages, id: \.self) { error in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                // VIN y datos básicos
                Section("Identificación") {
                    if let info = vehicleInfo {
                        VINRow(vin: info.vin)
                        InfoRow(label: "Año", value: info.year > 0 ? "\(info.year)" : "N/D")
                        InfoRow(label: "Serie", value: info.series.rawValue)
                        InfoRow(label: "Mercado", value: info.marketRegion.rawValue)
                    } else if extendedInfo.vin != nil {
                        VINRow(vin: extendedInfo.vin!)
                    } else if !isLoading {
                        InfoRowWithStatus(label: "VIN", value: "No disponible", status: .error)
                    }

                    if let calId = extendedInfo.calibrationId {
                        InfoRowWithSource(label: "Calibración ECU", value: calId, source: "Mode 09")
                    }
                }

                // Kilómetros de distintas fuentes
                Section("Kilometraje") {
                    if let odometer = extendedInfo.odometerKm {
                        InfoRowWithSource(
                            label: "Odómetro",
                            value: formatKm(odometer),
                            source: extendedInfo.odometerSource ?? "OBD"
                        )
                    } else if !isLoading {
                        InfoRowWithStatus(label: "Odómetro", value: "No disponible", status: .warning)
                    }

                    if let distDTC = extendedInfo.distanceSinceDTCClear {
                        InfoRowWithSource(
                            label: "Desde borrado DTCs",
                            value: formatKm(distDTC),
                            source: "PID 0x31"
                        )
                    }

                    if let distMIL = extendedInfo.distanceWithMIL {
                        InfoRowWithSource(
                            label: "Con MIL encendido",
                            value: formatKm(distMIL),
                            source: "PID 0x21"
                        )
                    }
                }

                // Estado del sistema
                Section("Estado del Sistema") {
                    if let milStatus = extendedInfo.milStatus {
                        HStack {
                            Text("Check Engine (MIL)")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(milStatus ? Color.red : Color.green)
                                    .frame(width: 10, height: 10)
                                Text(milStatus ? "ENCENDIDO" : "Apagado")
                                    .foregroundColor(milStatus ? .red : .green)
                                    .fontWeight(milStatus ? .bold : .regular)
                            }
                        }
                    }

                    if let dtcCount = extendedInfo.dtcCount {
                        InfoRow(label: "Códigos almacenados", value: "\(dtcCount)")
                    }

                    if let timeSinceDTC = extendedInfo.timeSinceDTCClear {
                        InfoRowWithSource(
                            label: "Tiempo desde borrado",
                            value: formatMinutes(timeSinceDTC),
                            source: "PID 0x4E"
                        )
                    }

                    if let runtime = extendedInfo.totalRuntime {
                        InfoRowWithSource(
                            label: "Runtime total ECU",
                            value: formatMinutes(runtime),
                            source: "PID 0x7F"
                        )
                    }
                }

                // Monitores OBD
                if !extendedInfo.monitorStatus.isEmpty {
                    Section("Monitores OBD") {
                        ForEach(Array(extendedInfo.monitorStatus.keys.sorted()), id: \.self) { monitor in
                            if let status = extendedInfo.monitorStatus[monitor] {
                                HStack {
                                    Text(monitor)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(status == "Completo" ? .green : (status == "Incompleto" ? .orange : .gray))
                                }
                            }
                        }
                    }
                }

                // Info del motor (siempre mostrar para RX-8)
                Section("Motor 13B-MSP Renesis") {
                    InfoRow(label: "Tipo", value: "Rotativo Wankel")
                    InfoRow(label: "Cilindrada", value: "1.3L (654cc x 2)")
                    InfoRow(label: "Compresión", value: "10.0:1")
                    InfoRow(label: "Potencia MT", value: "231 HP @ 8200 RPM")
                    InfoRow(label: "Potencia AT", value: "197 HP @ 7200 RPM")
                    InfoRow(label: "Par", value: "211 Nm @ 5500 RPM")
                    InfoRow(label: "Redline", value: "9000 RPM")
                }

                // Info del adaptador
                Section("Adaptador OBD") {
                    if let adapter = connectionManager.adapterInfo {
                        InfoRow(label: "Chip", value: adapter.chipType)
                        InfoRow(label: "Versión", value: adapter.version)
                    }
                    if let proto = connectionManager.vehicleProtocol {
                        InfoRow(label: "Protocolo", value: proto.rawValue)
                    }
                }

                // Botón de recarga si no está cargando
                if !isLoading {
                    Section {
                        Button(action: { Task { await readAllVehicleInfo() } }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Actualizar información")
                            }
                        }
                        .disabled(connectionManager.connectionState != .connectedToVehicle)
                    }
                }
            }
            .navigationTitle("Información del Vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task {
                if connectionManager.connectionState == .connectedToVehicle {
                    await readAllVehicleInfo()
                }
            }
        }
    }

    private func formatKm(_ km: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return (formatter.string(from: NSNumber(value: km)) ?? "\(km)") + " km"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes < 1440 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        } else {
            let days = minutes / 1440
            let hours = (minutes % 1440) / 60
            return "\(days)d \(hours)h"
        }
    }

    @MainActor
    private func readAllVehicleInfo() async {
        isLoading = true
        errorMessages = []
        extendedInfo = ExtendedVehicleInfo()

        // 1. Leer VIN (múltiples intentos)
        loadingStatus = "Leyendo VIN..."
        await readVIN()

        // 2. Leer odómetro
        loadingStatus = "Leyendo kilometraje..."
        await readOdometer()

        // 3. Leer estado MIL y monitores
        loadingStatus = "Leyendo estado del sistema..."
        await readSystemStatus()

        // 4. Leer distancias y tiempos
        loadingStatus = "Leyendo datos adicionales..."
        await readAdditionalData()

        // 5. Leer calibración ECU
        loadingStatus = "Leyendo calibración ECU..."
        await readCalibrationId()

        isLoading = false
        loadingStatus = "Completado"
    }

    private func readVIN() async {
        // Intentar Mode 09 PID 02 (VIN estándar)
        do {
            let vin = try await connectionManager.readVIN()
            if vin.count >= 10 {
                extendedInfo.vin = vin
                vehicleInfo = RX8VehicleInfo(vin: vin)
                return
            }
        } catch {
            // Intentar método alternativo
        }

        // Método alternativo: leer bytes directamente
        do {
            let response = try await connectionManager.sendCommand("0902", timeout: 8.0)
            if !response.contains("NO DATA") && !response.contains("ERROR") {
                // Parsear respuesta multilínea de VIN
                let vin = parseVINFromResponse(response)
                if vin.count >= 10 {
                    extendedInfo.vin = vin
                    vehicleInfo = RX8VehicleInfo(vin: vin)
                    return
                }
            }
        } catch {
            // Continuar
        }

        errorMessages.append("VIN no disponible")
    }

    private func parseVINFromResponse(_ response: String) -> String {
        // El VIN viene en múltiples líneas, cada una con índice
        var vinBytes: [UInt8] = []
        let lines = response.components(separatedBy: "\r")

        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.isEmpty { continue }

            // Extraer bytes hex (saltando el primer byte que es el índice)
            let hexPairs = cleaned.components(separatedBy: " ").filter { $0.count == 2 }
            if hexPairs.count > 1 {
                for (index, hex) in hexPairs.enumerated() {
                    if index == 0 { continue } // Saltar índice
                    if let byte = UInt8(hex, radix: 16), byte >= 0x20 && byte <= 0x7E {
                        vinBytes.append(byte)
                    }
                }
            }
        }

        if let vin = String(bytes: vinBytes.prefix(17), encoding: .ascii) {
            return vin.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func readOdometer() async {
        // Intentar múltiples fuentes

        // 1. Mode 22 PIDs Mazda
        let mazdaPIDs: [(UInt16, String)] = [
            (0x1254, "Mazda ECU"),
            (0x1255, "Mazda Alt"),
            (0x1001, "Mazda WDS"),
        ]

        for (pid, source) in mazdaPIDs {
            do {
                let cmd = String(format: "22%04X", pid)
                let response = try await connectionManager.sendCommand(cmd, timeout: 3.0)
                if !response.contains("NO DATA") && !response.contains("ERROR") {
                    if let km = parseOdometerResponse(response) {
                        extendedInfo.odometerKm = km
                        extendedInfo.odometerSource = source
                        return
                    }
                }
            } catch {
                continue
            }
        }

        // 2. PID estándar 0xA6
        do {
            let response = try await connectionManager.sendCommand("01A6", timeout: 3.0)
            if !response.contains("NO DATA") {
                if let km = parseOdometerResponse(response) {
                    extendedInfo.odometerKm = km
                    extendedInfo.odometerSource = "OBD2 0xA6"
                    return
                }
            }
        } catch {}

        // 3. Usar función del connectionManager
        do {
            let km = try await connectionManager.readOdometer()
            if km > 0 {
                extendedInfo.odometerKm = km
                extendedInfo.odometerSource = "OBD"
                return
            }
        } catch {}

        errorMessages.append("Odómetro no disponible")
    }

    private func parseOdometerResponse(_ response: String) -> Int? {
        let cleaned = response.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: ">", with: "")

        // Buscar bytes de datos después del header
        var hexData = cleaned
        if let range = hexData.range(of: "62") { // Respuesta Mode 22
            hexData = String(hexData[range.upperBound...])
        } else if let range = hexData.range(of: "41") { // Respuesta Mode 01
            hexData = String(hexData[range.upperBound...])
        }

        // Saltar PID (2-4 caracteres)
        if hexData.count > 4 {
            hexData = String(hexData.dropFirst(4))
        }

        // Parsear bytes
        var km = 0
        let byteCount = min(hexData.count / 2, 4)

        for i in 0..<byteCount {
            let start = hexData.index(hexData.startIndex, offsetBy: i * 2)
            let end = hexData.index(start, offsetBy: 2)
            if let byte = UInt8(String(hexData[start..<end]), radix: 16) {
                km = km * 256 + Int(byte)
            }
        }

        // Validar rango razonable
        if km > 0 && km < 1_000_000 {
            return km
        } else if km > 1_000_000 && km < 10_000_000 {
            // Posiblemente en decímetros
            return km / 10
        }

        return nil
    }

    private func readSystemStatus() async {
        // PID 0x01 - Estado de monitores y MIL
        do {
            let response = try await connectionManager.sendCommand("0101", timeout: 3.0)
            if !response.contains("NO DATA") {
                parseMonitorStatus(response)
            }
        } catch {}

        // Contar DTCs
        do {
            let dtcs = try await connectionManager.readDTCs()
            extendedInfo.dtcCount = dtcs.count
        } catch {}
    }

    private func parseMonitorStatus(_ response: String) {
        let bytes = connectionManager.parseHexResponse(response)
        guard bytes.count >= 4 else { return }

        // Byte A: MIL status y DTC count
        let milOn = (bytes[0] & 0x80) != 0
        extendedInfo.milStatus = milOn

        // Bytes B, C, D: Monitor status
        let monitors: [(String, UInt8, UInt8)] = [
            ("Misfire", bytes[1], 0x01),
            ("Fuel System", bytes[1], 0x02),
            ("Components", bytes[1], 0x04),
            ("Catalyst", bytes[2], 0x01),
            ("Heated Catalyst", bytes[2], 0x02),
            ("EVAP", bytes[2], 0x04),
            ("Secondary Air", bytes[2], 0x08),
            ("O2 Sensor", bytes[2], 0x20),
            ("O2 Heater", bytes[2], 0x40),
            ("EGR", bytes[2], 0x80),
        ]

        for (name, byte, mask) in monitors {
            let supported = (bytes[1] & mask) != 0 || (bytes[2] & mask) != 0
            if supported {
                let complete = (bytes[3] & mask) == 0
                extendedInfo.monitorStatus[name] = complete ? "Completo" : "Incompleto"
            }
        }
    }

    private func readAdditionalData() async {
        // PID 0x31 - Distancia desde borrado de DTCs
        do {
            let dist = try await connectionManager.readDistanceSinceDTCClear()
            if dist > 0 {
                extendedInfo.distanceSinceDTCClear = dist
            }
        } catch {}

        // PID 0x21 - Distancia con MIL encendido
        do {
            let response = try await connectionManager.sendCommand("0121", timeout: 3.0)
            if !response.contains("NO DATA") {
                let bytes = connectionManager.parseHexResponse(response)
                if bytes.count >= 2 {
                    let dist = Int(bytes[0]) * 256 + Int(bytes[1])
                    if dist > 0 {
                        extendedInfo.distanceWithMIL = dist
                    }
                }
            }
        } catch {}

        // PID 0x4E - Tiempo desde borrado de DTCs
        do {
            let response = try await connectionManager.sendCommand("014E", timeout: 3.0)
            if !response.contains("NO DATA") {
                let bytes = connectionManager.parseHexResponse(response)
                if bytes.count >= 2 {
                    let minutes = Int(bytes[0]) * 256 + Int(bytes[1])
                    extendedInfo.timeSinceDTCClear = minutes
                }
            }
        } catch {}

        // PID 0x7F - Runtime total ECU
        do {
            let response = try await connectionManager.sendCommand("017F", timeout: 3.0)
            if !response.contains("NO DATA") {
                let bytes = connectionManager.parseHexResponse(response)
                if bytes.count >= 4 {
                    let seconds = Int(bytes[0]) * 16777216 + Int(bytes[1]) * 65536 + Int(bytes[2]) * 256 + Int(bytes[3])
                    extendedInfo.totalRuntime = seconds / 60
                }
            }
        } catch {}
    }

    private func readCalibrationId() async {
        // Mode 09 PID 04 - Calibration ID
        do {
            let response = try await connectionManager.sendCommand("0904", timeout: 5.0)
            if !response.contains("NO DATA") && !response.contains("ERROR") {
                let bytes = connectionManager.parseHexResponse(response)
                if bytes.count > 1 {
                    // Los primeros bytes pueden ser contadores, buscar ASCII
                    let asciiBytes = bytes.filter { $0 >= 0x20 && $0 <= 0x7E }
                    if let calId = String(bytes: asciiBytes.prefix(16), encoding: .ascii) {
                        let cleaned = calId.trimmingCharacters(in: .whitespaces)
                        if !cleaned.isEmpty {
                            extendedInfo.calibrationId = cleaned
                        }
                    }
                }
            }
        } catch {}
    }
}

// Estructura para datos extendidos del vehículo
struct ExtendedVehicleInfo {
    var vin: String?
    var calibrationId: String?
    var odometerKm: Int?
    var odometerSource: String?
    var distanceSinceDTCClear: Int?
    var distanceWithMIL: Int?
    var timeSinceDTCClear: Int? // minutos
    var totalRuntime: Int? // minutos
    var milStatus: Bool?
    var dtcCount: Int?
    var monitorStatus: [String: String] = [:]
}

struct VINRow: View {
    let vin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VIN")
                .font(.caption)
                .foregroundColor(.gray)
            Text(vin)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.orange)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

struct InfoRowWithStatus: View {
    let label: String
    let value: String
    let status: InfoStatus

    enum InfoStatus {
        case ok, warning, error
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .foregroundColor(status == .ok ? .white : (status == .warning ? .orange : .red))
                Image(systemName: status == .ok ? "checkmark.circle" : (status == .warning ? "exclamationmark.triangle" : "xmark.circle"))
                    .foregroundColor(status == .ok ? .green : (status == .warning ? .orange : .red))
                    .font(.caption)
            }
        }
    }
}

struct InfoRowWithSource: View {
    let label: String
    let value: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .foregroundColor(.gray)
                Spacer()
                Text(value)
                    .foregroundColor(.white)
            }
            HStack {
                Spacer()
                Text(source)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Configuración de Alertas

struct AlertSettingsView: View {
    @AppStorage("coolantWarning") private var coolantWarning = 100.0
    @AppStorage("coolantCritical") private var coolantCritical = 105.0
    @AppStorage("oilWarning") private var oilWarning = 120.0
    @AppStorage("oilCritical") private var oilCritical = 130.0
    @AppStorage("batteryLow") private var batteryLow = 12.0
    @AppStorage("rpmWarning") private var rpmWarning = 8500

    var body: some View {
        List {
            Section("Temperatura Refrigerante") {
                Stepper("Advertencia: \(Int(coolantWarning))°C", value: $coolantWarning, in: 90...110)
                Stepper("Crítico: \(Int(coolantCritical))°C", value: $coolantCritical, in: 100...120)
            }

            Section("Temperatura Aceite") {
                Stepper("Advertencia: \(Int(oilWarning))°C", value: $oilWarning, in: 100...140)
                Stepper("Crítico: \(Int(oilCritical))°C", value: $oilCritical, in: 120...150)
            }

            Section("Batería") {
                Stepper("Bajo: \(String(format: "%.1f", batteryLow))V", value: $batteryLow, in: 10...13, step: 0.5)
            }

            Section("RPM") {
                Stepper("Advertencia: \(rpmWarning)", value: $rpmWarning, in: 7000...9500, step: 500)
            }

            Section {
                Button("Restaurar valores por defecto") {
                    coolantWarning = 100
                    coolantCritical = 105
                    oilWarning = 120
                    oilCritical = 130
                    batteryLow = 12.0
                    rpmWarning = 8500
                }
            }
        }
        .navigationTitle("Umbrales de Alerta")
    }
}

// MARK: - Configuración de Logging

struct DataLoggingSettingsView: View {
    @AppStorage("loggingEnabled") private var loggingEnabled = false
    @AppStorage("loggingInterval") private var loggingInterval = 1.0

    var body: some View {
        List {
            Section {
                Toggle("Registro activo", isOn: $loggingEnabled)
            }

            if loggingEnabled {
                Section("Intervalo de captura") {
                    Picker("Frecuencia", selection: $loggingInterval) {
                        Text("0.5 segundos").tag(0.5)
                        Text("1 segundo").tag(1.0)
                        Text("2 segundos").tag(2.0)
                        Text("5 segundos").tag(5.0)
                    }
                }

                Section("PIDs a registrar") {
                    Toggle("RPM", isOn: .constant(true))
                    Toggle("Velocidad", isOn: .constant(true))
                    Toggle("Temperaturas", isOn: .constant(true))
                    Toggle("Fuel Trims", isOn: .constant(true))
                    Toggle("Posición acelerador", isOn: .constant(true))
                }
            }
        }
        .navigationTitle("Registro de Datos")
    }
}

// MARK: - Exportar Datos

struct ExportDataView: View {
    var body: some View {
        List {
            Section {
                Button(action: {}) {
                    Label("Exportar como CSV", systemImage: "doc.text")
                }

                Button(action: {}) {
                    Label("Exportar como JSON", systemImage: "doc.badge.gearshape")
                }

                Button(action: {}) {
                    Label("Compartir reporte", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Text("Los datos exportados incluyen el historial de viajes, consumo de combustible y sesiones de diagnóstico.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Exportar Datos")
    }
}

// MARK: - Vista Acerca de

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "car.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)

                        Text("RX-8 Diagnostic Tool")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Versión 1.0.0")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    // Descripción
                    Text("La herramienta definitiva para diagnóstico y monitoreo del Mazda RX-8. Diseñada por y para entusiastas del motor rotativo.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Divider()
                        .background(Color.gray)
                        .padding(.horizontal)

                    // Créditos
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Créditos")
                            .font(.headline)
                            .foregroundColor(.white)

                        CreditRow(title: "PIDs CAN Bus", source: "topolittle/RX8-CAN-BUS")
                        CreditRow(title: "Librería OBD2", source: "SwiftOBD2")
                        CreditRow(title: "Comunidad", source: "RX8Club.com")
                        CreditRow(title: "Documentación", source: "RotaryHeads.com")
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Color.gray)
                        .padding(.horizontal)

                    // Especificaciones soportadas
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vehículos Soportados")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Mazda RX-8 Serie 1 (2003-2008)")
                                .foregroundColor(.gray)
                        }

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Mazda RX-8 Serie 2 (2009-2012)")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Footer
                    Text("Hecho con ❤️ para la comunidad RX-8")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

struct CreditRow: View {
    let title: String
    let source: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(source)
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}
