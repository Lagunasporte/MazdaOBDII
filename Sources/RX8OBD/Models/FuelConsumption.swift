import Foundation

// MARK: - Sistema de Control de Consumo RX-8
// El RX-8 no tiene ordenador de a bordo - esta funcionalidad es MUY útil

public class FuelConsumptionTracker: ObservableObject {

    // MARK: - Datos Publicados
    @Published public var instantConsumption: Double = 0 // L/100km
    @Published public var averageConsumption: Double = 0 // L/100km (media de la sesión)
    @Published public var tripConsumption: Double = 0 // L/100km
    @Published public var fuelUsedTrip: Double = 0 // Litros
    @Published public var distanceTrip: Double = 0 // km
    @Published public var estimatedRange: Double = 0 // km
    @Published public var fuelCost: Double = 0 // € o moneda local
    @Published public var co2Emissions: Double = 0 // g/km

    // MARK: - Nivel de Combustible
    @Published public var fuelLevel: Double = 50.0 // % del tanque (default 50%)
    @Published public var fuelLevelLiters: Double = 30.0 // Litros restantes
    @Published public var fuelLevelAvailable: Bool = false // Si el sensor está disponible

    // MARK: - Datos de tiempo y distancia
    @Published public var runtimeSeconds: Int = 0 // Tiempo desde arranque
    @Published public var distanceSinceDTCClear: Int = 0 // km desde último borrado

    // MARK: - Configuración
    public var tankCapacity: Double = 60.0 // Litros (RX-8 tiene 60L)
    public var fuelPricePerLiter: Double = 1.50 // €/L
    public var fuelType: FuelType = .gasoline95
    public var manualFuelLevel: Double? = nil // Si el usuario quiere poner nivel manual

    // MARK: - Datos Internos
    private var mafReadings: [MAFReading] = []
    private var speedReadings: [SpeedReading] = []
    private var tripStartTime: Date?
    private var tripStartOdometer: Double = 0
    private var lastUpdateTime: Date? // Para calcular tiempo real entre lecturas
    private var consumptionHistory: [Double] = [] // Historial para calcular media móvil

    // Constantes para cálculo
    private let airFuelRatioStoich: Double = 14.7 // Ratio estequiométrico gasolina
    private let gasolineDensity: Double = 0.755 // kg/L a 15°C

    // MARK: - Estructuras de Datos

    struct MAFReading {
        let timestamp: Date
        let mafGramsPerSecond: Double
        let rpm: Int
    }

    struct SpeedReading {
        let timestamp: Date
        let speedKmh: Double
    }

    public init() {
        // Iniciar con valores por defecto que tengan sentido
        averageConsumption = 13.0 // Consumo típico RX-8
    }

    // MARK: - Cálculo de Consumo Instantáneo

    /// Calcula consumo instantáneo basado en MAF (Mass Air Flow)
    /// Fórmula: Fuel Flow (L/h) = (MAF * 3600) / (AFR * Densidad * 1000)
    public func calculateInstantConsumption(mafGramsPerSecond: Double, speedKmh: Double, rpm: Int) -> Double {

        // Guardar lectura
        let mafReading = MAFReading(timestamp: Date(), mafGramsPerSecond: mafGramsPerSecond, rpm: rpm)
        mafReadings.append(mafReading)

        let speedReading = SpeedReading(timestamp: Date(), speedKmh: speedKmh)
        speedReadings.append(speedReading)

        // Limpiar lecturas antiguas (mantener últimos 60 segundos)
        let cutoff = Date().addingTimeInterval(-60)
        mafReadings.removeAll { $0.timestamp < cutoff }
        speedReadings.removeAll { $0.timestamp < cutoff }

        // Calcular flujo de combustible (L/h)
        // El motor rotativo tiene un AFR diferente en ciertas condiciones
        let effectiveAFR = calculateEffectiveAFR(rpm: rpm, maf: mafGramsPerSecond)
        let fuelFlowLitersPerHour = (mafGramsPerSecond * 3.6) / (effectiveAFR * gasolineDensity)

        // Calcular consumo instantáneo
        if speedKmh > 3 { // Evitar división por casi cero
            // L/100km = (L/h) / (km/h) * 100
            instantConsumption = (fuelFlowLitersPerHour / speedKmh) * 100

            // Limitar a valores razonables (0.1 - 50 L/100km)
            instantConsumption = min(max(instantConsumption, 0.1), 50.0)
        } else {
            // En ralentí, mostrar L/h en vez de L/100km
            instantConsumption = fuelFlowLitersPerHour // Será interpretado como L/h en la UI
        }

        // Actualizar estadísticas del trip
        updateTripStatistics(fuelFlowLitersPerHour: fuelFlowLitersPerHour, speedKmh: speedKmh)

        return instantConsumption
    }

    /// El motor rotativo tiene características de AFR específicas
    private func calculateEffectiveAFR(rpm: Int, maf: Double) -> Double {
        // En aceleración fuerte o RPM altos, el motor enriquece la mezcla
        if rpm > 7000 {
            return 12.5 // Mezcla rica para potencia/refrigeración
        } else if rpm > 5000 {
            return 13.5
        } else if rpm < 1500 {
            return 13.0 // Ralentí ligeramente rico para estabilidad
        }
        return airFuelRatioStoich // 14.7 en condiciones normales
    }

    // MARK: - Estadísticas del Viaje

    private func updateTripStatistics(fuelFlowLitersPerHour: Double, speedKmh: Double) {
        guard tripStartTime != nil else { return }

        let now = Date()

        // Calcular tiempo real transcurrido desde última actualización
        var deltaTimeHours: Double
        if let lastTime = lastUpdateTime {
            let deltaSeconds = now.timeIntervalSince(lastTime)
            // Limitar a máximo 2 segundos para evitar saltos grandes
            deltaTimeHours = min(deltaSeconds, 2.0) / 3600.0
        } else {
            // Primera lectura - usar un valor pequeño
            deltaTimeHours = 0.1 / 3600.0
        }
        lastUpdateTime = now

        // Combustible usado en este intervalo
        let fuelUsedInterval = fuelFlowLitersPerHour * deltaTimeHours
        fuelUsedTrip += fuelUsedInterval

        // Distancia recorrida en este intervalo (solo si hay velocidad)
        if speedKmh > 1 {
            let distanceInterval = speedKmh * deltaTimeHours
            distanceTrip += distanceInterval
        }

        // Consumo medio del viaje
        if distanceTrip > 0.1 {
            tripConsumption = (fuelUsedTrip / distanceTrip) * 100

            // Actualizar media móvil solo cuando el consumo es válido (en movimiento)
            if speedKmh > 10 && instantConsumption > 0 && instantConsumption < 40 {
                consumptionHistory.append(instantConsumption)
                // Mantener últimas 500 muestras (~8 minutos de conducción)
                if consumptionHistory.count > 500 {
                    consumptionHistory.removeFirst()
                }
                // Calcular media
                averageConsumption = consumptionHistory.reduce(0, +) / Double(consumptionHistory.count)
            }
        }

        // Costo estimado
        fuelCost = fuelUsedTrip * fuelPricePerLiter

        // Emisiones CO2 (gasolina: ~2.31 kg CO2 por litro)
        co2Emissions = (fuelUsedTrip * 2310) / max(distanceTrip, 0.1) // g/km

        // Recalcular autonomía con los nuevos datos
        calculateRangeAutomatically()
    }

    // MARK: - Control del Viaje

    public func startTrip() {
        tripStartTime = Date()
        lastUpdateTime = nil
        fuelUsedTrip = 0
        distanceTrip = 0
        tripConsumption = 0
        fuelCost = 0
        mafReadings.removeAll()
        speedReadings.removeAll()
        consumptionHistory.removeAll()
        // Mantener averageConsumption ya que es una media histórica
    }

    public func endTrip() -> TripSummary {
        let summary = TripSummary(
            startTime: tripStartTime ?? Date(),
            endTime: Date(),
            distance: distanceTrip,
            fuelUsed: fuelUsedTrip,
            averageConsumption: tripConsumption,
            fuelCost: fuelCost,
            averageSpeed: calculateAverageSpeed(),
            co2Emissions: co2Emissions * distanceTrip / 1000 // kg totales
        )

        tripStartTime = nil
        return summary
    }

    private func calculateAverageSpeed() -> Double {
        guard !speedReadings.isEmpty else { return 0 }
        let total = speedReadings.reduce(0) { $0 + $1.speedKmh }
        return total / Double(speedReadings.count)
    }

    // MARK: - Autonomía Estimada

    public func calculateRange(currentFuelLevel: Double) { // % del tanque
        let fuelRemaining = tankCapacity * (currentFuelLevel / 100)

        // Usar consumo medio si está disponible, si no usar consumo típico RX-8
        let consumptionToUse = averageConsumption > 0 ? averageConsumption : 13.0 // L/100km típico

        // Autonomía = (Litros restantes / (L/100km)) * 100
        estimatedRange = (fuelRemaining / consumptionToUse) * 100
    }

    /// Actualiza el nivel de combustible desde el sensor OBD2
    public func updateFuelLevel(_ level: Double) {
        fuelLevel = level
        fuelLevelLiters = tankCapacity * (level / 100)
        fuelLevelAvailable = true
        calculateRangeAutomatically()
    }

    /// Establece nivel manual (cuando el sensor no está disponible)
    public func setManualFuelLevel(_ liters: Double) {
        manualFuelLevel = liters
        fuelLevelLiters = liters
        fuelLevel = (liters / tankCapacity) * 100
        calculateRangeAutomatically()
    }

    /// Calcula la autonomía automáticamente basándose en el nivel actual
    private func calculateRangeAutomatically() {
        let effectiveLevel = manualFuelLevel ?? fuelLevelLiters

        // Usar consumo del viaje actual si hay datos, si no usar promedio o típico
        var consumptionToUse: Double
        if tripConsumption > 0 && distanceTrip > 5 {
            // Consumo del viaje actual (más preciso para condiciones actuales)
            consumptionToUse = tripConsumption
        } else if averageConsumption > 0 {
            consumptionToUse = averageConsumption
        } else {
            consumptionToUse = 13.0 // Consumo típico RX-8
        }

        // Autonomía = (Litros restantes / (L/100km)) * 100
        if consumptionToUse > 0 {
            estimatedRange = (effectiveLevel / consumptionToUse) * 100
        }
    }

    /// Actualiza datos adicionales del OBD
    public func updateOBDData(runtime: Int, distanceSinceClear: Int) {
        runtimeSeconds = runtime
        distanceSinceDTCClear = distanceSinceClear
    }

    /// Formato de tiempo de ejecución
    public var runtimeFormatted: String {
        let hours = runtimeSeconds / 3600
        let minutes = (runtimeSeconds % 3600) / 60
        let seconds = runtimeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Consumo Medio Histórico

    public func updateAverageConsumption(from history: [TripSummary]) {
        guard !history.isEmpty else { return }

        let totalDistance = history.reduce(0) { $0 + $1.distance }
        let totalFuel = history.reduce(0) { $0 + $1.fuelUsed }

        if totalDistance > 0 {
            averageConsumption = (totalFuel / totalDistance) * 100
        }
    }
}

// MARK: - Resumen del Viaje

public struct TripSummary: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let distance: Double // km
    public let fuelUsed: Double // L
    public let averageConsumption: Double // L/100km
    public let fuelCost: Double // €
    public let averageSpeed: Double // km/h
    public let co2Emissions: Double // kg

    public init(startTime: Date, endTime: Date, distance: Double, fuelUsed: Double,
                averageConsumption: Double, fuelCost: Double, averageSpeed: Double, co2Emissions: Double) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.fuelUsed = fuelUsed
        self.averageConsumption = averageConsumption
        self.fuelCost = fuelCost
        self.averageSpeed = averageSpeed
        self.co2Emissions = co2Emissions
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Tipo de Combustible

public enum FuelType: String, Codable, Sendable, CaseIterable {
    case gasoline95 = "Gasolina 95"
    case gasoline98 = "Gasolina 98"
    case gasoline100 = "Gasolina 100"

    public var recommendedForRX8: Bool {
        switch self {
        case .gasoline95: return true // Mínimo recomendado
        case .gasoline98: return true // Recomendado
        case .gasoline100: return true // Óptimo para track
        }
    }

    public var co2PerLiter: Double { // kg CO2/L
        return 2.31 // Similar para todas las gasolinas
    }
}

// MARK: - Datos de Consumo RX-8 de Referencia

public struct RX8ConsumptionReference {
    // Consumos típicos del RX-8 (L/100km)
    public static let cityTypical: Double = 15.0
    public static let highwayTypical: Double = 10.0
    public static let mixedTypical: Double = 13.0
    public static let trackDay: Double = 25.0 // Circuito

    // Consumos por modo de conducción
    public static func estimatedConsumption(forDrivingStyle style: DrivingStyle) -> Double {
        switch style {
        case .eco: return 11.0
        case .normal: return 13.0
        case .sport: return 16.0
        case .track: return 25.0
        }
    }
}

public enum DrivingStyle: String, Codable, Sendable {
    case eco = "Eco"
    case normal = "Normal"
    case sport = "Sport"
    case track = "Circuito"
}

// MARK: - Widget de Consumo para UI

public struct ConsumptionDisplayData {
    public let instantValue: Double
    public let instantUnit: String // "L/100km" o "L/h" en ralentí
    public let averageValue: Double
    public let rangeValue: Double
    public let fuelLevel: Double
    public let tripDistance: Double
    public let tripFuelUsed: Double

    public var instantFormatted: String {
        if instantUnit == "L/h" {
            return String(format: "%.1f", instantValue)
        }
        return String(format: "%.1f", instantValue)
    }

    public var averageFormatted: String {
        String(format: "%.1f L/100km", averageValue)
    }

    public var rangeFormatted: String {
        String(format: "%.0f km", rangeValue)
    }

    public var efficiencyRating: EfficiencyRating {
        if averageValue < 11 {
            return .excellent
        } else if averageValue < 13 {
            return .good
        } else if averageValue < 15 {
            return .normal
        } else if averageValue < 18 {
            return .high
        } else {
            return .veryHigh
        }
    }
}

public enum EfficiencyRating: String {
    case excellent = "Excelente"
    case good = "Bueno"
    case normal = "Normal"
    case high = "Alto"
    case veryHigh = "Muy Alto"

    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "teal"
        case .normal: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }

    public var icon: String {
        switch self {
        case .excellent: return "leaf.fill"
        case .good: return "leaf"
        case .normal: return "car.fill"
        case .high: return "flame"
        case .veryHigh: return "flame.fill"
        }
    }
}
