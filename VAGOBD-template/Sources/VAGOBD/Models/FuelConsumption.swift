import Foundation
import Combine

// MARK: - Fuel Consumption Calculator
@MainActor
public class FuelConsumption: ObservableObject {

    // MARK: - Published Properties
    @Published public var instantConsumption: Double = 0  // L/100km
    @Published public var averageConsumption: Double = 0  // L/100km
    @Published public var tripConsumption: Double = 0     // L/100km
    @Published public var totalFuelUsed: Double = 0       // Liters
    @Published public var tripDistance: Double = 0        // km
    @Published public var estimatedRange: Double = 0      // km

    // MARK: - Private Properties
    private var mafReadings: [Double] = []
    private var speedReadings: [Double] = []
    private var fuelLevelStart: Double = 0
    private var tripStartTime: Date?
    private var lastSpeed: Double = 0
    private var lastMAF: Double = 0

    // MARK: - Configuration
    public var fuelType: FuelType = .petrol95
    public var tankCapacity: Double = 55.0  // Liters

    // MARK: - Singleton
    public static let shared = FuelConsumption()

    private init() {}

    // MARK: - Fuel Density (g/L)
    private var fuelDensity: Double {
        switch fuelType {
        case .petrol95, .petrol98:
            return 750.0  // g/L for petrol
        case .diesel:
            return 835.0  // g/L for diesel
        default:
            return 750.0
        }
    }

    // MARK: - Air/Fuel Ratio
    private var stoichAFR: Double {
        switch fuelType {
        case .petrol95, .petrol98:
            return 14.7  // Stoichiometric AFR for petrol
        case .diesel:
            return 14.5  // Approximate for diesel
        default:
            return 14.7
        }
    }

    // MARK: - Update Methods
    public func update(maf: Double, speed: Double, fuelLevel: Double) {
        lastMAF = maf
        lastSpeed = speed

        // Calculate instant consumption
        if speed > 5 {  // Moving
            // Fuel rate (g/s) = MAF (g/s) / AFR
            let fuelRateGrams = maf / stoichAFR

            // Convert to L/h: (g/s * 3600) / density
            let fuelRateLitersPerHour = (fuelRateGrams * 3600) / fuelDensity

            // L/100km = (L/h / km/h) * 100
            instantConsumption = (fuelRateLitersPerHour / speed) * 100

            // Clamp to reasonable values
            instantConsumption = min(max(instantConsumption, 0), 50)
        } else if maf > 0 {
            // Idling - show L/h instead
            let fuelRateGrams = maf / stoichAFR
            let fuelRateLitersPerHour = (fuelRateGrams * 3600) / fuelDensity
            instantConsumption = fuelRateLitersPerHour  // L/h when stationary
        } else {
            instantConsumption = 0
        }

        // Store readings for averaging
        if speed > 5 {
            mafReadings.append(maf)
            speedReadings.append(speed)

            // Keep last 100 readings
            if mafReadings.count > 100 {
                mafReadings.removeFirst()
                speedReadings.removeFirst()
            }
        }

        // Calculate average consumption
        calculateAverageConsumption()

        // Update trip data
        updateTripData(speed: speed, fuelLevel: fuelLevel)

        // Calculate estimated range
        calculateEstimatedRange(fuelLevel: fuelLevel)
    }

    private func calculateAverageConsumption() {
        guard !mafReadings.isEmpty, !speedReadings.isEmpty else { return }

        let avgMAF = mafReadings.reduce(0, +) / Double(mafReadings.count)
        let avgSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)

        if avgSpeed > 0 {
            let fuelRateGrams = avgMAF / stoichAFR
            let fuelRateLitersPerHour = (fuelRateGrams * 3600) / fuelDensity
            averageConsumption = (fuelRateLitersPerHour / avgSpeed) * 100
            averageConsumption = min(max(averageConsumption, 0), 50)
        }
    }

    private func updateTripData(speed: Double, fuelLevel: Double) {
        if tripStartTime == nil {
            startNewTrip(fuelLevel: fuelLevel)
        }

        // Estimate distance traveled (simplified)
        // In real implementation, this would use GPS or odometer
        if speed > 0 {
            // Assume 100ms update interval
            let distanceIncrement = speed / 36000  // km per 100ms
            tripDistance += distanceIncrement
        }

        // Calculate fuel used based on level change
        if fuelLevel < fuelLevelStart {
            let levelDiff = fuelLevelStart - fuelLevel
            totalFuelUsed = (levelDiff / 100) * tankCapacity
        }

        // Calculate trip consumption
        if tripDistance > 0 {
            tripConsumption = (totalFuelUsed / tripDistance) * 100
        }
    }

    private func calculateEstimatedRange(fuelLevel: Double) {
        let fuelRemaining = (fuelLevel / 100) * tankCapacity

        if averageConsumption > 0 {
            estimatedRange = (fuelRemaining / averageConsumption) * 100
        } else if tripConsumption > 0 {
            estimatedRange = (fuelRemaining / tripConsumption) * 100
        } else {
            // Default estimate based on typical consumption
            let typicalConsumption = fuelType == .diesel ? 6.0 : 8.0
            estimatedRange = (fuelRemaining / typicalConsumption) * 100
        }
    }

    // MARK: - Trip Management
    public func startNewTrip(fuelLevel: Double) {
        tripStartTime = Date()
        fuelLevelStart = fuelLevel
        tripDistance = 0
        totalFuelUsed = 0
        tripConsumption = 0
        mafReadings.removeAll()
        speedReadings.removeAll()
    }

    public func resetAverages() {
        mafReadings.removeAll()
        speedReadings.removeAll()
        averageConsumption = 0
    }

    // MARK: - Trip Summary
    public struct TripSummary: Codable {
        public let startTime: Date
        public let endTime: Date
        public let distance: Double
        public let fuelUsed: Double
        public let averageConsumption: Double
        public let averageSpeed: Double

        public var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }

        public var formattedDuration: String {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            return String(format: "%d:%02d", hours, minutes)
        }
    }

    public func endTrip() -> TripSummary? {
        guard let startTime = tripStartTime else { return nil }

        let avgSpeed = speedReadings.isEmpty ? 0 : speedReadings.reduce(0, +) / Double(speedReadings.count)

        let summary = TripSummary(
            startTime: startTime,
            endTime: Date(),
            distance: tripDistance,
            fuelUsed: totalFuelUsed,
            averageConsumption: tripConsumption,
            averageSpeed: avgSpeed
        )

        return summary
    }
}

// MARK: - Fuel Economy Display
public struct FuelEconomyDisplay {

    public enum Unit: String, CaseIterable {
        case lPer100km = "L/100km"
        case kmPerL = "km/L"
        case mpgUS = "mpg (US)"
        case mpgUK = "mpg (UK)"
    }

    public static func convert(_ lPer100km: Double, to unit: Unit) -> Double {
        switch unit {
        case .lPer100km:
            return lPer100km
        case .kmPerL:
            return lPer100km > 0 ? 100 / lPer100km : 0
        case .mpgUS:
            return lPer100km > 0 ? 235.215 / lPer100km : 0
        case .mpgUK:
            return lPer100km > 0 ? 282.481 / lPer100km : 0
        }
    }

    public static func format(_ value: Double, unit: Unit) -> String {
        let converted = convert(value, to: unit)
        return String(format: "%.1f %@", converted, unit.rawValue)
    }
}
