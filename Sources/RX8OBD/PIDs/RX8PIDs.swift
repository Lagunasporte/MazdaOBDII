import Foundation

// MARK: - PIDs Específicos del Mazda RX-8
// Recopilados de: GitHub topolittle/RX8-CAN-BUS, FORScan, RX8Club, Torque Pro community

/// Protocolo base para todos los PIDs
public protocol OBDPID {
    var code: String { get }
    var name: String { get }
    var shortName: String { get }
    var description: String { get }
    var unit: String { get }
    var minValue: Double { get }
    var maxValue: Double { get }
    var header: String { get }
    var formula: (Data) -> Double { get }
    var category: PIDCategory { get }
}

public enum PIDCategory: String, CaseIterable, Sendable {
    case engine = "Motor"
    case temperature = "Temperaturas"
    case fuel = "Combustible"
    case ignition = "Encendido"
    case emissions = "Emisiones"
    case transmission = "Transmisión"
    case brakes = "Frenos"
    case steering = "Dirección"
    case tpms = "Presión Neumáticos"
    case electrical = "Eléctrico"
    case omp = "Sistema OMP"
    case diagnostic = "Diagnóstico"
}

// MARK: - PIDs CAN Bus Directos (Sin OBD2 - Lectura Directa)

public enum RX8CANPIDs {

    /// RPM del motor
    /// CAN ID: 0x201, Bytes 0-1, Fórmula: value / 4
    public static let rpm = CANPID(
        canID: 0x201,
        byteOffset: 0,
        byteLength: 2,
        name: "RPM",
        shortName: "RPM",
        unit: "rpm",
        formula: { data in Double(data.uint16(at: 0)) / 4.0 },
        minValue: 0,
        maxValue: 10000
    )

    /// Velocidad del vehículo
    /// CAN ID: 0x201, Bytes 4-5, Fórmula: (value - 10000) / 100
    public static let vehicleSpeed = CANPID(
        canID: 0x201,
        byteOffset: 4,
        byteLength: 2,
        name: "Velocidad",
        shortName: "VEL",
        unit: "km/h",
        formula: { data in (Double(data.uint16(at: 4)) - 10000) / 100 },
        minValue: 0,
        maxValue: 280
    )

    /// Posición del acelerador
    /// CAN ID: 0x201, Byte 6, Fórmula: value / 2
    public static let throttlePosition = CANPID(
        canID: 0x201,
        byteOffset: 6,
        byteLength: 1,
        name: "Posición Acelerador",
        shortName: "TPS",
        unit: "%",
        formula: { data in Double(data[6]) / 2.0 },
        minValue: 0,
        maxValue: 100
    )

    /// Pedal de freno presionado
    /// CAN ID: 0x212, Byte 5, Mask 0x08
    public static let brakePedal = CANPID(
        canID: 0x212,
        byteOffset: 5,
        byteLength: 1,
        name: "Pedal Freno",
        shortName: "BRK",
        unit: "",
        formula: { data in (data[5] & 0x08) != 0 ? 1.0 : 0.0 },
        minValue: 0,
        maxValue: 1,
        isBool: true
    )

    /// Freno de mano
    /// CAN ID: 0x212, Byte 4, Mask 0x40
    public static let handbrake = CANPID(
        canID: 0x212,
        byteOffset: 4,
        byteLength: 1,
        name: "Freno de Mano",
        shortName: "HBRK",
        unit: "",
        formula: { data in (data[4] & 0x40) != 0 ? 1.0 : 0.0 },
        minValue: 0,
        maxValue: 1,
        isBool: true
    )

    /// Posición Neutral
    /// CAN ID: 0x231, Byte 0, Mask 0x80, Invertido
    public static let neutralPosition = CANPID(
        canID: 0x231,
        byteOffset: 0,
        byteLength: 1,
        name: "Neutral",
        shortName: "N",
        unit: "",
        formula: { data in (data[0] & 0x80) == 0 ? 1.0 : 0.0 }, // Invertido
        minValue: 0,
        maxValue: 1,
        isBool: true
    )

    /// Temperatura del refrigerante
    /// CAN ID: 0x420, Byte 0, Fórmula: value - 40
    public static let coolantTemp = CANPID(
        canID: 0x420,
        byteOffset: 0,
        byteLength: 1,
        name: "Temp. Refrigerante",
        shortName: "ECT",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 150
    )

    /// Temperatura de admisión
    /// CAN ID: 0x250, Byte 3, Fórmula: value - 40
    public static let intakeAirTemp = CANPID(
        canID: 0x250,
        byteOffset: 3,
        byteLength: 1,
        name: "Temp. Admisión",
        shortName: "IAT",
        unit: "°C",
        formula: { data in Double(data[3]) - 40 },
        minValue: -40,
        maxValue: 100
    )

    /// Ángulo del volante
    /// CAN ID: 0x81, Bytes 2-3, Signed INT16
    public static let steeringAngle = CANPID(
        canID: 0x81,
        byteOffset: 2,
        byteLength: 2,
        name: "Ángulo Volante",
        shortName: "SAS",
        unit: "°",
        formula: { data in Double(data.int16(at: 2)) },
        minValue: -720,
        maxValue: 720
    )

    /// Warnings CAN ID 0x420 (MIL, Oil, Coolant, Alternator)
    public static let warningLights = CANPID(
        canID: 0x420,
        byteOffset: 1,
        byteLength: 1,
        name: "Luces de Aviso",
        shortName: "WARN",
        unit: "",
        formula: { data in Double(data[1]) },
        minValue: 0,
        maxValue: 255
    )

    /// ABS/DSC Warning
    /// CAN ID: 0x212
    public static let absDscWarning = CANPID(
        canID: 0x212,
        byteOffset: 0,
        byteLength: 1,
        name: "ABS/DSC Aviso",
        shortName: "ABS",
        unit: "",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 255
    )

    /// Todos los PIDs CAN directos
    public static let all: [CANPID] = [
        rpm, vehicleSpeed, throttlePosition, brakePedal, handbrake,
        neutralPosition, coolantTemp, intakeAirTemp, steeringAngle,
        warningLights, absDscWarning
    ]
}

// MARK: - PIDs OBD2 Modo 01 (Estándar)

public enum RX8OBD2StandardPIDs {

    public static let engineLoad = OBD2PID(
        mode: 0x01,
        pid: 0x04,
        name: "Carga del Motor",
        shortName: "LOAD",
        unit: "%",
        formula: { data in Double(data[0]) * 100.0 / 255.0 },
        minValue: 0,
        maxValue: 100
    )

    public static let coolantTemp = OBD2PID(
        mode: 0x01,
        pid: 0x05,
        name: "Temp. Refrigerante",
        shortName: "ECT",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 215
    )

    public static let shortTermFuelTrim = OBD2PID(
        mode: 0x01,
        pid: 0x06,
        name: "Ajuste Combustible Corto",
        shortName: "STFT",
        unit: "%",
        formula: { data in (Double(data[0]) - 128) * 100.0 / 128.0 },
        minValue: -100,
        maxValue: 100
    )

    public static let longTermFuelTrim = OBD2PID(
        mode: 0x01,
        pid: 0x07,
        name: "Ajuste Combustible Largo",
        shortName: "LTFT",
        unit: "%",
        formula: { data in (Double(data[0]) - 128) * 100.0 / 128.0 },
        minValue: -100,
        maxValue: 100
    )

    public static let fuelPressure = OBD2PID(
        mode: 0x01,
        pid: 0x0A,
        name: "Presión Combustible",
        shortName: "FP",
        unit: "kPa",
        formula: { data in Double(data[0]) * 3 },
        minValue: 0,
        maxValue: 765
    )

    public static let intakeManifoldPressure = OBD2PID(
        mode: 0x01,
        pid: 0x0B,
        name: "Presión Colector",
        shortName: "MAP",
        unit: "kPa",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 255
    )

    public static let rpm = OBD2PID(
        mode: 0x01,
        pid: 0x0C,
        name: "RPM",
        shortName: "RPM",
        unit: "rpm",
        formula: { data in Double(data.uint16(at: 0)) / 4.0 },
        minValue: 0,
        maxValue: 10000
    )

    public static let vehicleSpeed = OBD2PID(
        mode: 0x01,
        pid: 0x0D,
        name: "Velocidad",
        shortName: "VSS",
        unit: "km/h",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 255
    )

    public static let timingAdvance = OBD2PID(
        mode: 0x01,
        pid: 0x0E,
        name: "Avance Encendido",
        shortName: "SPARK",
        unit: "°",
        formula: { data in Double(data[0]) / 2.0 - 64 },
        minValue: -64,
        maxValue: 64
    )

    public static let intakeAirTemp = OBD2PID(
        mode: 0x01,
        pid: 0x0F,
        name: "Temp. Admisión",
        shortName: "IAT",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 215
    )

    public static let mafAirFlow = OBD2PID(
        mode: 0x01,
        pid: 0x10,
        name: "Flujo de Aire MAF",
        shortName: "MAF",
        unit: "g/s",
        formula: { data in Double(data.uint16(at: 0)) / 100.0 },
        minValue: 0,
        maxValue: 655
    )

    public static let throttlePosition = OBD2PID(
        mode: 0x01,
        pid: 0x11,
        name: "Posición Mariposa",
        shortName: "TPS",
        unit: "%",
        formula: { data in Double(data[0]) * 100.0 / 255.0 },
        minValue: 0,
        maxValue: 100
    )

    public static let o2SensorBank1Sensor1 = OBD2PID(
        mode: 0x01,
        pid: 0x14,
        name: "Sonda O2 B1S1",
        shortName: "O2B1S1",
        unit: "V",
        formula: { data in Double(data[0]) / 200.0 },
        minValue: 0,
        maxValue: 1.275
    )

    public static let o2SensorBank1Sensor2 = OBD2PID(
        mode: 0x01,
        pid: 0x15,
        name: "Sonda O2 B1S2",
        shortName: "O2B1S2",
        unit: "V",
        formula: { data in Double(data[0]) / 200.0 },
        minValue: 0,
        maxValue: 1.275
    )

    public static let runTime = OBD2PID(
        mode: 0x01,
        pid: 0x1F,
        name: "Tiempo Motor Encendido",
        shortName: "RUNTM",
        unit: "s",
        formula: { data in Double(data.uint16(at: 0)) },
        minValue: 0,
        maxValue: 65535
    )

    public static let fuelLevel = OBD2PID(
        mode: 0x01,
        pid: 0x2F,
        name: "Nivel Combustible",
        shortName: "FLI",
        unit: "%",
        formula: { data in Double(data[0]) * 100.0 / 255.0 },
        minValue: 0,
        maxValue: 100
    )

    public static let barometricPressure = OBD2PID(
        mode: 0x01,
        pid: 0x33,
        name: "Presión Barométrica",
        shortName: "BARO",
        unit: "kPa",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 255
    )

    public static let catalystTempBank1Sensor1 = OBD2PID(
        mode: 0x01,
        pid: 0x3C,
        name: "Temp. Catalizador B1S1",
        shortName: "CATB1S1",
        unit: "°C",
        formula: { data in Double(data.uint16(at: 0)) / 10.0 - 40 },
        minValue: -40,
        maxValue: 6513
    )

    public static let controlModuleVoltage = OBD2PID(
        mode: 0x01,
        pid: 0x42,
        name: "Voltaje Batería",
        shortName: "VPWR",
        unit: "V",
        formula: { data in Double(data.uint16(at: 0)) / 1000.0 },
        minValue: 0,
        maxValue: 65
    )

    public static let ambientAirTemp = OBD2PID(
        mode: 0x01,
        pid: 0x46,
        name: "Temp. Ambiente",
        shortName: "AAT",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 215
    )

    public static let all: [OBD2PID] = [
        engineLoad, coolantTemp, shortTermFuelTrim, longTermFuelTrim,
        fuelPressure, intakeManifoldPressure, rpm, vehicleSpeed,
        timingAdvance, intakeAirTemp, mafAirFlow, throttlePosition,
        o2SensorBank1Sensor1, o2SensorBank1Sensor2, runTime, fuelLevel,
        barometricPressure, catalystTempBank1Sensor1, controlModuleVoltage,
        ambientAirTemp
    ]
}

// MARK: - PIDs Extendidos Mazda (Mode 22)

public enum RX8ExtendedPIDs {

    /// Voltaje del MAF
    /// PID: 221177, Header: 7E0
    public static let mafVoltage = ExtendedPID(
        code: "221177",
        header: "7E0",
        name: "Voltaje MAF",
        shortName: "MAFv",
        unit: "V",
        formula: { data in Double(data.uint16(at: 0)) / 3700.0 },
        minValue: 0,
        maxValue: 5
    )

    /// Temperatura del aceite del motor
    /// PID: 221310, Header: 7E0
    public static let oilTemperature = ExtendedPID(
        code: "221310",
        header: "7E0",
        name: "Temp. Aceite Motor",
        shortName: "EOT",
        unit: "°C",
        formula: { data in (Double(data.uint16(at: 0)) / 100.0) - 40 },
        minValue: -40,
        maxValue: 200
    )

    /// Temperatura del combustible
    /// PID: 220522, Header: 7E0
    public static let fuelTemperature = ExtendedPID(
        code: "220522",
        header: "7E0",
        name: "Temp. Combustible",
        shortName: "FT",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 215
    )

    /// Presión de aceite (si disponible)
    /// Nota: RX-8 solo tiene switch, no sensor de presión en modelos estándar
    public static let oilPressureSwitch = ExtendedPID(
        code: "221318",
        header: "7E0",
        name: "Switch Presión Aceite",
        shortName: "OPS",
        unit: "",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 1
    )

    /// Posición del OMP (Oil Metering Pump)
    public static let ompPosition = ExtendedPID(
        code: "221350",
        header: "7E0",
        name: "Posición OMP",
        shortName: "OMP",
        unit: "%",
        formula: { data in Double(data[0]) * 100.0 / 255.0 },
        minValue: 0,
        maxValue: 100
    )

    /// Inyección de aceite activa
    public static let oilInjectionActive = ExtendedPID(
        code: "221351",
        header: "7E0",
        name: "Inyección Aceite",
        shortName: "OILA",
        unit: "",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 1
    )

    /// Presión neumático 1 (TPMS)
    /// PID: 22C901, Header: 751
    public static let tirePressure1 = ExtendedPID(
        code: "22C901",
        header: "751",
        name: "Presión Neumático 1",
        shortName: "TP1",
        unit: "psi",
        formula: { data in ((Double(data[0]) * 1373) / 1000) * 0.145037738 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure2 = ExtendedPID(
        code: "22C902",
        header: "751",
        name: "Presión Neumático 2",
        shortName: "TP2",
        unit: "psi",
        formula: { data in ((Double(data[0]) * 1373) / 1000) * 0.145037738 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure3 = ExtendedPID(
        code: "22C903",
        header: "751",
        name: "Presión Neumático 3",
        shortName: "TP3",
        unit: "psi",
        formula: { data in ((Double(data[0]) * 1373) / 1000) * 0.145037738 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure4 = ExtendedPID(
        code: "22C904",
        header: "751",
        name: "Presión Neumático 4",
        shortName: "TP4",
        unit: "psi",
        formula: { data in ((Double(data[0]) * 1373) / 1000) * 0.145037738 },
        minValue: 0,
        maxValue: 50
    )

    /// Temperatura aceite transmisión (automático)
    public static let transmissionFluidTemp = ExtendedPID(
        code: "221E1C",
        header: "7E1",
        name: "Temp. Aceite Transmisión",
        shortName: "TFT",
        unit: "°C",
        formula: { data in Double(data.int16(at: 0)) / 16.0 },
        minValue: -40,
        maxValue: 200
    )

    /// Marcha actual (automático)
    public static let currentGear = ExtendedPID(
        code: "221E12",
        header: "7E1",
        name: "Marcha Actual",
        shortName: "GEAR",
        unit: "",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 6
    )

    /// Ángulo de encendido Leading
    public static let ignitionTimingLeading = ExtendedPID(
        code: "221205",
        header: "7E0",
        name: "Avance Leading",
        shortName: "TIML",
        unit: "°",
        formula: { data in Double(data.int16(at: 0)) / 4.0 },
        minValue: -20,
        maxValue: 60
    )

    /// Ángulo de encendido Trailing
    public static let ignitionTimingTrailing = ExtendedPID(
        code: "221206",
        header: "7E0",
        name: "Avance Trailing",
        shortName: "TIMT",
        unit: "°",
        formula: { data in Double(data.int16(at: 0)) / 4.0 },
        minValue: -20,
        maxValue: 60
    )

    /// Knock sensor
    public static let knockSensor = ExtendedPID(
        code: "221230",
        header: "7E0",
        name: "Sensor Knock",
        shortName: "KNOCK",
        unit: "V",
        formula: { data in Double(data[0]) / 51.0 },
        minValue: 0,
        maxValue: 5
    )

    /// Ancho de pulso inyector
    public static let injectorPulseWidth = ExtendedPID(
        code: "221240",
        header: "7E0",
        name: "Ancho Pulso Inyector",
        shortName: "IPW",
        unit: "ms",
        formula: { data in Double(data.uint16(at: 0)) / 1000.0 },
        minValue: 0,
        maxValue: 25
    )

    public static let all: [ExtendedPID] = [
        mafVoltage, oilTemperature, fuelTemperature, oilPressureSwitch,
        ompPosition, oilInjectionActive, tirePressure1, tirePressure2,
        tirePressure3, tirePressure4, transmissionFluidTemp, currentGear,
        ignitionTimingLeading, ignitionTimingTrailing, knockSensor,
        injectorPulseWidth
    ]
}

// MARK: - Estructuras de PIDs

public struct CANPID: Sendable {
    public let canID: UInt16
    public let byteOffset: Int
    public let byteLength: Int
    public let name: String
    public let shortName: String
    public let unit: String
    public let formula: @Sendable (Data) -> Double
    public let minValue: Double
    public let maxValue: Double
    public var isBool: Bool = false

    public var canIDHex: String {
        String(format: "0x%03X", canID)
    }
}

public struct OBD2PID: Sendable {
    public let mode: UInt8
    public let pid: UInt8
    public let name: String
    public let shortName: String
    public let unit: String
    public let formula: @Sendable (Data) -> Double
    public let minValue: Double
    public let maxValue: Double

    public var code: String {
        String(format: "%02X%02X", mode, pid)
    }
}

public struct ExtendedPID: Sendable {
    public let code: String
    public let header: String
    public let name: String
    public let shortName: String
    public let unit: String
    public let formula: @Sendable (Data) -> Double
    public let minValue: Double
    public let maxValue: Double
}

// MARK: - Extensiones de Data para parsing

extension Data {
    func uint16(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    func int16(at offset: Int) -> Int16 {
        guard offset + 1 < count else { return 0 }
        let value = UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
        return Int16(bitPattern: value)
    }

    func uint32(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }
}

// MARK: - Grupo de PIDs para Diagnóstico

public struct DiagnosticPIDGroup {
    public let name: String
    public let description: String
    public let standardPIDs: [OBD2PID]
    public let extendedPIDs: [ExtendedPID]
    public let canPIDs: [CANPID]

    public static let engineHealth = DiagnosticPIDGroup(
        name: "Salud del Motor",
        description: "PIDs críticos para evaluar estado del motor rotativo",
        standardPIDs: [
            RX8OBD2StandardPIDs.engineLoad,
            RX8OBD2StandardPIDs.coolantTemp,
            RX8OBD2StandardPIDs.shortTermFuelTrim,
            RX8OBD2StandardPIDs.longTermFuelTrim,
            RX8OBD2StandardPIDs.mafAirFlow,
            RX8OBD2StandardPIDs.timingAdvance
        ],
        extendedPIDs: [
            RX8ExtendedPIDs.oilTemperature,
            RX8ExtendedPIDs.ompPosition,
            RX8ExtendedPIDs.knockSensor,
            RX8ExtendedPIDs.ignitionTimingLeading,
            RX8ExtendedPIDs.ignitionTimingTrailing
        ],
        canPIDs: [
            RX8CANPIDs.rpm,
            RX8CANPIDs.coolantTemp
        ]
    )

    public static let fuelSystem = DiagnosticPIDGroup(
        name: "Sistema de Combustible",
        description: "Monitoreo del sistema de inyección",
        standardPIDs: [
            RX8OBD2StandardPIDs.fuelLevel,
            RX8OBD2StandardPIDs.fuelPressure,
            RX8OBD2StandardPIDs.shortTermFuelTrim,
            RX8OBD2StandardPIDs.longTermFuelTrim
        ],
        extendedPIDs: [
            RX8ExtendedPIDs.fuelTemperature,
            RX8ExtendedPIDs.injectorPulseWidth
        ],
        canPIDs: []
    )

    public static let emissions = DiagnosticPIDGroup(
        name: "Emisiones",
        description: "Sondas lambda y catalizador",
        standardPIDs: [
            RX8OBD2StandardPIDs.o2SensorBank1Sensor1,
            RX8OBD2StandardPIDs.o2SensorBank1Sensor2,
            RX8OBD2StandardPIDs.catalystTempBank1Sensor1
        ],
        extendedPIDs: [],
        canPIDs: []
    )

    public static let driving = DiagnosticPIDGroup(
        name: "Conducción",
        description: "PIDs para monitoreo en tiempo real mientras conduces",
        standardPIDs: [
            RX8OBD2StandardPIDs.rpm,
            RX8OBD2StandardPIDs.vehicleSpeed,
            RX8OBD2StandardPIDs.throttlePosition,
            RX8OBD2StandardPIDs.engineLoad
        ],
        extendedPIDs: [
            RX8ExtendedPIDs.oilTemperature
        ],
        canPIDs: [
            RX8CANPIDs.rpm,
            RX8CANPIDs.vehicleSpeed,
            RX8CANPIDs.throttlePosition,
            RX8CANPIDs.coolantTemp,
            RX8CANPIDs.steeringAngle
        ]
    )

    public static let allGroups: [DiagnosticPIDGroup] = [
        engineHealth, fuelSystem, emissions, driving
    ]
}
