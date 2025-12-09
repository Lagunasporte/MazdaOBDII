import Foundation

// MARK: - Motor Rotativo 13B-MSP Renesis

/// Representa el estado completo del motor rotativo Mazda 13B-MSP
public struct RotaryEngineState: Codable, Sendable {

    // MARK: - Identificación
    public let timestamp: Date
    public var engineType: EngineType = .renesis13BMSP

    // MARK: - Parámetros Principales
    public var rpm: Int = 0
    public var vehicleSpeed: Double = 0 // km/h
    public var throttlePosition: Double = 0 // %
    public var acceleratorPosition: Double = 0 // %

    // MARK: - Temperaturas (°C)
    public var coolantTemperature: Double = 0
    public var oilTemperature: Double = 0
    public var intakeAirTemperature: Double = 0
    public var catalystTemperature: Double = 0

    // MARK: - Sistema de Combustible
    public var mafVoltage: Double = 0 // V
    public var mafAirFlow: Double = 0 // g/s
    public var fuelPressure: Double = 0 // kPa
    public var shortTermFuelTrim: Double = 0 // % Bank 1
    public var longTermFuelTrim: Double = 0 // % Bank 1
    public var shortTermFuelTrimB2: Double = 0 // % Bank 2 (rotor trasero)
    public var longTermFuelTrimB2: Double = 0 // % Bank 2 (rotor trasero)
    public var fuelLevel: Double = 0 // %

    // MARK: - Carga y Presión del Motor
    public var engineLoad: Double = 0 // % (calculado por ECU)
    public var manifoldPressure: Double = 0 // kPa (MAP sensor)

    // MARK: - Sistema de Encendido
    public var ignitionTiming: Double = 0 // grados
    public var batteryVoltage: Double = 0 // V

    // MARK: - Compresión (crítico para rotativo)
    public var compressionRotor1Chamber1: Double = 0 // kg/cm²
    public var compressionRotor1Chamber2: Double = 0
    public var compressionRotor1Chamber3: Double = 0
    public var compressionRotor2Chamber1: Double = 0
    public var compressionRotor2Chamber2: Double = 0
    public var compressionRotor2Chamber3: Double = 0

    // MARK: - Sistema OMP (Oil Metering Pump)
    public var ompPosition: Double = 0 // %
    public var ompStatus: OMPStatus = .unknown

    // MARK: - Sensores O2
    public var o2SensorBank1Sensor1: Double = 0 // V
    public var o2SensorBank1Sensor2: Double = 0 // V

    // MARK: - Estado del Vehículo
    public var brakePedalPressed: Bool = false
    public var handbrakeEngaged: Bool = false
    public var neutralPosition: Bool = false
    public var clutchPressed: Bool = false
    public var steeringAngle: Double = 0 // grados

    // MARK: - TPMS
    public var tirePressureFrontLeft: Double = 0 // psi
    public var tirePressureFrontRight: Double = 0
    public var tirePressureRearLeft: Double = 0
    public var tirePressureRearRight: Double = 0

    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}

// MARK: - Tipos de Motor

public enum EngineType: String, Codable, Sendable, CaseIterable {
    case renesis13BMSP = "13B-MSP Renesis"
    case renesis13BMSP_6Port = "13B-MSP Renesis 6-Port"

    public var description: String {
        switch self {
        case .renesis13BMSP:
            return "Motor rotativo 1.3L 2-rotor (Serie 1: 2003-2008)"
        case .renesis13BMSP_6Port:
            return "Motor rotativo 1.3L 2-rotor 6-port (Serie 2: 2009-2012)"
        }
    }

    public var maxRPM: Int {
        switch self {
        case .renesis13BMSP: return 9000
        case .renesis13BMSP_6Port: return 9500
        }
    }

    public var redlineRPM: Int {
        switch self {
        case .renesis13BMSP: return 8500
        case .renesis13BMSP_6Port: return 9000
        }
    }
}

// MARK: - Estado OMP

public enum OMPStatus: String, Codable, Sendable {
    case unknown = "Desconocido"
    case normal = "Normal"
    case warning = "Advertencia"
    case fault = "Fallo"
    case limp = "Modo Emergencia"
}

// MARK: - Análisis de Compresión

public struct CompressionAnalysis: Codable, Sendable {
    public let timestamp: Date
    public let rotor1Readings: [Double] // 3 cámaras
    public let rotor2Readings: [Double] // 3 cámaras
    public let engineTemperature: Double // °C - debe ser >80°C para test válido
    public let crankingRPM: Int // ~250 RPM ideal

    public var rotor1Average: Double {
        rotor1Readings.reduce(0, +) / Double(rotor1Readings.count)
    }

    public var rotor2Average: Double {
        rotor2Readings.reduce(0, +) / Double(rotor2Readings.count)
    }

    public var overallAverage: Double {
        (rotor1Average + rotor2Average) / 2
    }

    public var maxDifferenceWithinRotor1: Double {
        guard let max = rotor1Readings.max(), let min = rotor1Readings.min() else { return 0 }
        return max - min
    }

    public var maxDifferenceWithinRotor2: Double {
        guard let max = rotor2Readings.max(), let min = rotor2Readings.min() else { return 0 }
        return max - min
    }

    public var differenceBetweenRotors: Double {
        abs(rotor1Average - rotor2Average)
    }

    public var diagnosis: CompressionDiagnosis {
        // Especificaciones Mazda:
        // - Estándar: 830 kPa (8.5 kg/cm²) @ 250 RPM
        // - Mínimo: 680 kPa (6.9 kg/cm²)
        // - Diferencia máx entre cámaras: 150 kPa (1.5 kg/cm²)
        // - Diferencia máx entre rotores: 100 kPa (1.0 kg/cm²)

        let avgKg = overallAverage

        // Verificar si el test es válido
        guard engineTemperature >= 80 else {
            return .invalidTest(reason: "Motor frío (\(Int(engineTemperature))°C). Calentar a >80°C")
        }

        // Evaluar estado general
        if avgKg >= 8.5 {
            return .excellent
        } else if avgKg >= 8.0 {
            if maxDifferenceWithinRotor1 > 1.5 || maxDifferenceWithinRotor2 > 1.5 {
                return .unevenChambers
            }
            if differenceBetweenRotors > 1.0 {
                return .unevenRotors
            }
            return .veryGood
        } else if avgKg >= 7.5 {
            return .acceptable
        } else if avgKg >= 7.0 {
            return .marginal
        } else if avgKg >= 6.5 {
            return .poor
        } else {
            return .failed
        }
    }

    public init(rotor1: [Double], rotor2: [Double], temp: Double, rpm: Int) {
        self.timestamp = Date()
        self.rotor1Readings = rotor1
        self.rotor2Readings = rotor2
        self.engineTemperature = temp
        self.crankingRPM = rpm
    }
}

public enum CompressionDiagnosis: Sendable {
    case excellent
    case veryGood
    case acceptable
    case marginal
    case poor
    case failed
    case unevenChambers
    case unevenRotors
    case invalidTest(reason: String)

    public var title: String {
        switch self {
        case .excellent: return "Excelente"
        case .veryGood: return "Muy Bueno"
        case .acceptable: return "Aceptable"
        case .marginal: return "Marginal"
        case .poor: return "Deficiente"
        case .failed: return "Fallido"
        case .unevenChambers: return "Cámaras Desiguales"
        case .unevenRotors: return "Rotores Desiguales"
        case .invalidTest: return "Test Inválido"
        }
    }

    public var description: String {
        switch self {
        case .excellent:
            return "Motor en condiciones óptimas. Apex seals, corner seals y side seals en perfecto estado."
        case .veryGood:
            return "Motor en muy buen estado. Desgaste normal mínimo."
        case .acceptable:
            return "Motor funcional. Monitorear evolución. Mayoría de motores RX-8 con kilometraje están aquí."
        case .marginal:
            return "Motor con desgaste significativo. Planificar rebuild en próximos 20,000-30,000 km."
        case .poor:
            return "Motor fallando. Problemas de arranque en caliente probables. Rebuild necesario pronto."
        case .failed:
            return "Motor requiere rebuild inmediato. Apex seals probablemente dañados."
        case .unevenChambers:
            return "Diferencia >1.5 kg/cm² entre cámaras. Posible apex seal dañado o corner seal con fugas."
        case .unevenRotors:
            return "Diferencia >1.0 kg/cm² entre rotores. Un rotor más desgastado que el otro."
        case .invalidTest(let reason):
            return reason
        }
    }

    public var color: String { // Para UI
        switch self {
        case .excellent, .veryGood: return "green"
        case .acceptable: return "yellow"
        case .marginal: return "orange"
        case .poor, .failed, .unevenChambers, .unevenRotors: return "red"
        case .invalidTest: return "gray"
        }
    }

    public var recommendations: [String] {
        switch self {
        case .excellent:
            return [
                "Mantener intervalos de cambio de aceite (5,000 km)",
                "Usar aceite 5W-30 de calidad",
                "Verificar OMP funcionando correctamente"
            ]
        case .veryGood:
            return [
                "Continuar mantenimiento regular",
                "Revisar bujías cada 30,000 km",
                "Monitorear consumo de aceite"
            ]
        case .acceptable:
            return [
                "Realizar test de compresión cada 15,000 km",
                "Evitar arranques en frío cortos",
                "Considerar aditivo de motor (opcional)"
            ]
        case .marginal:
            return [
                "Comenzar a buscar motor de reemplazo o rebuild",
                "Evitar circuito/uso agresivo",
                "Test de compresión cada 5,000 km"
            ]
        case .poor, .failed:
            return [
                "Rebuild o reemplazo de motor necesario",
                "No usar para viajes largos",
                "Contactar especialista en rotativos"
            ]
        case .unevenChambers:
            return [
                "Posible apex seal con grieta",
                "Verificar corner seals",
                "Desmontar para inspección visual"
            ]
        case .unevenRotors:
            return [
                "Un rotor más desgastado",
                "Verificar inyección de aceite OMP",
                "Considerar rebuild parcial"
            ]
        case .invalidTest:
            return [
                "Calentar motor completamente (>80°C)",
                "Batería completamente cargada",
                "Repetir test en condiciones correctas"
            ]
        }
    }
}

// MARK: - Alertas del Motor

public struct EngineAlert: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: AlertType
    public let severity: AlertSeverity
    public let parameter: String
    public let value: Double
    public let threshold: Double
    public let message: String

    public init(type: AlertType, severity: AlertSeverity, parameter: String, value: Double, threshold: Double, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.severity = severity
        self.parameter = parameter
        self.value = value
        self.threshold = threshold
        self.message = message
    }
}

public enum AlertType: String, Codable, Sendable {
    case temperature = "Temperatura"
    case pressure = "Presión"
    case voltage = "Voltaje"
    case rpm = "RPM"
    case omp = "Sistema OMP"
    case compression = "Compresión"
    case fuel = "Combustible"
    case ignition = "Encendido"
}

public enum AlertSeverity: String, Codable, Sendable {
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

// MARK: - Umbrales de Alerta RX-8

public struct RX8AlertThresholds {
    // Temperaturas (°C)
    public static let coolantWarning: Double = 100
    public static let coolantCritical: Double = 105
    public static let oilWarning: Double = 120
    public static let oilCritical: Double = 130
    public static let intakeWarning: Double = 55
    public static let intakeCritical: Double = 65

    // Voltaje
    public static let batteryLow: Double = 11.5
    public static let batteryCritical: Double = 10.5

    // RPM
    public static let rpmRedline: Int = 9000
    public static let rpmLimit: Int = 9500

    // Compresión mínima (kg/cm²)
    public static let compressionMinimum: Double = 6.5
    public static let compressionWarning: Double = 7.0
}
