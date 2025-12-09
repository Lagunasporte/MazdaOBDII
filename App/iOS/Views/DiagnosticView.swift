import SwiftUI

// MARK: - Vista de Diagnóstico Completo

struct DiagnosticView: View {
    @EnvironmentObject var diagnosticMode: DiagnosticMode
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var showReport = false
    @State private var lastReport: DiagnosticReport?

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
                        QuickDiagnosticsGrid()

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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnósticos Rápidos")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickDiagnosticButton(
                    title: "Leer DTCs",
                    icon: "exclamationmark.triangle",
                    color: .red
                )

                QuickDiagnosticButton(
                    title: "Borrar DTCs",
                    icon: "trash",
                    color: .orange
                )

                QuickDiagnosticButton(
                    title: "Test O2",
                    icon: "leaf",
                    color: .green
                )

                QuickDiagnosticButton(
                    title: "Monitor Tiempo Real",
                    icon: "waveform.path.ecg",
                    color: .blue
                )

                QuickDiagnosticButton(
                    title: "Info Vehículo",
                    icon: "car",
                    color: .purple
                )

                QuickDiagnosticButton(
                    title: "Freeze Frame",
                    icon: "camera",
                    color: .teal
                )
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

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.2))
            .cornerRadius(12)
        }
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
