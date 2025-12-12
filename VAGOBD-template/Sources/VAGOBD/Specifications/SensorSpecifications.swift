import Foundation

// MARK: - VAG Sensor Specifications
public struct VAGSensorSpecs {

    // MARK: - Temperature Ranges
    public struct TemperatureRange {
        public let normal: ClosedRange<Double>
        public let warning: ClosedRange<Double>
        public let critical: ClosedRange<Double>

        public func status(for value: Double) -> AlertLevel {
            if critical.contains(value) || value > critical.upperBound { return .critical }
            if warning.contains(value) { return .warning }
            if normal.contains(value) { return .normal }
            return value < normal.lowerBound ? .normal : .warning
        }
    }

    // MARK: - Coolant Temperature
    public static let coolantTemp = TemperatureRange(
        normal: 85...95,
        warning: 96...105,
        critical: 106...130
    )

    // MARK: - Oil Temperature
    public static let oilTemp = TemperatureRange(
        normal: 90...110,
        warning: 111...125,
        critical: 126...150
    )

    // MARK: - DSG Oil Temperature
    public static let dsgOilTemp = TemperatureRange(
        normal: 80...100,
        warning: 101...115,
        critical: 116...140
    )

    // MARK: - Intake Temperature
    public static let intakeTemp = TemperatureRange(
        normal: 20...45,
        warning: 46...60,
        critical: 61...80
    )

    // MARK: - Exhaust Gas Temperature (Turbo)
    public static let exhaustTemp = TemperatureRange(
        normal: 200...850,
        warning: 851...950,
        critical: 951...1100
    )

    // MARK: - Boost Pressure Specs
    public struct BoostSpec {
        public let engine: String
        public let maxBoost: Double  // bar
        public let targetBoost: Double  // bar at WOT

        public func status(for value: Double) -> AlertLevel {
            if value > maxBoost * 1.1 { return .critical }
            if value > maxBoost { return .warning }
            return .normal
        }
    }

    public static let boostSpecs: [String: BoostSpec] = [
        // TSI Engines
        "1.4 TSI": BoostSpec(engine: "1.4 TSI", maxBoost: 1.2, targetBoost: 1.0),
        "1.8 TSI": BoostSpec(engine: "1.8 TSI", maxBoost: 1.4, targetBoost: 1.2),
        "2.0 TSI": BoostSpec(engine: "2.0 TSI", maxBoost: 1.8, targetBoost: 1.5),
        "2.0 TSI GTI": BoostSpec(engine: "2.0 TSI GTI", maxBoost: 2.0, targetBoost: 1.7),
        "2.0 TSI R": BoostSpec(engine: "2.0 TSI R", maxBoost: 2.2, targetBoost: 1.9),

        // TDI Engines
        "1.6 TDI": BoostSpec(engine: "1.6 TDI", maxBoost: 1.6, targetBoost: 1.4),
        "2.0 TDI": BoostSpec(engine: "2.0 TDI", maxBoost: 2.2, targetBoost: 1.8),
        "2.0 TDI 150": BoostSpec(engine: "2.0 TDI 150", maxBoost: 2.0, targetBoost: 1.7),
        "2.0 TDI 190": BoostSpec(engine: "2.0 TDI 190", maxBoost: 2.4, targetBoost: 2.0),

        // TFSI Engines (Audi)
        "2.0 TFSI": BoostSpec(engine: "2.0 TFSI", maxBoost: 1.8, targetBoost: 1.5),
        "2.5 TFSI RS": BoostSpec(engine: "2.5 TFSI RS", maxBoost: 2.5, targetBoost: 2.1),
    ]

    // MARK: - Oil Pressure Specs
    public struct OilPressureSpec {
        public let idleMin: Double     // bar at idle
        public let running3000: Double  // bar at 3000 rpm
        public let warningLow: Double   // bar

        public func status(rpm: Double, pressure: Double) -> AlertLevel {
            if rpm < 1000 {
                // Idle
                if pressure < warningLow { return .critical }
                if pressure < idleMin { return .warning }
            } else {
                // Running
                if pressure < warningLow { return .critical }
                if pressure < running3000 * 0.7 { return .warning }
            }
            return .normal
        }
    }

    public static let oilPressure = OilPressureSpec(
        idleMin: 0.8,
        running3000: 3.0,
        warningLow: 0.5
    )

    // MARK: - Fuel Trim Specs
    public struct FuelTrimSpec {
        public let normal: ClosedRange<Double>
        public let warning: ClosedRange<Double>

        public func status(for value: Double) -> AlertLevel {
            if normal.contains(value) { return .normal }
            if warning.contains(value) { return .warning }
            return .critical
        }
    }

    public static let fuelTrim = FuelTrimSpec(
        normal: -10...10,
        warning: -25...25
    )

    // MARK: - Battery/Voltage Specs
    public struct VoltageSpec {
        public let normal: ClosedRange<Double>
        public let engineOff: ClosedRange<Double>
        public let engineRunning: ClosedRange<Double>

        public func status(for value: Double, engineRunning: Bool) -> AlertLevel {
            let range = engineRunning ? self.engineRunning : self.engineOff
            if range.contains(value) { return .normal }
            if value < range.lowerBound - 1 || value > range.upperBound + 1 { return .critical }
            return .warning
        }
    }

    public static let voltage = VoltageSpec(
        normal: 12.4...14.8,
        engineOff: 12.4...12.8,
        engineRunning: 13.8...14.8
    )

    // MARK: - DPF Specs (Diesel)
    public struct DPFSpec {
        public let sootLoadWarning: Double  // grams
        public let sootLoadCritical: Double // grams
        public let ashLoadMax: Double       // grams
        public let regenInterval: Double    // km

        public func sootStatus(for value: Double) -> AlertLevel {
            if value >= sootLoadCritical { return .critical }
            if value >= sootLoadWarning { return .warning }
            return .normal
        }
    }

    public static let dpf = DPFSpec(
        sootLoadWarning: 25,
        sootLoadCritical: 40,
        ashLoadMax: 140,
        regenInterval: 500
    )

    // MARK: - Service Intervals
    public struct ServiceInterval {
        public let oilService: Int     // km
        public let inspection: Int     // km
        public let sparkPlugs: Int     // km (petrol only)
        public let timingBelt: Int     // km or years
        public let dsgService: Int     // km
        public let brakeFluid: Int     // years

        public static let standard = ServiceInterval(
            oilService: 15000,
            inspection: 30000,
            sparkPlugs: 60000,
            timingBelt: 120000,
            dsgService: 60000,
            brakeFluid: 2
        )

        public static let longLife = ServiceInterval(
            oilService: 30000,
            inspection: 30000,
            sparkPlugs: 60000,
            timingBelt: 120000,
            dsgService: 60000,
            brakeFluid: 2
        )
    }
}

// MARK: - Engine Specifications Database
public struct VAGEngineSpecs {

    public struct EngineSpec {
        public let code: String
        public let displacement: Double
        public let cylinders: Int
        public let power: Int          // kW
        public let torque: Int         // Nm
        public let maxRPM: Int
        public let compression: Double
        public let fuelType: FuelType
        public let hasTurbo: Bool
        public let hasDirectInjection: Bool

        public var powerHP: Int { Int(Double(power) * 1.341) }
    }

    public static let engines: [String: EngineSpec] = [
        // 1.4 TSI Family
        "CHPA": EngineSpec(code: "CHPA", displacement: 1.4, cylinders: 4, power: 110, torque: 250, maxRPM: 6500, compression: 10.0, fuelType: .petrol95, hasTurbo: true, hasDirectInjection: true),
        "CZEA": EngineSpec(code: "CZEA", displacement: 1.4, cylinders: 4, power: 110, torque: 250, maxRPM: 6500, compression: 10.0, fuelType: .petrol95, hasTurbo: true, hasDirectInjection: true),

        // 2.0 TSI Family
        "CHHB": EngineSpec(code: "CHHB", displacement: 2.0, cylinders: 4, power: 162, torque: 350, maxRPM: 6800, compression: 9.6, fuelType: .petrol98, hasTurbo: true, hasDirectInjection: true),
        "CJXC": EngineSpec(code: "CJXC", displacement: 2.0, cylinders: 4, power: 169, torque: 350, maxRPM: 6800, compression: 9.3, fuelType: .petrol98, hasTurbo: true, hasDirectInjection: true),
        "DJHC": EngineSpec(code: "DJHC", displacement: 2.0, cylinders: 4, power: 228, torque: 400, maxRPM: 7000, compression: 9.3, fuelType: .petrol98, hasTurbo: true, hasDirectInjection: true),

        // 2.0 TDI Family
        "DFGA": EngineSpec(code: "DFGA", displacement: 2.0, cylinders: 4, power: 110, torque: 340, maxRPM: 5000, compression: 16.2, fuelType: .diesel, hasTurbo: true, hasDirectInjection: true),
        "DGCA": EngineSpec(code: "DGCA", displacement: 2.0, cylinders: 4, power: 140, torque: 400, maxRPM: 5000, compression: 15.5, fuelType: .diesel, hasTurbo: true, hasDirectInjection: true),

        // 2.5 TFSI (RS)
        "CWGD": EngineSpec(code: "CWGD", displacement: 2.5, cylinders: 5, power: 294, torque: 480, maxRPM: 7000, compression: 10.0, fuelType: .petrol98, hasTurbo: true, hasDirectInjection: true),
    ]

    public static func lookup(code: String) -> EngineSpec? {
        return engines[code.uppercased()]
    }
}
