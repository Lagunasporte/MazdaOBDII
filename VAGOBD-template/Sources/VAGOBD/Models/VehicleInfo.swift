import Foundation

// MARK: - VAG Vehicle Info
public struct VAGVehicleInfo: Codable, Identifiable {
    public var id: String { vin }

    public let vin: String
    public let brand: VAGOBD.Brand
    public let model: String
    public let year: Int
    public let engineCode: String
    public let engineType: VAGEngineType
    public let displacement: Double
    public let power: Int  // kW
    public let torque: Int // Nm
    public let transmission: TransmissionType
    public let fuelType: FuelType

    public init(
        vin: String,
        brand: VAGOBD.Brand,
        model: String,
        year: Int,
        engineCode: String,
        engineType: VAGEngineType,
        displacement: Double,
        power: Int,
        torque: Int,
        transmission: TransmissionType,
        fuelType: FuelType
    ) {
        self.vin = vin
        self.brand = brand
        self.model = model
        self.year = year
        self.engineCode = engineCode
        self.engineType = engineType
        self.displacement = displacement
        self.power = power
        self.torque = torque
        self.transmission = transmission
        self.fuelType = fuelType
    }

    public var powerHP: Int {
        Int(Double(power) * 1.341)
    }

    public var displayName: String {
        "\(brand.rawValue) \(model) \(engineType.rawValue) \(displacement)L"
    }
}

// MARK: - Engine Type
public enum VAGEngineType: String, Codable, CaseIterable {
    case tsi = "TSI"
    case tfsi = "TFSI"
    case tdi = "TDI"
    case tdiCR = "TDI CR"
    case fsi = "FSI"
    case mpi = "MPI"
    case tgi = "TGI"  // Gas natural
    case etron = "e-tron"
    case hybrid = "Hybrid"
    case gti = "GTI"
    case r = "R"
    case rs = "RS"
    case s = "S"

    public var description: String {
        switch self {
        case .tsi: return "Turbocharged Stratified Injection"
        case .tfsi: return "Turbo Fuel Stratified Injection"
        case .tdi: return "Turbocharged Direct Injection (Diesel)"
        case .tdiCR: return "TDI Common Rail"
        case .fsi: return "Fuel Stratified Injection"
        case .mpi: return "Multi-Point Injection"
        case .tgi: return "Turbo Gas Injection (CNG)"
        case .etron: return "Electric Drive"
        case .hybrid: return "Plug-in Hybrid"
        case .gti: return "Grand Tourer Injection"
        case .r: return "Racing Line"
        case .rs: return "RennSport"
        case .s: return "Sport Line"
        }
    }

    public var isDiesel: Bool {
        self == .tdi || self == .tdiCR
    }

    public var isElectric: Bool {
        self == .etron
    }

    public var hasTurbo: Bool {
        switch self {
        case .tsi, .tfsi, .tdi, .tdiCR, .tgi, .gti, .r, .rs, .s:
            return true
        default:
            return false
        }
    }
}

// MARK: - Transmission Type
public enum TransmissionType: String, Codable, CaseIterable {
    case manual5 = "5-Speed Manual"
    case manual6 = "6-Speed Manual"
    case dsg6 = "6-Speed DSG"
    case dsg7 = "7-Speed DSG"
    case tiptronic6 = "6-Speed Tiptronic"
    case tiptronic8 = "8-Speed Tiptronic"
    case sLine7 = "7-Speed S tronic"
    case auto = "Automatic"

    public var isDSG: Bool {
        switch self {
        case .dsg6, .dsg7, .sLine7:
            return true
        default:
            return false
        }
    }

    public var isManual: Bool {
        switch self {
        case .manual5, .manual6:
            return true
        default:
            return false
        }
    }

    public var gearCount: Int {
        switch self {
        case .manual5: return 5
        case .manual6, .dsg6, .tiptronic6: return 6
        case .dsg7, .sLine7: return 7
        case .tiptronic8: return 8
        case .auto: return 6
        }
    }
}

// MARK: - Fuel Type
public enum FuelType: String, Codable, CaseIterable {
    case petrol95 = "Gasolina 95"
    case petrol98 = "Gasolina 98"
    case diesel = "Diésel"
    case cng = "Gas Natural"
    case electric = "Eléctrico"
    case hybrid = "Híbrido"

    public var requiresAdBlue: Bool {
        self == .diesel
    }
}

// MARK: - VIN Decoder
public struct VAGVINDecoder {

    public static func decode(vin: String) -> VAGVehicleInfo? {
        guard vin.count == 17 else { return nil }

        let wmi = String(vin.prefix(3))
        let brand = decodeBrand(wmi: wmi)

        // Extract model year (position 10)
        let yearIndex = vin.index(vin.startIndex, offsetBy: 9)
        let yearChar = vin[yearIndex]
        let year = decodeYear(char: yearChar)

        // Extract plant code (position 11)
        let plantIndex = vin.index(vin.startIndex, offsetBy: 10)
        let _ = vin[plantIndex]

        return VAGVehicleInfo(
            vin: vin,
            brand: brand,
            model: "Unknown",
            year: year,
            engineCode: "Unknown",
            engineType: .tsi,
            displacement: 0,
            power: 0,
            torque: 0,
            transmission: .auto,
            fuelType: .petrol95
        )
    }

    private static func decodeBrand(wmi: String) -> VAGOBD.Brand {
        // WMI codes for VAG brands
        switch wmi.prefix(2) {
        case "WV", "WF", "3V":
            return .volkswagen
        case "WA", "WU", "TR":
            return .audi
        case "VS", "VW":
            return .seat
        case "TM":
            return .skoda
        default:
            return .volkswagen
        }
    }

    private static func decodeYear(char: Character) -> Int {
        let yearCodes: [Character: Int] = [
            "A": 2010, "B": 2011, "C": 2012, "D": 2013, "E": 2014,
            "F": 2015, "G": 2016, "H": 2017, "J": 2018, "K": 2019,
            "L": 2020, "M": 2021, "N": 2022, "P": 2023, "R": 2024,
            "S": 2025
        ]
        return yearCodes[char] ?? 2020
    }
}

// MARK: - Common VAG Engine Codes
public struct VAGEngineCodes {

    public static let engines: [String: (type: VAGEngineType, displacement: Double, power: Int, torque: Int)] = [
        // TSI Engines
        "CHPA": (.tsi, 1.4, 110, 250),
        "CZCA": (.tsi, 1.4, 92, 200),
        "CZEA": (.tsi, 1.4, 110, 250),
        "CJSA": (.tsi, 1.8, 132, 250),
        "CJSB": (.tsi, 1.8, 132, 250),
        "CHHB": (.tsi, 2.0, 162, 350),
        "CXCA": (.tsi, 2.0, 162, 350),
        "DNUE": (.tsi, 2.0, 140, 320),

        // GTI/R Engines
        "CJXC": (.gti, 2.0, 169, 350),
        "CJXG": (.gti, 2.0, 195, 380),
        "DJHC": (.r, 2.0, 228, 400),

        // TDI Engines
        "CJAA": (.tdi, 2.0, 103, 320),
        "CBBB": (.tdi, 2.0, 125, 350),
        "CFGB": (.tdiCR, 2.0, 103, 320),
        "DFGA": (.tdiCR, 2.0, 110, 340),
        "DGCA": (.tdiCR, 2.0, 140, 400),
        "CUAA": (.tdiCR, 2.0, 135, 380),

        // TFSI (Audi)
        "DADA": (.tfsi, 2.0, 140, 320),
        "DNWA": (.tfsi, 2.0, 180, 370),
        "CWGD": (.tfsi, 2.5, 294, 480),  // RS3/TTRS

        // MPI Engines
        "CHYB": (.mpi, 1.0, 55, 95),
        "DKRA": (.mpi, 1.0, 70, 160),  // Turbo
    ]

    public static func lookup(code: String) -> (type: VAGEngineType, displacement: Double, power: Int, torque: Int)? {
        return engines[code.uppercased()]
    }
}
