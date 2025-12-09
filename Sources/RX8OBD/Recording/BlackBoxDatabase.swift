import Foundation
import SQLite3

// MARK: - Black Box Database
// Sistema de caja negra con SQLite - guarda sesiones automáticamente

public class BlackBoxDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    public static let maxSessions = 30

    // SQLITE_TRANSIENT para que SQLite haga una copia del string antes de que Swift lo libere
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init() {
        // Crear ruta en Documents
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = documents.appendingPathComponent("blackbox.sqlite").path

        openDatabase()
        createTables()
        cleanupOldSessions()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("BlackBox: Error opening database")
        }
    }

    private func createTables() {
        // Tabla de sesiones
        let createSessions = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            start_time REAL NOT NULL,
            end_time REAL,
            total_distance REAL DEFAULT 0,
            max_rpm INTEGER DEFAULT 0,
            max_speed REAL DEFAULT 0,
            max_coolant_temp REAL DEFAULT 0,
            max_oil_temp REAL DEFAULT 0,
            avg_consumption REAL DEFAULT 0,
            dtc_count INTEGER DEFAULT 0,
            alert_count INTEGER DEFAULT 0,
            notes TEXT,
            analysis_sent INTEGER DEFAULT 0,
            analysis_result TEXT,
            duration_seconds REAL DEFAULT 0
        );
        """

        // Tabla de snapshots (datos del motor) - Expandida para diagnóstico forense
        let createSnapshots = """
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            rpm INTEGER,
            speed REAL,
            coolant_temp REAL,
            oil_temp REAL,
            intake_temp REAL,
            catalyst_temp REAL,
            throttle REAL,
            maf REAL,
            stft REAL,
            ltft REAL,
            timing REAL,
            voltage REAL,
            fuel_level REAL,
            load REAL,
            o2b1s1 REAL DEFAULT 0,
            o2b1s2 REAL DEFAULT 0,
            map REAL DEFAULT 0,
            accelerator REAL DEFAULT 0,
            stft_b2 REAL DEFAULT 0,
            ltft_b2 REAL DEFAULT 0,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
        """

        // Migración: añadir nuevas columnas si no existen
        let migrations = [
            "ALTER TABLE snapshots ADD COLUMN o2b1s1 REAL DEFAULT 0;",
            "ALTER TABLE snapshots ADD COLUMN o2b1s2 REAL DEFAULT 0;",
            "ALTER TABLE snapshots ADD COLUMN map REAL DEFAULT 0;",
            "ALTER TABLE snapshots ADD COLUMN accelerator REAL DEFAULT 0;",
            "ALTER TABLE snapshots ADD COLUMN stft_b2 REAL DEFAULT 0;",
            "ALTER TABLE snapshots ADD COLUMN ltft_b2 REAL DEFAULT 0;",
            // Sondas de combustible duales (RX-8 saddle tank)
            "ALTER TABLE snapshots ADD COLUMN fuel_level_left REAL;",
            "ALTER TABLE snapshots ADD COLUMN fuel_level_right REAL;"
        ]

        // Tabla de alertas
        let createAlerts = """
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            type TEXT NOT NULL,
            severity TEXT NOT NULL,
            parameter TEXT,
            value REAL,
            threshold REAL,
            message TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
        """

        // Tabla de DTCs
        let createDTCs = """
        CREATE TABLE IF NOT EXISTS dtcs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
        """

        // Índices para búsquedas rápidas
        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_snapshots_session ON snapshots(session_id);
        CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON snapshots(timestamp);
        CREATE INDEX IF NOT EXISTS idx_alerts_session ON alerts(session_id);
        CREATE INDEX IF NOT EXISTS idx_dtcs_session ON dtcs(session_id);
        """

        executeSQL(createSessions)
        executeSQL(createSnapshots)
        executeSQL(createAlerts)
        executeSQL(createDTCs)
        executeSQL(createIndexes)

        // Aplicar migraciones (ignora errores si columnas ya existen)
        for migration in migrations {
            var errMsg: UnsafeMutablePointer<CChar>?
            sqlite3_exec(db, migration, nil, nil, &errMsg)
            if errMsg != nil { sqlite3_free(errMsg) }
        }

        // Migración para duration_seconds
        let durationMigration = "ALTER TABLE sessions ADD COLUMN duration_seconds REAL DEFAULT 0;"
        var errMsg2: UnsafeMutablePointer<CChar>?
        sqlite3_exec(db, durationMigration, nil, nil, &errMsg2)
        if errMsg2 != nil { sqlite3_free(errMsg2) }

        // Calcular y actualizar duración para sesiones antiguas que no la tienen
        updateMissingDurations()
    }

    private func updateMissingDurations() {
        // Buscar sesiones con end_time pero sin duration_seconds calculada
        let sql = """
        SELECT id, start_time, end_time FROM sessions
        WHERE end_time IS NOT NULL AND (duration_seconds IS NULL OR duration_seconds = 0);
        """

        var stmt: OpaquePointer?
        var sessionsToUpdate: [(id: String, duration: Double)] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let startTime = sqlite3_column_double(stmt, 1)
                let endTime = sqlite3_column_double(stmt, 2)
                let duration = endTime - startTime
                if duration > 0 {
                    sessionsToUpdate.append((id, duration))
                }
            }
        }
        sqlite3_finalize(stmt)

        // Actualizar las duraciones
        for session in sessionsToUpdate {
            let updateSql = "UPDATE sessions SET duration_seconds = ? WHERE id = ?;"
            if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, session.duration)
                sqlite3_bind_text(stmt, 2, session.id, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }

        // Para sesiones sin end_time, calcular desde snapshots
        let noEndTimeSql = "SELECT id, start_time FROM sessions WHERE end_time IS NULL;"
        var sessionsWithoutEndTime: [(id: String, startTime: Double)] = []

        if sqlite3_prepare_v2(db, noEndTimeSql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let startTime = sqlite3_column_double(stmt, 1)
                sessionsWithoutEndTime.append((id, startTime))
            }
        }
        sqlite3_finalize(stmt)

        // Calcular duración desde snapshots
        for session in sessionsWithoutEndTime {
            let maxTimeSql = "SELECT MAX(timestamp) FROM snapshots WHERE session_id = ?;"
            if sqlite3_prepare_v2(db, maxTimeSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, session.id, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_ROW && sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                    let lastSnapshotTime = sqlite3_column_double(stmt, 0)
                    let duration = lastSnapshotTime - session.startTime
                    if duration > 0 {
                        sqlite3_finalize(stmt)
                        // Actualizar tanto end_time como duration_seconds
                        let updateSql = "UPDATE sessions SET end_time = ?, duration_seconds = ? WHERE id = ?;"
                        if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
                            sqlite3_bind_double(stmt, 1, lastSnapshotTime)
                            sqlite3_bind_double(stmt, 2, duration)
                            sqlite3_bind_text(stmt, 3, session.id, -1, SQLITE_TRANSIENT)
                            sqlite3_step(stmt)
                        }
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("BlackBox SQL Error: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Session Management

    public func createSession() -> String {
        let sessionId = UUID().uuidString
        let startTime = Date().timeIntervalSince1970

        let sql = "INSERT INTO sessions (id, start_time) VALUES (?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, startTime)
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("BlackBox: Error creating session - \(String(cString: sqlite3_errmsg(db)))")
            } else {
                print("BlackBox: Session created successfully - \(sessionId)")
            }
        } else {
            print("BlackBox: Error preparing create session - \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)

        return sessionId
    }

    public func endSession(_ sessionId: String) {
        let endTime = Date().timeIntervalSince1970

        // Obtener start_time para calcular duración
        var startTime: Double = 0
        let startSql = "SELECT start_time FROM sessions WHERE id = ?;"
        var startStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, startSql, -1, &startStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(startStmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(startStmt) == SQLITE_ROW {
                startTime = sqlite3_column_double(startStmt, 0)
            }
        }
        sqlite3_finalize(startStmt)

        // Calcular duración real
        let durationSeconds = endTime - startTime

        // Calcular estadísticas de la sesión
        let stats = calculateSessionStats(sessionId)

        let sql = """
        UPDATE sessions SET
            end_time = ?,
            duration_seconds = ?,
            total_distance = ?,
            max_rpm = ?,
            max_speed = ?,
            max_coolant_temp = ?,
            max_oil_temp = ?,
            avg_consumption = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, endTime)
            sqlite3_bind_double(stmt, 2, durationSeconds)
            sqlite3_bind_double(stmt, 3, stats.totalDistance)
            sqlite3_bind_int(stmt, 4, Int32(stats.maxRPM))
            sqlite3_bind_double(stmt, 5, stats.maxSpeed)
            sqlite3_bind_double(stmt, 6, stats.maxCoolantTemp)
            sqlite3_bind_double(stmt, 7, stats.maxOilTemp)
            sqlite3_bind_double(stmt, 8, stats.avgConsumption)
            sqlite3_bind_text(stmt, 9, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Actualizar contadores
        updateSessionCounts(sessionId)

        // Limpiar sesiones antiguas si hay más de 30
        cleanupOldSessions()
    }

    private func calculateSessionStats(_ sessionId: String) -> SessionStats {
        var stats = SessionStats()

        let sql = """
        SELECT
            MAX(rpm) as max_rpm,
            MAX(speed) as max_speed,
            MAX(coolant_temp) as max_coolant,
            MAX(oil_temp) as max_oil,
            AVG(CASE WHEN speed > 10 THEN (maf * 0.0026 / speed * 100) ELSE NULL END) as avg_consumption
        FROM snapshots WHERE session_id = ?;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                stats.maxRPM = Int(sqlite3_column_int(stmt, 0))
                stats.maxSpeed = sqlite3_column_double(stmt, 1)
                stats.maxCoolantTemp = sqlite3_column_double(stmt, 2)
                stats.maxOilTemp = sqlite3_column_double(stmt, 3)
                stats.avgConsumption = sqlite3_column_double(stmt, 4)
            }
        }
        sqlite3_finalize(stmt)

        // Calcular distancia (integrar velocidad sobre tiempo)
        let distSql = """
        SELECT timestamp, speed FROM snapshots
        WHERE session_id = ? ORDER BY timestamp;
        """

        var lastTime: Double?
        var totalDistance: Double = 0

        if sqlite3_prepare_v2(db, distSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let time = sqlite3_column_double(stmt, 0)
                let speed = sqlite3_column_double(stmt, 1)

                if let last = lastTime {
                    let deltaHours = (time - last) / 3600.0
                    totalDistance += speed * deltaHours
                }
                lastTime = time
            }
        }
        sqlite3_finalize(stmt)

        stats.totalDistance = totalDistance
        return stats
    }

    private func updateSessionCounts(_ sessionId: String) {
        // Contar DTCs
        var dtcCount = 0
        let dtcSql = "SELECT COUNT(*) FROM dtcs WHERE session_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, dtcSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                dtcCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        // Contar alertas
        var alertCount = 0
        let alertSql = "SELECT COUNT(*) FROM alerts WHERE session_id = ?;"
        if sqlite3_prepare_v2(db, alertSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                alertCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        // Actualizar
        let updateSql = "UPDATE sessions SET dtc_count = ?, alert_count = ? WHERE id = ?;"
        if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(dtcCount))
            sqlite3_bind_int(stmt, 2, Int32(alertCount))
            sqlite3_bind_text(stmt, 3, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func cleanupOldSessions() {
        // Obtener número de sesiones
        let countSql = "SELECT COUNT(*) FROM sessions;"
        var stmt: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, countSql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        // Si hay más de 30, eliminar las más antiguas
        if count > Self.maxSessions {
            let toDelete = count - Self.maxSessions
            let deleteSql = """
            DELETE FROM sessions WHERE id IN (
                SELECT id FROM sessions ORDER BY start_time ASC LIMIT ?
            );
            """

            if sqlite3_prepare_v2(db, deleteSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(toDelete))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Data Recording

    public func recordSnapshot(_ sessionId: String, data: EngineSnapshot) {
        let sql = """
        INSERT INTO snapshots (
            session_id, timestamp, rpm, speed, coolant_temp, oil_temp, intake_temp,
            catalyst_temp, throttle, maf, stft, ltft, timing, voltage, fuel_level, load,
            o2b1s1, o2b1s2, map, accelerator, stft_b2, ltft_b2, fuel_level_left, fuel_level_right
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, data.timestamp)
            sqlite3_bind_int(stmt, 3, Int32(data.rpm))
            sqlite3_bind_double(stmt, 4, data.speed)
            sqlite3_bind_double(stmt, 5, data.coolantTemp)
            sqlite3_bind_double(stmt, 6, data.oilTemp)
            sqlite3_bind_double(stmt, 7, data.intakeTemp)
            sqlite3_bind_double(stmt, 8, data.catalystTemp)
            sqlite3_bind_double(stmt, 9, data.throttle)
            sqlite3_bind_double(stmt, 10, data.maf)
            sqlite3_bind_double(stmt, 11, data.stft)
            sqlite3_bind_double(stmt, 12, data.ltft)
            sqlite3_bind_double(stmt, 13, data.timing)
            sqlite3_bind_double(stmt, 14, data.voltage)
            sqlite3_bind_double(stmt, 15, data.fuelLevel)
            sqlite3_bind_double(stmt, 16, data.load)
            sqlite3_bind_double(stmt, 17, data.o2b1s1)
            sqlite3_bind_double(stmt, 18, data.o2b1s2)
            sqlite3_bind_double(stmt, 19, data.map)
            sqlite3_bind_double(stmt, 20, data.accelerator)
            sqlite3_bind_double(stmt, 21, data.stftB2)
            sqlite3_bind_double(stmt, 22, data.ltftB2)
            // Sondas de combustible duales - pueden ser nil
            if let leftLevel = data.fuelLevelLeft {
                sqlite3_bind_double(stmt, 23, leftLevel)
            } else {
                sqlite3_bind_null(stmt, 23)
            }
            if let rightLevel = data.fuelLevelRight {
                sqlite3_bind_double(stmt, 24, rightLevel)
            } else {
                sqlite3_bind_null(stmt, 24)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func recordAlert(_ sessionId: String, alert: BlackBoxAlert) {
        let sql = """
        INSERT INTO alerts (session_id, timestamp, type, severity, parameter, value, threshold, message)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, alert.timestamp)
            sqlite3_bind_text(stmt, 3, alert.type, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, alert.severity, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, alert.parameter, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 6, alert.value)
            sqlite3_bind_double(stmt, 7, alert.threshold)
            sqlite3_bind_text(stmt, 8, alert.message, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func recordDTC(_ sessionId: String, code: String, description: String) {
        // Verificar si ya existe
        let checkSql = "SELECT COUNT(*) FROM dtcs WHERE session_id = ? AND code = ?;"
        var stmt: OpaquePointer?
        var exists = false

        if sqlite3_prepare_v2(db, checkSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, code, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                exists = sqlite3_column_int(stmt, 0) > 0
            }
        }
        sqlite3_finalize(stmt)

        if !exists {
            let sql = "INSERT INTO dtcs (session_id, timestamp, code, description) VALUES (?, ?, ?, ?);"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, code, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, description, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Query Methods

    public func getAllSessions() -> [BlackBoxSession] {
        var sessions: [BlackBoxSession] = []

        let sql = """
        SELECT id, start_time, end_time, total_distance, max_rpm, max_speed,
               max_coolant_temp, max_oil_temp, avg_consumption, dtc_count, alert_count,
               notes, analysis_sent, analysis_result, duration_seconds
        FROM sessions ORDER BY start_time DESC;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let session = BlackBoxSession(
                    id: String(cString: sqlite3_column_text(stmt, 0)),
                    startTime: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                    endTime: sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)) : nil,
                    totalDistance: sqlite3_column_double(stmt, 3),
                    maxRPM: Int(sqlite3_column_int(stmt, 4)),
                    maxSpeed: sqlite3_column_double(stmt, 5),
                    maxCoolantTemp: sqlite3_column_double(stmt, 6),
                    maxOilTemp: sqlite3_column_double(stmt, 7),
                    avgConsumption: sqlite3_column_double(stmt, 8),
                    dtcCount: Int(sqlite3_column_int(stmt, 9)),
                    alertCount: Int(sqlite3_column_int(stmt, 10)),
                    notes: sqlite3_column_type(stmt, 11) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 11)) : nil,
                    analysisSent: sqlite3_column_int(stmt, 12) == 1,
                    analysisResult: sqlite3_column_type(stmt, 13) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 13)) : nil,
                    durationSeconds: sqlite3_column_double(stmt, 14)
                )
                sessions.append(session)
            }
        }
        sqlite3_finalize(stmt)

        return sessions
    }

    public func getSessionSnapshots(_ sessionId: String) -> [EngineSnapshot] {
        var snapshots: [EngineSnapshot] = []

        let sql = """
        SELECT timestamp, rpm, speed, coolant_temp, oil_temp, intake_temp,
               catalyst_temp, throttle, maf, stft, ltft, timing, voltage, fuel_level, load,
               o2b1s1, o2b1s2, map, accelerator, stft_b2, ltft_b2,
               fuel_level_left, fuel_level_right
        FROM snapshots WHERE session_id = ? ORDER BY timestamp;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                // Leer sondas de combustible duales (pueden ser NULL)
                let fuelLeft: Double? = sqlite3_column_type(stmt, 21) != SQLITE_NULL ? sqlite3_column_double(stmt, 21) : nil
                let fuelRight: Double? = sqlite3_column_type(stmt, 22) != SQLITE_NULL ? sqlite3_column_double(stmt, 22) : nil

                let snapshot = EngineSnapshot(
                    timestamp: sqlite3_column_double(stmt, 0),
                    rpm: Int(sqlite3_column_int(stmt, 1)),
                    speed: sqlite3_column_double(stmt, 2),
                    coolantTemp: sqlite3_column_double(stmt, 3),
                    oilTemp: sqlite3_column_double(stmt, 4),
                    intakeTemp: sqlite3_column_double(stmt, 5),
                    catalystTemp: sqlite3_column_double(stmt, 6),
                    throttle: sqlite3_column_double(stmt, 7),
                    maf: sqlite3_column_double(stmt, 8),
                    stft: sqlite3_column_double(stmt, 9),
                    ltft: sqlite3_column_double(stmt, 10),
                    timing: sqlite3_column_double(stmt, 11),
                    voltage: sqlite3_column_double(stmt, 12),
                    fuelLevel: sqlite3_column_double(stmt, 13),
                    load: sqlite3_column_double(stmt, 14),
                    o2b1s1: sqlite3_column_double(stmt, 15),
                    o2b1s2: sqlite3_column_double(stmt, 16),
                    map: sqlite3_column_double(stmt, 17),
                    accelerator: sqlite3_column_double(stmt, 18),
                    stftB2: sqlite3_column_double(stmt, 19),
                    ltftB2: sqlite3_column_double(stmt, 20),
                    fuelLevelLeft: fuelLeft,
                    fuelLevelRight: fuelRight
                )
                snapshots.append(snapshot)
            }
        }
        sqlite3_finalize(stmt)

        return snapshots
    }

    public func getSessionAlerts(_ sessionId: String) -> [BlackBoxAlert] {
        var alerts: [BlackBoxAlert] = []

        let sql = """
        SELECT timestamp, type, severity, parameter, value, threshold, message
        FROM alerts WHERE session_id = ? ORDER BY timestamp;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let alert = BlackBoxAlert(
                    timestamp: sqlite3_column_double(stmt, 0),
                    type: String(cString: sqlite3_column_text(stmt, 1)),
                    severity: String(cString: sqlite3_column_text(stmt, 2)),
                    parameter: sqlite3_column_type(stmt, 3) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 3)) : nil,
                    value: sqlite3_column_double(stmt, 4),
                    threshold: sqlite3_column_double(stmt, 5),
                    message: String(cString: sqlite3_column_text(stmt, 6))
                )
                alerts.append(alert)
            }
        }
        sqlite3_finalize(stmt)

        return alerts
    }

    public func getSessionDTCs(_ sessionId: String) -> [(code: String, description: String)] {
        var dtcs: [(code: String, description: String)] = []

        let sql = "SELECT code, description FROM dtcs WHERE session_id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(stmt, 0))
                let desc = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 1)) : ""
                dtcs.append((code, desc))
            }
        }
        sqlite3_finalize(stmt)

        return dtcs
    }

    public func deleteSession(_ sessionId: String) {
        // Las tablas relacionadas se borran en cascada
        let sql = "DELETE FROM sessions WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func saveAnalysisResult(_ sessionId: String, result: String) {
        let sql = "UPDATE sessions SET analysis_sent = 1, analysis_result = ? WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, result, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func addNote(_ sessionId: String, note: String) {
        let sql = "UPDATE sessions SET notes = ? WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, note, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Export for Analysis

    public func exportSessionForAnalysis(_ sessionId: String) -> String {
        guard let session = getAllSessions().first(where: { $0.id == sessionId }) else {
            return "Sesión no encontrada"
        }

        let snapshots = getSessionSnapshots(sessionId)
        let alerts = getSessionAlerts(sessionId)
        let dtcs = getSessionDTCs(sessionId)

        // Calcular estadísticas detalladas (pre-calculadas para evitar problemas de compilación)
        let rpmValues = snapshots.map { $0.rpm }
        let coolantValues = snapshots.map { $0.coolantTemp }
        let oilValues = snapshots.map { $0.oilTemp }
        let stftValues = snapshots.map { $0.stft }
        let ltftValues = snapshots.map { $0.ltft }
        let o2s1Values = snapshots.map { $0.o2b1s1 }.filter { $0 > 0 }
        let o2s2Values = snapshots.map { $0.o2b1s2 }.filter { $0 > 0 }
        let mapValues = snapshots.map { $0.map }.filter { $0 > 0 }
        let loadValues = snapshots.map { $0.load }.filter { $0 > 0 }
        let stftB2Values = snapshots.map { $0.stftB2 }
        let ltftB2Values = snapshots.map { $0.ltftB2 }

        // Pre-calcular promedios
        let rpmAvg = rpmValues.isEmpty ? 0 : rpmValues.reduce(0, +) / rpmValues.count
        let coolantAvg = coolantValues.isEmpty ? 0 : coolantValues.reduce(0, +) / Double(coolantValues.count)
        let oilAvg = oilValues.isEmpty ? 0 : oilValues.reduce(0, +) / Double(oilValues.count)
        let stftAvg = stftValues.isEmpty ? 0 : stftValues.reduce(0, +) / Double(stftValues.count)
        let ltftAvg = ltftValues.isEmpty ? 0 : ltftValues.reduce(0, +) / Double(ltftValues.count)
        let o2s1Avg = o2s1Values.isEmpty ? 0 : o2s1Values.reduce(0, +) / Double(o2s1Values.count)
        let o2s2Avg = o2s2Values.isEmpty ? 0 : o2s2Values.reduce(0, +) / Double(o2s2Values.count)
        let mapAvg = mapValues.isEmpty ? 0 : mapValues.reduce(0, +) / Double(mapValues.count)
        let loadAvg = loadValues.isEmpty ? 0 : loadValues.reduce(0, +) / Double(loadValues.count)
        let stftB2Avg = stftB2Values.isEmpty ? 0 : stftB2Values.reduce(0, +) / Double(stftB2Values.count)
        let ltftB2Avg = ltftB2Values.isEmpty ? 0 : ltftB2Values.reduce(0, +) / Double(ltftB2Values.count)
        let ltftDiff = abs(ltftAvg - ltftB2Avg)

        // Pre-calcular conteos
        let redlineCount = snapshots.filter { $0.rpm > 8500 }.count
        let idleCount = snapshots.filter { $0.rpm > 0 && $0.rpm < 1000 }.count
        let coolantOverheatCount = snapshots.filter { $0.coolantTemp > 100 }.count
        let oilOverheatCount = snapshots.filter { $0.oilTemp > 120 }.count
        let stftOutOfRange = snapshots.filter { abs($0.stft) > 10 }.count
        let ltftOutOfRange = snapshots.filter { abs($0.ltft) > 10 }.count
        let o2Cycles = countO2Cycles(o2s1Values)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        let sessionDate = dateFormatter.string(from: session.startTime)

        // Construir reporte en partes para evitar errores de compilación
        var report = "# Análisis Forense - Mazda RX-8 Motor Rotativo 13B-MSP Renesis\n\n"

        report += "## Información de la Sesión\n"
        report += "- Fecha: \(sessionDate)\n"
        report += "- Duración: \(session.durationFormatted)\n"
        report += "- Distancia: \(String(format: "%.1f", session.totalDistance)) km\n"
        report += "- Muestras registradas: \(snapshots.count)\n\n"

        report += "## Estadísticas del Motor\n\n"

        report += "### RPM\n"
        report += "- Máximo: \(session.maxRPM)\n"
        report += "- Promedio: \(rpmAvg)\n"
        report += "- Tiempo en zona roja (>8500): \(redlineCount) muestras\n"
        report += "- Tiempo en idle (<1000): \(idleCount) muestras\n\n"

        report += "### Carga del Motor\n"
        report += "- Carga máxima: \(String(format: "%.1f", loadValues.max() ?? 0))%\n"
        report += "- Carga promedio: \(String(format: "%.1f", loadAvg))%\n\n"

        report += "### Temperaturas\n"
        report += "- Refrigerante máx: \(String(format: "%.1f", session.maxCoolantTemp))°C\n"
        report += "- Refrigerante promedio: \(String(format: "%.1f", coolantAvg))°C\n"
        report += "- Aceite máx: \(String(format: "%.1f", session.maxOilTemp))°C\n"
        report += "- Aceite promedio: \(String(format: "%.1f", oilAvg))°C\n"
        report += "- Tiempo sobrecalentamiento ref. (>100°C): \(coolantOverheatCount) muestras\n"
        report += "- Tiempo sobrecalentamiento aceite (>120°C): \(oilOverheatCount) muestras\n\n"

        report += "### Fuel Trims Bank 1 (Rotor Delantero)\n"
        report += "- STFT promedio: \(String(format: "%+.1f", stftAvg))%\n"
        report += "- STFT máx: \(String(format: "%+.1f", stftValues.max() ?? 0))%\n"
        report += "- STFT mín: \(String(format: "%+.1f", stftValues.min() ?? 0))%\n"
        report += "- LTFT promedio: \(String(format: "%+.1f", ltftAvg))%\n"
        report += "- STFT fuera de rango (>±10%): \(stftOutOfRange) muestras\n"
        report += "- LTFT fuera de rango (>±10%): \(ltftOutOfRange) muestras\n\n"

        report += "### Fuel Trims Bank 2 (Rotor Trasero)\n"
        report += "- STFT B2 promedio: \(String(format: "%+.1f", stftB2Avg))%\n"
        report += "- LTFT B2 promedio: \(String(format: "%+.1f", ltftB2Avg))%\n"
        report += "- Diferencia LTFT entre rotores: \(String(format: "%.1f", ltftDiff))%\n\n"

        report += "### Sensores de Oxígeno\n"
        report += "- O2 B1S1 (pre-cat) promedio: \(String(format: "%.3f", o2s1Avg))V\n"
        report += "- O2 B1S1 máx: \(String(format: "%.3f", o2s1Values.max() ?? 0))V\n"
        report += "- O2 B1S1 mín: \(String(format: "%.3f", o2s1Values.min() ?? 0))V\n"
        report += "- O2 B1S2 (post-cat) promedio: \(String(format: "%.3f", o2s2Avg))V\n"
        report += "- Ciclos O2 (cruces 0.45V): \(o2Cycles)\n\n"

        report += "### Presión del Colector (MAP)\n"
        report += "- MAP promedio: \(String(format: "%.1f", mapAvg)) kPa\n"
        report += "- MAP máxima (aceleración): \(String(format: "%.1f", mapValues.max() ?? 0)) kPa\n"
        report += "- MAP mínima (vacío): \(String(format: "%.1f", mapValues.min() ?? 0)) kPa\n\n"

        report += "### Consumo\n"
        report += "- Consumo medio estimado: \(String(format: "%.1f", session.avgConsumption)) L/100km\n"
        report += "- Velocidad máxima: \(String(format: "%.0f", session.maxSpeed)) km/h\n\n"

        // DTCs
        if !dtcs.isEmpty {
            report += "\n## Códigos de Error (DTCs)\n"
            for dtc in dtcs {
                report += "- **\(dtc.code)**: \(dtc.description)\n"
            }
        } else {
            report += "\n## Códigos de Error (DTCs)\n- Sin códigos de error activos\n"
        }

        // Alertas
        if !alerts.isEmpty {
            report += "\n## Alertas Registradas (\(alerts.count) total)\n"

            // Agrupar por tipo
            let grouped = Dictionary(grouping: alerts, by: { $0.type })
            for (type, typeAlerts) in grouped.sorted(by: { $0.key < $1.key }) {
                report += "\n### \(type) (\(typeAlerts.count))\n"
                for alert in typeAlerts.prefix(5) {
                    report += "- [\(alert.severity)] \(alert.message)"
                    if let param = alert.parameter {
                        report += " (\(param): \(String(format: "%.1f", alert.value)))"
                    }
                    report += "\n"
                }
                if typeAlerts.count > 5 {
                    report += "- ... y \(typeAlerts.count - 5) más\n"
                }
            }
        }

        // Notas del usuario
        if let notes = session.notes, !notes.isEmpty {
            report += "\n## Notas del Usuario\n\(notes)\n"
        }

        // Análisis automático de indicadores
        report += "\n## Indicadores de Diagnóstico Automático\n"

        // Análisis de fuel trims (usar variables ya calculadas)
        if abs(ltftAvg) > 15 {
            report += "- **ALERTA**: LTFT muy fuera de rango (\(String(format: "%+.1f", ltftAvg))%) - Posible problema de sellos (apex/corner) o MAF\n"
        } else if abs(ltftAvg) > 10 {
            report += "- **ADVERTENCIA**: LTFT elevado (\(String(format: "%+.1f", ltftAvg))%) - Monitorear evolución\n"
        } else {
            report += "- Fuel trims dentro de rangos normales\n"
        }

        // Análisis de sensores O2 (usar variable ya calculada)
        if o2s1Values.count > 10 {
            if o2s1Avg < 0.3 {
                report += "- **ADVERTENCIA**: Sensor O2 indica mezcla pobre constante - Verificar fugas de vacío o inyectores\n"
            } else if o2s1Avg > 0.7 {
                report += "- **ADVERTENCIA**: Sensor O2 indica mezcla rica constante - Verificar MAF, presión combustible\n"
            }
        }

        // Análisis de temperaturas
        if session.maxCoolantTemp > 105 {
            let maxCoolantStr = String(format: "%.0f", session.maxCoolantTemp)
            report += "- **ALERTA**: Sobrecalentamiento detectado (\(maxCoolantStr)°C) - Verificar sistema de refrigeración\n"
        }
        if session.maxOilTemp > 130 {
            let maxOilStr = String(format: "%.0f", session.maxOilTemp)
            report += "- **ALERTA**: Temperatura de aceite crítica (\(maxOilStr)°C)\n"
        }

        // Solicitud de análisis forense (construida incrementalmente)
        report += "\n---\n\n"
        report += "## Solicitud de Análisis Forense\n\n"
        report += "Eres un experto en diagnóstico de motores rotativos Mazda Wankel (13B-MSP Renesis).\n"
        report += "Analiza estos datos considerando las características específicas del motor rotativo:\n\n"

        report += "### Consideraciones Específicas del Motor Rotativo:\n"
        report += "1. **Apex Seals**: Los fuel trims son indicadores clave del estado de los sellos apex\n"
        report += "   - LTFT >+10%: Posible fuga de compresión (apex seals desgastados)\n"
        report += "   - LTFT <-10%: Posible problema de inyección o MAF\n"
        report += "   - Diferencia entre Bank1/Bank2: Un rotor más desgastado que otro\n\n"

        report += "2. **Corner Seals y Side Seals**: Afectan la compresión igual que los apex\n"
        report += "   - Síntomas similares pero distribución diferente entre cámaras\n\n"

        report += "3. **Sistema de Refrigeración**: El RX-8 es muy sensible\n"
        report += "   - Temperatura normal: 85-95°C\n"
        report += "   - >100°C: Riesgo de daño a sellos\n"
        report += "   - El sobrecalentamiento acelera el desgaste de apex seals\n\n"

        report += "4. **Sistema OMP (Oil Metering Pump)**: Crítico para lubricación de sellos\n"
        report += "   - Fallo de OMP = destrucción rápida del motor\n"
        report += "   - LTFT elevado + humo azul = posible problema OMP\n\n"

        report += "5. **Bobinas de Encendido**: El rotativo es muy exigente\n"
        report += "   - Catalizador caliente + mezcla rica = bobinas fallando\n"
        report += "   - Recomendación: Cambiar cada 50,000 km\n\n"

        report += "6. **Sensores O2**:\n"
        report += "   - Debe ciclar entre 0.1V y 0.9V\n"
        report += "   - Pocos ciclos = sensor lento o mezcla estancada\n\n"

        report += "### Proporciona:\n"
        report += "- **Puntuación de salud del motor** (0-100)\n"
        report += "- **Diagnóstico principal** con nivel de severidad\n"
        report += "- **Problemas identificados** con probabilidad y causa raíz\n"
        report += "- **Recomendaciones de mantenimiento** inmediatas y a medio plazo\n"
        report += "- **Estimación de vida útil restante** si hay desgaste evidente\n"
        report += "- **Acciones urgentes** si las hay\n"

        return report
    }

    // Contar ciclos de O2 (cruces del punto estequiométrico)
    private func countO2Cycles(_ values: [Double]) -> Int {
        guard values.count > 1 else { return 0 }
        var cycles = 0
        let threshold = 0.45
        for i in 1..<values.count {
            let prev = values[i-1]
            let curr = values[i]
            if (prev < threshold && curr >= threshold) || (prev >= threshold && curr < threshold) {
                cycles += 1
            }
        }
        return cycles / 2 // Un ciclo completo = subida + bajada
    }
}

// MARK: - Data Structures

public struct EngineSnapshot {
    public let timestamp: Double
    public let rpm: Int
    public let speed: Double
    public let coolantTemp: Double
    public let oilTemp: Double
    public let intakeTemp: Double
    public let catalystTemp: Double
    public let throttle: Double
    public let maf: Double
    public let stft: Double
    public let ltft: Double
    public let timing: Double
    public let voltage: Double
    public let fuelLevel: Double
    public let load: Double

    // Nuevos campos para diagnóstico forense
    public let o2b1s1: Double      // Sensor O2 Bank 1 Sensor 1 (V)
    public let o2b1s2: Double      // Sensor O2 Bank 1 Sensor 2 (V)
    public let map: Double         // Presión absoluta del colector (kPa)
    public let accelerator: Double // Posición del acelerador (%)
    public let stftB2: Double      // STFT Bank 2 (%)
    public let ltftB2: Double      // LTFT Bank 2 (%)

    // Sondas de combustible duales (RX-8 saddle tank)
    public let fuelLevelLeft: Double?  // Sonda izquierda (%)
    public let fuelLevelRight: Double? // Sonda derecha (%)

    public init(
        timestamp: Double = Date().timeIntervalSince1970,
        rpm: Int = 0,
        speed: Double = 0,
        coolantTemp: Double = 0,
        oilTemp: Double = 0,
        intakeTemp: Double = 0,
        catalystTemp: Double = 0,
        throttle: Double = 0,
        maf: Double = 0,
        stft: Double = 0,
        ltft: Double = 0,
        timing: Double = 0,
        voltage: Double = 0,
        fuelLevel: Double = 0,
        load: Double = 0,
        o2b1s1: Double = 0,
        o2b1s2: Double = 0,
        map: Double = 0,
        accelerator: Double = 0,
        stftB2: Double = 0,
        ltftB2: Double = 0,
        fuelLevelLeft: Double? = nil,
        fuelLevelRight: Double? = nil
    ) {
        self.timestamp = timestamp
        self.rpm = rpm
        self.speed = speed
        self.coolantTemp = coolantTemp
        self.oilTemp = oilTemp
        self.intakeTemp = intakeTemp
        self.catalystTemp = catalystTemp
        self.throttle = throttle
        self.maf = maf
        self.stft = stft
        self.ltft = ltft
        self.timing = timing
        self.voltage = voltage
        self.fuelLevel = fuelLevel
        self.load = load
        self.o2b1s1 = o2b1s1
        self.o2b1s2 = o2b1s2
        self.map = map
        self.accelerator = accelerator
        self.stftB2 = stftB2
        self.ltftB2 = ltftB2
        self.fuelLevelLeft = fuelLevelLeft
        self.fuelLevelRight = fuelLevelRight
    }
}

public struct BlackBoxAlert {
    public let timestamp: Double
    public let type: String
    public let severity: String
    public let parameter: String?
    public let value: Double
    public let threshold: Double
    public let message: String

    public init(
        timestamp: Double = Date().timeIntervalSince1970,
        type: String,
        severity: String,
        parameter: String? = nil,
        value: Double = 0,
        threshold: Double = 0,
        message: String
    ) {
        self.timestamp = timestamp
        self.type = type
        self.severity = severity
        self.parameter = parameter
        self.value = value
        self.threshold = threshold
        self.message = message
    }
}

public struct BlackBoxSession: Identifiable {
    public let id: String
    public let startTime: Date
    public let endTime: Date?
    public let totalDistance: Double
    public let maxRPM: Int
    public let maxSpeed: Double
    public let maxCoolantTemp: Double
    public let maxOilTemp: Double
    public let avgConsumption: Double
    public let dtcCount: Int
    public let alertCount: Int
    public let notes: String?
    public let analysisSent: Bool
    public let analysisResult: String?
    public let durationSeconds: TimeInterval  // Duración guardada en DB

    /// Duración real de la sesión - usa el valor guardado si existe
    public var duration: TimeInterval {
        // Usar duración guardada si está disponible y es válida
        if durationSeconds > 0 {
            return durationSeconds
        }
        // Fallback: calcular desde endTime (solo si la sesión terminó)
        if let end = endTime {
            return end.timeIntervalSince(startTime)
        }
        // Sesión activa: mostrar 0 hasta que termine
        return 0
    }

    public var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm %02ds", minutes, seconds)
    }

    public var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: startTime)
    }

    /// Indica si la sesión está en progreso
    public var isActive: Bool {
        return endTime == nil && durationSeconds == 0
    }
}

private struct SessionStats {
    var totalDistance: Double = 0
    var maxRPM: Int = 0
    var maxSpeed: Double = 0
    var maxCoolantTemp: Double = 0
    var maxOilTemp: Double = 0
    var avgConsumption: Double = 0
}
