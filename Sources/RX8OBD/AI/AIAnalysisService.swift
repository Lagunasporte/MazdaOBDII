import Foundation

// MARK: - AI Analysis Service
// Servicio para enviar datos a Claude API para análisis experto

/// AI analysis result
public struct AIAnalysisResult: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let sessionId: UUID
    public let analysis: String
    public let healthScore: Int
    public let issues: [DiagnosedIssue]
    public let recommendations: [Recommendation]
    public let urgentActions: [String]

    public struct DiagnosedIssue: Codable, Identifiable {
        public let id: UUID
        public let title: String
        public let description: String
        public let severity: IssueSeverity
        public let affectedSystems: [String]
        public let possibleCauses: [String]
        public let relatedDTCs: [String]

        public init(title: String, description: String, severity: IssueSeverity,
                    affectedSystems: [String], possibleCauses: [String], relatedDTCs: [String] = []) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.severity = severity
            self.affectedSystems = affectedSystems
            self.possibleCauses = possibleCauses
            self.relatedDTCs = relatedDTCs
        }
    }

    public enum IssueSeverity: String, Codable {
        case low = "Baja"
        case medium = "Media"
        case high = "Alta"
        case critical = "Crítica"

        public var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }

    public struct Recommendation: Codable, Identifiable {
        public let id: UUID
        public let title: String
        public let description: String
        public let priority: Int
        public let estimatedCost: String?
        public let relatedProcedureId: String?

        public init(title: String, description: String, priority: Int,
                    estimatedCost: String? = nil, relatedProcedureId: String? = nil) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.priority = priority
            self.estimatedCost = estimatedCost
            self.relatedProcedureId = relatedProcedureId
        }
    }

    public init(sessionId: UUID, analysis: String, healthScore: Int,
                issues: [DiagnosedIssue], recommendations: [Recommendation], urgentActions: [String]) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionId = sessionId
        self.analysis = analysis
        self.healthScore = healthScore
        self.issues = issues
        self.recommendations = recommendations
        self.urgentActions = urgentActions
    }
}

/// Claude API request/response models
public struct ClaudeAPIRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]

    struct ClaudeMessage: Codable {
        let role: String
        let content: String
    }
}

public struct ClaudeAPIResponse: Codable {
    let id: String
    let content: [ContentBlock]

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

// MARK: - AI Analysis Service

public class AIAnalysisService: ObservableObject {
    @Published public var isAnalyzing = false
    @Published public var lastAnalysis: AIAnalysisResult?
    @Published public var analysisHistory: [AIAnalysisResult] = []
    @Published public var error: String?

    private var apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1/messages"

    public init() {
        loadAPIKey()
        loadAnalysisHistory()
    }

    // MARK: - API Key Management

    public func setAPIKey(_ key: String) {
        apiKey = key
        saveAPIKey(key)
    }

    public var hasAPIKey: Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    private func saveAPIKey(_ key: String) {
        // In production, use Keychain
        UserDefaults.standard.set(key, forKey: "claude_api_key")
    }

    private func loadAPIKey() {
        apiKey = UserDefaults.standard.string(forKey: "claude_api_key")
    }

    // MARK: - Analysis

    public func analyzeSession(_ session: RecordingSession, recorder: BlackBoxRecorder) async throws -> AIAnalysisResult {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIAnalysisError.noAPIKey
        }

        isAnalyzing = true
        error = nil

        defer { isAnalyzing = false }

        // Generate the analysis report
        let dataReport = recorder.exportForAIAnalysis(session)

        // Create the request
        let systemPrompt = """
        Eres un ingeniero de diagnóstico senior de Mazda, especializado en motores rotativos Renesis (13B-MSP) del Mazda RX-8.
        Tienes más de 20 años de experiencia con motores rotativos y conoces todos los problemas comunes, procedimientos de diagnóstico y soluciones.

        Tu tarea es analizar los datos de diagnóstico proporcionados y generar un informe detallado en español.

        El informe debe incluir:
        1. Evaluación general del estado del motor (puntuación de salud 0-100)
        2. Problemas identificados con su severidad (Baja, Media, Alta, Crítica)
        3. Causas probables de cada problema
        4. Recomendaciones de reparación ordenadas por prioridad
        5. Acciones urgentes si las hay

        Considera especialmente:
        - Estado de los apex seals (basado en compresión, consumo de aceite, comportamiento)
        - Sistema de lubricación OMP
        - Temperaturas de operación
        - Fuel trims y estado del sistema de combustible
        - Códigos de error (DTCs) y su significado específico para el rotativo
        - Patrones de conducción y su impacto

        Responde en formato JSON estructurado para facilitar el procesamiento:
        {
            "healthScore": 85,
            "summary": "Resumen general del estado...",
            "issues": [
                {
                    "title": "Título del problema",
                    "description": "Descripción detallada",
                    "severity": "Media",
                    "affectedSystems": ["Sistema 1", "Sistema 2"],
                    "possibleCauses": ["Causa 1", "Causa 2"],
                    "relatedDTCs": ["P0300"]
                }
            ],
            "recommendations": [
                {
                    "title": "Título de la recomendación",
                    "description": "Qué hacer y por qué",
                    "priority": 1,
                    "estimatedCost": "50-100€",
                    "procedureId": "spark_plug_inspection"
                }
            ],
            "urgentActions": ["Acción urgente si aplica"]
        }
        """

        let request = ClaudeAPIRequest(
            model: "claude-sonnet-4-20250514",
            max_tokens: 4096,
            system: systemPrompt,
            messages: [
                ClaudeAPIRequest.ClaudeMessage(role: "user", content: dataReport)
            ]
        )

        // Make the API call
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIAnalysisError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let apiResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)

        guard let textContent = apiResponse.content.first?.text else {
            throw AIAnalysisError.noContent
        }

        // Parse the response
        let result = try parseAnalysisResponse(textContent, sessionId: session.id)

        // Save the result
        lastAnalysis = result
        analysisHistory.insert(result, at: 0)
        saveAnalysisHistory()

        return result
    }

    private func parseAnalysisResponse(_ text: String, sessionId: UUID) throws -> AIAnalysisResult {
        // Try to extract JSON from the response
        var jsonString = text

        // Find JSON block if wrapped in markdown
        if let startRange = text.range(of: "{"),
           let endRange = text.range(of: "}", options: .backwards) {
            jsonString = String(text[startRange.lowerBound...endRange.upperBound])
        }

        // Parse the JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIAnalysisError.parseError
        }

        struct ParsedResponse: Codable {
            let healthScore: Int
            let summary: String
            let issues: [ParsedIssue]
            let recommendations: [ParsedRecommendation]
            let urgentActions: [String]?

            struct ParsedIssue: Codable {
                let title: String
                let description: String
                let severity: String
                let affectedSystems: [String]
                let possibleCauses: [String]
                let relatedDTCs: [String]?
            }

            struct ParsedRecommendation: Codable {
                let title: String
                let description: String
                let priority: Int
                let estimatedCost: String?
                let procedureId: String?
            }
        }

        let parsed = try JSONDecoder().decode(ParsedResponse.self, from: jsonData)

        // Convert to our model
        let issues = parsed.issues.map { issue in
            AIAnalysisResult.DiagnosedIssue(
                title: issue.title,
                description: issue.description,
                severity: AIAnalysisResult.IssueSeverity(rawValue: issue.severity) ?? .medium,
                affectedSystems: issue.affectedSystems,
                possibleCauses: issue.possibleCauses,
                relatedDTCs: issue.relatedDTCs ?? []
            )
        }

        let recommendations = parsed.recommendations.map { rec in
            AIAnalysisResult.Recommendation(
                title: rec.title,
                description: rec.description,
                priority: rec.priority,
                estimatedCost: rec.estimatedCost,
                relatedProcedureId: rec.procedureId
            )
        }

        return AIAnalysisResult(
            sessionId: sessionId,
            analysis: parsed.summary,
            healthScore: parsed.healthScore,
            issues: issues,
            recommendations: recommendations,
            urgentActions: parsed.urgentActions ?? []
        )
    }

    // MARK: - Quick Analysis (without API)

    public func quickAnalysis(session: RecordingSession, recorder: BlackBoxRecorder) -> AIAnalysisResult {
        let summary = recorder.generateSummary(for: session)
        var issues: [AIAnalysisResult.DiagnosedIssue] = []
        var recommendations: [AIAnalysisResult.Recommendation] = []
        var urgentActions: [String] = []
        var healthScore = 100

        // Analyze sensor stats
        for stat in summary.sensorStats {
            switch stat.sensorId {
            case "ect":
                if stat.max > 105 {
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: "Sobrecalentamiento del motor",
                        description: "Se detectó temperatura de refrigerante crítica (máx: \(String(format: "%.1f", stat.max))°C)",
                        severity: .critical,
                        affectedSystems: ["Sistema de refrigeración", "Motor"],
                        possibleCauses: ["Termostato defectuoso", "Bomba de agua", "Nivel de refrigerante bajo", "Ventilador"]
                    ))
                    healthScore -= 30
                    urgentActions.append("Verificar sistema de refrigeración inmediatamente")
                } else if stat.max > 98 {
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: "Temperatura de refrigerante elevada",
                        description: "Temperatura máxima registrada: \(String(format: "%.1f", stat.max))°C",
                        severity: .high,
                        affectedSystems: ["Sistema de refrigeración"],
                        possibleCauses: ["Termostato", "Radiador sucio", "Nivel bajo"]
                    ))
                    healthScore -= 15
                }

            case "oil_temp":
                if stat.max > 130 {
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: "Aceite sobrecalentado",
                        description: "Temperatura de aceite crítica: \(String(format: "%.1f", stat.max))°C. Riesgo para apex seals.",
                        severity: .critical,
                        affectedSystems: ["Lubricación", "Motor rotativo"],
                        possibleCauses: ["Aceite degradado", "Oil cooler obstruido", "Conducción muy agresiva"]
                    ))
                    healthScore -= 25
                    urgentActions.append("Cambiar aceite y verificar oil cooler")
                }

            case "stft", "ltft":
                if abs(stat.average) > 15 {
                    let isLean = stat.average > 0
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: isLean ? "Mezcla constantemente pobre" : "Mezcla constantemente rica",
                        description: "Fuel trim promedio: \(String(format: "%.1f", stat.average))%",
                        severity: .high,
                        affectedSystems: ["Sistema de combustible", "Admisión"],
                        possibleCauses: isLean ?
                            ["Fuga de vacío", "Sensor MAF sucio", "Inyectores obstruidos"] :
                            ["Regulador de presión", "Inyector con fuga", "Sensor O2 defectuoso"]
                    ))
                    healthScore -= 15
                    recommendations.append(AIAnalysisResult.Recommendation(
                        title: "Diagnóstico del sistema de combustible",
                        description: "Verificar fugas de vacío, limpiar MAF, y revisar inyectores",
                        priority: 2
                    ))
                }

            case "oil_pressure":
                if stat.min < 0.5 {
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: "Presión de aceite baja",
                        description: "Se registró presión mínima de \(String(format: "%.2f", stat.min)) bar",
                        severity: .critical,
                        affectedSystems: ["Lubricación", "Motor"],
                        possibleCauses: ["Nivel de aceite bajo", "Bomba de aceite desgastada", "Aceite degradado"]
                    ))
                    healthScore -= 30
                    urgentActions.append("PARAR el motor y verificar nivel/presión de aceite")
                }

            default:
                break
            }
        }

        // Analyze DTCs
        if !summary.dtcs.isEmpty {
            for dtc in summary.dtcs {
                if dtc.starts(with: "P030") {
                    issues.append(AIAnalysisResult.DiagnosedIssue(
                        title: "Fallos de encendido detectados",
                        description: "DTC \(dtc) indica fallos de encendido",
                        severity: .high,
                        affectedSystems: ["Encendido", "Compresión"],
                        possibleCauses: ["Bujías desgastadas", "Bobinas defectuosas", "Compresión baja"],
                        relatedDTCs: [dtc]
                    ))
                    healthScore -= 10
                    recommendations.append(AIAnalysisResult.Recommendation(
                        title: "Inspección del sistema de encendido",
                        description: "Verificar bujías y bobinas. Realizar test de compresión.",
                        priority: 1,
                        relatedProcedureId: "spark_plug_inspection"
                    ))
                }
            }
        }

        // Analyze anomalies
        for anomaly in summary.anomalies {
            healthScore -= anomaly.occurrences > 10 ? 10 : 5
        }

        // Ensure health score is in valid range
        healthScore = max(0, min(100, healthScore))

        // Add general recommendations based on health score
        if healthScore < 70 {
            recommendations.append(AIAnalysisResult.Recommendation(
                title: "Test de compresión recomendado",
                description: "Dado el estado general, se recomienda un test de compresión para evaluar los apex seals",
                priority: 1,
                estimatedCost: "50-100€",
                relatedProcedureId: "compression_test"
            ))
        }

        let analysisText = generateQuickAnalysisText(healthScore: healthScore, issues: issues)

        return AIAnalysisResult(
            sessionId: session.id,
            analysis: analysisText,
            healthScore: healthScore,
            issues: issues,
            recommendations: recommendations.sorted { $0.priority < $1.priority },
            urgentActions: urgentActions
        )
    }

    private func generateQuickAnalysisText(healthScore: Int, issues: [AIAnalysisResult.DiagnosedIssue]) -> String {
        var text = "Puntuación de salud del motor: \(healthScore)/100\n\n"

        if healthScore >= 80 {
            text += "El motor está en buen estado general. "
        } else if healthScore >= 60 {
            text += "El motor muestra algunos problemas que requieren atención. "
        } else if healthScore >= 40 {
            text += "El motor presenta problemas significativos. Se recomienda reparación pronto. "
        } else {
            text += "El motor está en estado crítico. Se requiere atención inmediata. "
        }

        if issues.isEmpty {
            text += "No se detectaron problemas significativos durante la sesión de grabación."
        } else {
            text += "Se detectaron \(issues.count) problema(s) durante el análisis."
        }

        return text
    }

    // MARK: - Persistence

    private func saveAnalysisHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(analysisHistory.prefix(50)) {
            UserDefaults.standard.set(data, forKey: "analysis_history")
        }
    }

    private func loadAnalysisHistory() {
        guard let data = UserDefaults.standard.data(forKey: "analysis_history") else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        analysisHistory = (try? decoder.decode([AIAnalysisResult].self, from: data)) ?? []
    }
}

// MARK: - Errors

public enum AIAnalysisError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent
    case parseError

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No se ha configurado la API key de Anthropic"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .apiError(let code, let message):
            return "Error de API (\(code)): \(message)"
        case .noContent:
            return "La respuesta no contiene contenido"
        case .parseError:
            return "Error al procesar la respuesta"
        }
    }
}
