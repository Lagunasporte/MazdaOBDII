import Foundation
import Combine

// MARK: - Engine Data
@MainActor
public class EngineData: ObservableObject {

    // MARK: - Basic Engine Parameters
    @Published public var rpm: Double = 0
    @Published public var speed: Double = 0
    @Published public var throttlePosition: Double = 0
    @Published public var engineLoad: Double = 0

    // MARK: - Temperatures
    @Published public var coolantTemp: Double = 0
    @Published public var oilTemp: Double = 0
    @Published public var intakeTemp: Double = 0
    @Published public var ambientTemp: Double = 0
    @Published public var exhaustGasTemp: Double = 0

    // MARK: - Pressures
    @Published public var boostPressure: Double = 0
    @Published public var oilPressure: Double = 0
    @Published public var fuelRailPressure: Double = 0
    @Published public var intakeManifoldPressure: Double = 0
    @Published public var barometricPressure: Double = 0

    // MARK: - Fuel System
    @Published public var fuelLevel: Double = 0
    @Published public var maf: Double = 0
    @Published public var shortTermFuelTrim: Double = 0
    @Published public var longTermFuelTrim: Double = 0

    // MARK: - Timing
    @Published public var timingAdvance: Double = 0
    @Published public var injectionTiming: Double = 0

    // MARK: - DSG/Transmission
    @Published public var dsgOilTemp: Double = 0
    @Published public var clutchWear: Double = 0
    @Published public var currentGear: Int = 0

    // MARK: - DPF (Diesel)
    @Published public var dpfSootLoad: Double = 0
    @Published public var dpfAshLoad: Double = 0
    @Published public var dpfRegenStatus: Double = 0
    @Published public var adBlueLevel: Double = 0

    // MARK: - Electrical
    @Published public var batteryVoltage: Double = 0
    @Published public var controlVoltage: Double = 0

    // MARK: - Runtime
    @Published public var engineRuntime: TimeInterval = 0
    @Published public var distanceWithMIL: Double = 0

    // MARK: - Status
    @Published public var isEngineRunning: Bool = false
    @Published public var isMILOn: Bool = false
    @Published public var lastUpdate: Date = Date()

    // MARK: - Singleton
    public static let shared = EngineData()

    private init() {}

    // MARK: - Alert Thresholds
    public struct AlertThresholds {
        // Temperatures
        public static let coolantWarning: Double = 100
        public static let coolantCritical: Double = 110
        public static let oilWarning: Double = 120
        public static let oilCritical: Double = 140
        public static let intakeWarning: Double = 55
        public static let intakeCritical: Double = 65
        public static let dsgOilWarning: Double = 110
        public static let dsgOilCritical: Double = 120

        // Pressures
        public static let boostWarning: Double = 2.0
        public static let boostCritical: Double = 2.5
        public static let oilPressureLow: Double = 0.5
        public static let oilPressureWarning: Double = 1.5

        // Electrical
        public static let voltageLow: Double = 11.5
        public static let voltageHigh: Double = 15.0
    }

    // MARK: - Alert Status
    public var coolantStatus: AlertLevel {
        if coolantTemp >= AlertThresholds.coolantCritical { return .critical }
        if coolantTemp >= AlertThresholds.coolantWarning { return .warning }
        return .normal
    }

    public var oilTempStatus: AlertLevel {
        if oilTemp >= AlertThresholds.oilCritical { return .critical }
        if oilTemp >= AlertThresholds.oilWarning { return .warning }
        return .normal
    }

    public var oilPressureStatus: AlertLevel {
        guard isEngineRunning else { return .normal }
        if oilPressure < AlertThresholds.oilPressureLow { return .critical }
        if oilPressure < AlertThresholds.oilPressureWarning { return .warning }
        return .normal
    }

    public var boostStatus: AlertLevel {
        if boostPressure >= AlertThresholds.boostCritical { return .critical }
        if boostPressure >= AlertThresholds.boostWarning { return .warning }
        return .normal
    }

    public var voltageStatus: AlertLevel {
        if batteryVoltage < AlertThresholds.voltageLow { return .warning }
        if batteryVoltage > AlertThresholds.voltageHigh { return .warning }
        return .normal
    }

    public var hasAnyWarning: Bool {
        coolantStatus != .normal ||
        oilTempStatus != .normal ||
        oilPressureStatus != .normal ||
        boostStatus != .normal ||
        voltageStatus != .normal ||
        isMILOn
    }

    // MARK: - Update Methods
    public func update(pid: UInt8, value: Double) {
        lastUpdate = Date()

        switch pid {
        case 0x04: engineLoad = value
        case 0x05: coolantTemp = value
        case 0x06: shortTermFuelTrim = value
        case 0x07: longTermFuelTrim = value
        case 0x0B: intakeManifoldPressure = value
        case 0x0C:
            rpm = value
            isEngineRunning = value > 400
        case 0x0D: speed = value
        case 0x0E: timingAdvance = value
        case 0x0F: intakeTemp = value
        case 0x10: maf = value
        case 0x11: throttlePosition = value
        case 0x1F: engineRuntime = value
        case 0x21: distanceWithMIL = value
        case 0x2F: fuelLevel = value
        case 0x33: barometricPressure = value
        case 0x42: controlVoltage = value
        case 0x46: ambientTemp = value
        case 0x5C: oilTemp = value
        default: break
        }
    }

    public func updateExtended(pid: UInt16, value: Double) {
        lastUpdate = Date()

        switch pid {
        case 0x2203: boostPressure = value
        case 0x2204: exhaustGasTemp = value
        case 0x2033: oilPressure = value
        case 0x1001: dsgOilTemp = value
        case 0x1002: clutchWear = value
        case 0xF40C: dpfRegenStatus = value
        case 0x205A: adBlueLevel = value
        case 0x295A: dpfSootLoad = value
        case 0x295B: dpfAshLoad = value
        case 0x3946: injectionTiming = value
        case 0x394C: fuelRailPressure = value
        default: break
        }
    }

    public func reset() {
        rpm = 0
        speed = 0
        throttlePosition = 0
        engineLoad = 0
        coolantTemp = 0
        oilTemp = 0
        intakeTemp = 0
        boostPressure = 0
        oilPressure = 0
        fuelLevel = 0
        batteryVoltage = 0
        isEngineRunning = false
        isMILOn = false
    }
}

// MARK: - Alert Level
public enum AlertLevel: String {
    case normal = "Normal"
    case warning = "Alerta"
    case critical = "Crítico"

    public var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Engine Data Snapshot
public struct EngineDataSnapshot: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date

    public let rpm: Double
    public let speed: Double
    public let coolantTemp: Double
    public let oilTemp: Double
    public let intakeTemp: Double
    public let boostPressure: Double
    public let throttlePosition: Double
    public let engineLoad: Double
    public let maf: Double
    public let fuelLevel: Double
    public let batteryVoltage: Double

    public init(from engineData: EngineData) {
        self.id = UUID()
        self.timestamp = Date()
        self.rpm = engineData.rpm
        self.speed = engineData.speed
        self.coolantTemp = engineData.coolantTemp
        self.oilTemp = engineData.oilTemp
        self.intakeTemp = engineData.intakeTemp
        self.boostPressure = engineData.boostPressure
        self.throttlePosition = engineData.throttlePosition
        self.engineLoad = engineData.engineLoad
        self.maf = engineData.maf
        self.fuelLevel = engineData.fuelLevel
        self.batteryVoltage = engineData.batteryVoltage
    }
}
