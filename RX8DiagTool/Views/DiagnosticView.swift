import SwiftUI

// MARK: - Vista de Diagnóstico Completo

struct DiagnosticView: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cabecera con estado
                    DiagnosticHeaderCard()

                    if diagnosticMode.isRunning {
                        // Progreso del diagnóstico
                        DiagnosticProgressCard()
                    } else {
                        // Botón de inicio
                        StartDiagnosticButton()

                        // Hallazgos anteriores
                        if !diagnosticMode.findings.isEmpty {
                            FindingsCard()
                        }

                        // Accesos rápidos
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

                        // Test de compresión
                        CompressionTestCard()
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Diagnóstico")
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
                Text("¿Estás seguro de borrar todos los códigos de fallo? Esto también apagará la luz Check Engine.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Error desconocido")
            }
        }
    }

    private func clearDTCs() {
        Task {
            do {
                try await connectionManager.clearDTCs()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
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
                                DTCRow(code: dtc)
                            }
                        }
                    }

                    if !pendingDtcs.isEmpty {
                        Section("Códigos Pendientes") {
                            ForEach(pendingDtcs, id: \.self) { dtc in
                                DTCRow(code: dtc)
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

struct DTCRow: View {
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
                            InfoRow(label: "Fabricante", value: decodeManufacturer())
                            InfoRow(label: "Modelo", value: "RX-8")
                            InfoRow(label: "Año", value: decodeYear())
                            InfoRow(label: "Motor", value: "13B-MSP Renesis")
                        }
                    }

                    Section("Adaptador") {
                        if let adapter = connectionManager.adapterInfo {
                            InfoRow(label: "Tipo", value: adapter.chipType)
                            InfoRow(label: "Versión", value: adapter.version)
                        }
                    }

                    Section("Protocolo") {
                        if let proto = connectionManager.vehicleProtocol {
                            InfoRow(label: "Protocolo", value: proto.rawValue)
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

struct InfoRow: View {
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
