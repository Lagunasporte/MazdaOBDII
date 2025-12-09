import SwiftUI
import UIKit

// MARK: - Black Box View
// Vista de la caja negra con sesiones automáticas y análisis IA

struct BlackBoxView: View {
    @EnvironmentObject var blackBoxRecorder: BlackBoxRecorder
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var selectedSession: BlackBoxSession?
    @State private var showingAnalysis = false
    @State private var showingAPIKeySheet = false
    @State private var apiKey = ""
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var analysisError: String?

    // API Key guardada en UserDefaults
    @AppStorage("anthropicAPIKey") private var savedAPIKey = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Estado de grabación actual
                RecordingStatusHeader(isConnected: connectionManager.connectionState == .connectedToVehicle)

                // Lista de sesiones
                List {
                    if blackBoxRecorder.sessions.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Sin sesiones grabadas")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("La grabación comienza automáticamente cuando el motor arranca (RPM > 400)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else {
                        Section(header: Text("Sesiones (\(blackBoxRecorder.sessions.count)/\(BlackBoxDatabase.maxSessions))")) {
                            ForEach(blackBoxRecorder.sessions) { session in
                                SessionRowView(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                    }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    blackBoxRecorder.deleteSession(blackBoxRecorder.sessions[index])
                                }
                            }
                        }
                    }

                    // Configuración de API
                    Section(header: Text("Análisis con IA")) {
                        if savedAPIKey.isEmpty {
                            Button(action: { showingAPIKeySheet = true }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.orange)
                                    Text("Configurar API Key de Anthropic")
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API Key configurada")
                                    .foregroundColor(.gray)
                                Spacer()
                                Button("Cambiar") {
                                    showingAPIKeySheet = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }

                        Text("Selecciona una sesión para ver el resumen y enviarla a Claude para análisis experto")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color.black)
            .navigationTitle("Caja Negra")
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(
                    session: session,
                    recorder: blackBoxRecorder,
                    apiKey: savedAPIKey,
                    onDismiss: { selectedSession = nil }
                )
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyConfigSheet(apiKey: $apiKey, savedAPIKey: $savedAPIKey)
            }
            .onAppear {
                blackBoxRecorder.loadSessions()
            }
        }
    }
}

// MARK: - Recording Status Header

struct RecordingStatusHeader: View {
    @EnvironmentObject var blackBoxRecorder: BlackBoxRecorder
    let isConnected: Bool

    var body: some View {
        HStack {
            // Indicador de grabación
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(blackBoxRecorder.isRecording ? 0.5 : 0), lineWidth: 3)
                        .scaleEffect(blackBoxRecorder.isRecording ? 1.5 : 1)
                        .opacity(blackBoxRecorder.isRecording ? 0 : 1)
                        .animation(blackBoxRecorder.isRecording ?
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: blackBoxRecorder.isRecording)
                )

            if blackBoxRecorder.isRecording {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRABANDO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text(formatDuration(blackBoxRecorder.recordingDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(blackBoxRecorder.snapshotCount)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("muestras")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else if isConnected {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conectado")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Text("Esperando motor en marcha...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sin conexión OBD")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Consulta sesiones anteriores abajo")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
    }

    private var statusColor: Color {
        if blackBoxRecorder.isRecording {
            return .red
        } else if isConnected {
            return .green
        } else {
            return .gray
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: BlackBoxSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.dateFormatted)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(session.durationFormatted)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 16) {
                // Distancia
                HStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(String(format: "%.1f km", session.totalDistance))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Max RPM
                HStack(spacing: 4) {
                    Image(systemName: "gauge.high")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(session.maxRPM) rpm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Alertas
                if session.alertCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(session.alertCount)")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                // DTCs
                if session.dtcCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(session.dtcCount) DTC")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                // Indicador de análisis
                if session.analysisSent {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                        .font(.caption)
                }
            }

            // Temperaturas máximas
            HStack(spacing: 12) {
                Text("Temp. máx:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("Refr: \(Int(session.maxCoolantTemp))°C")
                    .font(.caption2)
                    .foregroundColor(session.maxCoolantTemp > 98 ? .orange : .gray)
                Text("Aceite: \(Int(session.maxOilTemp))°C")
                    .font(.caption2)
                    .foregroundColor(session.maxOilTemp > 120 ? .orange : .gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Detail Sheet

struct SessionDetailSheet: View {
    let session: BlackBoxSession
    let recorder: BlackBoxRecorder
    let apiKey: String
    let onDismiss: () -> Void

    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var analysisError: String?
    @State private var showingExport = false
    @State private var noteText = ""
    @State private var showingNoteInput = false
    @State private var isGeneratingPDF = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Resumen
                    SessionSummaryCard(session: session)

                    // Estadísticas
                    SessionStatsCard(session: session)

                    // Alertas
                    let alerts = recorder.getSessionAlerts(session.id)
                    if !alerts.isEmpty {
                        SessionAlertsCard(alerts: alerts)
                    }

                    // DTCs
                    let dtcs = recorder.getSessionDTCs(session.id)
                    if !dtcs.isEmpty {
                        SessionDTCsCard(dtcs: dtcs)
                    }

                    // Notas
                    if let notes = session.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notas")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(12)
                    }

                    // Resultado del análisis
                    if let result = session.analysisResult ?? analysisResult {
                        AnalysisResultCard(result: result)
                    }

                    // Botones de acción
                    VStack(spacing: 12) {
                        // Exportar PDF
                        Button(action: generatePDF) {
                            HStack {
                                if isGeneratingPDF {
                                    ProgressView()
                                        .tint(.orange)
                                } else {
                                    Image(systemName: "doc.fill")
                                }
                                Text(isGeneratingPDF ? "Generando PDF..." : "Exportar Informe PDF")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isGeneratingPDF)

                        // Añadir nota
                        Button(action: { showingNoteInput = true }) {
                            HStack {
                                Image(systemName: "note.text")
                                Text("Añadir Nota")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }

                        // Análisis IA
                        if !apiKey.isEmpty && session.analysisResult == nil && analysisResult == nil {
                            Button(action: performAnalysis) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "brain")
                                    }
                                    Text(isAnalyzing ? "Analizando..." : "Analizar con Claude")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isAnalyzing)
                        }

                        if let error = analysisError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { onDismiss() }
                }
            }
            .alert("Añadir Nota", isPresented: $showingNoteInput) {
                TextField("Nota", text: $noteText)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") {
                    if !noteText.isEmpty {
                        recorder.addNote(session.id, note: noteText)
                        noteText = ""
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func generatePDF() {
        isGeneratingPDF = true

        Task {
            let url = await createPDFReport()

            await MainActor.run {
                pdfURL = url
                isGeneratingPDF = false
                if url != nil {
                    showShareSheet = true
                }
            }
        }
    }

    private func createPDFReport() async -> URL? {
        let pageWidth: CGFloat = 612 // Letter size
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfMetaData = [
            kCGPDFContextCreator: "RX-8 Diagnostic Tool",
            kCGPDFContextAuthor: "Mazda RX-8 OBD",
            kCGPDFContextTitle: "Informe Diagnóstico - \(session.dateFormatted)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin

            // Título
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
            let title = "Informe Diagnóstico Mazda RX-8"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttr)
            yPosition += 35

            // Subtítulo
            let subtitleFont = UIFont.systemFont(ofSize: 14)
            let subtitleAttr: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: UIColor.darkGray]
            let subtitle = "Motor Rotativo 13B-MSP Renesis"
            subtitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttr)
            yPosition += 30

            // Línea separadora
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: yPosition))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor.orange.setStroke()
            path.lineWidth = 2
            path.stroke()
            yPosition += 20

            // Información de la sesión
            let sectionFont = UIFont.boldSystemFont(ofSize: 16)
            let sectionAttr: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.black]
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let bodyAttr: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]

            "Información de la Sesión".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
            yPosition += 25

            let sessionInfo = [
                "Fecha: \(session.dateFormatted)",
                "Duración: \(session.durationFormatted)",
                "Distancia: \(String(format: "%.1f", session.totalDistance)) km",
                "Velocidad máxima: \(String(format: "%.0f", session.maxSpeed)) km/h",
                "Consumo medio: \(String(format: "%.1f", session.avgConsumption)) L/100km"
            ]

            for info in sessionInfo {
                info.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
                yPosition += 18
            }
            yPosition += 15

            // Estadísticas del Motor
            "Estadísticas del Motor".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
            yPosition += 25

            let motorStats = [
                "RPM máximo: \(session.maxRPM)",
                "Temperatura refrigerante máx: \(String(format: "%.0f", session.maxCoolantTemp))°C",
                "Temperatura aceite máx: \(String(format: "%.0f", session.maxOilTemp))°C",
                "Alertas registradas: \(session.alertCount)",
                "Códigos de error (DTC): \(session.dtcCount)"
            ]

            for stat in motorStats {
                stat.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
                yPosition += 18
            }
            yPosition += 15

            // Alertas
            let alerts = recorder.getSessionAlerts(session.id)
            if !alerts.isEmpty {
                "Alertas Registradas (\(alerts.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
                yPosition += 25

                for alert in alerts.prefix(15) {
                    let alertText = "[\(alert.severity)] \(alert.message)"
                    let color: UIColor = alert.severity == "Crítico" ? .red : .orange
                    let alertAttr: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: color]
                    alertText.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: alertAttr)
                    yPosition += 16

                    if yPosition > pageHeight - 100 {
                        context.beginPage()
                        yPosition = margin
                    }
                }
                yPosition += 15
            }

            // DTCs
            let dtcs = recorder.getSessionDTCs(session.id)
            if !dtcs.isEmpty {
                "Códigos de Error (DTC)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
                yPosition += 25

                for dtc in dtcs {
                    let dtcAttr: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.red]
                    "\(dtc.code): \(dtc.description)".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: dtcAttr)
                    yPosition += 18
                }
                yPosition += 15
            }

            // Notas
            if let notes = session.notes, !notes.isEmpty {
                "Notas del Usuario".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
                yPosition += 25
                notes.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttr)
                yPosition += 30
            }

            // Análisis de Claude (si existe)
            if let analysis = session.analysisResult ?? analysisResult {
                if yPosition > pageHeight - 200 {
                    context.beginPage()
                    yPosition = margin
                }

                "Análisis de Inteligencia Artificial".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttr)
                yPosition += 25

                // Dividir el análisis en líneas para que quepa
                let maxWidth = pageWidth - (margin * 2) - 10
                let analysisFont = UIFont.systemFont(ofSize: 11)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping

                let analysisAttr: [NSAttributedString.Key: Any] = [
                    .font: analysisFont,
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphStyle
                ]

                let analysisRect = CGRect(x: margin + 10, y: yPosition, width: maxWidth, height: pageHeight - yPosition - margin)
                let attributedAnalysis = NSAttributedString(string: analysis, attributes: analysisAttr)

                // Calcular altura necesaria
                let boundingRect = attributedAnalysis.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                    context: nil)

                // Si no cabe, crear nueva página
                if boundingRect.height > pageHeight - yPosition - margin {
                    // Dividir el texto en chunks que quepan
                    let lines = analysis.components(separatedBy: "\n")
                    for line in lines {
                        if yPosition > pageHeight - 50 {
                            context.beginPage()
                            yPosition = margin
                        }

                        let lineRect = CGRect(x: margin + 10, y: yPosition, width: maxWidth, height: 200)
                        line.draw(in: lineRect, withAttributes: analysisAttr)

                        let lineHeight = (line as NSString).boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                                          options: .usesLineFragmentOrigin,
                                                                          attributes: analysisAttr,
                                                                          context: nil).height
                        yPosition += lineHeight + 4
                    }
                } else {
                    attributedAnalysis.draw(in: analysisRect)
                }
            }

            // Pie de página en la última página
            let footerFont = UIFont.italicSystemFont(ofSize: 9)
            let footerAttr: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footer = "Generado por RX-8 Diagnostic Tool - \(Date().formatted())"
            footer.draw(at: CGPoint(x: margin, y: pageHeight - 30), withAttributes: footerAttr)
        }

        // Guardar PDF
        let fileName = "RX8_Diagnostico_\(session.dateFormatted.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error guardando PDF: \(error)")
            return nil
        }
    }

    private func performAnalysis() {
        isAnalyzing = true
        analysisError = nil

        Task {
            do {
                let report = recorder.exportSessionForAnalysis(session.id)
                let result = try await sendToAnthropic(prompt: report)

                await MainActor.run {
                    analysisResult = result
                    recorder.saveAnalysisResult(session.id, result: result)
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    private func sendToAnthropic(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "HTTP", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorBody)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String

        return text ?? "No se recibió respuesta"
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: BlackBoxSession

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.dateFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Duración: \(session.durationFormatted)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                if session.analysisSent {
                    HStack {
                        Image(systemName: "brain")
                        Text("Analizado")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
            }

            Divider()
                .background(Color.gray)

            HStack(spacing: 24) {
                BBStatItem(title: "Distancia", value: String(format: "%.1f", session.totalDistance), unit: "km")
                BBStatItem(title: "Vel. Máx", value: String(format: "%.0f", session.maxSpeed), unit: "km/h")
                BBStatItem(title: "Consumo", value: String(format: "%.1f", session.avgConsumption), unit: "L/100")
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct BBStatItem: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Session Stats Card

struct SessionStatsCard: View {
    let session: BlackBoxSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estadísticas del Motor")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(icon: "gauge.high", title: "RPM Máx", value: "\(session.maxRPM)",
                       color: session.maxRPM > 8500 ? .orange : .blue)

                StatBox(icon: "thermometer.high", title: "Refr. Máx",
                       value: "\(Int(session.maxCoolantTemp))°C",
                       color: session.maxCoolantTemp > 98 ? .orange : .green)

                StatBox(icon: "drop.fill", title: "Aceite Máx",
                       value: "\(Int(session.maxOilTemp))°C",
                       color: session.maxOilTemp > 120 ? .orange : .green)

                StatBox(icon: "exclamationmark.triangle", title: "Alertas",
                       value: "\(session.alertCount)",
                       color: session.alertCount > 0 ? .yellow : .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Session Alerts Card

struct SessionAlertsCard: View {
    let alerts: [BlackBoxAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Alertas (\(alerts.count))")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(Array(alerts.prefix(10).enumerated()), id: \.offset) { _, alert in
                HStack {
                    Circle()
                        .fill(alert.severity == "Crítico" ? Color.red : Color.yellow)
                        .frame(width: 8, height: 8)

                    Text(alert.message)
                        .font(.caption)
                        .foregroundColor(.white)

                    Spacer()

                    if let param = alert.parameter {
                        Text("\(param): \(String(format: "%.1f", alert.value))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            if alerts.count > 10 {
                Text("... y \(alerts.count - 10) más")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Session DTCs Card

struct SessionDTCsCard: View {
    let dtcs: [(code: String, description: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text("Códigos de Error (DTC)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(dtcs, id: \.code) { dtc in
                VStack(alignment: .leading, spacing: 4) {
                    Text(dtc.code)
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(dtc.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Analysis Result Card

struct AnalysisResultCard: View {
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("Análisis de Claude")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(result)
                .font(.body)
                .foregroundColor(.gray)
                .lineLimit(nil)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - API Key Config Sheet

struct APIKeyConfigSheet: View {
    @Binding var apiKey: String
    @Binding var savedAPIKey: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("API Key de Anthropic")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Para analizar tus sesiones con inteligencia artificial, necesitas una API key de Anthropic.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                TextField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Link("Obtener API Key en console.anthropic.com",
                     destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)

                Spacer()

                Button(action: {
                    savedAPIKey = apiKey
                    dismiss()
                }) {
                    Text("Guardar")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(apiKey.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(apiKey.isEmpty)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                apiKey = savedAPIKey
            }
        }
    }
}

// MARK: - Share Sheet (UIKit Wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    BlackBoxView()
        .environmentObject(BlackBoxRecorder())
        .environmentObject(OBDConnectionManager())
}
