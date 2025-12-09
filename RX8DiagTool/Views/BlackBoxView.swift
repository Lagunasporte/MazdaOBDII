import SwiftUI

// MARK: - Black Box Recording View

struct BlackBoxView: View {
    @StateObject private var recorder = BlackBoxRecorder()
    @StateObject private var aiService = AIAnalysisService()
    @State private var showingAPIKeySheet = false
    @State private var showingSessionDetail: RecordingSession?
    @State private var showingAnalysisResult: AIAnalysisResult?
    @State private var apiKeyInput = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Recording status
                RecordingStatusView(
                    isRecording: recorder.isRecording,
                    duration: recorder.recordingDuration,
                    snapshotCount: recorder.currentSession?.snapshotCount ?? 0,
                    onStart: { recorder.startRecording() },
                    onStop: {
                        if let session = recorder.stopRecording() {
                            showingSessionDetail = session
                        }
                    },
                    onAddMarker: { recorder.addUserMarker("Marcador del usuario") }
                )

                // Live data preview when recording
                if recorder.isRecording, let snapshot = recorder.lastSnapshot {
                    LiveDataPreview(snapshot: snapshot)
                        .padding()
                }

                // Saved sessions list
                List {
                    Section(header: Text("Sesiones Guardadas")) {
                        if recorder.savedSessions.isEmpty {
                            Text("No hay sesiones guardadas")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(recorder.savedSessions) { session in
                                SessionRow(session: session)
                                    .onTapGesture {
                                        showingSessionDetail = session
                                    }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    recorder.deleteSession(recorder.savedSessions[index])
                                }
                            }
                        }
                    }

                    Section(header: Text("Análisis IA")) {
                        if !aiService.hasAPIKey {
                            Button(action: { showingAPIKeySheet = true }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.orange)
                                    Text("Configurar API Key de Anthropic")
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API Key configurada")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Cambiar") {
                                    showingAPIKeySheet = true
                                }
                                .font(.caption)
                            }
                        }

                        if !aiService.analysisHistory.isEmpty {
                            ForEach(aiService.analysisHistory.prefix(5)) { result in
                                AnalysisHistoryRow(result: result)
                                    .onTapGesture {
                                        showingAnalysisResult = result
                                    }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Caja Negra")
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeySheet(apiKey: $apiKeyInput) { key in
                    aiService.setAPIKey(key)
                    showingAPIKeySheet = false
                }
            }
            .sheet(item: $showingSessionDetail) { session in
                SessionDetailView(
                    session: session,
                    recorder: recorder,
                    aiService: aiService,
                    onAnalysisComplete: { result in
                        showingAnalysisResult = result
                    }
                )
            }
            .sheet(item: $showingAnalysisResult) { result in
                AnalysisResultView(result: result)
            }
        }
    }
}

// MARK: - Recording Status View

struct RecordingStatusView: View {
    let isRecording: Bool
    let duration: TimeInterval
    let snapshotCount: Int
    let onStart: () -> Void
    let onStop: () -> Void
    let onAddMarker: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Recording indicator
                Circle()
                    .fill(isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 4)
                            .scaleEffect(isRecording ? 1.5 : 1)
                            .opacity(isRecording ? 0 : 1)
                            .animation(isRecording ? Animation.easeOut(duration: 1).repeatForever(autoreverses: false) : .default, value: isRecording)
                    )

                Text(isRecording ? "GRABANDO" : "DETENIDO")
                    .font(.headline)
                    .foregroundColor(isRecording ? .red : .secondary)

                Spacer()

                // Duration
                Text(formatDuration(duration))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.primary)
            }

            if isRecording {
                HStack {
                    Label("\(snapshotCount) muestras", systemImage: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Controls
            HStack(spacing: 20) {
                if isRecording {
                    Button(action: onAddMarker) {
                        Label("Marcador", systemImage: "flag.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(20)
                    }

                    Button(action: onStop) {
                        Label("Detener", systemImage: "stop.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(20)
                    }
                } else {
                    Button(action: onStart) {
                        Label("Iniciar Grabación", systemImage: "record.circle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(25)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Live Data Preview

struct LiveDataPreview: View {
    let snapshot: SensorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Datos en Tiempo Real")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(snapshot.readings.prefix(6)), id: \.key) { key, value in
                    VStack {
                        Text(key.uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", value))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(session.startTime))
                    .font(.headline)
                Spacer()
                Text(session.durationString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("\(session.snapshotCount) muestras", systemImage: "waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !session.dtcsCaptured.isEmpty {
                    Label("\(session.dtcsCaptured.count) DTCs", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if !session.events.filter({ $0.type == .critical }).isEmpty {
                    Label("Alertas", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Analysis History Row

struct AnalysisHistoryRow: View {
    let result: AIAnalysisResult

    var body: some View {
        HStack {
            HealthScoreBadge(score: result.healthScore)

            VStack(alignment: .leading) {
                Text(formatDate(result.timestamp))
                    .font(.subheadline)
                Text("\(result.issues.count) problemas, \(result.recommendations.count) recomendaciones")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Health Score Badge

struct HealthScoreBadge: View {
    let score: Int

    var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 4)
                .frame(width: 44, height: 44)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: RecordingSession
    let recorder: BlackBoxRecorder
    let aiService: AIAnalysisService
    let onAnalysisComplete: (AIAnalysisResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duración:")
                            Spacer()
                            Text(session.durationString)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Muestras:")
                            Spacer()
                            Text("\(session.snapshotCount)")
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Eventos:")
                            Spacer()
                            Text("\(session.events.count)")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // DTCs
                    if !session.dtcsCaptured.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DTCs Detectados")
                                .font(.headline)

                            ForEach(session.dtcsCaptured, id: \.self) { dtc in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(dtc)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Events timeline
                    if !session.events.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eventos")
                                .font(.headline)

                            ForEach(session.events.prefix(20)) { event in
                                HStack(alignment: .top) {
                                    Image(systemName: iconForEventType(event.type))
                                        .foregroundColor(colorForEventType(event.type))
                                        .frame(width: 20)

                                    VStack(alignment: .leading) {
                                        Text(event.description)
                                            .font(.subheadline)
                                        Text(formatTime(event.timestamp))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Analysis buttons
                    VStack(spacing: 12) {
                        Button(action: performQuickAnalysis) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Análisis Rápido (Offline)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        if aiService.hasAPIKey {
                            Button(action: performAIAnalysis) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "brain")
                                    }
                                    Text(isAnalyzing ? "Analizando..." : "Análisis IA (Claude)")
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
            .navigationTitle("Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func performQuickAnalysis() {
        let result = aiService.quickAnalysis(session: session, recorder: recorder)
        dismiss()
        onAnalysisComplete(result)
    }

    private func performAIAnalysis() {
        isAnalyzing = true
        analysisError = nil

        Task {
            do {
                let result = try await aiService.analyzeSession(session, recorder: recorder)
                await MainActor.run {
                    isAnalyzing = false
                    dismiss()
                    onAnalysisComplete(result)
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = error.localizedDescription
                }
            }
        }
    }

    private func iconForEventType(_ type: RecordingEvent.EventType) -> String {
        switch type {
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        case .dtcSet: return "exclamationmark.circle"
        case .dtcCleared: return "checkmark.circle"
        case .anomaly: return "waveform.badge.exclamationmark"
        case .userMarker: return "flag.fill"
        case .engineStart: return "power"
        case .engineStop: return "power.circle"
        }
    }

    private func colorForEventType(_ type: RecordingEvent.EventType) -> Color {
        switch type {
        case .warning: return .yellow
        case .critical: return .red
        case .dtcSet: return .orange
        case .dtcCleared: return .green
        case .anomaly: return .purple
        case .userMarker: return .blue
        case .engineStart: return .green
        case .engineStop: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let result: AIAnalysisResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Health score
                    HStack {
                        Spacer()
                        VStack {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                    .frame(width: 120, height: 120)

                                Circle()
                                    .trim(from: 0, to: CGFloat(result.healthScore) / 100)
                                    .stroke(healthColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))

                                VStack {
                                    Text("\(result.healthScore)")
                                        .font(.system(size: 36, weight: .bold))
                                    Text("/ 100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text("Puntuación de Salud")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen")
                            .font(.headline)
                        Text(result.analysis)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Urgent actions
                    if !result.urgentActions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Acciones Urgentes")
                                    .font(.headline)
                            }

                            ForEach(result.urgentActions, id: \.self) { action in
                                HStack(alignment: .top) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.red)
                                    Text(action)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Issues
                    if !result.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Problemas Detectados")
                                .font(.headline)

                            ForEach(result.issues) { issue in
                                IssueCard(issue: issue)
                            }
                        }
                    }

                    // Recommendations
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recomendaciones")
                                .font(.headline)

                            ForEach(result.recommendations) { rec in
                                RecommendationCard(recommendation: rec)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var healthColor: Color {
        if result.healthScore >= 80 { return .green }
        if result.healthScore >= 60 { return .yellow }
        if result.healthScore >= 40 { return .orange }
        return .red
    }
}

// MARK: - Issue Card

struct IssueCard: View {
    let issue: AIAnalysisResult.DiagnosedIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(issue.severity.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor(issue.severity))
                    .cornerRadius(8)
            }

            Text(issue.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if !issue.possibleCauses.isEmpty {
                Text("Causas posibles:")
                    .font(.caption)
                    .fontWeight(.medium)
                ForEach(issue.possibleCauses.prefix(3), id: \.self) { cause in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(cause)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func severityColor(_ severity: AIAnalysisResult.IssueSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: AIAnalysisResult.Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text("\(recommendation.priority)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let cost = recommendation.estimatedCost {
                    Text("Coste estimado: \(cost)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - API Key Sheet

struct APIKeySheet: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Configura tu API Key de Anthropic")
                    .font(.headline)

                Text("Para usar el análisis con IA, necesitas una API key de Anthropic (Claude).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Link("Obtener API Key", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)

                Spacer()

                Button(action: { onSave(apiKey) }) {
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
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BlackBoxView()
}
