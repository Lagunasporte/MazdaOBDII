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

                            Button("Aplicar recomendado") {
                                pollingInterval = results.recommendedInterval
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Rendimiento OBD")
                } footer: {
                    Text("Adaptadores baratos pueden necesitar intervalos más largos (200-300ms). El Carista funciona bien a 50-100ms.")
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

// MARK: - Vista de Información del Vehículo

struct VehicleInfoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var vehicleInfo: RX8VehicleInfo?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if let info = vehicleInfo {
                    Section("Identificación") {
                        InfoRow(label: "VIN", value: info.vin)
                        InfoRow(label: "Año", value: "\(info.year)")
                        InfoRow(label: "Serie", value: info.series.rawValue)
                        InfoRow(label: "Mercado", value: info.marketRegion.rawValue)
                    }

                    Section("Motor") {
                        InfoRow(label: "Código", value: info.engineCode)
                        InfoRow(label: "Tipo", value: "Rotativo Wankel")
                        InfoRow(label: "Cilindrada", value: "1.3L (654cc x 2)")
                        InfoRow(label: "Potencia", value: "231 HP @ 8200 RPM")
                        InfoRow(label: "Par", value: "211 Nm @ 5500 RPM")
                    }

                    Section("Transmisión") {
                        InfoRow(label: "Tipo", value: info.transmission.rawValue)
                        InfoRow(label: "Relación final", value: String(format: "%.2f", info.transmission.finalDrive))
                    }

                    Section("Notas del mercado") {
                        ForEach(info.marketRegion.specificNotes, id: \.self) { note in
                            HStack(alignment: .top) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(note)
                                    .font(.caption)
                            }
                        }
                    }

                    Section("Características \(info.series.rawValue)") {
                        ForEach(info.series.differences, id: \.self) { diff in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(diff)
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    Section {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Leyendo VIN...")
                            }
                        } else {
                            Button("Leer información del vehículo") {
                                readVehicleInfo()
                            }
                        }
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
        }
    }

    func readVehicleInfo() {
        isLoading = true
        Task {
            do {
                let vin = try await connectionManager.readVIN()
                vehicleInfo = RX8VehicleInfo(vin: vin)
            } catch {
                // Manejar error
            }
            isLoading = false
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
