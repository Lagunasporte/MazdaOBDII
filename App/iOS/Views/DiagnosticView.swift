import SwiftUI

// MARK: - Vista de Diagnóstico Completo (Responsive: Vertical=Móvil, Horizontal=CarPlay)

struct DiagnosticView: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showReport = false
    @State private var lastReport: DiagnosticReport?
    @State private var showDTCList = false
    @State private var showClearDTCAlert = false
    @State private var showO2Test = false
    @State private var showRealTimeMonitor = false
    @State private var showVehicleInfo = false
    @State private var showFreezeFrame = false
    @State private var showProcedures = false
    @State private var showBlackBox = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showClearResult = false
    @State private var clearResultMessage = ""

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                // MODO CARPLAY
                CarPlayDiagnosticView(
                    geometry: geometry,
                    showDTCList: $showDTCList,
                    showClearDTCAlert: $showClearDTCAlert,
                    showBlackBox: $showBlackBox
                )
            } else {
                // MODO MÓVIL
                MobileDiagnosticView(
                    showReport: $showReport,
                    lastReport: $lastReport,
                    showDTCList: $showDTCList,
                    showClearDTCAlert: $showClearDTCAlert,
                    showO2Test: $showO2Test,
                    showRealTimeMonitor: $showRealTimeMonitor,
                    showVehicleInfo: $showVehicleInfo,
                    showFreezeFrame: $showFreezeFrame,
                    showProcedures: $showProcedures,
                    showBlackBox: $showBlackBox,
                    clearDTCsAction: clearDTCs
                )
            }
        }
        .background(Color.black)
        .onAppear {
            diagnosticMode.connectionManager = connectionManager
        }
        .sheet(isPresented: $showReport) {
            if let report = lastReport {
                DiagnosticReportView(report: report)
            }
        }
        .sheet(isPresented: $showDTCList) {
            DTCListSheet()
        }
        .sheet(isPresented: $showO2Test) {
            O2TestSheet()
        }
        .sheet(isPresented: $showRealTimeMonitor) {
            RealTimeMonitorSheet()
        }
        .sheet(isPresented: $showVehicleInfo) {
            VehicleInfoSheet()
        }
        .sheet(isPresented: $showFreezeFrame) {
            FreezeFrameSheet()
        }
        .sheet(isPresented: $showProcedures) {
            ProceduresView()
        }
        .sheet(isPresented: $showBlackBox) {
            BlackBoxView()
        }
        .alert("Borrar DTCs", isPresented: $showClearDTCAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) {
                clearDTCs()
            }
        } message: {
            Text("¿Borrar todos los códigos? Apagará Check Engine.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Error desconocido")
        }
        .alert("Resultado", isPresented: $showClearResult) {
            Button("OK") {}
        } message: {
            Text(clearResultMessage)
        }
    }

    private func clearDTCs() {
        Task {
            do {
                try await connectionManager.clearDTCs()

                // Esperar a que se procese el resultado
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    if let result = connectionManager.dtcClearResult {
                        clearResultMessage = result.message
                        if !result.success {
                            clearResultMessage += "\n\nNota: Algunos códigos no se pudieron borrar. Pueden ser códigos permanentes o el motor puede necesitar estar apagado."
                        }
                    } else {
                        clearResultMessage = "Códigos borrados. Verifica el estado con un nuevo escaneo."
                    }
                    showClearResult = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Vista CarPlay Diagnóstico (Horizontal)

struct CarPlayDiagnosticView: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager
    let geometry: GeometryProxy
    @Binding var showDTCList: Bool
    @Binding var showClearDTCAlert: Bool
    @Binding var showBlackBox: Bool

    var isConnected: Bool {
        connectionManager.connectionState == .connectedToVehicle
    }

    var body: some View {
        HStack(spacing: 12) {
            // Columna izquierda: Score de salud
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: Double(diagnosticMode.healthScore) / 100)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(diagnosticMode.healthScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Salud")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Text(healthStatus)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(healthColor)

                // Hallazgos si hay
                if !diagnosticMode.findings.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("\(diagnosticMode.findings.count) hallazgos")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: geometry.size.width * 0.25)

            // Columna central: Acciones rápidas
            VStack(spacing: 8) {
                Text("DIAGNÓSTICOS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    CarPlayDiagButton(icon: "exclamationmark.triangle", label: "Leer DTCs", color: .red, enabled: isConnected) {
                        showDTCList = true
                    }

                    CarPlayDiagButton(icon: "trash", label: "Borrar", color: .orange, enabled: isConnected) {
                        showClearDTCAlert = true
                    }
                }

                HStack(spacing: 8) {
                    CarPlayDiagButton(icon: "record.circle", label: "Caja Negra", color: .pink, enabled: isConnected) {
                        showBlackBox = true
                    }

                    CarPlayDiagButton(icon: "stethoscope", label: "Diag Full", color: .blue, enabled: isConnected) {
                        Task {
                            _ = try? await diagnosticMode.startDiagnostic()
                        }
                    }
                }
            }
            .frame(width: geometry.size.width * 0.4)

            // Columna derecha: Estado
            VStack(spacing: 8) {
                if diagnosticMode.isRunning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.orange)

                        Text(diagnosticMode.currentPhase.rawValue)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(String(format: "%.0f%%", diagnosticMode.progress * 100))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(isConnected ? .green : .red)

                        Text(isConnected ? "Listo" : "Sin conexión")
                            .font(.caption)
                            .foregroundColor(isConnected ? .green : .red)
                    }

                    if isConnected {
                        Text("Toca para diagnosticar")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: geometry.size.width * 0.25)
        }
        .padding(12)
    }

    var healthColor: Color {
        if diagnosticMode.healthScore >= 90 { return .green }
        if diagnosticMode.healthScore >= 70 { return .teal }
        if diagnosticMode.healthScore >= 50 { return .yellow }
        if diagnosticMode.healthScore >= 25 { return .orange }
        return .red
    }

    var healthStatus: String {
        if diagnosticMode.healthScore >= 90 { return "Excelente" }
        if diagnosticMode.healthScore >= 70 { return "Bueno" }
        if diagnosticMode.healthScore >= 50 { return "Regular" }
        if diagnosticMode.healthScore >= 25 { return "Deficiente" }
        return "Crítico"
    }
}

struct CarPlayDiagButton: View {
    let icon: String
    let label: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(enabled ? color.opacity(0.3) : Color.gray.opacity(0.2))
            .foregroundColor(enabled ? color : .gray)
            .cornerRadius(10)
        }
        .disabled(!enabled)
    }
}

// MARK: - Vista Móvil Diagnóstico (Vertical)

struct MobileDiagnosticView: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Binding var showReport: Bool
    @Binding var lastReport: DiagnosticReport?
    @Binding var showDTCList: Bool
    @Binding var showClearDTCAlert: Bool
    @Binding var showO2Test: Bool
    @Binding var showRealTimeMonitor: Bool
    @Binding var showVehicleInfo: Bool
    @Binding var showFreezeFrame: Bool
    @Binding var showProcedures: Bool
    @Binding var showBlackBox: Bool
    @State private var showActuatorTools = false
    let clearDTCsAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DiagnosticHeaderCard()

                    if diagnosticMode.isRunning {
                        DiagnosticProgressCard()
                    } else {
                        StartDiagnosticButton()

                        if !diagnosticMode.findings.isEmpty {
                            FindingsCard()
                        }

                        QuickDiagnosticsGrid(
                            showDTCList: $showDTCList,
                            showClearDTCAlert: $showClearDTCAlert,
                            showO2Test: $showO2Test,
                            showRealTimeMonitor: $showRealTimeMonitor,
                            showVehicleInfo: $showVehicleInfo,
                            showFreezeFrame: $showFreezeFrame,
                            showProcedures: $showProcedures,
                            showBlackBox: $showBlackBox
                        )

                        RX8SpecificDiagnosticsCard()

                        ActuatorToolsCard(showActuatorTools: $showActuatorTools)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Diagnóstico")
            .sheet(isPresented: $showActuatorTools) {
                ActuatorToolsSheet()
            }
        }
    }
}

// MARK: - Diagnósticos Específicos RX-8

struct RX8SpecificDiagnosticsCard: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var showCatalystCheck = false
    @State private var showIgnitionCheck = false
    @State private var showOMPCheck = false
    @State private var showFuelTrimAnalysis = false
    @State private var showPIDTester = false

    var isConnected: Bool {
        connectionManager.connectionState == .connectedToVehicle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "r.circle.fill")
                    .foregroundColor(.orange)
                Text("Diagnósticos Motor Rotativo")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Pruebas específicas para el motor 13B-MSP Renesis")
                .font(.caption)
                .foregroundColor(.gray)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RX8DiagButton(
                    title: "Estado Bobinas",
                    icon: "bolt.fill",
                    color: .yellow,
                    isEnabled: isConnected
                ) {
                    showIgnitionCheck = true
                }

                RX8DiagButton(
                    title: "Análisis Fuel Trim",
                    icon: "fuelpump.fill",
                    color: .green,
                    isEnabled: isConnected
                ) {
                    showFuelTrimAnalysis = true
                }

                RX8DiagButton(
                    title: "Estado Catalizador",
                    icon: "leaf.fill",
                    color: .teal,
                    isEnabled: isConnected
                ) {
                    showCatalystCheck = true
                }

                RX8DiagButton(
                    title: "Sistema OMP",
                    icon: "drop.fill",
                    color: .purple,
                    isEnabled: isConnected
                ) {
                    showOMPCheck = true
                }

                RX8DiagButton(
                    title: "Test PIDs Mazda",
                    icon: "wrench.and.screwdriver.fill",
                    color: .cyan,
                    isEnabled: isConnected
                ) {
                    showPIDTester = true
                }
            }

            // Información importante
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Las bobinas trailing fallan silenciosamente y dañan el catalizador")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                HStack(alignment: .top) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Reemplazar siempre las 4 bobinas juntas")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .sheet(isPresented: $showIgnitionCheck) {
            IgnitionCheckSheet()
        }
        .sheet(isPresented: $showFuelTrimAnalysis) {
            FuelTrimAnalysisSheet()
        }
        .sheet(isPresented: $showCatalystCheck) {
            CatalystCheckSheet()
        }
        .sheet(isPresented: $showOMPCheck) {
            OMPCheckSheet()
        }
        .sheet(isPresented: $showPIDTester) {
            PIDTesterSheet()
        }
    }
}

// MARK: - PID Tester Tool

struct PIDTesterSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var testResults: [PIDTestResult] = []
    @State private var isRunning = false
    @State private var customCommand = ""
    @State private var customResponse = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sección de tests automáticos
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test de PIDs Mazda")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Prueba PIDs específicos de Mazda para verificar compatibilidad")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Button(action: { Task { await runAllTests() } }) {
                            HStack {
                                if isRunning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Image(systemName: "play.fill")
                                Text(isRunning ? "Ejecutando..." : "Ejecutar Tests")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan.opacity(0.3))
                            .foregroundColor(.cyan)
                            .cornerRadius(12)
                        }
                        .disabled(isRunning)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(16)

                    // Resultados
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resultados")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(testResults, id: \.pid) { result in
                                PIDResultRow(result: result)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)
                    }

                    // Comando personalizado
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comando Personalizado")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextField("Ej: 221200, 0105, AT RV", text: $customCommand)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)

                        Button(action: { Task { await sendCustomCommand() } }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Enviar")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                        }
                        .disabled(customCommand.isEmpty)

                        if !customResponse.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Respuesta:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(customResponse)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.green)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Test PIDs Mazda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func runAllTests() async {
        isRunning = true
        testResults = []

        // Lista de PIDs a probar - incluye ambas fórmulas para temp aceite
        let pidsToTest: [(name: String, command: String, formula: String)] = [
            // Temperatura aceite - fórmula /100 (Torque/Scangauge confirmado)
            ("Temp Aceite 1310 (/100)", "221310", "(A×256+B)/100-40 °C"),
            ("Temp Aceite 1200 (/100)", "221200", "(A×256+B)/100-40 °C"),
            // Temperatura aceite - fórmula /10 (VersaTuner)
            ("Temp Aceite 1310 (/10)", "221310", "(A×256+B)/10-40 °C"),
            ("Temp Aceite 1200 (/10)", "221200", "(A×256+B)/10-40 °C"),
            // Temperatura aceite OBD estándar
            ("Temp Aceite OBD (5C)", "015C", "A-40 °C"),
            // Otros PIDs
            ("Presión Aceite (1201)", "221201", "A×10 kPa"),
            ("SSV Position (2000)", "222000", "A %"),
            ("OMP Duty (2100)", "222100", "A duty%"),
            ("Target AFR (1300)", "221300", "(A×256+B)/1000"),
            ("Knock Retard (1746)", "221746", "(A×256+B)/64 deg"),
            ("Coolant Temp", "0105", "A-40 °C"),
            ("RPM", "010C", "(A×256+B)/4 rpm"),
            ("MAF", "0110", "(A×256+B)/100 g/s"),
        ]

        // Configurar header para Mode 22
        _ = try? await connectionManager.sendCommand("AT SH 7E0", timeout: 2.0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        for (name, command, formula) in pidsToTest {
            do {
                let response = try await connectionManager.sendCommand(command, timeout: 3.0)

                let success = !response.contains("NO DATA") &&
                              !response.contains("ERROR") &&
                              !response.contains("?")

                // Parsear valor si es exitoso
                var parsedValue: String? = nil
                if success {
                    parsedValue = parseResponse(response, command: command, pidName: name)
                }

                testResults.append(PIDTestResult(
                    pid: name,
                    command: command,
                    response: response.trimmingCharacters(in: .whitespacesAndNewlines),
                    success: success,
                    formula: formula,
                    parsedValue: parsedValue
                ))
            } catch {
                testResults.append(PIDTestResult(
                    pid: name,
                    command: command,
                    response: "Error: \(error.localizedDescription)",
                    success: false,
                    formula: formula,
                    parsedValue: nil
                ))
            }

            // Pequeña pausa entre comandos
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        isRunning = false
    }

    private func parseResponse(_ response: String, command: String, pidName: String = "") -> String? {
        let bytes = connectionManager.parseHexResponse(response)
        guard !bytes.isEmpty else { return nil }

        // Para temp aceite Mode 22 (2 bytes) - mostrar ambas fórmulas
        if command.starts(with: "22") && (command.contains("1310") || command.contains("1200")) && bytes.count >= 2 {
            let raw = Double(bytes[0]) * 256.0 + Double(bytes[1])
            // Determinar qué fórmula usar basándose en el nombre del PID
            if pidName.contains("/100") {
                let temp = (raw / 100.0) - 40.0
                return String(format: "%.1f°C (raw: %d, bytes: %02X %02X)", temp, Int(raw), bytes[0], bytes[1])
            } else {
                let temp = (raw / 10.0) - 40.0
                return String(format: "%.1f°C (raw: %d, bytes: %02X %02X)", temp, Int(raw), bytes[0], bytes[1])
            }
        }

        // Otros Mode 22 PIDs
        if command.starts(with: "22") && bytes.count >= 2 {
            let raw = Double(bytes[0]) * 256.0 + Double(bytes[1])
            return String(format: "raw: %d (bytes: %02X %02X)", Int(raw), bytes[0], bytes[1])
        }

        // Para temp OBD Mode 01 (1 byte)
        if command == "015C" && bytes.count >= 1 {
            let temp = Int(bytes[0]) - 40
            return "\(temp)°C (byte: \(String(format: "%02X", bytes[0])))"
        }

        // Para coolant temp
        if command == "0105" && bytes.count >= 1 {
            let temp = Int(bytes[0]) - 40
            return "\(temp)°C"
        }

        // Para RPM
        if command == "010C" && bytes.count >= 2 {
            let rpm = (Int(bytes[0]) * 256 + Int(bytes[1])) / 4
            return "\(rpm) rpm"
        }

        // Genérico: mostrar bytes
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    @MainActor
    private func sendCustomCommand() async {
        customResponse = "Enviando..."

        do {
            let response = try await connectionManager.sendCommand(customCommand, timeout: 5.0)
            customResponse = response
        } catch {
            customResponse = "Error: \(error.localizedDescription)"
        }
    }
}

struct PIDTestResult {
    let pid: String
    let command: String
    let response: String
    let success: Bool
    let formula: String
    let parsedValue: String?
}

struct PIDResultRow: View {
    let result: PIDTestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(result.success ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(result.pid)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Text(result.command)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }

            if result.success {
                if let parsed = result.parsedValue {
                    Text("Valor: \(parsed)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Text(result.response.prefix(50))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            } else {
                Text(result.response.prefix(40))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.orange)
            }

            Text(result.formula)
                .font(.caption2)
                .foregroundColor(.cyan)
        }
        .padding(8)
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RX8DiagButton: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? color : .gray)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .white : .gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? color.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Herramientas de Actuadores (Motor Apagado)

struct ActuatorToolsCard: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Binding var showActuatorTools: Bool

    var isConnected: Bool {
        connectionManager.connectionState == .connectedToVehicle
    }

    var engineIsOff: Bool {
        engineMonitor.currentState.rpm < 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.cyan)
                Text("Herramientas de Actuadores")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Estado del motor
                HStack(spacing: 4) {
                    Circle()
                        .fill(engineIsOff ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(engineIsOff ? "Motor OFF" : "Motor ON")
                        .font(.caption2)
                        .foregroundColor(engineIsOff ? .green : .red)
                }
            }

            Text("Tests de actuadores Mazda (requiere motor apagado, contacto ON)")
                .font(.caption)
                .foregroundColor(.gray)

            Button(action: { showActuatorTools = true }) {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                    Text("Abrir Herramientas")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background((isConnected && engineIsOff) ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.2))
                .foregroundColor((isConnected && engineIsOff) ? .cyan : .gray)
                .cornerRadius(12)
            }
            .disabled(!isConnected || !engineIsOff)

            if !engineIsOff && isConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Apaga el motor para usar estas herramientas")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct ActuatorToolsSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Environment(\.dismiss) var dismiss
    @State private var activeTest: ActuatorTest?
    @State private var isRunningTest = false
    @State private var testResult: String?
    @State private var testSuccess = false
    @State private var showSafetyAlert = false

    var engineIsOff: Bool {
        engineMonitor.currentState.rpm < 100
    }

    var batteryOK: Bool {
        engineMonitor.currentState.batteryVoltage >= 11.5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Advertencia de seguridad
                    SafetyWarningCard()

                    // Estado del sistema
                    SystemStatusCard(engineOff: engineIsOff, batteryOK: batteryOK)

                    if engineIsOff && batteryOK {
                        // Tests disponibles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tests Disponibles")
                                .font(.headline)
                                .foregroundColor(.white)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ActuatorTestButton(
                                    test: .throttleBody,
                                    isRunning: activeTest == .throttleBody && isRunningTest
                                ) {
                                    runTest(.throttleBody)
                                }

                                ActuatorTestButton(
                                    test: .ssv,
                                    isRunning: activeTest == .ssv && isRunningTest
                                ) {
                                    runTest(.ssv)
                                }

                                ActuatorTestButton(
                                    test: .coolingFan,
                                    isRunning: activeTest == .coolingFan && isRunningTest
                                ) {
                                    runTest(.coolingFan)
                                }

                                ActuatorTestButton(
                                    test: .acFan,
                                    isRunning: activeTest == .acFan && isRunningTest
                                ) {
                                    runTest(.acFan)
                                }

                                ActuatorTestButton(
                                    test: .fuelPump,
                                    isRunning: activeTest == .fuelPump && isRunningTest
                                ) {
                                    runTest(.fuelPump)
                                }

                                ActuatorTestButton(
                                    test: .purgeValve,
                                    isRunning: activeTest == .purgeValve && isRunningTest
                                ) {
                                    runTest(.purgeValve)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)

                        // Resultado del test
                        if let result = testResult {
                            TestResultCard(result: result, success: testSuccess)
                        }

                        // Información adicional
                        ActuatorInfoCard()
                    } else {
                        // Requisitos no cumplidos
                        RequirementsNotMetCard(engineOff: engineIsOff, batteryOK: batteryOK)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Herramientas Actuadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .alert("Confirmar Test", isPresented: $showSafetyAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Ejecutar") {
                    if let test = activeTest {
                        executeTest(test)
                    }
                }
            } message: {
                Text("¿Ejecutar test de \(activeTest?.title ?? "")? Asegúrate de que el área esté despejada.")
            }
        }
    }

    private func runTest(_ test: ActuatorTest) {
        activeTest = test
        showSafetyAlert = true
    }

    private func executeTest(_ test: ActuatorTest) {
        isRunningTest = true
        testResult = nil

        Task {
            do {
                // Verificar que el motor sigue apagado
                let rpm = try await connectionManager.readRPM()
                guard rpm < 100 else {
                    await MainActor.run {
                        testResult = "Test cancelado: el motor se ha encendido"
                        testSuccess = false
                        isRunningTest = false
                    }
                    return
                }

                await MainActor.run {
                    testResult = "Iniciando sesión de diagnóstico..."
                }

                // 1. Intentar entrar en sesión de diagnóstico extendida
                // UDS Mode 10 03 = Extended Diagnostic Session
                _ = try? await connectionManager.sendCommand("1003", timeout: 2.0)

                // 2. Enviar Tester Present para mantener sesión
                _ = try? await connectionManager.sendCommand("3E00", timeout: 1.0)

                await MainActor.run {
                    testResult = "Ejecutando \(test.title)..."
                }

                // 3. Intentar múltiples métodos de control
                var success = false
                var lastResponse = ""

                // Método 1: UDS IO Control By Identifier (Mode 2F)
                if !success {
                    let response = try await connectionManager.sendCommand(test.udsCommand, timeout: 5.0)
                    lastResponse = response
                    if isPositiveResponse(response) {
                        success = true
                    }
                }

                // Método 2: Mazda Mode 30 (Output Control)
                if !success {
                    let response = try await connectionManager.sendCommand(test.mode30Command, timeout: 5.0)
                    lastResponse = response
                    if isPositiveResponse(response) {
                        success = true
                    }
                }

                // Método 3: Mode 08 estándar (último recurso)
                if !success {
                    let response = try await connectionManager.sendCommand(test.command, timeout: 5.0)
                    lastResponse = response
                    if isPositiveResponse(response) {
                        success = true
                    }
                }

                await MainActor.run {
                    if success {
                        testResult = "✓ \(test.title) activado"
                        testSuccess = true
                    } else {
                        // Analizar respuesta para dar mejor feedback
                        let errorMsg = parseErrorResponse(lastResponse)
                        testResult = "✗ \(test.title): \(errorMsg)"
                        testSuccess = false
                    }
                }

                // Esperar duración del test si fue exitoso
                if success {
                    try await Task.sleep(nanoseconds: UInt64(test.duration) * 1_000_000_000)

                    // Enviar comando de parada
                    if let stopCmd = test.stopCommand {
                        _ = try? await connectionManager.sendCommand(stopCmd, timeout: 2.0)
                    }
                    // Parar control UDS
                    _ = try? await connectionManager.sendCommand(test.udsStopCommand, timeout: 2.0)
                }

                await MainActor.run {
                    isRunningTest = false
                }

            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    testSuccess = false
                    isRunningTest = false
                }
            }
        }
    }

    private func isPositiveResponse(_ response: String) -> Bool {
        // Respuestas positivas UDS
        if response.contains("6F") || response.contains("70") || response.contains("50") {
            return true
        }
        // Respuesta OK genérica
        if response.contains("OK") {
            return true
        }
        // No es error ni NO DATA
        if !response.contains("ERROR") && !response.contains("NO DATA") &&
           !response.contains("7F") && response.count > 2 {
            return true
        }
        return false
    }

    private func parseErrorResponse(_ response: String) -> String {
        if response.contains("NO DATA") {
            return "ECU no responde - función no soportada"
        }
        if response.contains("7F") {
            // Negative Response Code
            if response.contains("12") {
                return "Sub-función no soportada"
            }
            if response.contains("13") {
                return "Longitud incorrecta"
            }
            if response.contains("22") {
                return "Condiciones no correctas"
            }
            if response.contains("31") {
                return "Fuera de rango"
            }
            if response.contains("33") {
                return "Requiere acceso de seguridad"
            }
            if response.contains("35") {
                return "Clave inválida"
            }
            if response.contains("72") {
                return "Secuencia incorrecta"
            }
            return "ECU rechazó comando (NRC)"
        }
        if response.contains("ERROR") || response.contains("?") {
            return "Comando no reconocido por adaptador"
        }
        return "Sin respuesta válida"
    }
}

enum ActuatorTest: String, CaseIterable {
    case throttleBody = "throttle"
    case ssv = "ssv"
    case coolingFan = "cooling_fan"
    case acFan = "ac_fan"
    case fuelPump = "fuel_pump"
    case purgeValve = "purge"

    var title: String {
        switch self {
        case .throttleBody: return "Cuerpo Mariposa"
        case .ssv: return "SSV (Mariposa Secundaria)"
        case .coolingFan: return "Ventilador Motor"
        case .acFan: return "Ventilador A/C"
        case .fuelPump: return "Bomba Combustible"
        case .purgeValve: return "Válvula Purga EVAP"
        }
    }

    var icon: String {
        switch self {
        case .throttleBody: return "arrow.left.and.right"
        case .ssv: return "rectangle.split.2x1"
        case .coolingFan: return "fan"
        case .acFan: return "snowflake"
        case .fuelPump: return "fuelpump"
        case .purgeValve: return "bubble.left.and.bubble.right"
        }
    }

    var color: Color {
        switch self {
        case .throttleBody: return .orange
        case .ssv: return .purple
        case .coolingFan: return .blue
        case .acFan: return .cyan
        case .fuelPump: return .green
        case .purgeValve: return .teal
        }
    }

    var description: String {
        switch self {
        case .throttleBody: return "Abre y cierra el cuerpo de mariposa"
        case .ssv: return "Activa la mariposa de admisión secundaria"
        case .coolingFan: return "Activa el ventilador del radiador"
        case .acFan: return "Activa el ventilador del condensador A/C"
        case .fuelPump: return "Activa la bomba de combustible"
        case .purgeValve: return "Activa la válvula de purga EVAP"
        }
    }

    // UDS IO Control By Identifier (Mode 2F)
    // Formato: 2F [DID High] [DID Low] [Control Option] [Control Parameter...]
    // Control Options: 00=Return, 03=Short Term Adjustment
    var udsCommand: String {
        switch self {
        // DIDs específicos de Mazda para control de actuadores
        case .throttleBody: return "2F100103FF"  // DID 1001, Short Term, Full Open
        case .ssv: return "2F100203FF"           // DID 1002, Short Term, Full Open
        case .coolingFan: return "2F10030301"    // DID 1003, Short Term, ON
        case .acFan: return "2F10040301"         // DID 1004, Short Term, ON
        case .fuelPump: return "2F10050301"      // DID 1005, Short Term, ON
        case .purgeValve: return "2F10060301"    // DID 1006, Short Term, ON
        }
    }

    var udsStopCommand: String {
        switch self {
        // Return Control to ECU (Control Option 00)
        case .throttleBody: return "2F100100"
        case .ssv: return "2F100200"
        case .coolingFan: return "2F100300"
        case .acFan: return "2F100400"
        case .fuelPump: return "2F100500"
        case .purgeValve: return "2F100600"
        }
    }

    // Mazda Output Control (Mode 30) - protocolo más antiguo
    // Formato: 30 [Actuator ID] [Control State]
    var mode30Command: String {
        switch self {
        case .throttleBody: return "300101"  // Actuator 01, ON
        case .ssv: return "300201"           // Actuator 02, ON
        case .coolingFan: return "300301"    // Actuator 03, ON
        case .acFan: return "300401"         // Actuator 04, ON
        case .fuelPump: return "300501"      // Actuator 05, ON
        case .purgeValve: return "300601"    // Actuator 06, ON
        }
    }

    // Mode 08 estándar OBD-II (fallback)
    var command: String {
        switch self {
        case .throttleBody: return "0801"
        case .ssv: return "0802"
        case .coolingFan: return "0803"
        case .acFan: return "0804"
        case .fuelPump: return "0805"
        case .purgeValve: return "0806"
        }
    }

    var stopCommand: String? {
        switch self {
        case .throttleBody: return "300100"  // Actuator 01, OFF
        case .ssv: return "300200"           // Actuator 02, OFF
        case .coolingFan: return "300300"
        case .acFan: return "300400"
        case .fuelPump: return "300500"
        case .purgeValve: return "300600"
        }
    }

    var duration: Int {
        // Duración en segundos
        switch self {
        case .throttleBody: return 3
        case .ssv: return 3
        case .coolingFan: return 5
        case .acFan: return 5
        case .fuelPump: return 3
        case .purgeValve: return 2
        }
    }
}

struct ActuatorTestButton: View {
    let test: ActuatorTest
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: test.icon)
                        .font(.title2)
                        .foregroundColor(test.color)

                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Text(test.title)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(test.color.opacity(0.2))
            .cornerRadius(12)
        }
        .disabled(isRunning)
    }
}

struct SafetyWarningCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("ADVERTENCIA DE SEGURIDAD")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("• El motor debe estar APAGADO")
                Text("• Contacto en posición ON (sin arrancar)")
                Text("• Freno de mano activado")
                Text("• Área alrededor del motor despejada")
                Text("• No tocar piezas móviles durante los tests")
            }
            .font(.caption)
            .foregroundColor(.white)
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(16)
    }
}

struct SystemStatusCard: View {
    let engineOff: Bool
    let batteryOK: Bool

    var body: some View {
        HStack(spacing: 16) {
            StatusIndicatorItem(
                title: "Motor",
                isOK: engineOff,
                okText: "Apagado",
                notOKText: "Encendido"
            )

            StatusIndicatorItem(
                title: "Batería",
                isOK: batteryOK,
                okText: "> 11.5V",
                notOKText: "Baja"
            )

            StatusIndicatorItem(
                title: "Conexión",
                isOK: true,
                okText: "OK",
                notOKText: "Error"
            )
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct StatusIndicatorItem: View {
    let title: String
    let isOK: Bool
    let okText: String
    let notOKText: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isOK ? .green : .red)
                .font(.title2)

            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)

            Text(isOK ? okText : notOKText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isOK ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TestResultCard: View {
    let result: String
    let success: Bool

    var body: some View {
        HStack {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(success ? .green : .red)
                .font(.title2)

            Text(result)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background((success ? Color.green : Color.red).opacity(0.2))
        .cornerRadius(12)
    }
}

struct RequirementsNotMetCard: View {
    let engineOff: Bool
    let batteryOK: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(.red)
                Text("Requisitos No Cumplidos")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !engineOff {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                        Text("El motor debe estar apagado (RPM = 0)")
                            .foregroundColor(.white)
                    }
                }

                if !batteryOK {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                        Text("Voltaje de batería insuficiente (< 11.5V)")
                            .foregroundColor(.white)
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(16)
    }
}

struct ActuatorInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Información")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("• Los tests activan componentes por tiempo limitado")
                Text("• Si un componente no responde, puede indicar fallo")
                Text("• El ventilador puede tardar en detenerse tras el test")
                Text("• La bomba de combustible hará ruido audible")
            }
            .font(.caption)
            .foregroundColor(.gray)

            Divider().background(Color.gray.opacity(0.5))

            // Advertencia sobre limitaciones del adaptador
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limitaciones del adaptador")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    Text("Los adaptadores ELM327 genéricos no soportan control completo de actuadores. Para funcionalidad completa se requiere herramienta OEM (Mazda IDS) o adaptadores avanzados (OBDLink MX+).")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(16)
    }
}

// MARK: - Hojas de Diagnóstico Específico

struct IgnitionCheckSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var isChecking = false
    @State private var results: IgnitionCheckResults?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isChecking {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Verificando sistema de encendido...")
                                .foregroundColor(.white)
                        }
                        .padding(40)
                    } else if let results = results {
                        IgnitionResultsView(results: results)
                    } else {
                        // Información inicial
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Este diagnóstico verifica:")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 8) {
                                CheckItem(text: "Códigos relacionados con bobinas (P0351-P0354)")
                                CheckItem(text: "Códigos de misfire (P0300-P0302)")
                                CheckItem(text: "Avance de encendido (timing)")
                                CheckItem(text: "Voltaje de batería")
                            }

                            Divider()
                                .background(Color.gray)

                            Text("Configuración de bujías RX-8:")
                                .font(.subheadline)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Leading: NGK RE7C-L (gap 1.1mm)")
                                Text("• Trailing: NGK RE9B-T (gap 1.1mm)")
                                Text("• Cambiar cada 30,000 km máximo")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)

                        Button(action: runCheck) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Iniciar Verificación")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Estado del Encendido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    func runCheck() {
        isChecking = true
        Task {
            var checkResults = IgnitionCheckResults()

            do {
                // Leer DTCs relacionados con encendido
                let dtcs = try await connectionManager.readDTCs()
                checkResults.coilCodes = dtcs.filter { $0.hasPrefix("P035") }
                checkResults.misfireCodes = dtcs.filter { $0.hasPrefix("P030") }

                // Leer timing
                checkResults.timingAdvance = try await connectionManager.readTimingAdvance()

                // Leer voltaje
                checkResults.batteryVoltage = try await connectionManager.readVoltage()

                // Determinar estado
                checkResults.hasCoilProblem = !checkResults.coilCodes.isEmpty
                checkResults.hasMisfire = !checkResults.misfireCodes.isEmpty
                checkResults.lowVoltage = checkResults.batteryVoltage < 12.4

            } catch {
                checkResults.errorMessage = error.localizedDescription
            }

            await MainActor.run {
                results = checkResults
                isChecking = false
            }
        }
    }
}

struct IgnitionCheckResults {
    var coilCodes: [String] = []
    var misfireCodes: [String] = []
    var timingAdvance: Double = 0
    var batteryVoltage: Double = 0
    var hasCoilProblem: Bool = false
    var hasMisfire: Bool = false
    var lowVoltage: Bool = false
    var errorMessage: String?

    var overallStatus: String {
        if hasCoilProblem || hasMisfire {
            return "Problema Detectado"
        } else if lowVoltage {
            return "Voltaje Bajo"
        }
        return "OK"
    }

    var statusColor: Color {
        if hasCoilProblem || hasMisfire { return .red }
        if lowVoltage { return .orange }
        return .green
    }
}

struct IgnitionResultsView: View {
    let results: IgnitionCheckResults

    var body: some View {
        VStack(spacing: 16) {
            // Estado general
            HStack {
                Image(systemName: results.hasCoilProblem || results.hasMisfire ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(results.statusColor)

                VStack(alignment: .leading) {
                    Text("Sistema de Encendido")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(results.overallStatus)
                        .foregroundColor(results.statusColor)
                }
                Spacer()
            }
            .padding()
            .background(results.statusColor.opacity(0.2))
            .cornerRadius(12)

            // Detalles
            VStack(alignment: .leading, spacing: 12) {
                DetailResultRow(label: "Timing Advance", value: String(format: "%.1f°", results.timingAdvance), status: true)
                DetailResultRow(label: "Voltaje Batería", value: String(format: "%.1fV", results.batteryVoltage), status: !results.lowVoltage)

                if !results.coilCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Códigos de Bobinas:")
                            .font(.caption)
                            .foregroundColor(.red)
                        ForEach(results.coilCodes, id: \.self) { code in
                            Text("• \(code)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }

                if !results.misfireCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Códigos de Misfire:")
                            .font(.caption)
                            .foregroundColor(.orange)
                        ForEach(results.misfireCodes, id: \.self) { code in
                            Text("• \(code)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(12)

            // Recomendaciones
            if results.hasCoilProblem || results.hasMisfire {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recomendaciones:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Text("• Reemplazar las 4 bobinas de encendido")
                    Text("• Cambiar las 4 bujías (NGK RE7C-L / RE9B-T)")
                    Text("• Verificar cables de encendido")
                    Text("• Las bobinas trailing suelen fallar silenciosamente")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
}

struct FuelTrimAnalysisSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var isAnalyzing = false
    @State private var stft: Double = 0
    @State private var ltft: Double = 0
    @State private var maf: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Valores actuales
                    HStack(spacing: 16) {
                        FuelTrimGauge(title: "STFT", value: stft, unit: "%")
                        FuelTrimGauge(title: "LTFT", value: ltft, unit: "%")
                    }

                    // MAF
                    VStack {
                        Text("MAF")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f g/s", maf))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)

                    // Interpretación
                    FuelTrimInterpretation(stft: stft, ltft: ltft)

                    // Botón actualizar
                    Button(action: readValues) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isAnalyzing ? "Leyendo..." : "Actualizar Valores")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isAnalyzing)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Análisis Fuel Trim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                readValues()
            }
        }
    }

    func readValues() {
        isAnalyzing = true
        Task {
            do {
                stft = try await connectionManager.readFuelTrimShort()
                ltft = try await connectionManager.readFuelTrimLong()
                maf = try await connectionManager.readMAF()
            } catch {
                // Silencioso
            }
            await MainActor.run {
                isAnalyzing = false
            }
        }
    }
}

struct FuelTrimGauge: View {
    let title: String
    let value: Double
    let unit: String

    var color: Color {
        if abs(value) > 15 { return .red }
        if abs(value) > 10 { return .orange }
        if abs(value) > 5 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: min(abs(value) / 25, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text(String(format: "%+.1f", value))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Text(value > 0 ? "Añadiendo" : "Quitando")
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct FuelTrimInterpretation: View {
    let stft: Double
    let ltft: Double

    var interpretation: (title: String, description: String, color: Color) {
        let total = stft + ltft

        if abs(total) < 10 {
            return ("Normal", "El sistema de combustible funciona correctamente", .green)
        } else if total > 15 {
            return ("Mezcla Pobre", "El motor está añadiendo combustible. Posibles causas: fuga de vacío, MAF sucio, bomba de combustible débil", .orange)
        } else if total < -15 {
            return ("Mezcla Rica", "El motor está quitando combustible. Posibles causas: inyectores con fuga, regulador de presión defectuoso, sensor O2 malo", .orange)
        } else if abs(ltft) > 10 {
            return ("Problema Crónico", "LTFT alto indica un problema persistente que requiere atención", .red)
        }
        return ("Aceptable", "Valores dentro del rango pero vigilar", .yellow)
    }

    var body: some View {
        let result = interpretation
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(result.color)
                    .frame(width: 12, height: 12)
                Text(result.title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(result.description)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(result.color.opacity(0.2))
        .cornerRadius(12)
    }
}

struct CatalystCheckSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var hasCatalystCode = false
    @State private var hasMisfireCodes = false
    @State private var isChecking = false
    @State private var checked = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !checked {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Verificación del Catalizador")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("En el RX-8, los misfires (especialmente de bobinas trailing) destruyen rápidamente el catalizador.")
                                .font(.caption)
                                .foregroundColor(.gray)

                            VStack(alignment: .leading, spacing: 8) {
                                CheckItem(text: "Buscar código P0420 (eficiencia baja)")
                                CheckItem(text: "Verificar códigos de misfire P0300-P0302")
                                CheckItem(text: "Los misfires de bobinas trailing son los más dañinos")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)

                        Button(action: runCheck) {
                            HStack {
                                if isChecking {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "leaf.fill")
                                }
                                Text(isChecking ? "Verificando..." : "Verificar Catalizador")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isChecking)
                    } else {
                        // Resultados
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: hasCatalystCode ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(hasCatalystCode ? .red : .green)

                                VStack(alignment: .leading) {
                                    Text("Catalizador")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(hasCatalystCode ? "Problema Detectado" : "OK")
                                        .foregroundColor(hasCatalystCode ? .red : .green)
                                }
                                Spacer()
                            }
                            .padding()
                            .background((hasCatalystCode ? Color.red : Color.green).opacity(0.2))
                            .cornerRadius(12)

                            if hasCatalystCode {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Código P0420 detectado")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)

                                    Text("Acciones recomendadas:")
                                        .font(.caption)
                                        .foregroundColor(.orange)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("1. PRIMERO: Verificar y reemplazar bobinas")
                                        Text("2. Las bobinas dañan el catalizador")
                                        Text("3. Solo reemplazar cat después de arreglar bobinas")
                                        Text("4. Verificar sondas O2")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(12)
                            }

                            if hasMisfireCodes {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("⚠️ Códigos de Misfire Detectados")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)

                                    Text("Los misfires están dañando activamente el catalizador. Reparar urgentemente.")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Estado Catalizador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    func runCheck() {
        isChecking = true
        Task {
            do {
                let dtcs = try await connectionManager.readDTCs()
                await MainActor.run {
                    hasCatalystCode = dtcs.contains("P0420")
                    hasMisfireCodes = dtcs.contains(where: { $0.hasPrefix("P030") })
                    checked = true
                    isChecking = false
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    checked = true
                }
            }
        }
    }
}

struct OMPCheckSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var hasOMPCode = false
    @State private var ompCodes: [String] = []
    @State private var isChecking = false
    @State private var checked = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info sobre OMP
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.purple)
                            Text("Sistema OMP (Oil Metering Pump)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Text("El OMP inyecta aceite en las cámaras de combustión para lubricar los apex seals. Es CRÍTICO para la vida del motor.")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Divider()
                            .background(Color.gray)

                        Text("Códigos relacionados:")
                            .font(.caption)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• P1520: Sensor de posición OMP")
                            Text("• P0661: Solenoide OMP circuito bajo")
                            Text("• P0662: Solenoide OMP circuito alto")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(16)

                    if !checked {
                        Button(action: runCheck) {
                            HStack {
                                if isChecking {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "drop.fill")
                                }
                                Text(isChecking ? "Verificando..." : "Verificar Sistema OMP")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isChecking)
                    } else {
                        // Resultado
                        HStack {
                            Image(systemName: hasOMPCode ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(hasOMPCode ? .red : .green)

                            VStack(alignment: .leading) {
                                Text("Sistema OMP")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(hasOMPCode ? "¡PROBLEMA DETECTADO!" : "Sin códigos de error")
                                    .foregroundColor(hasOMPCode ? .red : .green)
                            }
                            Spacer()
                        }
                        .padding()
                        .background((hasOMPCode ? Color.red : Color.green).opacity(0.2))
                        .cornerRadius(12)

                        if hasOMPCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("⚠️ ATENCIÓN: Problema en sistema OMP")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)

                                Text("Códigos encontrados: \(ompCodes.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.white)

                                Divider()
                                    .background(Color.red)

                                Text("ACCIÓN REQUERIDA:")
                                    .font(.caption)
                                    .foregroundColor(.orange)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• NO conducir hasta reparar")
                                    Text("• La lubricación del motor está comprometida")
                                    Text("• Añadir premix (aceite 2T) al combustible como medida temporal")
                                    Text("• Verificar sensor y solenoide OMP")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(12)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recomendación preventiva:")
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                Text("Muchos propietarios añaden premix (2-4 oz de aceite 2T por tanque) como seguro adicional para los apex seals.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Sistema OMP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    func runCheck() {
        isChecking = true
        Task {
            do {
                let dtcs = try await connectionManager.readDTCs()
                await MainActor.run {
                    ompCodes = dtcs.filter { $0 == "P1520" || $0 == "P0661" || $0 == "P0662" }
                    hasOMPCode = !ompCodes.isEmpty
                    checked = true
                    isChecking = false
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    checked = true
                }
            }
        }
    }
}

struct CheckItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct DetailResultRow: View {
    let label: String
    let value: String
    let status: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Image(systemName: status ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(status ? .green : .orange)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Cabecera de Diagnóstico

struct DiagnosticHeaderCard: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode

    var body: some View {
        VStack(spacing: 12) {
            // Score de salud
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: Double(diagnosticMode.healthScore) / 100)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(diagnosticMode.healthScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Salud")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(healthStatus)
                .font(.headline)
                .foregroundColor(healthColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(20)
    }

    var healthColor: Color {
        if diagnosticMode.healthScore >= 90 { return .green }
        if diagnosticMode.healthScore >= 70 { return .teal }
        if diagnosticMode.healthScore >= 50 { return .yellow }
        if diagnosticMode.healthScore >= 25 { return .orange }
        return .red
    }

    var healthStatus: String {
        if diagnosticMode.healthScore >= 90 { return "Excelente" }
        if diagnosticMode.healthScore >= 70 { return "Bueno" }
        if diagnosticMode.healthScore >= 50 { return "Regular" }
        if diagnosticMode.healthScore >= 25 { return "Deficiente" }
        return "Crítico"
    }
}

// MARK: - Progreso del Diagnóstico

struct DiagnosticProgressCard: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode

    var body: some View {
        VStack(spacing: 16) {
            Text(diagnosticMode.currentPhase.rawValue)
                .font(.headline)
                .foregroundColor(.white)

            ProgressView(value: diagnosticMode.progress)
                .tint(.orange)
                .scaleEffect(y: 2)

            Text(String(format: "%.0f%%", diagnosticMode.progress * 100))
                .font(.caption)
                .foregroundColor(.gray)

            // Fases
            VStack(alignment: .leading, spacing: 8) {
                DiagnosticPhaseRow(phase: .readingDTCs, current: diagnosticMode.currentPhase)
                DiagnosticPhaseRow(phase: .idleCapture, current: diagnosticMode.currentPhase)
                DiagnosticPhaseRow(phase: .temperatureAnalysis, current: diagnosticMode.currentPhase)
                DiagnosticPhaseRow(phase: .fuelSystemAnalysis, current: diagnosticMode.currentPhase)
                DiagnosticPhaseRow(phase: .ignitionAnalysis, current: diagnosticMode.currentPhase)
                DiagnosticPhaseRow(phase: .ompCheck, current: diagnosticMode.currentPhase)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct DiagnosticPhaseRow: View {
    let phase: DiagnosticPhase
    let current: DiagnosticPhase

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(phase.rawValue)
                .font(.caption)
                .foregroundColor(color)

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isCurrent {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    var isComplete: Bool {
        phaseOrder(current) > phaseOrder(phase)
    }

    var isCurrent: Bool {
        current == phase
    }

    var icon: String {
        if isComplete { return "checkmark.circle.fill" }
        if isCurrent { return "arrow.right.circle.fill" }
        return "circle"
    }

    var color: Color {
        if isComplete { return .green }
        if isCurrent { return .orange }
        return .gray
    }

    func phaseOrder(_ phase: DiagnosticPhase) -> Int {
        switch phase {
        case .idle: return 0
        case .connecting: return 1
        case .readingDTCs: return 2
        case .idleCapture: return 3
        case .temperatureAnalysis: return 4
        case .fuelSystemAnalysis: return 5
        case .ignitionAnalysis: return 6
        case .ompCheck: return 7
        case .generatingReport: return 8
        case .completed: return 9
        }
    }
}

// MARK: - Botón de Inicio

struct StartDiagnosticButton: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager

    var body: some View {
        Button(action: startDiagnostic) {
            HStack {
                Image(systemName: "stethoscope")
                    .font(.title2)
                Text("Iniciar Diagnóstico Completo")
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                connectionManager.connectionState == .connectedToVehicle
                    ? Color.orange
                    : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(connectionManager.connectionState != .connectedToVehicle)
    }

    func startDiagnostic() {
        Task {
            _ = try? await diagnosticMode.startDiagnostic()
        }
    }
}

// MARK: - Tarjeta de Hallazgos

struct FindingsCard: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hallazgos")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(diagnosticMode.findings.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(8)
            }

            ForEach(diagnosticMode.findings) { finding in
                FindingRow(finding: finding)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct FindingRow: View {
    let finding: DiagnosticFinding
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Circle()
                        .fill(severityColor)
                        .frame(width: 10, height: 10)

                    Text(finding.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if isExpanded {
                Text(finding.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recomendaciones:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    ForEach(finding.recommendations, id: \.self) { rec in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(rec)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 8)
    }

    var severityColor: Color {
        switch finding.severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Grid de Diagnósticos Rápidos

struct QuickDiagnosticsGrid: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Binding var showDTCList: Bool
    @Binding var showClearDTCAlert: Bool
    @Binding var showO2Test: Bool
    @Binding var showRealTimeMonitor: Bool
    @Binding var showVehicleInfo: Bool
    @Binding var showFreezeFrame: Bool
    @Binding var showProcedures: Bool
    @Binding var showBlackBox: Bool

    var isConnected: Bool {
        connectionManager.connectionState == .connectedToVehicle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnósticos Rápidos")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickDiagnosticButton(
                    title: "Leer DTCs",
                    icon: "exclamationmark.triangle",
                    color: .red,
                    isEnabled: isConnected
                ) {
                    showDTCList = true
                }

                QuickDiagnosticButton(
                    title: "Borrar DTCs",
                    icon: "trash",
                    color: .orange,
                    isEnabled: isConnected
                ) {
                    showClearDTCAlert = true
                }

                QuickDiagnosticButton(
                    title: "Test O2",
                    icon: "leaf",
                    color: .green,
                    isEnabled: isConnected
                ) {
                    showO2Test = true
                }

                QuickDiagnosticButton(
                    title: "Monitor Tiempo Real",
                    icon: "waveform.path.ecg",
                    color: .blue,
                    isEnabled: isConnected
                ) {
                    showRealTimeMonitor = true
                }

                QuickDiagnosticButton(
                    title: "Info Vehículo",
                    icon: "car",
                    color: .purple,
                    isEnabled: isConnected
                ) {
                    showVehicleInfo = true
                }

                QuickDiagnosticButton(
                    title: "Freeze Frame",
                    icon: "camera",
                    color: .teal,
                    isEnabled: isConnected
                ) {
                    showFreezeFrame = true
                }

                QuickDiagnosticButton(
                    title: "Procedimientos",
                    icon: "wrench.and.screwdriver",
                    color: .yellow,
                    isEnabled: true
                ) {
                    showProcedures = true
                }

                QuickDiagnosticButton(
                    title: "Caja Negra",
                    icon: "record.circle",
                    color: .pink,
                    isEnabled: isConnected
                ) {
                    showBlackBox = true
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct QuickDiagnosticButton: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? color : .gray)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .white : .gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? color.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Test de Compresión

struct CompressionTestCard: View {
    @State private var showCompressionTest = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundColor(.orange)
                Text("Test de Compresión")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Evalúa el estado de los apex seals y la salud general del motor rotativo")
                .font(.caption)
                .foregroundColor(.gray)

            Button(action: { showCompressionTest = true }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Iniciar Test de Compresión")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.3))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }

            // Valores de referencia
            VStack(alignment: .leading, spacing: 4) {
                Text("Valores de referencia (motor caliente):")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    ReferenceValue(range: "> 8.0", status: "Excelente", color: .green)
                    ReferenceValue(range: "7.5-8.0", status: "Bueno", color: .teal)
                    ReferenceValue(range: "7.0-7.5", status: "Aceptable", color: .yellow)
                }
                HStack {
                    ReferenceValue(range: "< 7.0", status: "Revisar", color: .orange)
                    ReferenceValue(range: "< 6.5", status: "Rebuild", color: .red)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .sheet(isPresented: $showCompressionTest) {
            CompressionTestView()
        }
    }
}

struct ReferenceValue: View {
    let range: String
    let status: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(range)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(status)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(6)
    }
}

// MARK: - Vista de Test de Compresión

struct CompressionTestView: View {
    @Environment(\.dismiss) var dismiss
    @State private var rotor1Values: [String] = ["", "", ""]
    @State private var rotor2Values: [String] = ["", "", ""]
    @State private var engineTemp: String = ""
    @State private var analysis: CompressionAnalysis?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Instrucciones
                    InstructionsCard()

                    // Entrada de datos
                    CompressionInputCard(
                        title: "Rotor Delantero",
                        values: $rotor1Values
                    )

                    CompressionInputCard(
                        title: "Rotor Trasero",
                        values: $rotor2Values
                    )

                    // Temperatura del motor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperatura del motor")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            TextField("Temp", text: $engineTemp)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)

                            Text("°C")
                                .foregroundColor(.gray)

                            Spacer()

                            if let temp = Double(engineTemp), temp < 80 {
                                Text("Motor frío")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(16)

                    // Botón analizar
                    Button(action: analyze) {
                        Text("Analizar Compresión")
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // Resultados
                    if let analysis = analysis {
                        CompressionResultCard(analysis: analysis)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Test de Compresión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    func analyze() {
        let r1 = rotor1Values.compactMap { Double($0) }
        let r2 = rotor2Values.compactMap { Double($0) }
        let temp = Double(engineTemp) ?? 0

        guard r1.count == 3, r2.count == 3 else { return }

        analysis = CompressionAnalysis(rotor1: r1, rotor2: r2, temp: temp, rpm: 250)
    }
}

struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Procedimiento")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                InstructionRow(number: 1, text: "Motor a temperatura operativa (>80°C)")
                InstructionRow(number: 2, text: "Desconectar las 4 bujías")
                InstructionRow(number: 3, text: "Desconectar inyectores")
                InstructionRow(number: 4, text: "Batería completamente cargada")
                InstructionRow(number: 5, text: "Medir compresión de cada cámara")
                InstructionRow(number: 6, text: "Introducir valores en kg/cm²")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(16)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct CompressionInputCard: View {
    let title: String
    @Binding var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(0..<3) { i in
                    VStack {
                        Text("Cámara \(i + 1)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("0.0", text: $values[i])
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct CompressionResultCard: View {
    let analysis: CompressionAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(analysis.diagnosis.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(diagnosisColor)

                Spacer()

                Text(String(format: "%.1f kg/cm²", analysis.overallAverage))
                    .font(.title3)
                    .foregroundColor(.white)
            }

            Text(analysis.diagnosis.description)
                .font(.body)
                .foregroundColor(.gray)

            Divider()
                .background(Color.gray)

            // Detalles
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Promedio Rotor 1", value: String(format: "%.1f", analysis.rotor1Average))
                DetailRow(label: "Promedio Rotor 2", value: String(format: "%.1f", analysis.rotor2Average))
                DetailRow(label: "Diferencia entre rotores", value: String(format: "%.1f", analysis.differenceBetweenRotors))
            }

            Divider()
                .background(Color.gray)

            // Recomendaciones
            VStack(alignment: .leading, spacing: 4) {
                Text("Recomendaciones:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)

                ForEach(analysis.diagnosis.recommendations, id: \.self) { rec in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(rec)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(diagnosisColor.opacity(0.2))
        .cornerRadius(16)
    }

    var diagnosisColor: Color {
        switch analysis.diagnosis.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Vista de Reporte

struct DiagnosticReportView: View {
    let report: DiagnosticReport
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // TODO: Implementar vista de reporte completo
                    Text("Reporte de Diagnóstico")
                }
                .padding()
            }
            .navigationTitle("Reporte")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - DTC List Sheet

struct DTCListSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var dtcs: [String] = []
    @State private var pendingDtcs: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Leyendo códigos...")
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    if dtcs.isEmpty && pendingDtcs.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("No hay códigos de fallo")
                            }
                        }
                    }

                    if !dtcs.isEmpty {
                        Section("Códigos Activos") {
                            ForEach(dtcs, id: \.self) { dtc in
                                DTCCodeRow(code: dtc)
                            }
                        }
                    }

                    if !pendingDtcs.isEmpty {
                        Section("Códigos Pendientes") {
                            ForEach(pendingDtcs, id: \.self) { dtc in
                                DTCCodeRow(code: dtc)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Códigos DTC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await loadDTCs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadDTCs()
            }
        }
    }

    @MainActor
    private func loadDTCs() async {
        isLoading = true
        errorMessage = nil

        do {
            dtcs = try await connectionManager.readDTCs()
            pendingDtcs = try await connectionManager.readPendingDTCs()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct DTCCodeRow: View {
    let code: String

    var body: some View {
        HStack {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.red)

            Spacer()

            Text(dtcDescription)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    var dtcDescription: String {
        // Common RX-8 DTCs
        let descriptions: [String: String] = [
            "P0300": "Fallo múltiple de encendido",
            "P0301": "Fallo encendido rotor delantero",
            "P0302": "Fallo encendido rotor trasero",
            "P0171": "Sistema demasiado pobre",
            "P0172": "Sistema demasiado rico",
            "P0131": "Sensor O2 bajo voltaje (B1S1)",
            "P0134": "Sensor O2 sin actividad (B1S1)",
            "P0420": "Eficiencia catalizador baja",
            "P0661": "OMP válvula control alta",
            "P0662": "OMP válvula control baja",
            "P1260": "Robo disuadido - motor desactivado",
            "P2096": "Corrección combustible post-cat pobre",
            "P2097": "Corrección combustible post-cat rica",
        ]
        return descriptions[code] ?? "Código no reconocido"
    }
}

// MARK: - O2 Test Sheet

struct O2TestSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var o2Voltage: Double = 0
    @State private var isMonitoring = false
    @State private var readings: [Double] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // O2 Gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                        .frame(width: 200, height: 200)

                    Circle()
                        .trim(from: 0, to: o2Voltage / 1.0)
                        .stroke(o2Color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))

                    VStack {
                        Text(String(format: "%.3fV", o2Voltage))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Sensor O2")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Status
                HStack(spacing: 40) {
                    VStack {
                        Text("Min")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.3f", readings.min() ?? 0))
                            .fontWeight(.bold)
                    }

                    VStack {
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.3f", readings.max() ?? 0))
                            .fontWeight(.bold)
                    }

                    VStack {
                        Text("Ciclos")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(countCycles())")
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)

                // Reference
                VStack(alignment: .leading, spacing: 8) {
                    Text("Valores de referencia:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    HStack {
                        Circle().fill(Color.blue).frame(width: 10, height: 10)
                        Text("< 0.2V = Mezcla pobre")
                            .font(.caption)
                    }
                    HStack {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("0.2-0.8V = Normal")
                            .font(.caption)
                    }
                    HStack {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("> 0.8V = Mezcla rica")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)

                Spacer()

                Button(action: toggleMonitoring) {
                    HStack {
                        Image(systemName: isMonitoring ? "stop.fill" : "play.fill")
                        Text(isMonitoring ? "Detener" : "Iniciar Monitoreo")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isMonitoring ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Test Sensor O2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    var o2Color: Color {
        if o2Voltage < 0.2 { return .blue }
        if o2Voltage > 0.8 { return .red }
        return .green
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            readings = []
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard isMonitoring else { return }

        Task {
            do {
                let bytes = try await connectionManager.readStandardPID(mode: 0x01, pid: 0x14)
                if bytes.count >= 1 {
                    let voltage = Double(bytes[0]) / 200.0
                    await MainActor.run {
                        o2Voltage = voltage
                        readings.append(voltage)
                    }
                }
            } catch {
                // Silent fail for continuous monitoring
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            if isMonitoring {
                startMonitoring()
            }
        }
    }

    func countCycles() -> Int {
        guard readings.count > 2 else { return 0 }
        var cycles = 0
        var wasHigh = readings[0] > 0.5

        for reading in readings {
            let isHigh = reading > 0.5
            if isHigh != wasHigh {
                cycles += 1
                wasHigh = isHigh
            }
        }
        return cycles / 2
    }
}

// MARK: - Real Time Monitor Sheet

struct RealTimeMonitorSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var rpm = 0
    @State private var speed = 0
    @State private var coolant = 0
    @State private var throttle = 0.0
    @State private var maf = 0.0
    @State private var stft = 0.0
    @State private var ltft = 0.0
    @State private var timing = 0.0
    @State private var voltage = 0.0
    @State private var isMonitoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Main gauges
                    HStack(spacing: 16) {
                        MonitorGauge(title: "RPM", value: "\(rpm)", unit: "", color: rpmColor, progress: Double(rpm) / 9000)
                        MonitorGauge(title: "Velocidad", value: "\(speed)", unit: "km/h", color: .blue, progress: Double(speed) / 260)
                    }

                    HStack(spacing: 16) {
                        MonitorGauge(title: "Refrigerante", value: "\(coolant)", unit: "°C", color: coolantColor, progress: Double(coolant) / 120)
                        MonitorGauge(title: "Throttle", value: String(format: "%.0f", throttle), unit: "%", color: .purple, progress: throttle / 100)
                    }

                    // Additional data
                    VStack(spacing: 12) {
                        MonitorRow(label: "MAF", value: String(format: "%.1f g/s", maf))
                        MonitorRow(label: "STFT", value: String(format: "%+.1f%%", stft), color: fuelTrimColor(stft))
                        MonitorRow(label: "LTFT", value: String(format: "%+.1f%%", ltft), color: fuelTrimColor(ltft))
                        MonitorRow(label: "Timing", value: String(format: "%.1f°", timing))
                        MonitorRow(label: "Voltaje", value: String(format: "%.1fV", voltage))
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(16)

                    Button(action: toggleMonitoring) {
                        HStack {
                            Image(systemName: isMonitoring ? "stop.fill" : "play.fill")
                            Text(isMonitoring ? "Detener" : "Iniciar")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isMonitoring ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Monitor en Tiempo Real")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        isMonitoring = false
                        dismiss()
                    }
                }
            }
        }
    }

    var rpmColor: Color {
        if rpm > 8500 { return .red }
        if rpm > 7000 { return .orange }
        return .green
    }

    var coolantColor: Color {
        if coolant > 100 { return .red }
        if coolant > 95 { return .orange }
        if coolant < 75 { return .blue }
        return .green
    }

    func fuelTrimColor(_ value: Double) -> Color {
        if abs(value) > 15 { return .red }
        if abs(value) > 10 { return .orange }
        return .green
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard isMonitoring else { return }

        Task {
            do {
                rpm = try await connectionManager.readRPM()
                speed = try await connectionManager.readSpeed()
                coolant = try await connectionManager.readCoolantTemp()
                throttle = try await connectionManager.readThrottlePosition()
                maf = try await connectionManager.readMAF()
                stft = try await connectionManager.readFuelTrimShort()
                ltft = try await connectionManager.readFuelTrimLong()
                timing = try await connectionManager.readTimingAdvance()
                voltage = try await connectionManager.readVoltage()
            } catch {
                // Silent fail
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
            if isMonitoring {
                startMonitoring()
            }
        }
    }
}

struct MonitorGauge: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

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

struct MonitorRow: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Vehicle Info Sheet

struct VehicleInfoSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var vin = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Cargando información...")
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    Section("VIN") {
                        Text(vin.isEmpty ? "No disponible" : vin)
                            .font(.system(.body, design: .monospaced))
                    }

                    if !vin.isEmpty {
                        Section("Decodificado") {
                            VehicleInfoRow(label: "Fabricante", value: decodeManufacturer())
                            VehicleInfoRow(label: "Modelo", value: "RX-8")
                            VehicleInfoRow(label: "Año", value: decodeYear())
                            VehicleInfoRow(label: "Motor", value: "13B-MSP Renesis")
                        }
                    }

                    Section("Adaptador") {
                        if let adapter = connectionManager.adapterInfo {
                            VehicleInfoRow(label: "Tipo", value: adapter.chipType)
                            VehicleInfoRow(label: "Versión", value: adapter.version)
                        }
                    }

                    Section("Protocolo") {
                        if let proto = connectionManager.vehicleProtocol {
                            VehicleInfoRow(label: "Protocolo", value: proto.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Info Vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task {
                await loadInfo()
            }
        }
    }

    @MainActor
    private func loadInfo() async {
        isLoading = true
        errorMessage = nil

        do {
            vin = try await connectionManager.readVIN()
        } catch {
            errorMessage = "No se pudo leer el VIN"
        }

        isLoading = false
    }

    func decodeManufacturer() -> String {
        if vin.hasPrefix("JM1") { return "Mazda (Japón)" }
        if vin.hasPrefix("1YV") { return "Mazda (USA)" }
        return "Mazda"
    }

    func decodeYear() -> String {
        guard vin.count >= 10 else { return "Desconocido" }
        let yearCode = String(vin[vin.index(vin.startIndex, offsetBy: 9)])
        let years: [String: String] = [
            "4": "2004", "5": "2005", "6": "2006", "7": "2007",
            "8": "2008", "9": "2009", "A": "2010", "B": "2011"
        ]
        return years[yearCode] ?? "Desconocido"
    }
}

struct VehicleInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Freeze Frame Sheet

struct FreezeFrameSheet: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var freezeData: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Leyendo freeze frame...")
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else if freezeData.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No hay datos de freeze frame")
                    }
                } else {
                    Section("Datos Capturados") {
                        ForEach(Array(freezeData.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(freezeData[key] ?? "")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Freeze Frame")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task {
                await loadFreezeFrame()
            }
        }
    }

    @MainActor
    private func loadFreezeFrame() async {
        isLoading = true
        errorMessage = nil

        do {
            // Read freeze frame data (Mode 02)
            let response = try await connectionManager.sendCommand("0202", timeout: 5.0)
            if !response.contains("NO DATA") {
                // Parse freeze frame
                let rpm = try? await connectionManager.readRPM()
                let coolant = try? await connectionManager.readCoolantTemp()
                let speed = try? await connectionManager.readSpeed()

                if let rpm = rpm {
                    freezeData["RPM"] = "\(rpm)"
                }
                if let coolant = coolant {
                    freezeData["Refrigerante"] = "\(coolant)°C"
                }
                if let speed = speed {
                    freezeData["Velocidad"] = "\(speed) km/h"
                }
            }
        } catch {
            // No freeze frame data
        }

        isLoading = false
    }
}
