import Foundation
import SQLite3

// MARK: - Black Box Database
// Sistema de caja negra con SQLite - guarda sesiones automáticamente

public class BlackBoxDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    public static let maxSessions = 30

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
            analysis_result TEXT
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
            "ALTER TABLE snapshots ADD COLUMN ltft_b2 REAL DEFAULT 0;"
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            sqlite3_bind_double(stmt, 2, startTime)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        return sessionId
    }

    public func endSession(_ sessionId: String) {
        let endTime = Date().timeIntervalSince1970

        // Calcular estadísticas de la sesión
        let stats = calculateSessionStats(sessionId)

        let sql = """
        UPDATE sessions SET
            end_time = ?,
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
            sqlite3_bind_double(stmt, 2, stats.totalDistance)
            sqlite3_bind_int(stmt, 3, Int32(stats.maxRPM))
            sqlite3_bind_double(stmt, 4, stats.maxSpeed)
            sqlite3_bind_double(stmt, 5, stats.maxCoolantTemp)
            sqlite3_bind_double(stmt, 6, stats.maxOilTemp)
            sqlite3_bind_double(stmt, 7, stats.avgConsumption)
            sqlite3_bind_text(stmt, 8, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                dtcCount = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        // Contar alertas
        var alertCount = 0
        let alertSql = "SELECT COUNT(*) FROM alerts WHERE session_id = ?;"
        if sqlite3_prepare_v2(db, alertSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 3, sessionId, -1, nil)
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
            o2b1s1, o2b1s2, map, accelerator, stft_b2, ltft_b2
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            sqlite3_bind_double(stmt, 2, alert.timestamp)
            sqlite3_bind_text(stmt, 3, alert.type, -1, nil)
            sqlite3_bind_text(stmt, 4, alert.severity, -1, nil)
            sqlite3_bind_text(stmt, 5, alert.parameter, -1, nil)
            sqlite3_bind_double(stmt, 6, alert.value)
            sqlite3_bind_double(stmt, 7, alert.threshold)
            sqlite3_bind_text(stmt, 8, alert.message, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            sqlite3_bind_text(stmt, 2, code, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                exists = sqlite3_column_int(stmt, 0) > 0
            }
        }
        sqlite3_finalize(stmt)

        if !exists {
            let sql = "INSERT INTO dtcs (session_id, timestamp, code, description) VALUES (?, ?, ?, ?);"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
                sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, code, -1, nil)
                sqlite3_bind_text(stmt, 4, description, -1, nil)
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
               notes, analysis_sent, analysis_result
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
                    analysisResult: sqlite3_column_type(stmt, 13) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 13)) : nil
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
               o2b1s1, o2b1s2, map, accelerator, stft_b2, ltft_b2
        FROM snapshots WHERE session_id = ? ORDER BY timestamp;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
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
                    ltftB2: sqlite3_column_double(stmt, 20)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func saveAnalysisResult(_ sessionId: String, result: String) {
        let sql = "UPDATE sessions SET analysis_sent = 1, analysis_result = ? WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, result, -1, nil)
            sqlite3_bind_text(stmt, 2, sessionId, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func addNote(_ sessionId: String, note: String) {
        let sql = "UPDATE sessions SET notes = ? WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, note, -1, nil)
            sqlite3_bind_text(stmt, 2, sessionId, -1, nil)
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

        // Calcular estadísticas detalladas
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"

        var report = """
        # Análisis Forense - Mazda RX-8 Motor Rotativo 13B-MSP Renesis

        ## Información de la Sesión
        - Fecha: \(dateFormatter.string(from: session.startTime))
        - Duración: \(session.durationFormatted)
        - Distancia: \(String(format: "%.1f", session.totalDistance)) km
        - Muestras registradas: \(snapshots.count)

        ## Estadísticas del Motor

        ### RPM
        - Máximo: \(session.maxRPM)
        - Promedio: \(rpmValues.isEmpty ? 0 : rpmValues.reduce(0, +) / rpmValues.count)
        - Tiempo en zona roja (>8500): \(snapshots.filter { $0.rpm > 8500 }.count) muestras
        - Tiempo en idle (<1000): \(snapshots.filter { $0.rpm > 0 && $0.rpm < 1000 }.count) muestras

        ### Carga del Motor
        - Carga máxima: \(String(format: "%.1f", loadValues.max() ?? 0))%
        - Carga promedio: \(String(format: "%.1f", loadValues.isEmpty ? 0 : loadValues.reduce(0, +) / Double(loadValues.count)))%

        ### Temperaturas
        - Refrigerante máx: \(String(format: "%.1f", session.maxCoolantTemp))°C
        - Refrigerante promedio: \(String(format: "%.1f", coolantValues.isEmpty ? 0 : coolantValues.reduce(0, +) / Double(coolantValues.count)))°C
        - Aceite máx: \(String(format: "%.1f", session.maxOilTemp))°C
        - Aceite promedio: \(String(format: "%.1f", oilValues.isEmpty ? 0 : oilValues.reduce(0, +) / Double(oilValues.count)))°C
        - Tiempo sobrecalentamiento ref. (>100°C): \(snapshots.filter { $0.coolantTemp > 100 }.count) muestras
        - Tiempo sobrecalentamiento aceite (>120°C): \(snapshots.filter { $0.oilTemp > 120 }.count) muestras

        ### Fuel Trims Bank 1 (Rotor Delantero)
        - STFT promedio: \(String(format: "%+.1f", stftValues.isEmpty ? 0 : stftValues.reduce(0, +) / Double(stftValues.count)))%
        - STFT máx: \(String(format: "%+.1f", stftValues.max() ?? 0))%
        - STFT mín: \(String(format: "%+.1f", stftValues.min() ?? 0))%
        - LTFT promedio: \(String(format: "%+.1f", ltftValues.isEmpty ? 0 : ltftValues.reduce(0, +) / Double(ltftValues.count)))%
        - STFT fuera de rango (>±10%): \(snapshots.filter { abs($0.stft) > 10 }.count) muestras
        - LTFT fuera de rango (>±10%): \(snapshots.filter { abs($0.ltft) > 10 }.count) muestras

        ### Fuel Trims Bank 2 (Rotor Trasero)
        - STFT B2 promedio: \(String(format: "%+.1f", stftB2Values.isEmpty ? 0 : stftB2Values.reduce(0, +) / Double(stftB2Values.count)))%
        - LTFT B2 promedio: \(String(format: "%+.1f", ltftB2Values.isEmpty ? 0 : ltftB2Values.reduce(0, +) / Double(ltftB2Values.count)))%
        - Diferencia LTFT entre rotores: \(String(format: "%.1f", abs((ltftValues.isEmpty ? 0 : ltftValues.reduce(0, +) / Double(ltftValues.count)) - (ltftB2Values.isEmpty ? 0 : ltftB2Values.reduce(0, +) / Double(ltftB2Values.count)))))%

        ### Sensores de Oxígeno
        - O2 B1S1 (pre-cat) promedio: \(String(format: "%.3f", o2s1Values.isEmpty ? 0 : o2s1Values.reduce(0, +) / Double(o2s1Values.count)))V
        - O2 B1S1 máx: \(String(format: "%.3f", o2s1Values.max() ?? 0))V
        - O2 B1S1 mín: \(String(format: "%.3f", o2s1Values.min() ?? 0))V
        - O2 B1S2 (post-cat) promedio: \(String(format: "%.3f", o2s2Values.isEmpty ? 0 : o2s2Values.reduce(0, +) / Double(o2s2Values.count)))V
        - Ciclos O2 (cruces 0.45V): \(countO2Cycles(o2s1Values))

        ### Presión del Colector (MAP)
        - MAP promedio: \(String(format: "%.1f", mapValues.isEmpty ? 0 : mapValues.reduce(0, +) / Double(mapValues.count))) kPa
        - MAP máxima (aceleración): \(String(format: "%.1f", mapValues.max() ?? 0)) kPa
        - MAP mínima (vacío): \(String(format: "%.1f", mapValues.min() ?? 0)) kPa

        ### Consumo
        - Consumo medio estimado: \(String(format: "%.1f", session.avgConsumption)) L/100km
        - Velocidad máxima: \(String(format: "%.0f", session.maxSpeed)) km/h

        """

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

        // Análisis de fuel trims
        let avgStft = stftValues.isEmpty ? 0 : stftValues.reduce(0, +) / Double(stftValues.count)
        let avgLtft = ltftValues.isEmpty ? 0 : ltftValues.reduce(0, +) / Double(ltftValues.count)

        if abs(avgLtft) > 15 {
            report += "- **ALERTA**: LTFT muy fuera de rango (\(String(format: "%+.1f", avgLtft))%) - Posible problema de sellos (apex/corner) o MAF\n"
        } else if abs(avgLtft) > 10 {
            report += "- **ADVERTENCIA**: LTFT elevado (\(String(format: "%+.1f", avgLtft))%) - Monitorear evolución\n"
        } else {
            report += "- Fuel trims dentro de rangos normales\n"
        }

        // Análisis de sensores O2
        let avgO2 = o2s1Values.isEmpty ? 0 : o2s1Values.reduce(0, +) / Double(o2s1Values.count)
        if o2s1Values.count > 10 {
            if avgO2 < 0.3 {
                report += "- **ADVERTENCIA**: Sensor O2 indica mezcla pobre constante - Verificar fugas de vacío o inyectores\n"
            } else if avgO2 > 0.7 {
                report += "- **ADVERTENCIA**: Sensor O2 indica mezcla rica constante - Verificar MAF, presión combustible\n"
            }
        }

        // Análisis de temperaturas
        if session.maxCoolantTemp > 105 {
            report += "- **ALERTA**: Sobrecalentamiento detectado (\(String(format: "%.0f", session.maxCoolantTemp))°C) - Verificar sistema de refrigeración\n"
        }
        if session.maxOilTemp > 130 {
            report += "- **ALERTA**: Temperatura de aceite crítica (\(String(format: "%.0f", session.maxOilTemp))°C)\n"
        }

        report += """

        ---

        ## Solicitud de Análisis Forense

        Eres un experto en diagnóstico de motores rotativos Mazda Wankel (13B-MSP Renesis).
        Analiza estos datos considerando las características específicas del motor rotativo:

        ### Consideraciones Específicas del Motor Rotativo:
        1. **Apex Seals**: Los fuel trims son indicadores clave del estado de los sellos apex
           - LTFT >+10%: Posible fuga de compresión (apex seals desgastados)
           - LTFT <-10%: Posible problema de inyección o MAF
           - Diferencia entre Bank1/Bank2: Un rotor más desgastado que otro

        2. **Corner Seals y Side Seals**: Afectan la compresión igual que los apex
           - Síntomas similares pero distribución diferente entre cámaras

        3. **Sistema de Refrigeración**: El RX-8 es muy sensible
           - Temperatura normal: 85-95°C
           - >100°C: Riesgo de daño a sellos
           - El sobrecalentamiento acelera el desgaste de apex seals

        4. **Sistema OMP (Oil Metering Pump)**: Crítico para lubricación de sellos
           - Fallo de OMP = destrucción rápida del motor
           - LTFT elevado + humo azul = posible problema OMP

        5. **Bobinas de Encendido**: El rotativo es muy exigente
           - Catalizador caliente + mezcla rica = bobinas fallando
           - Recomendación: Cambiar cada 50,000 km

        6. **Sensores O2**:
           - Debe ciclar entre 0.1V y 0.9V
           - Pocos ciclos = sensor lento o mezcla estancada

        ### Proporciona:
        - **Puntuación de salud del motor** (0-100)
        - **Diagnóstico principal** con nivel de severidad
        - **Problemas identificados** con probabilidad y causa raíz
        - **Recomendaciones de mantenimiento** inmediatas y a medio plazo
        - **Estimación de vida útil restante** si hay desgaste evidente
        - **Acciones urgentes** si las hay
        """

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
        ltftB2: Double = 0
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

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
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
}

private struct SessionStats {
    var totalDistance: Double = 0
    var maxRPM: Int = 0
    var maxSpeed: Double = 0
    var maxCoolantTemp: Double = 0
    var maxOilTemp: Double = 0
    var avgConsumption: Double = 0
}
