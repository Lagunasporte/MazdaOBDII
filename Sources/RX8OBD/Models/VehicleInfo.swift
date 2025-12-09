import Foundation

// MARK: - Información del Vehículo RX-8

public struct RX8VehicleInfo: Codable, Sendable {
    public let vin: String
    public var series: RX8Series
    public var year: Int
    public var transmission: TransmissionType
    public var engineCode: String
    public var marketRegion: MarketRegion

    // Información extraída del VIN
    public var productionPlant: String?
    public var sequenceNumber: String?

    public init(vin: String) {
        self.vin = vin
        self.series = Self.decodeSeries(from: vin)
        self.year = Self.decodeYear(from: vin)
        self.transmission = .manual6Speed // Default, se actualiza con lectura OBD
        self.engineCode = "13B-MSP"
        self.marketRegion = Self.decodeMarket(from: vin)
    }

    // MARK: - VIN Decoding

    private static func decodeSeries(from vin: String) -> RX8Series {
        guard vin.count >= 10 else { return .unknown }
        let yearChar = vin[vin.index(vin.startIndex, offsetBy: 9)]
        let year = decodeYear(from: vin)

        if year >= 2009 {
            return .series2
        } else {
            return .series1
        }
    }

    private static func decodeYear(from vin: String) -> Int {
        guard vin.count >= 10 else { return 0 }
        let yearChar = vin[vin.index(vin.startIndex, offsetBy: 9)]

        let yearMap: [Character: Int] = [
            "3": 2003, "4": 2004, "5": 2005, "6": 2006,
            "7": 2007, "8": 2008, "9": 2009, "A": 2010,
            "B": 2011, "C": 2012
        ]

        return yearMap[yearChar] ?? 0
    }

    private static func decodeMarket(from vin: String) -> MarketRegion {
        guard !vin.isEmpty else { return .unknown }
        let firstChar = vin.first!

        switch firstChar {
        case "J": return .japan
        case "1", "4", "5": return .northAmerica
        case "W": return .europe
        default: return .unknown
        }
    }
}

// MARK: - Series RX-8

public enum RX8Series: String, Codable, Sendable, CaseIterable {
    case series1 = "Serie 1"
    case series2 = "Serie 2"
    case unknown = "Desconocida"

    public var yearRange: String {
        switch self {
        case .series1: return "2003-2008"
        case .series2: return "2009-2012"
        case .unknown: return "N/A"
        }
    }

    public var chassisCode: String {
        return "SE3P"
    }

    public var differences: [String] {
        switch self {
        case .series1:
            return [
                "Motor 13B-MSP 231 HP (MT) / 197 HP (AT)",
                "4-port intake",
                "Diseño original faros/paragolpes",
                "Interior original"
            ]
        case .series2:
            return [
                "Motor 13B-MSP 232 HP revisado",
                "6-port intake mejorado",
                "Faros LED, diseño actualizado",
                "Interior rediseñado",
                "Mejor gestión térmica"
            ]
        case .unknown:
            return []
        }
    }
}

// MARK: - Tipo de Transmisión

public enum TransmissionType: String, Codable, Sendable {
    case manual5Speed = "Manual 5 vel"
    case manual6Speed = "Manual 6 vel"
    case automatic4Speed = "Automático 4 vel"
    case automatic6Speed = "Automático 6 vel"

    public var gearRatios: [Double] {
        switch self {
        case .manual6Speed:
            return [3.76, 2.27, 1.65, 1.26, 1.00, 0.84] // + reverse 3.99
        case .automatic4Speed:
            return [2.86, 1.57, 1.00, 0.70]
        case .automatic6Speed:
            return [3.54, 2.26, 1.58, 1.19, 1.00, 0.87]
        case .manual5Speed:
            return [3.76, 2.27, 1.65, 1.26, 1.00]
        }
    }

    public var finalDrive: Double {
        switch self {
        case .manual6Speed: return 4.44
        case .automatic4Speed: return 4.78
        case .automatic6Speed: return 4.44
        case .manual5Speed: return 4.44
        }
    }
}

// MARK: - Región de Mercado

public enum MarketRegion: String, Codable, Sendable {
    case japan = "Japón (JDM)"
    case northAmerica = "Norteamérica (USDM)"
    case europe = "Europa (EDM)"
    case unknown = "Desconocido"

    public var specificNotes: [String] {
        switch self {
        case .japan:
            return [
                "Limitador velocidad 180 km/h",
                "Cruise control limitado a 100 km/h",
                "Requiere bobinas OEM Mazda",
                "Puede tener airbags diferentes"
            ]
        case .northAmerica:
            return [
                "Sin limitador de velocidad",
                "Emisiones más estrictas (CARB en California)",
                "Side markers en paragolpes"
            ]
        case .europe:
            return [
                "Sin limitador de velocidad",
                "Faros con regulación automática",
                "Puede incluir xenon de fábrica"
            ]
        case .unknown:
            return []
        }
    }
}

// MARK: - Historial de Mantenimiento

public struct MaintenanceRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let odometer: Int // km
    public let type: MaintenanceType
    public let description: String
    public let notes: String?
    public var compressionTest: CompressionAnalysis?

    public init(date: Date, odometer: Int, type: MaintenanceType, description: String, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.odometer = odometer
        self.type = type
        self.description = description
        self.notes = notes
    }
}

public enum MaintenanceType: String, Codable, Sendable, CaseIterable {
    case oilChange = "Cambio de aceite"
    case sparkPlugs = "Bujías"
    case ignitionCoils = "Bobinas de encendido"
    case compressionTest = "Test de compresión"
    case coolantFlush = "Cambio refrigerante"
    case transmissionFluid = "Aceite transmisión"
    case brakes = "Frenos"
    case timing = "Distribución/Timing"
    case omp = "Sistema OMP"
    case rebuild = "Rebuild motor"
    case other = "Otro"

    public var recommendedInterval: Int? { // km
        switch self {
        case .oilChange: return 5000
        case .sparkPlugs: return 30000
        case .ignitionCoils: return 60000
        case .compressionTest: return 20000
        case .coolantFlush: return 50000
        case .transmissionFluid: return 60000
        default: return nil
        }
    }
}

// MARK: - Sesión de Diagnóstico

public struct DiagnosticSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?
    public let vehicleInfo: RX8VehicleInfo?
    public var dtcCodes: [DTCCode]
    public var engineSnapshots: [RotaryEngineState]
    public var compressionAnalysis: CompressionAnalysis?
    public var notes: String

    public init(vehicleInfo: RX8VehicleInfo? = nil) {
        self.id = UUID()
        self.startTime = Date()
        self.vehicleInfo = vehicleInfo
        self.dtcCodes = []
        self.engineSnapshots = []
        self.notes = ""
    }

    public mutating func end() {
        self.endTime = Date()
    }

    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}
