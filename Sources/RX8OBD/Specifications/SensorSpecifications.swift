import Foundation

// MARK: - Sensor Specifications from Mazda Workshop Manual
// Valores óptimos extraídos del manual de taller Mazda RX-8 (2003-2012)

/// Operating condition for sensor validation
public enum OperatingCondition: String, CaseIterable, Codable {
    case coldStart = "Arranque en frío"
    case warmIdle = "Ralentí en caliente"
    case normalDriving = "Conducción normal"
    case highLoad = "Alta carga"
    case deceleration = "Deceleración"
    case wot = "WOT (Aceleración máxima)"
}

/// Sensor status after validation
public enum SensorStatus: String, Codable {
    case optimal = "Óptimo"
    case warning = "Atención"
    case critical = "Crítico"
    case unknown = "Desconocido"
    case outOfRange = "Fuera de rango"

    public var color: String {
        switch self {
        case .optimal: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        case .unknown: return "gray"
        case .outOfRange: return "orange"
        }
    }
}

/// Sensor specification with optimal ranges
public struct SensorSpec: Identifiable, Codable {
    public let id: String
    public let name: String
    public let nameES: String
    public let unit: String
    public let description: String
    public let conditions: [ConditionSpec]
    public let workshopNotes: String?
    public let rotarySpecific: Bool

    public init(id: String, name: String, nameES: String, unit: String, description: String,
                conditions: [ConditionSpec], workshopNotes: String? = nil, rotarySpecific: Bool = false) {
        self.id = id
        self.name = name
        self.nameES = nameES
        self.unit = unit
        self.description = description
        self.conditions = conditions
        self.workshopNotes = workshopNotes
        self.rotarySpecific = rotarySpecific
    }
}

/// Specification for a specific operating condition
public struct ConditionSpec: Codable {
    public let condition: OperatingCondition
    public let minValue: Double
    public let maxValue: Double
    public let optimalValue: Double?
    public let warningLow: Double?
    public let warningHigh: Double?
    public let criticalLow: Double?
    public let criticalHigh: Double?

    public init(condition: OperatingCondition, minValue: Double, maxValue: Double,
                optimalValue: Double? = nil, warningLow: Double? = nil, warningHigh: Double? = nil,
                criticalLow: Double? = nil, criticalHigh: Double? = nil) {
        self.condition = condition
        self.minValue = minValue
        self.maxValue = maxValue
        self.optimalValue = optimalValue
        self.warningLow = warningLow
        self.warningHigh = warningHigh
        self.criticalLow = criticalLow
        self.criticalHigh = criticalHigh
    }

    public func validate(_ value: Double) -> SensorStatus {
        if let criticalLow = criticalLow, value < criticalLow { return .critical }
        if let criticalHigh = criticalHigh, value > criticalHigh { return .critical }
        if let warningLow = warningLow, value < warningLow { return .warning }
        if let warningHigh = warningHigh, value > warningHigh { return .warning }
        if value >= minValue && value <= maxValue { return .optimal }
        return .outOfRange
    }
}

/// Validation result for a sensor reading
public struct SensorValidation: Identifiable {
    public let id = UUID()
    public let sensorId: String
    public let sensorName: String
    public let currentValue: Double
    public let unit: String
    public let status: SensorStatus
    public let condition: OperatingCondition
    public let expectedRange: String
    public let recommendation: String?
    public let timestamp: Date

    public init(sensorId: String, sensorName: String, currentValue: Double, unit: String,
                status: SensorStatus, condition: OperatingCondition, expectedRange: String,
                recommendation: String? = nil) {
        self.sensorId = sensorId
        self.sensorName = sensorName
        self.currentValue = currentValue
        self.unit = unit
        self.status = status
        self.condition = condition
        self.expectedRange = expectedRange
        self.recommendation = recommendation
        self.timestamp = Date()
    }
}

// MARK: - RX-8 Sensor Database (from Mazda Workshop Manual)

public struct RX8SensorSpecs {

    // MARK: - Engine Sensors

    /// Coolant Temperature Sensor (ECT)
    /// Manual de Taller: Sección 01-10A-14
    public static let coolantTemp = SensorSpec(
        id: "ect",
        name: "Engine Coolant Temperature",
        nameES: "Temperatura del Refrigerante",
        unit: "°C",
        description: "Sensor de temperatura del refrigerante del motor",
        conditions: [
            ConditionSpec(condition: .coldStart, minValue: -40, maxValue: 40,
                         optimalValue: 20, criticalLow: -40),
            ConditionSpec(condition: .warmIdle, minValue: 82, maxValue: 95,
                         optimalValue: 88, warningHigh: 98, criticalHigh: 105),
            ConditionSpec(condition: .normalDriving, minValue: 85, maxValue: 100,
                         optimalValue: 90, warningHigh: 102, criticalHigh: 108),
            ConditionSpec(condition: .highLoad, minValue: 90, maxValue: 105,
                         optimalValue: 95, warningHigh: 108, criticalHigh: 115)
        ],
        workshopNotes: """
            El motor rotativo es sensible al sobrecalentamiento.
            Valores por encima de 105°C pueden causar deformación de las housings.
            Verificar termostato si no alcanza 82°C en 10 minutos.
            Rango de resistencia del sensor: 2.1-2.7 kΩ a 20°C, 0.29-0.35 kΩ a 80°C
            """,
        rotarySpecific: true
    )

    /// Oil Temperature Sensor
    /// Manual de Taller: Sección 01-10A-18
    public static let oilTemp = SensorSpec(
        id: "oil_temp",
        name: "Engine Oil Temperature",
        nameES: "Temperatura del Aceite",
        unit: "°C",
        description: "Sensor de temperatura del aceite del motor",
        conditions: [
            ConditionSpec(condition: .coldStart, minValue: -20, maxValue: 40, optimalValue: 20),
            ConditionSpec(condition: .warmIdle, minValue: 70, maxValue: 100,
                         optimalValue: 85, warningHigh: 110),
            ConditionSpec(condition: .normalDriving, minValue: 80, maxValue: 110,
                         optimalValue: 95, warningHigh: 120, criticalHigh: 130),
            ConditionSpec(condition: .highLoad, minValue: 90, maxValue: 120,
                         optimalValue: 105, warningHigh: 125, criticalHigh: 135),
            ConditionSpec(condition: .wot, minValue: 100, maxValue: 130,
                         optimalValue: 110, warningHigh: 135, criticalHigh: 145)
        ],
        workshopNotes: """
            El aceite del motor rotativo lubrica los apex seals.
            Temperatura crítica máxima: 135°C - por encima hay riesgo de daño a los sellos.
            Usar siempre aceite 5W-30 o 5W-40 de calidad.
            El sistema OMP inyecta aceite adicional a altas temperaturas.
            """,
        rotarySpecific: true
    )

    /// Intake Air Temperature (IAT)
    /// Manual de Taller: Sección 01-10A-22
    public static let intakeAirTemp = SensorSpec(
        id: "iat",
        name: "Intake Air Temperature",
        nameES: "Temperatura del Aire de Admisión",
        unit: "°C",
        description: "Sensor de temperatura del aire de admisión",
        conditions: [
            ConditionSpec(condition: .coldStart, minValue: -40, maxValue: 50, optimalValue: 25),
            ConditionSpec(condition: .warmIdle, minValue: 20, maxValue: 60,
                         optimalValue: 35, warningHigh: 65),
            ConditionSpec(condition: .normalDriving, minValue: 25, maxValue: 55,
                         optimalValue: 40, warningHigh: 60),
            ConditionSpec(condition: .highLoad, minValue: 30, maxValue: 70,
                         optimalValue: 45, warningHigh: 75, criticalHigh: 85)
        ],
        workshopNotes: """
            Temperatura alta de admisión reduce potencia.
            Valores superiores a 60°C pueden indicar heat soak.
            Verificar filtro de aire y sistema de admisión si hay lecturas anormales.
            Resistencia del sensor: 5.3 kΩ a 0°C, 2.5 kΩ a 20°C
            """
    )

    /// Mass Air Flow (MAF)
    /// Manual de Taller: Sección 01-10A-26
    public static let maf = SensorSpec(
        id: "maf",
        name: "Mass Air Flow",
        nameES: "Flujo de Aire Másico",
        unit: "g/s",
        description: "Sensor de flujo de masa de aire",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 2.5, maxValue: 5.0,
                         optimalValue: 3.5, warningLow: 2.0, warningHigh: 6.0),
            ConditionSpec(condition: .normalDriving, minValue: 15, maxValue: 80,
                         optimalValue: 40),
            ConditionSpec(condition: .highLoad, minValue: 60, maxValue: 150,
                         optimalValue: 100),
            ConditionSpec(condition: .wot, minValue: 120, maxValue: 200,
                         optimalValue: 160, warningLow: 100)
        ],
        workshopNotes: """
            El MAF es crítico para la mezcla aire/combustible.
            Valores bajos en ralentí pueden indicar fuga de vacío.
            Limpiar el MAF con spray específico si hay lecturas erráticas.
            Voltaje de salida: 0.2-4.8V (0.2V mínimo flujo, 4.8V máximo)
            """,
        rotarySpecific: true
    )

    /// Throttle Position Sensor (TPS)
    /// Manual de Taller: Sección 01-10A-30
    public static let throttlePosition = SensorSpec(
        id: "tps",
        name: "Throttle Position",
        nameES: "Posición del Acelerador",
        unit: "%",
        description: "Sensor de posición del acelerador",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 0, maxValue: 3,
                         optimalValue: 0, warningHigh: 5),
            ConditionSpec(condition: .normalDriving, minValue: 5, maxValue: 60,
                         optimalValue: 25),
            ConditionSpec(condition: .highLoad, minValue: 50, maxValue: 85,
                         optimalValue: 70),
            ConditionSpec(condition: .wot, minValue: 95, maxValue: 100,
                         optimalValue: 100, warningLow: 90)
        ],
        workshopNotes: """
            En ralentí debe estar entre 0-3%.
            Si no llega al 100% en WOT, verificar cable del acelerador.
            Voltaje: 0.3-0.7V cerrado, 4.0-4.8V abierto completamente.
            El cuerpo de aceleración electrónico (DBW) se autocalibra al encender.
            """
    )

    /// Engine RPM
    /// Manual de Taller: Sección 01-10A-8
    public static let rpm = SensorSpec(
        id: "rpm",
        name: "Engine Speed",
        nameES: "Revoluciones del Motor",
        unit: "RPM",
        description: "Velocidad de giro del motor",
        conditions: [
            ConditionSpec(condition: .coldStart, minValue: 1200, maxValue: 1800,
                         optimalValue: 1500, warningLow: 1000, warningHigh: 2000),
            ConditionSpec(condition: .warmIdle, minValue: 700, maxValue: 900,
                         optimalValue: 800, warningLow: 600, warningHigh: 1000,
                         criticalLow: 500),
            ConditionSpec(condition: .normalDriving, minValue: 2000, maxValue: 5000,
                         optimalValue: 3500),
            ConditionSpec(condition: .highLoad, minValue: 4000, maxValue: 7500,
                         optimalValue: 6000),
            ConditionSpec(condition: .wot, minValue: 7500, maxValue: 9000,
                         optimalValue: 8500, criticalHigh: 9500)
        ],
        workshopNotes: """
            Ralentí frío: 1200-1800 RPM (baja gradualmente al calentar)
            Ralentí caliente: 750-850 RPM
            Línea roja: 9000 RPM (Series 1), 9000 RPM (Series 2)
            Corte de inyección: 9500 RPM
            El motor rotativo vibra más a bajas RPM - es normal.
            """,
        rotarySpecific: true
    )

    /// Oil Pressure
    /// Manual de Taller: Sección 01-10A-40
    public static let oilPressure = SensorSpec(
        id: "oil_pressure",
        name: "Oil Pressure",
        nameES: "Presión de Aceite",
        unit: "bar",
        description: "Presión del aceite del motor",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 0.8, maxValue: 2.0,
                         optimalValue: 1.2, warningLow: 0.6, criticalLow: 0.4),
            ConditionSpec(condition: .normalDriving, minValue: 2.5, maxValue: 5.0,
                         optimalValue: 3.5, warningLow: 2.0),
            ConditionSpec(condition: .highLoad, minValue: 3.0, maxValue: 6.0,
                         optimalValue: 4.5, warningLow: 2.5, criticalLow: 2.0)
        ],
        workshopNotes: """
            La presión de aceite es vital para los apex seals.
            Presión mínima en ralentí caliente: 0.8 bar
            Presión normal a 3000 RPM: 3-4 bar
            Si la luz de presión se enciende, PARAR INMEDIATAMENTE.
            Verificar nivel de aceite y estado de la bomba si hay lecturas bajas.
            """,
        rotarySpecific: true
    )

    /// Manifold Absolute Pressure (MAP)
    /// Manual de Taller: Sección 01-10A-34
    public static let manifoldPressure = SensorSpec(
        id: "map",
        name: "Manifold Absolute Pressure",
        nameES: "Presión Absoluta del Colector",
        unit: "kPa",
        description: "Sensor de presión absoluta del colector de admisión",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 25, maxValue: 40,
                         optimalValue: 30, warningHigh: 50),
            ConditionSpec(condition: .deceleration, minValue: 20, maxValue: 30,
                         optimalValue: 25),
            ConditionSpec(condition: .normalDriving, minValue: 40, maxValue: 80,
                         optimalValue: 60),
            ConditionSpec(condition: .wot, minValue: 95, maxValue: 105,
                         optimalValue: 101)
        ],
        workshopNotes: """
            En ralentí debe mostrar vacío (25-40 kPa).
            WOT debe acercarse a presión atmosférica (~101 kPa).
            Valores altos en ralentí indican fuga de vacío.
            Voltaje de salida: 0.5-4.5V
            """
    )

    // MARK: - Fuel System Sensors

    /// Short Term Fuel Trim (STFT)
    public static let stft = SensorSpec(
        id: "stft",
        name: "Short Term Fuel Trim",
        nameES: "Ajuste de Combustible a Corto Plazo",
        unit: "%",
        description: "Corrección instantánea de la mezcla aire/combustible",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: -10, maxValue: 10,
                         optimalValue: 0, warningLow: -15, warningHigh: 15,
                         criticalLow: -25, criticalHigh: 25),
            ConditionSpec(condition: .normalDriving, minValue: -10, maxValue: 10,
                         optimalValue: 0, warningLow: -15, warningHigh: 15),
            ConditionSpec(condition: .highLoad, minValue: -15, maxValue: 15,
                         optimalValue: 0, warningLow: -20, warningHigh: 20)
        ],
        workshopNotes: """
            Valores positivos: ECU añade combustible (mezcla pobre detectada)
            Valores negativos: ECU reduce combustible (mezcla rica detectada)
            Valores fuera de ±10% en ralentí indican problema.
            Causas comunes: fugas de vacío, inyectores sucios, MAF defectuoso.
            """,
        rotarySpecific: true
    )

    /// Long Term Fuel Trim (LTFT)
    public static let ltft = SensorSpec(
        id: "ltft",
        name: "Long Term Fuel Trim",
        nameES: "Ajuste de Combustible a Largo Plazo",
        unit: "%",
        description: "Corrección aprendida de la mezcla aire/combustible",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: -8, maxValue: 8,
                         optimalValue: 0, warningLow: -12, warningHigh: 12,
                         criticalLow: -20, criticalHigh: 20),
            ConditionSpec(condition: .normalDriving, minValue: -8, maxValue: 8,
                         optimalValue: 0, warningLow: -12, warningHigh: 12)
        ],
        workshopNotes: """
            LTFT refleja adaptaciones a largo plazo.
            Valores altos positivos: sistema constantemente pobre (fugas, inyectores)
            Valores altos negativos: sistema constantemente rico (presión combustible alta)
            Se resetea al desconectar batería o borrar DTCs.
            """
    )

    /// Fuel Pressure
    public static let fuelPressure = SensorSpec(
        id: "fuel_pressure",
        name: "Fuel Pressure",
        nameES: "Presión de Combustible",
        unit: "bar",
        description: "Presión del sistema de combustible",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 3.0, maxValue: 3.5,
                         optimalValue: 3.2, warningLow: 2.8, criticalLow: 2.5),
            ConditionSpec(condition: .wot, minValue: 3.8, maxValue: 4.5,
                         optimalValue: 4.0, warningLow: 3.5)
        ],
        workshopNotes: """
            Presión nominal: 3.2 bar (sin vacío)
            Con vacío en ralentí: ~2.7 bar
            Verificar regulador de presión si hay variaciones.
            Bomba de combustible debe mantener presión estable.
            """
    )

    // MARK: - Ignition System

    /// Ignition Timing Advance
    public static let ignitionTiming = SensorSpec(
        id: "timing",
        name: "Ignition Timing",
        nameES: "Avance de Encendido",
        unit: "°BTDC",
        description: "Grados de avance del encendido",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 5, maxValue: 15,
                         optimalValue: 10, warningLow: 0),
            ConditionSpec(condition: .normalDriving, minValue: 20, maxValue: 40,
                         optimalValue: 30),
            ConditionSpec(condition: .highLoad, minValue: 25, maxValue: 45,
                         optimalValue: 35),
            ConditionSpec(condition: .wot, minValue: 15, maxValue: 30,
                         optimalValue: 22)
        ],
        workshopNotes: """
            El RX-8 usa sistema de encendido directo con 4 bobinas.
            Leading plugs: bobinas 1 y 2
            Trailing plugs: bobinas 3 y 4
            Avance se reduce con detonación detectada.
            Bujías leading: NGK RE7C-L o RE9B-T
            Bujías trailing: NGK RE8C-L o RE9B-T
            """,
        rotarySpecific: true
    )

    // MARK: - Oxygen Sensors

    /// Oxygen Sensor Bank 1 Sensor 1 (Pre-Cat)
    public static let o2PreCat = SensorSpec(
        id: "o2_pre_cat",
        name: "O2 Sensor Pre-Catalyst",
        nameES: "Sonda Lambda Pre-Catalizador",
        unit: "V",
        description: "Sensor de oxígeno antes del catalizador",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 0.1, maxValue: 0.9,
                         optimalValue: 0.45),
            ConditionSpec(condition: .normalDriving, minValue: 0.1, maxValue: 0.9,
                         optimalValue: 0.45)
        ],
        workshopNotes: """
            Debe oscilar entre 0.1V y 0.9V constantemente (switching).
            Frecuencia de oscilación: 1-3 Hz en condiciones normales.
            Si está fija en un valor, el sensor está defectuoso.
            Rico: >0.45V, Pobre: <0.45V
            Calentar motor antes de verificar funcionamiento.
            """
    )

    /// Oxygen Sensor Bank 1 Sensor 2 (Post-Cat)
    public static let o2PostCat = SensorSpec(
        id: "o2_post_cat",
        name: "O2 Sensor Post-Catalyst",
        nameES: "Sonda Lambda Post-Catalizador",
        unit: "V",
        description: "Sensor de oxígeno después del catalizador",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 0.5, maxValue: 0.8,
                         optimalValue: 0.65),
            ConditionSpec(condition: .normalDriving, minValue: 0.5, maxValue: 0.8,
                         optimalValue: 0.65)
        ],
        workshopNotes: """
            Debe ser más estable que el sensor pre-cat.
            Valor típico: 0.6-0.7V estable
            Si oscila como el pre-cat, el catalizador está agotado.
            Importante para verificar eficiencia del catalizador.
            """
    )

    // MARK: - RX-8 Specific Sensors

    /// Oil Metering Pump (OMP) Position
    public static let ompPosition = SensorSpec(
        id: "omp",
        name: "Oil Metering Pump Position",
        nameES: "Posición de la Bomba de Aceite OMP",
        unit: "%",
        description: "Posición del sistema de lubricación de ápex seals",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 20, maxValue: 40,
                         optimalValue: 30, warningLow: 15, criticalLow: 10),
            ConditionSpec(condition: .normalDriving, minValue: 30, maxValue: 60,
                         optimalValue: 45),
            ConditionSpec(condition: .highLoad, minValue: 50, maxValue: 80,
                         optimalValue: 65),
            ConditionSpec(condition: .wot, minValue: 70, maxValue: 100,
                         optimalValue: 85, warningLow: 60)
        ],
        workshopNotes: """
            El OMP inyecta aceite directamente en las cámaras de combustión.
            Crítico para la lubricación de los apex seals.
            Aumenta con RPM y carga del motor.
            Si no aumenta con la carga, verificar solenoide OMP.
            Consumo normal de aceite: 0.5-1L cada 3000-5000 km.
            """,
        rotarySpecific: true
    )

    /// Secondary Shutter Valve (SSV) Position
    public static let ssvPosition = SensorSpec(
        id: "ssv",
        name: "Secondary Shutter Valve Position",
        nameES: "Posición de Válvula Secundaria SSV",
        unit: "%",
        description: "Posición de la válvula de admisión secundaria",
        conditions: [
            ConditionSpec(condition: .warmIdle, minValue: 0, maxValue: 5,
                         optimalValue: 0),
            ConditionSpec(condition: .normalDriving, minValue: 0, maxValue: 50,
                         optimalValue: 25),
            ConditionSpec(condition: .highLoad, minValue: 80, maxValue: 100,
                         optimalValue: 95),
            ConditionSpec(condition: .wot, minValue: 95, maxValue: 100,
                         optimalValue: 100, warningLow: 90)
        ],
        workshopNotes: """
            La SSV controla el flujo de aire secundario.
            Cerrada en ralentí y bajas RPM para mejor torque bajo.
            Abre completamente a altas RPM para máximo flujo.
            Si no abre completamente, limitar potencia notable.
            Verificar actuador y varillaje si hay problemas.
            """,
        rotarySpecific: true
    )

    /// Compression (Relative)
    public static let compression = SensorSpec(
        id: "compression",
        name: "Engine Compression",
        nameES: "Compresión del Motor",
        unit: "kPa",
        description: "Compresión relativa del motor rotativo",
        conditions: [
            ConditionSpec(condition: .coldStart, minValue: 750, maxValue: 900,
                         optimalValue: 850, warningLow: 700, criticalLow: 650),
            ConditionSpec(condition: .warmIdle, minValue: 700, maxValue: 850,
                         optimalValue: 800, warningLow: 650, criticalLow: 600)
        ],
        workshopNotes: """
            Test de compresión rotativo usa herramienta especial Mazda.
            Valores mínimos por cámara: 6.0 kg/cm² (588 kPa)
            Diferencia máxima entre cámaras: 1.0 kg/cm²
            Valores bajos indican desgaste de apex seals.
            Realizar test con motor caliente y acelerador abierto.
            Número de rotaciones para test: 7-10 rotaciones del rotor.
            """,
        rotarySpecific: true
    )

    // MARK: - All Sensors Collection

    public static let allSensors: [SensorSpec] = [
        coolantTemp,
        oilTemp,
        intakeAirTemp,
        maf,
        throttlePosition,
        rpm,
        oilPressure,
        manifoldPressure,
        stft,
        ltft,
        fuelPressure,
        ignitionTiming,
        o2PreCat,
        o2PostCat,
        ompPosition,
        ssvPosition,
        compression
    ]

    public static let rotarySpecificSensors: [SensorSpec] = allSensors.filter { $0.rotarySpecific }

    public static func sensor(byId id: String) -> SensorSpec? {
        return allSensors.first { $0.id == id }
    }
}

// MARK: - Real-Time Sensor Analyzer

public class SensorAnalyzer: ObservableObject {
    @Published public var validations: [SensorValidation] = []
    @Published public var currentCondition: OperatingCondition = .warmIdle
    @Published public var overallHealth: Double = 100.0
    @Published public var criticalIssues: [SensorValidation] = []
    @Published public var warnings: [SensorValidation] = []

    public init() {}

    /// Detect operating condition based on sensor values
    public func detectCondition(rpm: Double, throttle: Double, coolantTemp: Double, speed: Double) -> OperatingCondition {
        if coolantTemp < 70 {
            return .coldStart
        } else if throttle > 90 {
            return .wot
        } else if throttle < 5 && rpm < 1000 {
            return .warmIdle
        } else if throttle < 3 && speed > 30 {
            return .deceleration
        } else if throttle > 70 && rpm > 5000 {
            return .highLoad
        } else {
            return .normalDriving
        }
    }

    /// Validate a single sensor reading
    public func validate(sensorId: String, value: Double, condition: OperatingCondition) -> SensorValidation? {
        guard let spec = RX8SensorSpecs.sensor(byId: sensorId) else { return nil }
        guard let conditionSpec = spec.conditions.first(where: { $0.condition == condition }) else { return nil }

        let status = conditionSpec.validate(value)
        let rangeStr = "\(conditionSpec.minValue) - \(conditionSpec.maxValue) \(spec.unit)"

        var recommendation: String? = nil
        if status == .warning || status == .critical {
            recommendation = generateRecommendation(spec: spec, value: value, conditionSpec: conditionSpec, status: status)
        }

        return SensorValidation(
            sensorId: sensorId,
            sensorName: spec.nameES,
            currentValue: value,
            unit: spec.unit,
            status: status,
            condition: condition,
            expectedRange: rangeStr,
            recommendation: recommendation
        )
    }

    /// Validate all sensors and update health score
    public func validateAll(readings: [String: Double], rpm: Double, throttle: Double, coolantTemp: Double, speed: Double) {
        currentCondition = detectCondition(rpm: rpm, throttle: throttle, coolantTemp: coolantTemp, speed: speed)

        validations.removeAll()
        criticalIssues.removeAll()
        warnings.removeAll()

        for (sensorId, value) in readings {
            if let validation = validate(sensorId: sensorId, value: value, condition: currentCondition) {
                validations.append(validation)

                switch validation.status {
                case .critical:
                    criticalIssues.append(validation)
                case .warning:
                    warnings.append(validation)
                default:
                    break
                }
            }
        }

        calculateOverallHealth()
    }

    private func calculateOverallHealth() {
        guard !validations.isEmpty else {
            overallHealth = 100.0
            return
        }

        var score = 100.0

        for validation in validations {
            switch validation.status {
            case .critical:
                score -= 15.0
            case .warning:
                score -= 5.0
            case .outOfRange:
                score -= 3.0
            default:
                break
            }
        }

        overallHealth = max(0, score)
    }

    private func generateRecommendation(spec: SensorSpec, value: Double, conditionSpec: ConditionSpec, status: SensorStatus) -> String {
        switch spec.id {
        case "ect":
            if value > (conditionSpec.warningHigh ?? 100) {
                return "Motor sobrecalentando. Verificar nivel de refrigerante, termostato y ventilador."
            } else if value < conditionSpec.minValue {
                return "Motor no alcanza temperatura. Verificar termostato (puede estar abierto permanentemente)."
            }
        case "oil_temp":
            if value > (conditionSpec.warningHigh ?? 120) {
                return "Aceite sobrecalentado. Reducir carga, verificar nivel y estado del aceite."
            }
        case "rpm":
            if value < (conditionSpec.warningLow ?? 600) {
                return "Ralentí inestable. Verificar cuerpo de aceleración, válvula IAC, y fugas de vacío."
            } else if value > (conditionSpec.criticalHigh ?? 9000) {
                return "¡RPM excesivas! Riesgo de daño al motor."
            }
        case "stft", "ltft":
            if value > 10 {
                return "Mezcla pobre. Verificar fugas de vacío, inyectores, sensor MAF."
            } else if value < -10 {
                return "Mezcla rica. Verificar regulador de presión, inyectores con fugas."
            }
        case "omp":
            if value < (conditionSpec.warningLow ?? 20) {
                return "OMP bajo. Verificar solenoide OMP y nivel de aceite. Riesgo para apex seals."
            }
        case "oil_pressure":
            if value < (conditionSpec.criticalLow ?? 0.5) {
                return "¡PARAR MOTOR! Presión de aceite crítica. Verificar nivel y bomba de aceite."
            }
        case "compression":
            if value < (conditionSpec.warningLow ?? 700) {
                return "Compresión baja. Posible desgaste de apex seals. Considerar rebuild."
            }
        default:
            break
        }

        return "Valor fuera del rango óptimo. Revisar sensor y sistemas relacionados."
    }
}
