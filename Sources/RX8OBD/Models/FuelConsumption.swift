import Foundation
import SQLite3

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
    @Published public var odometerKm: Int = 0 // Odómetro total del vehículo
    @Published public var odometerAvailable: Bool = false // Si el odómetro está disponible
    @Published public var tripStartOdometerKm: Int = 0 // Odómetro al inicio del viaje

    // MARK: - Parciales de consumo
    @Published public var partial1: TripPartial = TripPartial(id: 1) // Viaje actual
    @Published public var partial2: TripPartial = TripPartial(id: 2) // Acumulado

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
    private let consumptionDB = ConsumptionDatabase()

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
        // Cargar parciales desde la base de datos
        loadPartials()
    }

    // MARK: - Parciales

    public func loadPartials() {
        partial1 = consumptionDB.getPartial(1)
        partial2 = consumptionDB.getPartial(2)
    }

    public func resetPartial(_ id: Int) {
        consumptionDB.resetPartial(id)
        loadPartials()
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

        // Guardar en la base de datos de consumo (parciales)
        if speedKmh > 1 {
            let deltaSeconds = deltaTimeHours * 3600
            let distanceInterval = speedKmh * deltaTimeHours

            consumptionDB.recordConsumptionData(
                distanceKm: distanceInterval,
                fuelUsedLiters: fuelUsedInterval,
                speedKmh: speedKmh,
                fuelPricePerLiter: fuelPricePerLiter,
                drivingTimeSeconds: deltaSeconds
            )

            // Actualizar parciales publicados cada ~5 segundos para no sobrecargar UI
            if Int(distanceTrip * 1000) % 50 == 0 {
                partial1 = consumptionDB.getPartial(1)
                partial2 = consumptionDB.getPartial(2)
            }
        }
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

        // Verificar si debemos continuar el viaje anterior o empezar uno nuevo
        let continuedTrip = consumptionDB.startOrContinueTrip()
        if !continuedTrip {
            // Nuevo viaje, cargar parciales actualizados
            loadPartials()
        }
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
    public func updateOBDData(runtime: Int, distanceSinceClear: Int, odometer: Int? = nil) {
        runtimeSeconds = runtime
        distanceSinceDTCClear = distanceSinceClear

        // Actualizar odómetro si está disponible
        if let odo = odometer, odo > 0 {
            odometerKm = odo
            odometerAvailable = true

            // Si tenemos odómetro de inicio, calcular distancia real
            if tripStartOdometerKm > 0 {
                let realDistance = Double(odo - tripStartOdometerKm)
                if realDistance >= 0 && realDistance < 10000 { // Validar rango razonable
                    distanceTrip = realDistance
                }
            }
        }
    }

    /// Actualiza el odómetro al inicio del viaje
    public func setTripStartOdometer(_ odometer: Int) {
        tripStartOdometerKm = odometer
        odometerKm = odometer
        odometerAvailable = true
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

// MARK: - Trip Partial Model

public struct TripPartial {
    public let id: Int // 1 = viaje actual, 2 = acumulado
    public var distance: Double = 0 // km
    public var fuelUsed: Double = 0 // litros
    public var fuelCost: Double = 0 // €
    public var startTime: Date?
    public var lastUpdate: Date?
    public var avgConsumption: Double = 0 // L/100km
    public var avgSpeed: Double = 0 // km/h
    public var maxSpeed: Double = 0 // km/h
    public var drivingTime: TimeInterval = 0 // segundos
    public var co2Emissions: Double = 0 // kg

    public init(id: Int) {
        self.id = id
    }

    public var drivingTimeFormatted: String {
        let hours = Int(drivingTime) / 3600
        let minutes = (Int(drivingTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    public var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"

        guard let start = startTime else { return "--" }

        if let last = lastUpdate, !Calendar.current.isDate(start, inSameDayAs: last) {
            return "\(formatter.string(from: start)) - \(formatter.string(from: last))"
        }
        return formatter.string(from: start)
    }

    public var name: String {
        id == 1 ? "Viaje Actual" : "Acumulado"
    }
}

// MARK: - Consumption Database
// Guarda los parciales de consumo (viaje actual y acumulado)

public class ConsumptionDatabase {
    private var db: OpaquePointer?
    private let dbPath: String

    // Tiempo máximo de parada para considerar el mismo viaje (2 horas)
    private let maxStopTimeForSameTrip: TimeInterval = 2 * 60 * 60

    public init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = documents.appendingPathComponent("consumption.sqlite").path

        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Consumption DB: Error opening database")
        }
    }

    private func createTables() {
        // Tabla de parciales
        let createPartials = """
        CREATE TABLE IF NOT EXISTS partials (
            id INTEGER PRIMARY KEY CHECK (id IN (1, 2)),
            distance REAL DEFAULT 0,
            fuel_used REAL DEFAULT 0,
            fuel_cost REAL DEFAULT 0,
            start_time REAL,
            last_update REAL,
            avg_consumption REAL DEFAULT 0,
            avg_speed REAL DEFAULT 0,
            max_speed REAL DEFAULT 0,
            driving_time REAL DEFAULT 0,
            co2_emissions REAL DEFAULT 0
        );
        """

        // Tabla de configuración
        let createConfig = """
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """

        // Insertar registros iniciales si no existen
        let initPartials = """
        INSERT OR IGNORE INTO partials (id) VALUES (1);
        INSERT OR IGNORE INTO partials (id) VALUES (2);
        """

        executeSQL(createPartials)
        executeSQL(createConfig)
        executeSQL(initPartials)
    }

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("Consumption SQL Error: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Partial Management

    public func getPartial(_ id: Int) -> TripPartial {
        var partial = TripPartial(id: id)

        let sql = """
        SELECT distance, fuel_used, fuel_cost, start_time, last_update,
               avg_consumption, avg_speed, max_speed, driving_time, co2_emissions
        FROM partials WHERE id = ?;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                partial.distance = sqlite3_column_double(stmt, 0)
                partial.fuelUsed = sqlite3_column_double(stmt, 1)
                partial.fuelCost = sqlite3_column_double(stmt, 2)
                if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
                    partial.startTime = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                }
                if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
                    partial.lastUpdate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                }
                partial.avgConsumption = sqlite3_column_double(stmt, 5)
                partial.avgSpeed = sqlite3_column_double(stmt, 6)
                partial.maxSpeed = sqlite3_column_double(stmt, 7)
                partial.drivingTime = sqlite3_column_double(stmt, 8)
                partial.co2Emissions = sqlite3_column_double(stmt, 9)
            }
        }
        sqlite3_finalize(stmt)

        return partial
    }

    public func updatePartial(_ partial: TripPartial) {
        let sql = """
        UPDATE partials SET
            distance = ?,
            fuel_used = ?,
            fuel_cost = ?,
            start_time = ?,
            last_update = ?,
            avg_consumption = ?,
            avg_speed = ?,
            max_speed = ?,
            driving_time = ?,
            co2_emissions = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, partial.distance)
            sqlite3_bind_double(stmt, 2, partial.fuelUsed)
            sqlite3_bind_double(stmt, 3, partial.fuelCost)
            if let start = partial.startTime {
                sqlite3_bind_double(stmt, 4, start.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            if let last = partial.lastUpdate {
                sqlite3_bind_double(stmt, 5, last.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_double(stmt, 6, partial.avgConsumption)
            sqlite3_bind_double(stmt, 7, partial.avgSpeed)
            sqlite3_bind_double(stmt, 8, partial.maxSpeed)
            sqlite3_bind_double(stmt, 9, partial.drivingTime)
            sqlite3_bind_double(stmt, 10, partial.co2Emissions)
            sqlite3_bind_int(stmt, 11, Int32(partial.id))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func resetPartial(_ id: Int) {
        let sql = """
        UPDATE partials SET
            distance = 0,
            fuel_used = 0,
            fuel_cost = 0,
            start_time = NULL,
            last_update = NULL,
            avg_consumption = 0,
            avg_speed = 0,
            max_speed = 0,
            driving_time = 0,
            co2_emissions = 0
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Trip Logic

    /// Determina si debemos continuar con el viaje actual o empezar uno nuevo
    public func shouldContinueTrip() -> Bool {
        let partial1 = getPartial(1)

        guard let lastUpdate = partial1.lastUpdate else {
            return false // No hay viaje previo
        }

        // Si la última actualización fue hace menos de 2 horas, continuamos el viaje
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceLastUpdate < maxStopTimeForSameTrip
    }

    /// Inicia o continúa un viaje
    public func startOrContinueTrip() -> Bool {
        let shouldContinue = shouldContinueTrip()

        if !shouldContinue {
            // Nuevo viaje - resetear parcial 1
            resetPartial(1)

            var partial1 = getPartial(1)
            partial1.startTime = Date()
            partial1.lastUpdate = Date()
            updatePartial(partial1)
        }

        return shouldContinue
    }

    /// Registra datos de consumo para ambos parciales
    public func recordConsumptionData(
        distanceKm: Double,
        fuelUsedLiters: Double,
        speedKmh: Double,
        fuelPricePerLiter: Double,
        drivingTimeSeconds: Double
    ) {
        let now = Date()

        // Actualizar parcial 1 (viaje actual)
        var partial1 = getPartial(1)
        if partial1.startTime == nil {
            partial1.startTime = now
        }
        partial1.distance += distanceKm
        partial1.fuelUsed += fuelUsedLiters
        partial1.fuelCost = partial1.fuelUsed * fuelPricePerLiter
        partial1.lastUpdate = now
        partial1.maxSpeed = max(partial1.maxSpeed, speedKmh)
        partial1.drivingTime += drivingTimeSeconds

        if partial1.distance > 0.1 {
            partial1.avgConsumption = (partial1.fuelUsed / partial1.distance) * 100
        }
        if partial1.drivingTime > 0 {
            partial1.avgSpeed = partial1.distance / (partial1.drivingTime / 3600)
        }
        partial1.co2Emissions = partial1.fuelUsed * 2.31 // kg CO2 por litro de gasolina

        updatePartial(partial1)

        // Actualizar parcial 2 (acumulado)
        var partial2 = getPartial(2)
        if partial2.startTime == nil {
            partial2.startTime = now
        }
        partial2.distance += distanceKm
        partial2.fuelUsed += fuelUsedLiters
        partial2.fuelCost = partial2.fuelUsed * fuelPricePerLiter
        partial2.lastUpdate = now
        partial2.maxSpeed = max(partial2.maxSpeed, speedKmh)
        partial2.drivingTime += drivingTimeSeconds

        if partial2.distance > 0.1 {
            partial2.avgConsumption = (partial2.fuelUsed / partial2.distance) * 100
        }
        if partial2.drivingTime > 0 {
            partial2.avgSpeed = partial2.distance / (partial2.drivingTime / 3600)
        }
        partial2.co2Emissions = partial2.fuelUsed * 2.31

        updatePartial(partial2)
    }

    // MARK: - Config

    public func setConfig(_ key: String, value: String) {
        let sql = "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, nil)
            sqlite3_bind_text(stmt, 2, value, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func getConfig(_ key: String) -> String? {
        let sql = "SELECT value FROM config WHERE key = ?;"
        var stmt: OpaquePointer?
        var result: String?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        return result
    }
}
