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
        report.idleData = await captureIdleData(duration: 30)
        analyzeIdleData(report.idleData)

        // Fase 4: Análisis de temperaturas
        currentPhase = .temperatureAnalysis
        progress = 0.45
        report.temperatureData = await captureTemperatureData()
        analyzeTemperatures(report.temperatureData)

        // Fase 5: Análisis del sistema de combustible
        currentPhase = .fuelSystemAnalysis
        progress = 0.60
        report.fuelSystemData = await captureFuelSystemData()
        analyzeFuelSystem(report.fuelSystemData)

        // Fase 6: Análisis del sistema de encendido
        currentPhase = .ignitionAnalysis
        progress = 0.75
        report.ignitionData = await captureIgnitionData()
        analyzeIgnition(report.ignitionData)

        // Fase 7: Verificar OMP
        currentPhase = .ompCheck
        progress = 0.85
        report.ompData = await captureOMPData()
        analyzeOMP(report.ompData)

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

    // MARK: - Captura de Datos

    private func scanDTCs() async -> DTCScanResult {
        // Simulación - en implementación real, leer del OBD2
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return DTCScanResult(codes: [], pendingCodes: [], milStatus: false)
    }

    private func captureIdleData(duration: Int) async -> IdleCaptureData {
        // Captura datos durante X segundos en ralentí
        var rpmReadings: [Double] = []
        var loadReadings: [Double] = []
        var vacuumReadings: [Double] = []

        // Simulación
        for i in 0..<duration {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            progress = 0.25 + (Double(i) / Double(duration)) * 0.20
        }

        return IdleCaptureData(
            averageRPM: 750,
            rpmVariation: 25,
            averageLoad: 28,
            averageVacuum: 65,
            isStable: true
        )
    }

    private func captureTemperatureData() async -> TemperatureCaptureData {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return TemperatureCaptureData(
            coolant: 88,
            oil: 95,
            intake: 32,
            ambient: 22,
            coolantToOilDelta: 7
        )
    }

    private func captureFuelSystemData() async -> FuelSystemCaptureData {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return FuelSystemCaptureData(
            shortTermFuelTrim: 2.5,
            longTermFuelTrim: -1.0,
            fuelPressure: 350,
            mafReading: 3.2,
            injectorPulseWidth: 2.8
        )
    }

    private func captureIgnitionData() async -> IgnitionCaptureData {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return IgnitionCaptureData(
            timingAdvanceLeading: 10,
            timingAdvanceTrailing: -15,
            batteryVoltage: 14.2,
            coilDwellTime: 2.5
        )
    }

    private func captureOMPData() async -> OMPCaptureData {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return OMPCaptureData(
            position: 35,
            isActive: true,
            sensorVoltage: 2.4,
            status: .normal
        )
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
