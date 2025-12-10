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
// Fuente: VersaTuner, RX8Club, equinox311 GitHub, Mazda WDS

public enum RX8ExtendedPIDs {

    // MARK: - Motor Avanzado

    /// Temperatura del aceite del motor
    /// PID: 22 1200, Header: 7E0
    /// CRÍTICO: mantener 80-95°C para longevidad. >110°C = peligro
    public static let oilTemperature = ExtendedPID(
        code: "221200",
        header: "7E0",
        name: "Temp. Aceite Motor",
        shortName: "OIL_T",
        unit: "°C",
        formula: { data in (Double(data.uint16(at: 0)) / 10.0) - 40 },
        minValue: -40,
        maxValue: 250,
        warningThreshold: 105,
        dangerThreshold: 110,
        isCritical: true
    )

    /// Presión de aceite del motor
    /// PID: 22 1201, Header: 7E0
    /// VITAL: mínimo 200kPa en ralentí caliente. Ref: 350kPa@3000rpm
    public static let oilPressure = ExtendedPID(
        code: "221201",
        header: "7E0",
        name: "Presión Aceite",
        shortName: "OIL_P",
        unit: "kPa",
        formula: { data in Double(data[0]) * 10 },
        minValue: 0,
        maxValue: 1000,
        warningThreshold: 250,
        dangerThreshold: 200,
        isCritical: true
    )

    /// Retardo de encendido por detonación (knock)
    /// PID: 22 1746, Header: 7E0
    /// Tuning: valores >2 grados indican detonación
    public static let knockRetard = ExtendedPID(
        code: "221746",
        header: "7E0",
        name: "Retardo Knock",
        shortName: "KR",
        unit: "°",
        formula: { data in Double(data.int16(at: 0)) / 64.0 },
        minValue: -32,
        maxValue: 32,
        warningThreshold: 2
    )

    /// Avance de encendido actual
    /// PID: 22 1747, Header: 7E0
    public static let ignitionTiming = ExtendedPID(
        code: "221747",
        header: "7E0",
        name: "Avance Encendido",
        shortName: "IGN_T",
        unit: "°",
        formula: { data in Double(data.int16(at: 0)) / 64.0 },
        minValue: -64,
        maxValue: 64
    )

    /// Relación aire-combustible objetivo
    /// PID: 22 1300, Header: 7E0
    /// Stock ~14.7 en cruise. WOT ~12.5-13.0 para rotary
    public static let targetAFR = ExtendedPID(
        code: "221300",
        header: "7E0",
        name: "AFR Objetivo",
        shortName: "TGT_AFR",
        unit: ":1",
        formula: { data in Double(data.uint16(at: 0)) / 1000.0 },
        minValue: 0,
        maxValue: 25
    )

    /// Relación aire-combustible actual medida
    /// PID: 22 1301, Header: 7E0
    public static let actualAFR = ExtendedPID(
        code: "221301",
        header: "7E0",
        name: "AFR Actual",
        shortName: "ACT_AFR",
        unit: ":1",
        formula: { data in Double(data.uint16(at: 0)) / 1000.0 },
        minValue: 0,
        maxValue: 25
    )

    /// Ciclo de trabajo de inyectores
    /// PID: 22 1400, Header: 7E0
    /// Tuning: >85% indica necesidad de inyectores más grandes
    public static let injectorDutyCycle = ExtendedPID(
        code: "221400",
        header: "7E0",
        name: "Duty Inyector",
        shortName: "IDC",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100,
        warningThreshold: 85
    )

    /// Tiempo de carga de bobinas de encendido
    /// PID: 22 1500, Header: 7E0
    /// Stock trailing: 3.5ms, leading: 2.8ms
    public static let coilDwell = ExtendedPID(
        code: "221500",
        header: "7E0",
        name: "Dwell Bobinas",
        shortName: "DWELL",
        unit: "ms",
        formula: { data in Double(data[0]) * 0.1 },
        minValue: 0,
        maxValue: 25
    )

    /// Voltaje del MAF
    /// PID: 22 1177, Header: 7E0
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

    /// Temperatura del combustible
    /// PID: 22 0522, Header: 7E0
    public static let fuelTemperature = ExtendedPID(
        code: "220522",
        header: "7E0",
        name: "Temp. Combustible",
        shortName: "FUEL_T",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 215
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

    /// Knock sensor voltage (legacy)
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

    // MARK: - Sistemas Específicos del Rotary

    /// Posición de la válvula SSV (Secondary Shutter Valve)
    /// PID: 22 2000, Header: 7E0
    /// Se abre ~5800 rpm. Diagnóstico de fallas de potencia en alto rpm
    public static let ssvPosition = ExtendedPID(
        code: "222000",
        header: "7E0",
        name: "Posición SSV",
        shortName: "SSV",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100,
        isRotarySpecific: true
    )

    /// Posición de la válvula APV (Auxiliary Port Valve)
    /// PID: 22 2001, Header: 7E0
    /// Se abre ~6500 rpm. Aumenta potencia en alto rpm
    public static let apvPosition = ExtendedPID(
        code: "222001",
        header: "7E0",
        name: "Posición APV",
        shortName: "APV",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100,
        isRotarySpecific: true
    )

    /// Posición del sistema VDI (Variable Dynamic Intake)
    /// PID: 22 2002, Header: 7E0
    /// Cambia geometría del intake según rpm
    public static let vdiPosition = ExtendedPID(
        code: "222002",
        header: "7E0",
        name: "Posición VDI",
        shortName: "VDI",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100,
        isRotarySpecific: true
    )

    /// Duty cycle de bomba de aceite OMP (Oil Metering Pump)
    /// PID: 22 2100, Header: 7E0
    /// VITAL: inyecta aceite en cámaras. Fallas = motor muerto. NUNCA reducir
    public static let ompDuty = ExtendedPID(
        code: "222100",
        header: "7E0",
        name: "Duty OMP",
        shortName: "OMP",
        unit: "%",
        formula: { data in Double(data[0]) * 100.0 / 255.0 },
        minValue: 0,
        maxValue: 100,
        isCritical: true,
        isRotarySpecific: true
    )

    /// Sistema de inyección de aire secundario
    /// PID: 22 2200, Header: 7E0
    /// Reduce emisiones en arranque frío. Fallas comunes >100k km
    public static let airPumpDuty = ExtendedPID(
        code: "222200",
        header: "7E0",
        name: "Duty Bomba Aire",
        shortName: "AIR_P",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100,
        isRotarySpecific: true
    )

    // MARK: - Sistema de Refrigeración

    /// Velocidad del ventilador primario del radiador
    /// PID: 22 3000, Header: 7E0
    /// Activación recomendada: 85°C
    public static let fan1Speed = ExtendedPID(
        code: "223000",
        header: "7E0",
        name: "Ventilador 1",
        shortName: "FAN1",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100
    )

    /// Velocidad del ventilador secundario
    /// PID: 22 3001, Header: 7E0
    /// Activación stock ~92°C
    public static let fan2Speed = ExtendedPID(
        code: "223001",
        header: "7E0",
        name: "Ventilador 2",
        shortName: "FAN2",
        unit: "%",
        formula: { data in Double(data[0]) },
        minValue: 0,
        maxValue: 100
    )

    // MARK: - TPMS (Header: 751 - Módulo ABS)

    /// Presión de todos los neumáticos (TPMS)
    /// PID: 22 C901, Header: 751
    /// Bytes A,B,C,D para cada neumático
    /// Fórmula: byte * 0.199136814274 = psi
    public static let tirePressure1 = ExtendedPID(
        code: "22C901",
        header: "751",
        name: "Presión Neumático 1",
        shortName: "TP1",
        unit: "psi",
        formula: { data in Double(data[0]) * 0.199136814274 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure2 = ExtendedPID(
        code: "22C901",
        header: "751",
        name: "Presión Neumático 2",
        shortName: "TP2",
        unit: "psi",
        formula: { data in data.count > 1 ? Double(data[1]) * 0.199136814274 : 0 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure3 = ExtendedPID(
        code: "22C901",
        header: "751",
        name: "Presión Neumático 3",
        shortName: "TP3",
        unit: "psi",
        formula: { data in data.count > 2 ? Double(data[2]) * 0.199136814274 : 0 },
        minValue: 0,
        maxValue: 50
    )

    public static let tirePressure4 = ExtendedPID(
        code: "22C901",
        header: "751",
        name: "Presión Neumático 4",
        shortName: "TP4",
        unit: "psi",
        formula: { data in data.count > 3 ? Double(data[3]) * 0.199136814274 : 0 },
        minValue: 0,
        maxValue: 50
    )

    /// Temperatura neumático 1
    /// PID: 22 C902, Header: 751
    public static let tireTemp1 = ExtendedPID(
        code: "22C902",
        header: "751",
        name: "Temp. Neumático 1",
        shortName: "TT1",
        unit: "°C",
        formula: { data in Double(data[0]) - 40 },
        minValue: -40,
        maxValue: 100
    )

    // MARK: - Transmisión (Header: 7E1)

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

    // MARK: - DSC/Chassis (Header: módulo ABS)

    /// Ángulo del volante
    /// PID: 22 7000, Header: ABS
    public static let steeringAngleDSC = ExtendedPID(
        code: "227000",
        header: "751",
        name: "Ángulo Volante DSC",
        shortName: "STEER",
        unit: "°",
        formula: { data in Double(data.int16(at: 0)) / 10.0 },
        minValue: -720,
        maxValue: 720
    )

    /// Velocidad de guiñada (yaw rate)
    /// PID: 22 7001, Header: ABS
    public static let yawRate = ExtendedPID(
        code: "227001",
        header: "751",
        name: "Yaw Rate",
        shortName: "YAW",
        unit: "°/s",
        formula: { data in Double(data.int16(at: 0)) / 100.0 },
        minValue: -100,
        maxValue: 100
    )

    /// Aceleración lateral
    /// PID: 22 7002, Header: ABS
    public static let lateralG = ExtendedPID(
        code: "227002",
        header: "751",
        name: "G Lateral",
        shortName: "LAT_G",
        unit: "g",
        formula: { data in Double(data.int16(at: 0)) / 1000.0 },
        minValue: -2,
        maxValue: 2
    )

    /// Aceleración longitudinal
    /// PID: 22 7003, Header: ABS
    public static let longitudinalG = ExtendedPID(
        code: "227003",
        header: "751",
        name: "G Longitudinal",
        shortName: "LONG_G",
        unit: "g",
        formula: { data in Double(data.int16(at: 0)) / 1000.0 },
        minValue: -2,
        maxValue: 2
    )

    // MARK: - Colecciones

    public static let all: [ExtendedPID] = [
        // Motor avanzado
        oilTemperature, oilPressure, knockRetard, ignitionTiming,
        targetAFR, actualAFR, injectorDutyCycle, coilDwell,
        mafVoltage, fuelTemperature, injectorPulseWidth,
        ignitionTimingLeading, ignitionTimingTrailing, knockSensor,
        // Rotary específico
        ssvPosition, apvPosition, vdiPosition, ompDuty, airPumpDuty,
        // Refrigeración
        fan1Speed, fan2Speed,
        // TPMS
        tirePressure1, tirePressure2, tirePressure3, tirePressure4, tireTemp1,
        // Transmisión
        transmissionFluidTemp, currentGear,
        // DSC/Chassis
        steeringAngleDSC, yawRate, lateralG, longitudinalG
    ]

    /// PIDs específicos del motor rotativo
    public static let rotarySpecific: [ExtendedPID] = [
        ssvPosition, apvPosition, vdiPosition, ompDuty, airPumpDuty
    ]

    /// PIDs críticos para la salud del motor
    public static let critical: [ExtendedPID] = [
        oilTemperature, oilPressure, ompDuty
    ]

    /// PIDs para tuning
    public static let tuning: [ExtendedPID] = [
        knockRetard, ignitionTiming, targetAFR, actualAFR,
        injectorDutyCycle, coilDwell, ignitionTimingLeading, ignitionTimingTrailing
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
    public let warningThreshold: Double?
    public let dangerThreshold: Double?
    public let isCritical: Bool
    public let isRotarySpecific: Bool

    public init(
        code: String,
        header: String,
        name: String,
        shortName: String,
        unit: String,
        formula: @escaping @Sendable (Data) -> Double,
        minValue: Double,
        maxValue: Double,
        warningThreshold: Double? = nil,
        dangerThreshold: Double? = nil,
        isCritical: Bool = false,
        isRotarySpecific: Bool = false
    ) {
        self.code = code
        self.header = header
        self.name = name
        self.shortName = shortName
        self.unit = unit
        self.formula = formula
        self.minValue = minValue
        self.maxValue = maxValue
        self.warningThreshold = warningThreshold
        self.dangerThreshold = dangerThreshold
        self.isCritical = isCritical
        self.isRotarySpecific = isRotarySpecific
    }
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
            RX8ExtendedPIDs.oilPressure,
            RX8ExtendedPIDs.ompDuty,
            RX8ExtendedPIDs.knockSensor,
            RX8ExtendedPIDs.knockRetard,
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
            RX8ExtendedPIDs.injectorPulseWidth,
            RX8ExtendedPIDs.injectorDutyCycle,
            RX8ExtendedPIDs.targetAFR,
            RX8ExtendedPIDs.actualAFR
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

    public static let rotarySystem = DiagnosticPIDGroup(
        name: "Sistema Rotativo",
        description: "PIDs específicos del motor rotativo Renesis",
        standardPIDs: [],
        extendedPIDs: [
            RX8ExtendedPIDs.ssvPosition,
            RX8ExtendedPIDs.apvPosition,
            RX8ExtendedPIDs.vdiPosition,
            RX8ExtendedPIDs.ompDuty,
            RX8ExtendedPIDs.airPumpDuty
        ],
        canPIDs: []
    )

    public static let cooling = DiagnosticPIDGroup(
        name: "Refrigeración",
        description: "Monitoreo del sistema de refrigeración",
        standardPIDs: [
            RX8OBD2StandardPIDs.coolantTemp
        ],
        extendedPIDs: [
            RX8ExtendedPIDs.oilTemperature,
            RX8ExtendedPIDs.fan1Speed,
            RX8ExtendedPIDs.fan2Speed
        ],
        canPIDs: [
            RX8CANPIDs.coolantTemp
        ]
    )

    public static let tpms = DiagnosticPIDGroup(
        name: "Presión Neumáticos",
        description: "Sistema TPMS - presión y temperatura de neumáticos",
        standardPIDs: [],
        extendedPIDs: [
            RX8ExtendedPIDs.tirePressure1,
            RX8ExtendedPIDs.tirePressure2,
            RX8ExtendedPIDs.tirePressure3,
            RX8ExtendedPIDs.tirePressure4,
            RX8ExtendedPIDs.tireTemp1
        ],
        canPIDs: []
    )

    public static let chassis = DiagnosticPIDGroup(
        name: "Chasis/DSC",
        description: "Datos de DSC, aceleración G y dinámica del vehículo",
        standardPIDs: [],
        extendedPIDs: [
            RX8ExtendedPIDs.steeringAngleDSC,
            RX8ExtendedPIDs.yawRate,
            RX8ExtendedPIDs.lateralG,
            RX8ExtendedPIDs.longitudinalG
        ],
        canPIDs: [
            RX8CANPIDs.steeringAngle,
            RX8CANPIDs.absDscWarning
        ]
    )

    public static let allGroups: [DiagnosticPIDGroup] = [
        engineHealth, fuelSystem, emissions, driving,
        rotarySystem, cooling, tpms, chassis
    ]
}
