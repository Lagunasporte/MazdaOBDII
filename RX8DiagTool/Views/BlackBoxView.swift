import SwiftUI

// MARK: - Black Box View
// Vista de la caja negra con sesiones automáticas y análisis IA

struct BlackBoxView: View {
    @EnvironmentObject var blackBoxRecorder: BlackBoxRecorder
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
                RecordingStatusHeader()

                // Lista de sesiones
                List {
                    if blackBoxRecorder.sessions.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "car.side")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Sin sesiones grabadas")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("La grabación comienza automáticamente cuando el motor arranca")
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

                        Text("El análisis enviará los datos de la sesión a Claude para obtener un diagnóstico experto del motor rotativo")
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

    var body: some View {
        HStack {
            // Indicador de grabación
            Circle()
                .fill(blackBoxRecorder.isRecording ? Color.red : Color.gray)
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
            } else {
                Text("Esperando motor...")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
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
                StatItem(title: "Distancia", value: String(format: "%.1f", session.totalDistance), unit: "km")
                StatItem(title: "Vel. Máx", value: String(format: "%.0f", session.maxSpeed), unit: "km/h")
                StatItem(title: "Consumo", value: String(format: "%.1f", session.avgConsumption), unit: "L/100")
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct StatItem: View {
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

#Preview {
    BlackBoxView()
        .environmentObject(BlackBoxRecorder())
}
