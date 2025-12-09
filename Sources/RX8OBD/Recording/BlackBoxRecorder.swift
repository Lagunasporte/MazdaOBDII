import Foundation
import Combine

// MARK: - Black Box Recorder
// Sistema de grabación automática - detecta cuando el coche arranca y graba

public class BlackBoxRecorder: ObservableObject {
    // MARK: - Published Properties
    @Published public var isRecording = false
    @Published public var currentSessionId: String?
    @Published public var sessions: [BlackBoxSession] = []
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var snapshotCount: Int = 0
    @Published public var lastAlert: BlackBoxAlert?

    // MARK: - Private Properties
    private let database = BlackBoxDatabase()
    private var recordingStartTime: Date?
    private var lastSnapshotTime: Date?
    private var durationTimer: Timer?

    // Configuración
    private let snapshotInterval: TimeInterval = 1.0 // Guardar cada segundo
    private let minRPMToStart: Int = 400 // RPM mínimo para detectar motor encendido
    private let maxIdleTimeToStop: TimeInterval = 30 // Segundos sin RPM para parar

    private var lastRPMTime: Date?
    private var engineWasRunning = false

    public init() {
        loadSessions()
    }

    // MARK: - Session Control

    /// Llamar esto desde el monitor de motor con cada lectura de RPM
    public func checkEngineState(rpm: Int) {
        let now = Date()

        if rpm >= minRPMToStart {
            lastRPMTime = now

            if !isRecording {
                // Motor acaba de arrancar - iniciar grabación
                startRecording()
            }
            engineWasRunning = true
        } else if engineWasRunning && isRecording {
            // Motor parado - verificar si ha pasado suficiente tiempo
            if let lastTime = lastRPMTime,
               now.timeIntervalSince(lastTime) > maxIdleTimeToStop {
                stopRecording()
                engineWasRunning = false
            }
        }
    }

    public func startRecording() {
        guard !isRecording else { return }

        currentSessionId = database.createSession()
        recordingStartTime = Date()
        isRecording = true
        snapshotCount = 0

        // Timer para actualizar duración
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }

        print("BlackBox: Sesión iniciada - \(currentSessionId ?? "")")
    }

    public func stopRecording() {
        guard isRecording, let sessionId = currentSessionId else { return }

        durationTimer?.invalidate()
        durationTimer = nil

        database.endSession(sessionId)
        isRecording = false
        currentSessionId = nil
        recordingDuration = 0

        loadSessions()

        print("BlackBox: Sesión finalizada")
    }

    // MARK: - Data Recording

    public func recordSnapshot(state: RotaryEngineState) {
        let now = Date()

        // PRIMERO verificar estado del motor (puede iniciar la grabación)
        checkEngineState(rpm: state.rpm)

        // Si no está grabando después de verificar, salir
        guard isRecording, let sessionId = currentSessionId else { return }

        // Solo guardar cada segundo
        if let lastTime = lastSnapshotTime,
           now.timeIntervalSince(lastTime) < snapshotInterval {
            return
        }
        lastSnapshotTime = now

        let snapshot = EngineSnapshot(
            timestamp: now.timeIntervalSince1970,
            rpm: state.rpm,
            speed: state.vehicleSpeed,
            coolantTemp: state.coolantTemperature,
            oilTemp: state.oilTemperature,
            intakeTemp: state.intakeAirTemperature,
            catalystTemp: state.catalystTemperature,
            throttle: state.throttlePosition,
            maf: state.mafAirFlow,
            stft: state.shortTermFuelTrim,
            ltft: state.longTermFuelTrim,
            timing: state.ignitionTiming,
            voltage: state.batteryVoltage,
            fuelLevel: state.fuelLevel,
            load: state.engineLoad,
            o2b1s1: state.o2SensorBank1Sensor1,
            o2b1s2: state.o2SensorBank1Sensor2,
            map: state.manifoldPressure,
            accelerator: state.acceleratorPosition,
            stftB2: state.shortTermFuelTrimB2,
            ltftB2: state.longTermFuelTrimB2
        )

        database.recordSnapshot(sessionId, data: snapshot)
        snapshotCount += 1

        // Detectar y registrar alertas
        checkAndRecordAlerts(sessionId: sessionId, state: state)
    }

    /// Método alternativo para grabar desde diccionario (compatibilidad)
    public func recordSnapshot(readings: [String: Double]) {
        let now = Date()

        // PRIMERO verificar estado del motor (puede iniciar la grabación)
        if let rpm = readings["rpm"] {
            checkEngineState(rpm: Int(rpm))
        }

        // Si no está grabando después de verificar, salir
        guard isRecording, let sessionId = currentSessionId else { return }

        // Solo guardar cada segundo
        if let lastTime = lastSnapshotTime,
           now.timeIntervalSince(lastTime) < snapshotInterval {
            return
        }
        lastSnapshotTime = now

        let snapshot = EngineSnapshot(
            timestamp: now.timeIntervalSince1970,
            rpm: Int(readings["rpm"] ?? 0),
            speed: readings["speed"] ?? 0,
            coolantTemp: readings["ect"] ?? 0,
            oilTemp: readings["oil_temp"] ?? 0,
            intakeTemp: readings["iat"] ?? 0,
            catalystTemp: readings["cat_temp"] ?? 0,
            throttle: readings["throttle"] ?? 0,
            maf: readings["maf"] ?? 0,
            stft: readings["stft"] ?? 0,
            ltft: readings["ltft"] ?? 0,
            timing: readings["timing"] ?? 0,
            voltage: readings["voltage"] ?? 0,
            fuelLevel: readings["fuel_level"] ?? 0,
            load: readings["load"] ?? 0
        )

        database.recordSnapshot(sessionId, data: snapshot)
        snapshotCount += 1

        // Detectar y registrar alertas
        checkAndRecordAlertsFromReadings(sessionId: sessionId, readings: readings)
    }

    // MARK: - Alert Detection

    private func checkAndRecordAlerts(sessionId: String, state: RotaryEngineState) {
        // Temperatura de refrigerante
        if state.coolantTemperature > 105 {
            recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Crítico",
                       parameter: "Refrigerante", value: state.coolantTemperature, threshold: 105,
                       message: "Temperatura de refrigerante crítica")
        } else if state.coolantTemperature > 98 {
            recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Advertencia",
                       parameter: "Refrigerante", value: state.coolantTemperature, threshold: 98,
                       message: "Temperatura de refrigerante elevada")
        }

        // Temperatura de aceite
        if state.oilTemperature > 130 {
            recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Crítico",
                       parameter: "Aceite", value: state.oilTemperature, threshold: 130,
                       message: "Temperatura de aceite crítica")
        } else if state.oilTemperature > 120 {
            recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Advertencia",
                       parameter: "Aceite", value: state.oilTemperature, threshold: 120,
                       message: "Temperatura de aceite elevada")
        }

        // Catalizador
        if state.catalystTemperature > 900 {
            recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Crítico",
                       parameter: "Catalizador", value: state.catalystTemperature, threshold: 900,
                       message: "Catalizador sobrecalentado")
        }

        // RPM
        if state.rpm > 9000 {
            recordAlert(sessionId: sessionId, type: "Motor", severity: "Crítico",
                       parameter: "RPM", value: Double(state.rpm), threshold: 9000,
                       message: "RPM en zona roja")
        }

        // Fuel trims
        if abs(state.shortTermFuelTrim) > 20 {
            recordAlert(sessionId: sessionId, type: "Combustible", severity: "Advertencia",
                       parameter: "STFT", value: state.shortTermFuelTrim, threshold: 20,
                       message: state.shortTermFuelTrim > 0 ? "Mezcla muy pobre" : "Mezcla muy rica")
        }

        if abs(state.longTermFuelTrim) > 15 {
            recordAlert(sessionId: sessionId, type: "Combustible", severity: "Advertencia",
                       parameter: "LTFT", value: state.longTermFuelTrim, threshold: 15,
                       message: "LTFT fuera de rango - posible problema de combustible")
        }

        // Voltaje
        if state.batteryVoltage < 12.0 && state.rpm > 800 {
            recordAlert(sessionId: sessionId, type: "Eléctrico", severity: "Advertencia",
                       parameter: "Voltaje", value: state.batteryVoltage, threshold: 12.0,
                       message: "Voltaje de batería bajo")
        }
    }

    private func checkAndRecordAlertsFromReadings(sessionId: String, readings: [String: Double]) {
        // Temperatura de refrigerante
        if let coolant = readings["ect"] {
            if coolant > 105 {
                recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Crítico",
                           parameter: "Refrigerante", value: coolant, threshold: 105,
                           message: "Temperatura de refrigerante crítica")
            } else if coolant > 98 {
                recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Advertencia",
                           parameter: "Refrigerante", value: coolant, threshold: 98,
                           message: "Temperatura de refrigerante elevada")
            }
        }

        // Temperatura de aceite
        if let oilTemp = readings["oil_temp"] {
            if oilTemp > 130 {
                recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Crítico",
                           parameter: "Aceite", value: oilTemp, threshold: 130,
                           message: "Temperatura de aceite crítica")
            } else if oilTemp > 120 {
                recordAlert(sessionId: sessionId, type: "Temperatura", severity: "Advertencia",
                           parameter: "Aceite", value: oilTemp, threshold: 120,
                           message: "Temperatura de aceite elevada")
            }
        }

        // Fuel trims
        if let stft = readings["stft"], abs(stft) > 20 {
            recordAlert(sessionId: sessionId, type: "Combustible", severity: "Advertencia",
                       parameter: "STFT", value: stft, threshold: 20,
                       message: stft > 0 ? "Mezcla muy pobre" : "Mezcla muy rica")
        }

        if let ltft = readings["ltft"], abs(ltft) > 15 {
            recordAlert(sessionId: sessionId, type: "Combustible", severity: "Advertencia",
                       parameter: "LTFT", value: ltft, threshold: 15,
                       message: "LTFT fuera de rango")
        }
    }

    private func recordAlert(sessionId: String, type: String, severity: String,
                            parameter: String, value: Double, threshold: Double, message: String) {
        let alert = BlackBoxAlert(
            type: type,
            severity: severity,
            parameter: parameter,
            value: value,
            threshold: threshold,
            message: message
        )

        database.recordAlert(sessionId, alert: alert)
        lastAlert = alert
    }

    // MARK: - DTC Recording

    public func recordDTC(_ code: String, description: String) {
        guard let sessionId = currentSessionId else { return }
        database.recordDTC(sessionId, code: code, description: description)
    }

    // MARK: - Session Management

    public func loadSessions() {
        sessions = database.getAllSessions()
    }

    public func deleteSession(_ session: BlackBoxSession) {
        database.deleteSession(session.id)
        loadSessions()
    }

    public func addNote(_ sessionId: String, note: String) {
        database.addNote(sessionId, note: note)
        loadSessions()
    }

    // MARK: - Analysis

    public func getSessionSnapshots(_ sessionId: String) -> [EngineSnapshot] {
        return database.getSessionSnapshots(sessionId)
    }

    public func getSessionAlerts(_ sessionId: String) -> [BlackBoxAlert] {
        return database.getSessionAlerts(sessionId)
    }

    public func getSessionDTCs(_ sessionId: String) -> [(code: String, description: String)] {
        return database.getSessionDTCs(sessionId)
    }

    public func exportSessionForAnalysis(_ sessionId: String) -> String {
        return database.exportSessionForAnalysis(sessionId)
    }

    public func saveAnalysisResult(_ sessionId: String, result: String) {
        database.saveAnalysisResult(sessionId, result: result)
        loadSessions()
    }
}
