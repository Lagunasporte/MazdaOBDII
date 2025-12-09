import Foundation
import Combine

// MARK: - Black Box Recording System
// Sistema de grabación continua de datos como una caja negra de avión

/// Single data point recorded
public struct DataPoint: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let sensorId: String
    public let value: Double
    public let unit: String

    public init(sensorId: String, value: Double, unit: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.sensorId = sensorId
        self.value = value
        self.unit = unit
    }
}

/// Snapshot of all sensors at a moment in time
public struct SensorSnapshot: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public var readings: [String: Double]
    public var location: LocationData?
    public var events: [RecordingEvent]

    public init(readings: [String: Double] = [:], location: LocationData? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.readings = readings
        self.location = location
        self.events = []
    }
}

/// Location data for GPS logging
public struct LocationData: Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let speed: Double // m/s
    public let heading: Double

    public init(latitude: Double, longitude: Double, altitude: Double = 0, speed: Double = 0, heading: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.heading = heading
    }
}

/// Event that occurred during recording
public struct RecordingEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: EventType
    public let description: String
    public let sensorId: String?
    public let value: Double?

    public enum EventType: String, Codable {
        case warning = "Advertencia"
        case critical = "Crítico"
        case dtcSet = "DTC Activo"
        case dtcCleared = "DTC Borrado"
        case anomaly = "Anomalía"
        case userMarker = "Marcador"
        case engineStart = "Arranque"
        case engineStop = "Parada"
    }

    public init(type: EventType, description: String, sensorId: String? = nil, value: Double? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.description = description
        self.sensorId = sensorId
        self.value = value
    }
}

/// Complete recording session
public struct RecordingSession: Codable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?
    public let vehicleInfo: RecordedVehicleInfo
    public var snapshots: [SensorSnapshot]
    public var events: [RecordingEvent]
    public var dtcsCaptured: [String]
    public var notes: String

    public struct RecordedVehicleInfo: Codable {
        public let vin: String?
        public let year: Int
        public let series: Int // 1 or 2
        public let mileage: Int?

        public init(vin: String? = nil, year: Int = 2004, series: Int = 1, mileage: Int? = nil) {
            self.vin = vin
            self.year = year
            self.series = series
            self.mileage = mileage
        }
    }

    public init(vehicleInfo: RecordedVehicleInfo = RecordedVehicleInfo()) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.vehicleInfo = vehicleInfo
        self.snapshots = []
        self.events = []
        self.dtcsCaptured = []
        self.notes = ""
    }

    public var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }

    public var durationString: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var snapshotCount: Int {
        return snapshots.count
    }

    // Statistics
    public func statistics(for sensorId: String) -> SensorStatistics? {
        let values = snapshots.compactMap { $0.readings[sensorId] }
        guard !values.isEmpty else { return nil }

        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let avg = values.reduce(0, +) / Double(values.count)

        return SensorStatistics(sensorId: sensorId, min: min, max: max, average: avg, samples: values.count)
    }
}

/// Statistics for a sensor during a session
public struct SensorStatistics: Codable {
    public let sensorId: String
    public let min: Double
    public let max: Double
    public let average: Double
    public let samples: Int
}

/// Summary for AI analysis
public struct SessionSummary: Codable {
    public let sessionId: UUID
    public let vehicleInfo: RecordingSession.RecordedVehicleInfo
    public let duration: TimeInterval
    public let startTime: Date
    public let endTime: Date?
    public let sensorStats: [SensorStatistics]
    public let events: [RecordingEvent]
    public let dtcs: [String]
    public let notes: String
    public let anomalies: [AnomalyReport]

    public struct AnomalyReport: Codable {
        public let sensorId: String
        public let description: String
        public let severity: String
        public let occurrences: Int
        public let exampleValues: [Double]
    }
}

// MARK: - Black Box Recorder

public class BlackBoxRecorder: ObservableObject {
    @Published public var isRecording = false
    @Published public var currentSession: RecordingSession?
    @Published public var savedSessions: [RecordingSession] = []
    @Published public var lastSnapshot: SensorSnapshot?
    @Published public var recordingDuration: TimeInterval = 0

    private var timer: Timer?
    private var recordingInterval: TimeInterval = 0.5 // 2 samples per second
    private let maxSnapshots = 7200 // 1 hour at 2 samples/sec
    private let fileManager = FileManager.default
    private let sessionsDirectory: URL

    public init() {
        // Setup sessions directory
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        sessionsDirectory = documents.appendingPathComponent("BlackBoxSessions", isDirectory: true)

        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        loadSavedSessions()
    }

    // MARK: - Recording Control

    public func startRecording(vehicleInfo: RecordingSession.RecordedVehicleInfo = .init()) {
        guard !isRecording else { return }

        currentSession = RecordingSession(vehicleInfo: vehicleInfo)
        isRecording = true
        recordingDuration = 0

        // Add engine start event
        addEvent(RecordingEvent(type: .engineStart, description: "Grabación iniciada"))

        // Start timer for duration updates
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration = self?.currentSession?.duration ?? 0
        }
    }

    public func stopRecording() -> RecordingSession? {
        guard isRecording, var session = currentSession else { return nil }

        timer?.invalidate()
        timer = nil

        session.endTime = Date()
        addEvent(RecordingEvent(type: .engineStop, description: "Grabación finalizada"))

        isRecording = false

        // Save session
        saveSession(session)
        savedSessions.insert(session, at: 0)

        let completedSession = session
        currentSession = nil

        return completedSession
    }

    public func pauseRecording() {
        timer?.invalidate()
        timer = nil
    }

    public func resumeRecording() {
        guard isRecording else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration = self?.currentSession?.duration ?? 0
        }
    }

    // MARK: - Data Recording

    public func recordSnapshot(readings: [String: Double], location: LocationData? = nil) {
        guard isRecording, currentSession != nil else { return }

        var snapshot = SensorSnapshot(readings: readings, location: location)

        // Check for anomalies
        let anomalies = detectAnomalies(readings: readings)
        snapshot.events = anomalies

        currentSession?.snapshots.append(snapshot)
        lastSnapshot = snapshot

        // Trim old snapshots if needed
        if let count = currentSession?.snapshots.count, count > maxSnapshots {
            currentSession?.snapshots.removeFirst(count - maxSnapshots)
        }
    }

    public func addEvent(_ event: RecordingEvent) {
        currentSession?.events.append(event)
    }

    public func addDTC(_ code: String) {
        guard currentSession != nil else { return }
        if !(currentSession?.dtcsCaptured.contains(code) ?? false) {
            currentSession?.dtcsCaptured.append(code)
            addEvent(RecordingEvent(type: .dtcSet, description: "DTC detectado: \(code)"))
        }
    }

    public func addUserMarker(_ description: String) {
        addEvent(RecordingEvent(type: .userMarker, description: description))
    }

    public func addNote(_ note: String) {
        currentSession?.notes += (currentSession?.notes.isEmpty == true ? "" : "\n") + note
    }

    // MARK: - Anomaly Detection

    private func detectAnomalies(readings: [String: Double]) -> [RecordingEvent] {
        var anomalies: [RecordingEvent] = []

        // Check coolant temp
        if let coolant = readings["ect"], coolant > 105 {
            anomalies.append(RecordingEvent(
                type: .critical,
                description: "Temperatura de refrigerante crítica",
                sensorId: "ect",
                value: coolant
            ))
        } else if let coolant = readings["ect"], coolant > 98 {
            anomalies.append(RecordingEvent(
                type: .warning,
                description: "Temperatura de refrigerante elevada",
                sensorId: "ect",
                value: coolant
            ))
        }

        // Check oil temp
        if let oilTemp = readings["oil_temp"], oilTemp > 130 {
            anomalies.append(RecordingEvent(
                type: .critical,
                description: "Temperatura de aceite crítica",
                sensorId: "oil_temp",
                value: oilTemp
            ))
        } else if let oilTemp = readings["oil_temp"], oilTemp > 120 {
            anomalies.append(RecordingEvent(
                type: .warning,
                description: "Temperatura de aceite elevada",
                sensorId: "oil_temp",
                value: oilTemp
            ))
        }

        // Check oil pressure
        if let oilPressure = readings["oil_pressure"], oilPressure < 0.5 {
            anomalies.append(RecordingEvent(
                type: .critical,
                description: "Presión de aceite crítica",
                sensorId: "oil_pressure",
                value: oilPressure
            ))
        }

        // Check fuel trims
        if let stft = readings["stft"], abs(stft) > 20 {
            anomalies.append(RecordingEvent(
                type: .warning,
                description: stft > 0 ? "Mezcla muy pobre" : "Mezcla muy rica",
                sensorId: "stft",
                value: stft
            ))
        }

        // Check RPM
        if let rpm = readings["rpm"], rpm > 9000 {
            anomalies.append(RecordingEvent(
                type: .warning,
                description: "RPM en zona roja",
                sensorId: "rpm",
                value: rpm
            ))
        } else if let rpm = readings["rpm"], rpm < 600 && rpm > 0 {
            anomalies.append(RecordingEvent(
                type: .warning,
                description: "Ralentí inestable",
                sensorId: "rpm",
                value: rpm
            ))
        }

        return anomalies
    }

    // MARK: - Session Management

    private func saveSession(_ session: RecordingSession) {
        let filename = "session_\(session.id.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
        } catch {
            print("Error saving session: \(error)")
        }
    }

    private func loadSavedSessions() {
        do {
            let files = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            savedSessions = jsonFiles.compactMap { url -> RecordingSession? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(RecordingSession.self, from: data)
            }.sorted { $0.startTime > $1.startTime }

        } catch {
            print("Error loading sessions: \(error)")
        }
    }

    public func deleteSession(_ session: RecordingSession) {
        let filename = "session_\(session.id.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(filename)

        try? fileManager.removeItem(at: fileURL)
        savedSessions.removeAll { $0.id == session.id }
    }

    public func exportSession(_ session: RecordingSession) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(session)
    }

    // MARK: - Summary Generation

    public func generateSummary(for session: RecordingSession) -> SessionSummary {
        // Calculate statistics for all sensors
        var stats: [SensorStatistics] = []
        let sensorIds = Set(session.snapshots.flatMap { $0.readings.keys })

        for sensorId in sensorIds {
            if let stat = session.statistics(for: sensorId) {
                stats.append(stat)
            }
        }

        // Detect anomalies patterns
        var anomalyReports: [SessionSummary.AnomalyReport] = []
        var anomalyCounts: [String: (count: Int, values: [Double], description: String)] = [:]

        for snapshot in session.snapshots {
            for event in snapshot.events {
                if let sensorId = event.sensorId, let value = event.value {
                    if var existing = anomalyCounts[sensorId] {
                        existing.count += 1
                        existing.values.append(value)
                        anomalyCounts[sensorId] = existing
                    } else {
                        anomalyCounts[sensorId] = (1, [value], event.description)
                    }
                }
            }
        }

        for (sensorId, data) in anomalyCounts {
            anomalyReports.append(SessionSummary.AnomalyReport(
                sensorId: sensorId,
                description: data.description,
                severity: data.count > 10 ? "Alta" : (data.count > 3 ? "Media" : "Baja"),
                occurrences: data.count,
                exampleValues: Array(data.values.prefix(5))
            ))
        }

        return SessionSummary(
            sessionId: session.id,
            vehicleInfo: session.vehicleInfo,
            duration: session.duration,
            startTime: session.startTime,
            endTime: session.endTime,
            sensorStats: stats,
            events: session.events,
            dtcs: session.dtcsCaptured,
            notes: session.notes,
            anomalies: anomalyReports
        )
    }

    // MARK: - Export for AI Analysis

    public func exportForAIAnalysis(_ session: RecordingSession) -> String {
        let summary = generateSummary(for: session)

        var report = """
        # Datos de Diagnóstico RX-8 para Análisis

        ## Información del Vehículo
        - Año: \(summary.vehicleInfo.year)
        - Series: \(summary.vehicleInfo.series)
        - VIN: \(summary.vehicleInfo.vin ?? "No disponible")
        - Kilometraje: \(summary.vehicleInfo.mileage.map { "\($0) km" } ?? "No disponible")

        ## Sesión de Grabación
        - Inicio: \(formatDate(summary.startTime))
        - Duración: \(Int(summary.duration / 60)) minutos
        - Muestras: \(session.snapshots.count)

        ## DTCs Detectados
        """

        if summary.dtcs.isEmpty {
            report += "\nNo se detectaron códigos de error.\n"
        } else {
            for dtc in summary.dtcs {
                report += "\n- \(dtc)"
            }
        }

        report += "\n\n## Estadísticas de Sensores\n"

        for stat in summary.sensorStats.sorted(by: { $0.sensorId < $1.sensorId }) {
            report += """

            ### \(stat.sensorId)
            - Mínimo: \(String(format: "%.2f", stat.min))
            - Máximo: \(String(format: "%.2f", stat.max))
            - Promedio: \(String(format: "%.2f", stat.average))
            - Muestras: \(stat.samples)
            """
        }

        if !summary.anomalies.isEmpty {
            report += "\n\n## Anomalías Detectadas\n"
            for anomaly in summary.anomalies {
                report += """

                ### \(anomaly.sensorId) - \(anomaly.severity)
                - Descripción: \(anomaly.description)
                - Ocurrencias: \(anomaly.occurrences)
                - Valores ejemplo: \(anomaly.exampleValues.map { String(format: "%.2f", $0) }.joined(separator: ", "))
                """
            }
        }

        if !summary.events.isEmpty {
            report += "\n\n## Eventos Registrados\n"
            for event in summary.events.prefix(50) {
                report += "\n- [\(event.type.rawValue)] \(formatDate(event.timestamp)): \(event.description)"
            }
        }

        if !summary.notes.isEmpty {
            report += "\n\n## Notas del Usuario\n\(summary.notes)"
        }

        report += """

        \n\n---
        Por favor, analiza estos datos como si fueras un ingeniero de diagnóstico de Mazda especializado
        en motores rotativos. Identifica posibles problemas, su severidad, y proporciona recomendaciones
        de reparación o mantenimiento preventivo.
        """

        return report
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}
