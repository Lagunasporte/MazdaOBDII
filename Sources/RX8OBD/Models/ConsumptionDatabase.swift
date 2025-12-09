import Foundation
import SQLite3

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
