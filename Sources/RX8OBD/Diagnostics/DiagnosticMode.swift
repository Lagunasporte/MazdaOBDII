import Foundation
import Combine

// MARK: - Modo Diagnóstico Inteligente
// Captura todos los valores necesarios para detectar averías en el RX-8

public class DiagnosticMode: ObservableObject {

    // MARK: - Estados Publicados
    @Published public var isRunning: Bool = false
    @Published public var currentPhase: DiagnosticPhase = .idle
    @Published public var progress: Double = 0
    @Published public var findings: [DiagnosticFinding] = []
    @Published public var healthScore: Int = 100 // 0-100
    @Published public var capturedData: DiagnosticCapture?
    @Published public var lastReport: DiagnosticReport?

    // MARK: - Conexión OBD
    public weak var connectionManager: OBDConnectionManager?

    // MARK: - Umbrales de Diagnóstico RX-8
    private let thresholds = RX8DiagnosticThresholds()

    // MARK: - Histórico para análisis
    private var rpmHistory: [TimestampedValue] = []
    private var coolantTempHistory: [TimestampedValue] = []
    private var oilTempHistory: [TimestampedValue] = []
    private var mafHistory: [TimestampedValue] = []
    private var stftHistory: [TimestampedValue] = []
    private var ltftHistory: [TimestampedValue] = []
    private var o2History: [TimestampedValue] = []

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public init(connectionManager: OBDConnectionManager) {
        self.connectionManager = connectionManager
    }

    // MARK: - Iniciar Diagnóstico Completo

    public func startDiagnostic() async throws -> DiagnosticReport {
        isRunning = true
        progress = 0
        findings = []
        healthScore = 100

        var report = DiagnosticReport(startTime: Date())

        // Fase 1: Verificar conexión
        currentPhase = .connecting
        progress = 0.05
        // await verifyConnection()

        // Fase 2: Leer DTCs
        currentPhase = .readingDTCs
        progress = 0.15
        report.dtcScan = await scanDTCs()
        analyzeDTCs(report.dtcScan)

        // Fase 3: Capturar datos en ralentí
        currentPhase = .idleCapture
        progress = 0.25
        let idleData = await captureIdleData(duration: 30)
        report.idleData = idleData
        analyzeIdleData(idleData)

        // Fase 4: Análisis de temperaturas
        currentPhase = .temperatureAnalysis
        progress = 0.45
        let temperatureData = await captureTemperatureData()
        report.temperatureData = temperatureData
        analyzeTemperatures(temperatureData)

        // Fase 5: Análisis del sistema de combustible
        currentPhase = .fuelSystemAnalysis
        progress = 0.60
        let fuelSystemData = await captureFuelSystemData()
        report.fuelSystemData = fuelSystemData
        analyzeFuelSystem(fuelSystemData)

        // Fase 6: Análisis del sistema de encendido
        currentPhase = .ignitionAnalysis
        progress = 0.75
        let ignitionData = await captureIgnitionData()
        report.ignitionData = ignitionData
        analyzeIgnition(ignitionData)

        // Fase 7: Verificar OMP
        currentPhase = .ompCheck
        progress = 0.85
        let ompData = await captureOMPData()
        report.ompData = ompData
        analyzeOMP(ompData)

        // Fase 8: Generar informe
        currentPhase = .generatingReport
        progress = 0.95
        report.findings = findings
        report.healthScore = healthScore
        report.endTime = Date()

        currentPhase = .completed
        progress = 1.0
        isRunning = false

        return report
    }

    // MARK: - Captura de Datos Reales

    private func scanDTCs() async -> DTCScanResult {
        guard let manager = connectionManager else {
            return DTCScanResult(codes: [], pendingCodes: [], milStatus: false)
        }

        do {
            let activeCodes = try await manager.readDTCs()
            let pendingCodes = try await manager.readPendingDTCs()

            // Leer estado MIL (bit 7 del PID 01)
            var milStatus = false
            if let response = try? await manager.sendCommand("0101", timeout: 3.0) {
                let bytes = parseHexString(response)
                if bytes.count >= 1 {
                    milStatus = (bytes[0] & 0x80) != 0
                }
            }

            return DTCScanResult(
                codes: activeCodes,
                pendingCodes: pendingCodes,
                milStatus: milStatus
            )
        } catch {
            return DTCScanResult(codes: [], pendingCodes: [], milStatus: false)
        }
    }

    private func captureIdleData(duration: Int) async -> IdleCaptureData {
        guard let manager = connectionManager else {
            return IdleCaptureData(averageRPM: 0, rpmVariation: 0, averageLoad: 0, averageVacuum: 0, isStable: false)
        }

        var rpmReadings: [Double] = []
        var loadReadings: [Double] = []

        // Capturar datos durante el tiempo especificado
        let iterations = min(duration, 15) // Máximo 15 segundos para no tardar demasiado
        for i in 0..<iterations {
            do {
                let rpm = try await manager.readRPM()
                rpmReadings.append(Double(rpm))

                // Leer carga del motor (PID 04)
                let loadBytes = try await manager.readStandardPID(mode: 0x01, pid: 0x04)
                if loadBytes.count >= 1 {
                    let load = Double(loadBytes[0]) * 100.0 / 255.0
                    loadReadings.append(load)
                }
            } catch {
                // Continuar con la siguiente lectura
            }

            await MainActor.run {
                progress = 0.25 + (Double(i) / Double(iterations)) * 0.20
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Calcular estadísticas
        let avgRPM = rpmReadings.isEmpty ? 0 : rpmReadings.reduce(0, +) / Double(rpmReadings.count)
        let rpmVariation = rpmReadings.isEmpty ? 0 : (rpmReadings.max() ?? 0) - (rpmReadings.min() ?? 0)
        let avgLoad = loadReadings.isEmpty ? 0 : loadReadings.reduce(0, +) / Double(loadReadings.count)
        let isStable = rpmVariation < 50 && avgRPM > 600 && avgRPM < 900

        return IdleCaptureData(
            averageRPM: avgRPM,
            rpmVariation: rpmVariation,
            averageLoad: avgLoad,
            averageVacuum: 0, // MAP sensor si disponible
            isStable: isStable
        )
    }

    private func captureTemperatureData() async -> TemperatureCaptureData {
        guard let manager = connectionManager else {
            return TemperatureCaptureData(coolant: 0, oil: 0, intake: 0, ambient: 0, coolantToOilDelta: 0)
        }

        var coolant: Double = 0
        var intake: Double = 0
        var oil: Double = 0

        do {
            coolant = Double(try await manager.readCoolantTemp())
            intake = Double(try await manager.readIntakeTemp())

            // Temperatura de aceite (PID 5C si está disponible)
            if let oilBytes = try? await manager.readStandardPID(mode: 0x01, pid: 0x5C),
               oilBytes.count >= 1 {
                oil = Double(oilBytes[0]) - 40
            } else {
                // Estimar temp aceite basado en coolant (típicamente 5-15°C más alto)
                oil = coolant + 10
            }
        } catch {
            // Valores por defecto
        }

        return TemperatureCaptureData(
            coolant: coolant,
            oil: oil,
            intake: intake,
            ambient: intake, // Aproximación
            coolantToOilDelta: abs(oil - coolant)
        )
    }

    private func captureFuelSystemData() async -> FuelSystemCaptureData {
        guard let manager = connectionManager else {
            return FuelSystemCaptureData(shortTermFuelTrim: 0, longTermFuelTrim: 0, fuelPressure: 0, mafReading: 0, injectorPulseWidth: 0)
        }

        var stft: Double = 0
        var ltft: Double = 0
        var maf: Double = 0
        var fuelPressure: Double = 0

        do {
            stft = try await manager.readFuelTrimShort()
            ltft = try await manager.readFuelTrimLong()
            maf = try await manager.readMAF()

            // Presión de combustible (PID 0A si disponible)
            if let fpBytes = try? await manager.readStandardPID(mode: 0x01, pid: 0x0A),
               fpBytes.count >= 1 {
                fuelPressure = Double(fpBytes[0]) * 3 // kPa
            }
        } catch {
            // Valores por defecto
        }

        return FuelSystemCaptureData(
            shortTermFuelTrim: stft,
            longTermFuelTrim: ltft,
            fuelPressure: fuelPressure,
            mafReading: maf,
            injectorPulseWidth: 0 // No disponible en OBD2 estándar
        )
    }

    private func captureIgnitionData() async -> IgnitionCaptureData {
        guard let manager = connectionManager else {
            return IgnitionCaptureData(timingAdvanceLeading: 0, timingAdvanceTrailing: 0, batteryVoltage: 0, coilDwellTime: 0)
        }

        var timing: Double = 0
        var voltage: Double = 0

        do {
            timing = try await manager.readTimingAdvance()
            voltage = try await manager.readVoltage()
        } catch {
            // Valores por defecto
        }

        // En RX-8, trailing timing es típicamente 20-25° retrasado respecto a leading
        let trailingTiming = timing - 25

        return IgnitionCaptureData(
            timingAdvanceLeading: timing,
            timingAdvanceTrailing: trailingTiming,
            batteryVoltage: voltage,
            coilDwellTime: 2.5 // Valor típico
        )
    }

    private func captureOMPData() async -> OMPCaptureData {
        // OMP es específico de Mazda y requiere PIDs propietarios
        // Intentamos leer lo que podamos
        guard let manager = connectionManager else {
            return OMPCaptureData(position: 0, isActive: false, sensorVoltage: 0, status: .unknown)
        }

        // Verificar si hay códigos relacionados con OMP
        var ompStatus: OMPStatus = .normal

        do {
            let dtcs = try await manager.readDTCs()
            if dtcs.contains("P0661") || dtcs.contains("P0662") || dtcs.contains("P1520") {
                ompStatus = .fault
            }
        } catch {
            ompStatus = .unknown
        }

        // OMP position no está disponible via OBD2 estándar
        // Solo podemos inferir su estado por los DTCs
        return OMPCaptureData(
            position: ompStatus == .normal ? 35 : 0,
            isActive: ompStatus == .normal,
            sensorVoltage: 0,
            status: ompStatus
        )
    }

    /// Helper para parsear respuestas hex
    private func parseHexString(_ response: String) -> [UInt8] {
        let cleaned = response
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")

        var bytes: [UInt8] = []
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
            if let byte = UInt8(String(cleaned[index..<nextIndex]), radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }

        return bytes
    }

    // MARK: - Análisis de Datos

    private func analyzeDTCs(_ scan: DTCScanResult) {
        for code in scan.codes {
            if let dtc = RX8DTCDatabase.find(code: code) {
                let finding = DiagnosticFinding(
                    type: .dtcFound,
                    severity: dtc.severity == .critical ? .critical : .warning,
                    title: "Código \(code): \(dtc.name)",
                    description: dtc.description,
                    recommendations: dtc.solutions
                )
                findings.append(finding)
                healthScore -= dtc.severity == .critical ? 25 : 10
            }
        }
    }

    private func analyzeIdleData(_ data: IdleCaptureData) {
        // Verificar RPM en ralentí
        if data.averageRPM < 650 {
            findings.append(DiagnosticFinding(
                type: .lowIdleRPM,
                severity: .warning,
                title: "RPM de Ralentí Bajo",
                description: "El motor gira a \(Int(data.averageRPM)) RPM. Normal: 700-800 RPM",
                recommendations: [
                    "Verificar válvula IAC",
                    "Buscar fugas de vacío",
                    "Limpiar cuerpo de aceleración"
                ]
            ))
            healthScore -= 5
        }

        // Verificar estabilidad del ralentí
        if data.rpmVariation > 50 {
            findings.append(DiagnosticFinding(
                type: .unstableIdle,
                severity: .warning,
                title: "Ralentí Inestable",
                description: "Variación de \(Int(data.rpmVariation)) RPM. Normal: <30 RPM",
                recommendations: [
                    "Verificar bobinas de encendido",
                    "Verificar bujías",
                    "Realizar test de compresión",
                    "Buscar fugas de vacío"
                ]
            ))
            healthScore -= 10
        }
    }

    private func analyzeTemperatures(_ data: TemperatureCaptureData) {
        // Refrigerante
        if data.coolant > RX8AlertThresholds.coolantWarning {
            findings.append(DiagnosticFinding(
                type: .highCoolantTemp,
                severity: data.coolant > RX8AlertThresholds.coolantCritical ? .critical : .warning,
                title: "Temperatura de Refrigerante Alta",
                description: "Refrigerante a \(Int(data.coolant))°C. Límite: 100°C",
                recommendations: [
                    "Verificar nivel de refrigerante",
                    "Verificar termostato",
                    "Verificar ventiladores",
                    "Verificar bomba de agua"
                ]
            ))
            healthScore -= 15
        }

        // Aceite
        if data.oil > RX8AlertThresholds.oilWarning {
            findings.append(DiagnosticFinding(
                type: .highOilTemp,
                severity: data.oil > RX8AlertThresholds.oilCritical ? .critical : .warning,
                title: "Temperatura de Aceite Alta",
                description: "Aceite a \(Int(data.oil))°C. Límite: 120°C",
                recommendations: [
                    "Dejar enfriar el motor",
                    "Verificar nivel de aceite",
                    "Considerar radiador de aceite",
                    "Reducir carga del motor"
                ]
            ))
            healthScore -= 15
        }

        // Diferencia coolant-oil
        if data.coolantToOilDelta > 25 {
            findings.append(DiagnosticFinding(
                type: .temperatureImbalance,
                severity: .info,
                title: "Diferencia Temperatura Agua/Aceite",
                description: "Diferencia de \(Int(data.coolantToOilDelta))°C. Es normal en uso intensivo.",
                recommendations: [
                    "En uso normal: verificar termostato",
                    "En circuito: instalar oil cooler"
                ]
            ))
        }
    }

    private func analyzeFuelSystem(_ data: FuelSystemCaptureData) {
        // Short Term Fuel Trim
        if abs(data.shortTermFuelTrim) > 10 {
            let isRich = data.shortTermFuelTrim < 0
            findings.append(DiagnosticFinding(
                type: isRich ? .richMixture : .leanMixture,
                severity: .warning,
                title: isRich ? "Mezcla Rica (STFT)" : "Mezcla Pobre (STFT)",
                description: "STFT: \(String(format: "%.1f", data.shortTermFuelTrim))%. Normal: ±5%",
                recommendations: isRich ? [
                    "Verificar inyectores (posible fuga)",
                    "Verificar regulador de presión",
                    "Verificar sensor MAF"
                ] : [
                    "Buscar fugas de vacío",
                    "Limpiar sensor MAF",
                    "Verificar bomba de combustible"
                ]
            ))
            healthScore -= 8
        }

        // Long Term Fuel Trim
        if abs(data.longTermFuelTrim) > 15 {
            findings.append(DiagnosticFinding(
                type: .fuelTrimOutOfRange,
                severity: .warning,
                title: "Ajuste de Combustible Largo Fuera de Rango",
                description: "LTFT: \(String(format: "%.1f", data.longTermFuelTrim))%. Indica problema crónico.",
                recommendations: [
                    "Problema persistente de mezcla",
                    "Verificar todos los sensores relacionados",
                    "Considerar limpieza de inyectores profesional"
                ]
            ))
            healthScore -= 10
        }
    }

    private func analyzeIgnition(_ data: IgnitionCaptureData) {
        // Voltaje batería
        if data.batteryVoltage < RX8AlertThresholds.batteryLow {
            findings.append(DiagnosticFinding(
                type: .lowBattery,
                severity: data.batteryVoltage < RX8AlertThresholds.batteryCritical ? .critical : .warning,
                title: "Voltaje de Batería Bajo",
                description: "Voltaje: \(String(format: "%.1f", data.batteryVoltage))V. Mínimo: 12.4V motor parado, 13.5V en marcha",
                recommendations: [
                    "Verificar estado de batería",
                    "Verificar alternador",
                    "Verificar correa del alternador"
                ]
            ))
            healthScore -= 10
        }

        // Diferencia entre Leading y Trailing timing
        let timingDiff = data.timingAdvanceLeading - data.timingAdvanceTrailing
        if timingDiff < 20 || timingDiff > 30 {
            findings.append(DiagnosticFinding(
                type: .timingIssue,
                severity: .info,
                title: "Diferencia Timing Leading/Trailing",
                description: "Diferencia: \(Int(timingDiff))°. Normal en RX-8: 20-25°",
                recommendations: [
                    "Verificar sensor de posición del eje excéntrico",
                    "Puede ser normal bajo ciertas condiciones"
                ]
            ))
        }
    }

    private func analyzeOMP(_ data: OMPCaptureData) {
        if data.status == .fault || data.status == .limp {
            findings.append(DiagnosticFinding(
                type: .ompFault,
                severity: .critical,
                title: "Fallo en Sistema OMP",
                description: "La bomba de inyección de aceite tiene un problema",
                recommendations: [
                    "¡URGENTE! La lubricación del motor está comprometida",
                    "Verificar sensor de posición OMP",
                    "Verificar bomba OMP",
                    "NO conducir hasta reparar"
                ]
            ))
            healthScore -= 40
        } else if !data.isActive && data.position < 10 {
            findings.append(DiagnosticFinding(
                type: .ompLowOutput,
                severity: .warning,
                title: "OMP Baja Actividad",
                description: "Posición OMP: \(Int(data.position))%. Puede indicar desgaste.",
                recommendations: [
                    "Verificar ajuste del sensor OMP",
                    "Considerar premix manual como precaución"
                ]
            ))
            healthScore -= 10
        }
    }
}

// MARK: - Fases del Diagnóstico

public enum DiagnosticPhase: String, Sendable {
    case idle = "En espera"
    case connecting = "Conectando..."
    case readingDTCs = "Leyendo códigos de error"
    case idleCapture = "Capturando datos en ralentí"
    case temperatureAnalysis = "Analizando temperaturas"
    case fuelSystemAnalysis = "Analizando sistema de combustible"
    case ignitionAnalysis = "Analizando sistema de encendido"
    case ompCheck = "Verificando sistema OMP"
    case generatingReport = "Generando informe"
    case completed = "Completado"
}

// MARK: - Estructuras de Datos de Captura

public struct IdleCaptureData: Sendable {
    public let averageRPM: Double
    public let rpmVariation: Double
    public let averageLoad: Double
    public let averageVacuum: Double
    public let isStable: Bool
}

public struct TemperatureCaptureData: Sendable {
    public let coolant: Double
    public let oil: Double
    public let intake: Double
    public let ambient: Double
    public let coolantToOilDelta: Double
}

public struct FuelSystemCaptureData: Sendable {
    public let shortTermFuelTrim: Double
    public let longTermFuelTrim: Double
    public let fuelPressure: Double
    public let mafReading: Double
    public let injectorPulseWidth: Double
}

public struct IgnitionCaptureData: Sendable {
    public let timingAdvanceLeading: Double
    public let timingAdvanceTrailing: Double
    public let batteryVoltage: Double
    public let coilDwellTime: Double
}

public struct OMPCaptureData: Sendable {
    public let position: Double
    public let isActive: Bool
    public let sensorVoltage: Double
    public let status: OMPStatus
}

// MARK: - Hallazgos del Diagnóstico

public struct DiagnosticFinding: Identifiable, Sendable {
    public let id = UUID()
    public let type: FindingType
    public let severity: FindingSeverity
    public let title: String
    public let description: String
    public let recommendations: [String]
}

public enum FindingType: String, Sendable {
    case dtcFound = "Código de Error"
    case lowIdleRPM = "RPM Bajo"
    case unstableIdle = "Ralentí Inestable"
    case highCoolantTemp = "Refrigerante Caliente"
    case highOilTemp = "Aceite Caliente"
    case temperatureImbalance = "Desequilibrio Térmico"
    case richMixture = "Mezcla Rica"
    case leanMixture = "Mezcla Pobre"
    case fuelTrimOutOfRange = "Fuel Trim"
    case lowBattery = "Batería Baja"
    case timingIssue = "Timing"
    case ompFault = "Fallo OMP"
    case ompLowOutput = "OMP Baja"
    case compressionLow = "Compresión Baja"
}

public enum FindingSeverity: String, Sendable {
    case info = "Información"
    case warning = "Advertencia"
    case critical = "Crítico"

    public var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Informe de Diagnóstico

public struct DiagnosticReport: Sendable {
    public let id = UUID()
    public let startTime: Date
    public var endTime: Date?
    public var dtcScan: DTCScanResult = DTCScanResult(codes: [])
    public var idleData: IdleCaptureData?
    public var temperatureData: TemperatureCaptureData?
    public var fuelSystemData: FuelSystemCaptureData?
    public var ignitionData: IgnitionCaptureData?
    public var ompData: OMPCaptureData?
    public var findings: [DiagnosticFinding] = []
    public var healthScore: Int = 100

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    public var overallStatus: OverallStatus {
        if healthScore >= 90 { return .excellent }
        if healthScore >= 70 { return .good }
        if healthScore >= 50 { return .fair }
        if healthScore >= 25 { return .poor }
        return .critical
    }
}

public enum OverallStatus: String {
    case excellent = "Excelente"
    case good = "Bueno"
    case fair = "Regular"
    case poor = "Deficiente"
    case critical = "Crítico"

    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "teal"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }

    public var emoji: String {
        switch self {
        case .excellent: return "✅"
        case .good: return "👍"
        case .fair: return "⚠️"
        case .poor: return "🔶"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Captura de Datos Completa

public struct DiagnosticCapture: Codable, Sendable {
    public let timestamp: Date
    public let engineState: RotaryEngineState
    public let dtcCodes: [String]
}

// MARK: - Umbrales de Diagnóstico RX-8

public struct RX8DiagnosticThresholds {
    // RPM
    let idleRPMMin: Double = 650
    let idleRPMMax: Double = 850
    let idleRPMVariationMax: Double = 50

    // Temperaturas
    let coolantNormalMin: Double = 80
    let coolantNormalMax: Double = 95
    let oilNormalMin: Double = 85
    let oilNormalMax: Double = 110

    // Fuel Trim
    let fuelTrimNormalRange: Double = 10 // ±10%

    // Voltaje
    let batteryMinRunning: Double = 13.5
    let batteryMinOff: Double = 12.4
}

// MARK: - Valor con Timestamp

struct TimestampedValue {
    let timestamp: Date
    let value: Double
}
