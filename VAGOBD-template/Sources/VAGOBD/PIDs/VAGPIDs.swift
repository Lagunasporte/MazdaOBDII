import Foundation

// MARK: - PID Definition
public struct OBDPIDDefinition {
    public let mode: UInt8
    public let pid: UInt16
    public let name: String
    public let description: String
    public let unit: String
    public let minValue: Double
    public let maxValue: Double
    public let formula: ([UInt8]) -> Double?

    public init(
        mode: UInt8,
        pid: UInt16,
        name: String,
        description: String,
        unit: String,
        minValue: Double,
        maxValue: Double,
        formula: @escaping ([UInt8]) -> Double?
    ) {
        self.mode = mode
        self.pid = pid
        self.name = name
        self.description = description
        self.unit = unit
        self.minValue = minValue
        self.maxValue = maxValue
        self.formula = formula
    }
}

// MARK: - VAG PIDs
public struct VAGPIDs {

    // MARK: - Standard OBD2 PIDs (Mode 01)
    public static let standardPIDs: [UInt8: OBDPIDDefinition] = [

        0x04: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x04,
            name: "ENGINE_LOAD",
            description: "Carga del motor",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x05: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x05,
            name: "COOLANT_TEMP",
            description: "Temperatura refrigerante",
            unit: "°C",
            minValue: -40,
            maxValue: 215,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) - 40.0
            }
        ),

        0x06: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x06,
            name: "STFT_BANK1",
            description: "Ajuste combustible corto plazo B1",
            unit: "%",
            minValue: -100,
            maxValue: 99.2,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
            }
        ),

        0x07: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x07,
            name: "LTFT_BANK1",
            description: "Ajuste combustible largo plazo B1",
            unit: "%",
            minValue: -100,
            maxValue: 99.2,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
            }
        ),

        0x0B: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x0B,
            name: "INTAKE_PRESSURE",
            description: "Presión colector admisión",
            unit: "kPa",
            minValue: 0,
            maxValue: 255,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0])
            }
        ),

        0x0C: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x0C,
            name: "RPM",
            description: "Revoluciones motor",
            unit: "rpm",
            minValue: 0,
            maxValue: 16383.75,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 4.0
            }
        ),

        0x0D: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x0D,
            name: "SPEED",
            description: "Velocidad vehículo",
            unit: "km/h",
            minValue: 0,
            maxValue: 255,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0])
            }
        ),

        0x0E: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x0E,
            name: "TIMING_ADVANCE",
            description: "Avance de encendido",
            unit: "°",
            minValue: -64,
            maxValue: 63.5,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) / 2.0 - 64.0
            }
        ),

        0x0F: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x0F,
            name: "INTAKE_TEMP",
            description: "Temperatura admisión",
            unit: "°C",
            minValue: -40,
            maxValue: 215,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) - 40.0
            }
        ),

        0x10: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x10,
            name: "MAF",
            description: "Flujo de aire (MAF)",
            unit: "g/s",
            minValue: 0,
            maxValue: 655.35,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 100.0
            }
        ),

        0x11: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x11,
            name: "THROTTLE_POS",
            description: "Posición acelerador",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x1F: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x1F,
            name: "RUNTIME",
            description: "Tiempo motor encendido",
            unit: "s",
            minValue: 0,
            maxValue: 65535,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
            }
        ),

        0x21: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x21,
            name: "DISTANCE_MIL",
            description: "Distancia con MIL encendido",
            unit: "km",
            minValue: 0,
            maxValue: 65535,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
            }
        ),

        0x2F: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x2F,
            name: "FUEL_LEVEL",
            description: "Nivel combustible",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x33: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x33,
            name: "BARO_PRESSURE",
            description: "Presión barométrica",
            unit: "kPa",
            minValue: 0,
            maxValue: 255,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0])
            }
        ),

        0x42: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x42,
            name: "CONTROL_VOLTAGE",
            description: "Voltaje módulo control",
            unit: "V",
            minValue: 0,
            maxValue: 65.535,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 1000.0
            }
        ),

        0x46: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x46,
            name: "AMBIENT_TEMP",
            description: "Temperatura ambiente",
            unit: "°C",
            minValue: -40,
            maxValue: 215,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) - 40.0
            }
        ),

        0x5C: OBDPIDDefinition(
            mode: 0x01,
            pid: 0x5C,
            name: "OIL_TEMP",
            description: "Temperatura aceite motor",
            unit: "°C",
            minValue: -40,
            maxValue: 210,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) - 40.0
            }
        ),
    ]

    // MARK: - VAG Extended PIDs (Mode 22)
    public static let extendedPIDs: [UInt16: OBDPIDDefinition] = [

        0x2203: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x2203,
            name: "BOOST_PRESSURE",
            description: "Presión turbo",
            unit: "bar",
            minValue: 0,
            maxValue: 3.0,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 1000.0
            }
        ),

        0x2204: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x2204,
            name: "BOOST_TEMP",
            description: "Temperatura turbo",
            unit: "°C",
            minValue: -40,
            maxValue: 300,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 10.0 - 40.0
            }
        ),

        0x2033: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x2033,
            name: "OIL_PRESSURE",
            description: "Presión aceite",
            unit: "bar",
            minValue: 0,
            maxValue: 10.0,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 1000.0
            }
        ),

        0xF40C: OBDPIDDefinition(
            mode: 0x22,
            pid: 0xF40C,
            name: "DPF_REGEN",
            description: "Regeneración DPF",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x205A: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x205A,
            name: "ADBLUE_LEVEL",
            description: "Nivel AdBlue",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x1001: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x1001,
            name: "DSG_OIL_TEMP",
            description: "Temperatura aceite DSG",
            unit: "°C",
            minValue: -40,
            maxValue: 200,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) - 40.0
            }
        ),

        0x1002: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x1002,
            name: "DSG_CLUTCH_WEAR",
            description: "Desgaste embrague DSG",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),

        0x295A: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x295A,
            name: "DPF_SOOT_LOAD",
            description: "Carga hollín DPF",
            unit: "g",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 100.0
            }
        ),

        0x295B: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x295B,
            name: "DPF_ASH_LOAD",
            description: "Carga ceniza DPF",
            unit: "g",
            minValue: 0,
            maxValue: 200,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 100.0
            }
        ),

        0x3946: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x3946,
            name: "INJECTION_TIMING",
            description: "Timing inyección",
            unit: "°",
            minValue: -50,
            maxValue: 50,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
                return Double(raw) / 100.0
            }
        ),

        0x394C: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x394C,
            name: "RAIL_PRESSURE",
            description: "Presión raíl combustible",
            unit: "bar",
            minValue: 0,
            maxValue: 2500,
            formula: { bytes in
                guard bytes.count >= 2 else { return nil }
                return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 10.0
            }
        ),

        0x2962: OBDPIDDefinition(
            mode: 0x22,
            pid: 0x2962,
            name: "EGR_POSITION",
            description: "Posición EGR",
            unit: "%",
            minValue: 0,
            maxValue: 100,
            formula: { bytes in
                guard bytes.count >= 1 else { return nil }
                return Double(bytes[0]) * 100.0 / 255.0
            }
        ),
    ]

    // MARK: - PID Groups for quick access
    public static let temperaturePIDs: [UInt8] = [0x05, 0x0F, 0x46, 0x5C]
    public static let pressurePIDs: [UInt8] = [0x0B, 0x33]
    public static let enginePIDs: [UInt8] = [0x04, 0x0C, 0x0D, 0x11, 0x10]
    public static let fuelPIDs: [UInt8] = [0x06, 0x07, 0x2F]

    // MARK: - Helper Methods
    public static func getPIDDefinition(mode: UInt8, pid: UInt16) -> OBDPIDDefinition? {
        if mode == 0x01 {
            return standardPIDs[UInt8(pid)]
        } else if mode == 0x22 {
            return extendedPIDs[pid]
        }
        return nil
    }

    public static func decodeValue(mode: UInt8, pid: UInt16, data: [UInt8]) -> Double? {
        guard let definition = getPIDDefinition(mode: mode, pid: pid) else {
            return nil
        }
        return definition.formula(data)
    }
}

// MARK: - Live Data Structure
public struct LiveDataValue: Identifiable {
    public let id = UUID()
    public let pid: UInt16
    public let name: String
    public let description: String
    public let value: Double
    public let unit: String
    public let timestamp: Date

    public var formattedValue: String {
        if unit == "°C" || unit == "%" || unit == "°" {
            return String(format: "%.1f %@", value, unit)
        } else if unit == "rpm" {
            return String(format: "%.0f %@", value, unit)
        } else if unit == "km/h" {
            return String(format: "%.0f %@", value, unit)
        } else {
            return String(format: "%.2f %@", value, unit)
        }
    }
}
