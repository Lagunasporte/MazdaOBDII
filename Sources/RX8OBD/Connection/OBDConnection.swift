import Foundation
import CoreBluetooth
import Combine

// MARK: - Gestor de Conexión OBD2
// Compatible con ELM327 v1.4+, STN1110, OBDLink y clones vía Bluetooth LE

// MARK: - UUIDs de Servicios BLE para Adaptadores OBD conocidos
public struct OBDServiceUUIDs {
    // ELM327 estándar / Genéricos (una sola característica para todo)
    static let elm327Service = CBUUID(string: "FFE0")
    static let elm327Characteristic = CBUUID(string: "FFE1")

    // Carista / STN1110 / STN2120 - IMPORTANTE: FFF1=RX(notify), FFF2=TX(write)
    static let stnService = CBUUID(string: "FFF0")
    static let stnReadCharacteristic = CBUUID(string: "FFF1")  // Notify/Read - recibimos aquí
    static let stnWriteCharacteristic = CBUUID(string: "FFF2") // Write - enviamos aquí

    // Alternativo STN (algunos modelos)
    static let stnAltService = CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")

    // vLinker / vGate
    static let vLinkerService = CBUUID(string: "18F0")
    static let vLinkerAltService = CBUUID(string: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F")

    // OBDLink
    static let obdLinkService = CBUUID(string: "FFE0")

    // LELink
    static let leLinkService = CBUUID(string: "C0FFE0")

    // Veepeak
    static let veepeakService = CBUUID(string: "FFE0")

    // BAFX
    static let bafxService = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")

    // Konnwei (usa mismo esquema que STN)
    static let konnweiService = CBUUID(string: "FFF0")

    // Lista de todos los servicios conocidos para escaneo
    static let allKnownServices: [CBUUID] = [
        elm327Service, stnService, stnAltService,
        vLinkerService, vLinkerAltService, obdLinkService,
        leLinkService, veepeakService, bafxService, konnweiService
    ]
}

public class OBDConnectionManager: NSObject, ObservableObject {

    // MARK: - Estados Publicados
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var adapterInfo: OBDAdapterInfo?
    @Published public var vehicleProtocol: VehicleProtocol?
    @Published public var isScanning: Bool = false
    @Published public var discoveredDevices: [OBDDevice] = []
    @Published public var lastError: OBDError?
    @Published public var lastResponse: String = ""
    @Published public var isAutoConnecting: Bool = false
    @Published public var savedAdapterName: String?

    // MARK: - Debug y Diagnóstico
    @Published public var debugLog: [String] = []
    @Published public var isVerboseMode: Bool = false
    @Published public var detectedAdapterType: AdapterType = .unknown
    @Published public var diagnosticResults: DiagnosticResults?

    // MARK: - Bluetooth
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    // MARK: - Buffer y Cola de Comandos
    private var responseBuffer = ""
    private var commandQueue: [(command: String, completion: (Result<String, OBDError>) -> Void)] = []
    private var isProcessingCommand = false
    private var responseCompletion: ((Result<String, OBDError>) -> Void)?
    private var responseTimer: Timer?

    // MARK: - Auto-conexión
    private let savedAdapterUUIDKey = "SavedOBDAdapterUUID"
    private let savedAdapterNameKey = "SavedOBDAdapterName"
    private let autoConnectEnabledKey = "OBDAutoConnectEnabled"
    private var pendingAutoConnect = false
    private var autoConnectAttempts = 0
    private let maxAutoConnectAttempts = 3

    // MARK: - Inicialización

    public override init() {
        super.init()
        loadSavedAdapter()
        DispatchQueue.main.async { [weak self] in
            self?.centralManager = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // MARK: - Guardado de Adaptador

    private func loadSavedAdapter() {
        savedAdapterName = UserDefaults.standard.string(forKey: savedAdapterNameKey)
    }

    public var savedAdapterUUID: UUID? {
        get {
            if let uuidString = UserDefaults.standard.string(forKey: savedAdapterUUIDKey) {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            if let uuid = newValue {
                UserDefaults.standard.set(uuid.uuidString, forKey: savedAdapterUUIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: savedAdapterUUIDKey)
            }
        }
    }

    public var isAutoConnectEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoConnectEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoConnectEnabledKey) }
    }

    public func saveCurrentAdapter() {
        guard let peripheral = connectedPeripheral else { return }
        savedAdapterUUID = peripheral.identifier
        savedAdapterName = peripheral.name ?? "OBD Adapter"
        UserDefaults.standard.set(savedAdapterName, forKey: savedAdapterNameKey)
        isAutoConnectEnabled = true
    }

    public func forgetSavedAdapter() {
        savedAdapterUUID = nil
        savedAdapterName = nil
        UserDefaults.standard.removeObject(forKey: savedAdapterNameKey)
        isAutoConnectEnabled = false
    }

    // MARK: - Auto-conexión

    public func attemptAutoConnect() {
        guard isAutoConnectEnabled,
              let savedUUID = savedAdapterUUID,
              connectionState == .disconnected else {
            return
        }

        guard let central = centralManager, central.state == .poweredOn else {
            pendingAutoConnect = true
            return
        }

        isAutoConnecting = true
        autoConnectAttempts = 0
        connectionState = .connecting

        // Buscar el dispositivo guardado
        let knownPeripherals = central.retrievePeripherals(withIdentifiers: [savedUUID])

        if let peripheral = knownPeripherals.first {
            // Dispositivo encontrado directamente
            connect(toPeripheral: peripheral)
        } else {
            // Escanear para encontrarlo
            startScanningForSavedAdapter()
        }
    }

    private func startScanningForSavedAdapter() {
        guard let central = centralManager, central.state == .poweredOn else { return }

        central.scanForPeripherals(withServices: nil, options: nil)

        // Timeout para auto-conexión
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isAutoConnecting else { return }
            self.stopScanning()

            if self.connectionState != .connectedToVehicle && self.connectionState != .connectedToAdapter {
                self.autoConnectAttempts += 1
                if self.autoConnectAttempts < self.maxAutoConnectAttempts {
                    // Reintentar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.startScanningForSavedAdapter()
                    }
                } else {
                    self.isAutoConnecting = false
                    self.connectionState = .disconnected
                    self.lastError = .initializationFailed("No se pudo conectar al adaptador guardado. Verifica que esté encendido.")
                }
            }
        }
    }

    private func connect(toPeripheral peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }

    // MARK: - Escaneo de Dispositivos

    public func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else {
            lastError = .bluetoothNotAvailable
            return
        }

        isScanning = true
        discoveredDevices.removeAll()
        lastError = nil

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }

    public func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }

    // MARK: - Conexión

    public func connect(to device: OBDDevice) {
        guard let peripheral = device.peripheral else {
            lastError = .deviceNotFound
            return
        }

        stopScanning()
        connectionState = .connecting
        lastError = nil
        centralManager?.connect(peripheral, options: nil)
    }

    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

    private func cleanup() {
        responseTimer?.invalidate()
        responseTimer = nil
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        responseBuffer = ""
        commandQueue.removeAll()
        isProcessingCommand = false
        responseCompletion = nil
        connectionState = .disconnected
        adapterInfo = nil
        vehicleProtocol = nil
        detectedAdapterType = .unknown
    }

    // MARK: - Logging para Debug
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async { [weak self] in
            self?.debugLog.append(entry)
            // Mantener solo los últimos 100 logs
            if self?.debugLog.count ?? 0 > 100 {
                self?.debugLog.removeFirst()
            }
        }
        if isVerboseMode {
            print("OBD: \(message)")
        }
    }

    public func clearDebugLog() {
        debugLog.removeAll()
    }

    // MARK: - Inicialización del Adaptador ELM327/STN compatible

    public func initializeAdapter() {
        connectionState = .initializing
        log("Iniciando inicialización del adaptador...")

        Task { @MainActor in
            do {
                // Paso 1: Detectar tipo de adaptador y hacer reset
                log("Paso 1: Reset del adaptador")
                let adapterVersion = await detectAndResetAdapter()

                // Paso 2: Configuración básica del adaptador
                log("Paso 2: Configuración básica")
                await configureAdapter()

                // Paso 3: Obtener información del adaptador
                log("Paso 3: Obteniendo info del adaptador")
                adapterInfo = OBDAdapterInfo(version: adapterVersion)
                detectedAdapterType = AdapterType.detect(from: adapterVersion)
                log("Tipo de adaptador detectado: \(detectedAdapterType.rawValue)")

                // Paso 4: Configuración específica según tipo de adaptador
                log("Paso 4: Configuración específica para \(detectedAdapterType.rawValue)")
                await configureForAdapterType(detectedAdapterType)

                // Paso 5: Intentar conexión con el vehículo
                log("Paso 5: Intentando conexión con vehículo")
                let vehicleConnected = await attemptVehicleConnection()

                if vehicleConnected {
                    let protocolResponse = try await sendCommand("ATDPN", timeout: 3.0)
                    vehicleProtocol = VehicleProtocol.from(elm327Code: protocolResponse)
                    connectionState = .connectedToVehicle
                    log("Conexión exitosa - Protocolo: \(vehicleProtocol?.rawValue ?? "desconocido")")
                } else {
                    connectionState = .connectedToAdapter
                    log("Adaptador OK pero sin conexión al vehículo")
                    lastError = .initializationFailed("Adaptador OK. Verifica: 1) Contacto puesto (no hace falta arrancar) 2) Adaptador bien conectado al puerto OBD")
                }

            } catch {
                log("Error en inicialización: \(error.localizedDescription)")
                lastError = .initializationFailed("Error: \(error.localizedDescription)")
                connectionState = .connectedToAdapter
            }
        }
    }

    private func detectAndResetAdapter() async -> String {
        var version = ""

        // Intento 1: Reset estándar ATZ
        for attempt in 1...3 {
            do {
                log("Reset ATZ intento \(attempt)/3")
                let response = try await sendCommand("ATZ", timeout: 10.0)
                log("ATZ respuesta: \(response)")

                if response.contains("ELM") || response.contains("STN") ||
                   response.contains("OBD") || response.uppercased().contains("V1") ||
                   response.uppercased().contains("V2") {
                    version = response
                    break
                }
            } catch {
                log("ATZ intento \(attempt) falló: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }

        // Si ATZ falló, intentar warm start
        if version.isEmpty {
            log("ATZ falló, intentando ATWS (warm start)")
            do {
                let wsResponse = try await sendCommand("ATWS", timeout: 8.0)
                log("ATWS respuesta: \(wsResponse)")
                if !wsResponse.isEmpty {
                    version = wsResponse
                }
            } catch {
                log("ATWS falló: \(error.localizedDescription)")
            }
        }

        // Obtener versión con ATI si aún no la tenemos clara
        if version.isEmpty || (!version.contains("ELM") && !version.contains("STN")) {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                let atiResponse = try await sendCommand("ATI", timeout: 5.0)
                log("ATI respuesta: \(atiResponse)")
                version = atiResponse
            } catch {
                log("ATI falló: \(error.localizedDescription)")
            }
        }

        return version
    }

    private func configureAdapter() async {
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Echo off - crítico para comunicación limpia
        for _ in 1...3 {
            if let resp = try? await sendCommand("ATE0", timeout: 3.0) {
                log("ATE0: \(resp)")
                break
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        // Configuraciones estándar
        let configs: [(String, String)] = [
            ("ATL0", "Linefeeds off"),
            ("ATS0", "Spaces off"),
            ("ATH0", "Headers off"),
            ("ATAT2", "Adaptive timing aggressive"),
            ("ATSTFF", "Max timeout")
        ]

        for (cmd, desc) in configs {
            if let resp = try? await sendCommand(cmd, timeout: 2.0) {
                log("\(cmd) (\(desc)): \(resp)")
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func configureForAdapterType(_ type: AdapterType) async {
        switch type {
        case .stn1110, .stn2120, .carista:
            log("Aplicando configuración STN...")
            // STN soporta comandos adicionales
            _ = try? await sendCommand("STPO", timeout: 2.0) // Desactivar protocolo actual
            try? await Task.sleep(nanoseconds: 200_000_000)
            _ = try? await sendCommand("STCMM1", timeout: 2.0) // Modo monitoreo CAN
            try? await Task.sleep(nanoseconds: 200_000_000)

        case .obdLink:
            log("Aplicando configuración OBDLink...")
            _ = try? await sendCommand("ATCAF1", timeout: 2.0) // CAN auto formatting
            try? await Task.sleep(nanoseconds: 200_000_000)

        case .elm327, .elm327Clone, .unknown:
            log("Usando configuración ELM327 estándar...")
            // Ya configurado con comandos básicos
        }
    }

    private func attemptVehicleConnection() async -> Bool {
        // Protocolos a intentar (en orden de probabilidad para Mazda RX-8)
        let protocols: [(cmd: String, name: String, wait: UInt64)] = [
            ("ATSP0", "Auto", 2_000_000_000),
            ("ATSP6", "CAN 500k 11bit", 1_500_000_000),
            ("ATSP7", "CAN 500k 29bit", 1_500_000_000),
            ("ATSP8", "CAN 250k 11bit", 1_500_000_000),
            ("ATSP5", "KWP Fast", 2_000_000_000),
            ("ATSP3", "ISO 9141", 2_500_000_000)
        ]

        for (protocolCmd, protocolName, waitTime) in protocols {
            log("Intentando protocolo: \(protocolName)")

            // Establecer protocolo
            if let resp = try? await sendCommand(protocolCmd, timeout: 3.0) {
                log("\(protocolCmd): \(resp)")
            }

            try? await Task.sleep(nanoseconds: waitTime)

            // Test de conexión con PID 0100 (PIDs soportados)
            for attempt in 1...2 {
                do {
                    log("Test 0100 intento \(attempt)")
                    let testResponse = try await sendCommand("0100", timeout: 12.0)
                    log("0100 respuesta: \(testResponse)")

                    // Verificar respuesta válida
                    if isValidOBDResponse(testResponse) {
                        log("Conexión exitosa con protocolo \(protocolName)")
                        return true
                    }
                } catch {
                    log("0100 error: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return false
    }

    private func isValidOBDResponse(_ response: String) -> Bool {
        let upper = response.uppercased()

        // Respuestas de error
        if upper.contains("NO DATA") ||
           upper.contains("UNABLE") ||
           upper.contains("ERROR") ||
           upper.contains("BUS INIT") ||
           upper.contains("CAN ERROR") ||
           upper.contains("?") ||
           upper.contains("STOPPED") {
            return false
        }

        // Respuesta válida debe contener 41 (respuesta al modo 01)
        if upper.contains("41") {
            return true
        }

        // También puede ser válida si tiene datos hex
        let hexPattern = response.replacingOccurrences(of: " ", with: "")
        if hexPattern.count >= 4 && hexPattern.allSatisfy({ $0.isHexDigit }) {
            return true
        }

        return false
    }

    // MARK: - Envío de Comandos

    public func sendCommand(_ command: String, timeout: TimeInterval = 3.0) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.sendCommandInternal(command, timeout: timeout) { result in
                    continuation.resume(with: result)
                }
            }
        }
    }

    private func sendCommandInternal(_ command: String, timeout: TimeInterval, completion: @escaping (Result<String, OBDError>) -> Void) {
        commandQueue.append((command, completion))
        processNextCommand(timeout: timeout)
    }

    private func processNextCommand(timeout: TimeInterval = 3.0) {
        guard !isProcessingCommand, !commandQueue.isEmpty else { return }

        guard let writeChar = writeCharacteristic, let peripheral = connectedPeripheral else {
            if !commandQueue.isEmpty {
                let pending = commandQueue.removeFirst()
                pending.completion(.failure(.notConnected))
            }
            return
        }

        isProcessingCommand = true
        let (command, completion) = commandQueue.removeFirst()
        responseCompletion = completion
        responseBuffer = ""

        let commandWithCR = command + "\r"
        guard let data = commandWithCR.data(using: .ascii) else {
            isProcessingCommand = false
            completion(.failure(.invalidCommand))
            processNextCommand()
            return
        }

        // Log detalles de escritura
        log("TX[\(writeChar.uuid)]: \(command)")

        // Intentar primero con writeWithResponse para mejor fiabilidad
        let writeType: CBCharacteristicWriteType
        if writeChar.properties.contains(.write) {
            writeType = .withResponse
        } else {
            writeType = .withoutResponse
        }

        peripheral.writeValue(data, for: writeChar, type: writeType)

        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard isProcessingCommand else { return }
        isProcessingCommand = false

        if !responseBuffer.isEmpty {
            let response = cleanResponse(responseBuffer)
            responseCompletion?(.success(response))
        } else {
            responseCompletion?(.failure(.timeout))
        }
        responseCompletion = nil
        processNextCommand()
    }

    private func handleResponse(_ data: Data) {
        // Log datos raw recibidos
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        log("RX raw (\(data.count) bytes): \(hexString)")

        guard let str = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else {
            log("RX: No se pudo decodificar")
            return
        }

        log("RX: \(str.replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n"))")

        responseBuffer += str

        // Detectar fin de respuesta - múltiples terminadores posibles
        let hasPrompt = responseBuffer.contains(">")
        let hasOK = responseBuffer.hasSuffix("OK\r") || responseBuffer.hasSuffix("OK\r\n")
        let hasError = responseBuffer.contains("?") && responseBuffer.contains("\r")
        let hasELM = responseBuffer.contains("ELM") && responseBuffer.contains("\r")
        let hasSTN = responseBuffer.contains("STN") && responseBuffer.contains("\r")

        if hasPrompt || hasOK || hasError || hasELM || hasSTN {
            responseTimer?.invalidate()
            responseTimer = nil

            let response = cleanResponse(responseBuffer)
            lastResponse = response
            log("Respuesta completa: \(response)")

            isProcessingCommand = false
            responseCompletion?(.success(response))
            responseCompletion = nil

            processNextCommand()
        }
    }

    private func cleanResponse(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "SEARCHING...", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Lectura de PIDs

    public func readPID(_ pid: String) async throws -> String {
        let response = try await sendCommand(pid, timeout: 3.0)
        if response.contains("NO DATA") || response.contains("ERROR") {
            throw OBDError.noData
        }
        return response
    }

    public func readStandardPID(mode: UInt8, pid: UInt8) async throws -> [UInt8] {
        let command = String(format: "%02X%02X", mode, pid)
        let response = try await readPID(command)
        return parseHexResponse(response)
    }

    private func parseHexResponse(_ response: String) -> [UInt8] {
        let hexOnly = response.components(separatedBy: .whitespaces).joined()
        var bytes: [UInt8] = []
        var index = hexOnly.startIndex

        while index < hexOnly.endIndex {
            guard let nextIndex = hexOnly.index(index, offsetBy: 2, limitedBy: hexOnly.endIndex) else { break }
            let byteString = String(hexOnly[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }

        if bytes.count > 2 {
            return Array(bytes.dropFirst(2))
        }
        return bytes
    }

    // MARK: - Funciones de Lectura Comunes

    public func readRPM() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0C)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }
        return (Int(bytes[0]) * 256 + Int(bytes[1])) / 4
    }

    public func readSpeed() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0D)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Int(bytes[0])
    }

    public func readCoolantTemp() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x05)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Int(bytes[0]) - 40
    }

    public func readThrottlePosition() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x11)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) * 100.0 / 255.0
    }

    public func readMAF() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x10)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) * 256.0 + Double(bytes[1])) / 100.0
    }

    public func readIntakeTemp() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0F)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Int(bytes[0]) - 40
    }

    /// Lee temperatura del catalizador Bank 1 Sensor 1 (PID 0x3C)
    /// Retorna temperatura en °C (rango: -40 a 6513.5°C)
    public func readCatalystTemp() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x3C)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) * 256.0 + Double(bytes[1])) / 10.0 - 40.0
    }

    /// Lee temperatura del aceite (PID 0x5C)
    /// Retorna temperatura en °C
    public func readOilTemp() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x5C)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Int(bytes[0]) - 40
    }

    /// Lee carga del motor (PID 0x04)
    /// Retorna porcentaje 0-100%
    public func readEngineLoad() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x04)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) * 100.0 / 255.0
    }

    /// Lee nivel de combustible (PID 0x2F)
    /// Retorna porcentaje 0-100%
    public func readFuelLevel() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x2F)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) * 100.0 / 255.0
    }

    /// Lee presión del sistema de combustible (PID 0x0A)
    /// Retorna presión en kPa
    public func readFuelPressure() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0A)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) * 3.0
    }

    /// Lee distancia recorrida desde borrado de DTCs (PID 0x31)
    /// Retorna distancia en km
    public func readDistanceSinceDTCClear() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x31)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }
        return Int(bytes[0]) * 256 + Int(bytes[1])
    }

    /// Lee tiempo desde arranque del motor (PID 0x1F)
    /// Retorna segundos
    public func readRuntimeSinceStart() async throws -> Int {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x1F)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }
        return Int(bytes[0]) * 256 + Int(bytes[1])
    }

    public func readFuelTrimShort() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x06)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
    }

    public func readFuelTrimLong() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x07)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
    }

    public func readTimingAdvance() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0E)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) - 128.0) / 2.0
    }

    public func readVoltage() async throws -> Double {
        let response = try await sendCommand("ATRV", timeout: 2.0)
        let digits = response.filter { $0.isNumber || $0 == "." }
        return Double(digits) ?? 0.0
    }

    /// Lee sensor O2 Bank 1 Sensor 1 (PID 0x14)
    /// Retorna voltaje 0-1.275V
    public func readO2VoltageB1S1() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x14)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) / 200.0
    }

    /// Lee sensor O2 Bank 1 Sensor 2 (PID 0x15)
    /// Retorna voltaje 0-1.275V
    public func readO2VoltageB1S2() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x15)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) / 200.0
    }

    /// Lee presión absoluta del colector (MAP) (PID 0x0B)
    /// Retorna presión en kPa
    public func readMAP() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x0B)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0])
    }

    /// Lee posición del acelerador (PID 0x49)
    /// Retorna porcentaje 0-100%
    public func readAcceleratorPosition() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x49)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return Double(bytes[0]) * 100.0 / 255.0
    }

    /// Lee STFT Bank 2 (PID 0x08)
    public func readFuelTrimShortB2() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x08)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
    }

    /// Lee LTFT Bank 2 (PID 0x09)
    public func readFuelTrimLongB2() async throws -> Double {
        let bytes = try await readStandardPID(mode: 0x01, pid: 0x09)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }
        return (Double(bytes[0]) - 128.0) * 100.0 / 128.0
    }

    // MARK: - Mode 22 (Enhanced/Manufacturer Specific PIDs)

    /// Lee un PID en Mode 22 (Enhanced Diagnostics - Mazda específico)
    /// El PID se envía como 22XXXX y la respuesta es 62XXXX + datos
    public func readEnhancedPID(_ pid: UInt16) async throws -> [UInt8] {
        // Configurar header para ECU del motor (7E0 para Mazda)
        _ = try? await sendCommand("ATSH7E0", timeout: 2.0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Enviar comando Mode 22
        let command = String(format: "22%04X", pid)
        let response = try await sendCommand(command, timeout: 3.0)

        if response.contains("NO DATA") || response.contains("ERROR") || response.contains("?") {
            throw OBDError.noData
        }

        // Parsear respuesta - buscar 62 seguido del PID
        let expectedPrefix = String(format: "62%04X", pid).uppercased()
        let bytes = parseEnhancedResponse(response, expectedPrefix: expectedPrefix)

        if bytes.isEmpty {
            throw OBDError.invalidResponse
        }

        return bytes
    }

    private func parseEnhancedResponse(_ response: String, expectedPrefix: String) -> [UInt8] {
        // Limpiar respuesta y convertir a bytes
        let hexOnly = response.uppercased()
            .components(separatedBy: .whitespaces)
            .joined()

        // Buscar el prefijo esperado (62XXXX)
        guard let range = hexOnly.range(of: expectedPrefix) else {
            return []
        }

        // Extraer bytes después del prefijo
        let dataStart = hexOnly[range.upperBound...]
        var bytes: [UInt8] = []
        var index = dataStart.startIndex

        while index < dataStart.endIndex {
            guard let nextIndex = dataStart.index(index, offsetBy: 2, limitedBy: dataStart.endIndex) else { break }
            let byteString = String(dataStart[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }

        return bytes
    }

    /// Lee temperatura del aceite vía Mode 22 PID 1310 (Mazda RX-8)
    /// IMPORTANTE: El RX-8 NO tiene sensor físico de temperatura de aceite.
    /// La ECU CALCULA este valor basándose en: RPM, carga del motor,
    /// posición del solenoide de la bomba de aceite, temp refrigerante y velocidad.
    /// Cuando el motor está frío o la ECU no ha convergido, el valor es basura.
    public func readOilTempMazda() async throws -> Double {
        let bytes = try await readEnhancedPID(0x1310)
        guard bytes.count >= 1 else { throw OBDError.invalidResponse }

        var tempC: Double

        // Probar diferentes fórmulas según el número de bytes recibidos
        if bytes.count >= 2 {
            let rawValue = Double(bytes[0]) * 256.0 + Double(bytes[1])

            // Intentar varias fórmulas comunes de Mazda
            // Fórmula 1: (rawValue / 10) - 40 (común en Mazda)
            let temp1 = (rawValue / 10.0) - 40.0

            // Fórmula 2: (rawValue / 100) - 40
            let temp2 = (rawValue / 100.0) - 40.0

            // Fórmula 3: rawValue - 40 (si rawValue es pequeño)
            let temp3 = rawValue - 40.0

            // Usar la que dé un valor más razonable (80-130°C para motor caliente)
            if temp1 >= 50 && temp1 <= 150 {
                tempC = temp1
            } else if temp2 >= 50 && temp2 <= 150 {
                tempC = temp2
            } else if temp3 >= 50 && temp3 <= 150 {
                tempC = temp3
            } else {
                // Ninguna fórmula da valor razonable - usar fórmula estándar
                tempC = temp1
            }
        } else {
            // Un solo byte - fórmula estándar OBD: A - 40
            tempC = Double(bytes[0]) - 40.0
        }

        // Si el valor es menor a 50°C, considerarlo no válido
        // (el motor no ha calentado o la ECU no ha calculado bien)
        guard tempC >= 50 else {
            throw OBDError.noData
        }

        return tempC
    }

    /// Lee voltaje MAF vía Mode 22 PID 1177 (Mazda específico)
    /// Fórmula: ((A*256)+B)/3700 = V
    public func readMAFVoltageMazda() async throws -> Double {
        let bytes = try await readEnhancedPID(0x1177)
        guard bytes.count >= 2 else { throw OBDError.invalidResponse }

        let rawValue = Double(bytes[0]) * 256.0 + Double(bytes[1])
        return rawValue / 3700.0
    }

    // MARK: - Fuel Level Senders (RX-8 Dual Tank)

    /// El RX-8 tiene un depósito "saddle tank" dividido en dos secciones
    /// con sondas independientes. Una sonda defectuosa causa lecturas incorrectas.

    /// PIDs posibles para sondas de combustible Mazda (Mode 22)
    /// Nota: Los PIDs exactos pueden variar según año/versión de ECU
    private static let fuelSenderPIDsLeft: [UInt16] = [0x1170, 0x1172, 0x1168]
    private static let fuelSenderPIDsRight: [UInt16] = [0x1171, 0x1173, 0x1169]

    /// Lee el nivel de combustible de una sonda específica
    /// Intenta múltiples PIDs hasta encontrar uno que funcione
    private func readFuelSenderMazda(pids: [UInt16]) async -> Double? {
        for pid in pids {
            if let bytes = try? await readEnhancedPID(pid), bytes.count >= 1 {
                let value = Double(bytes[0]) * 100.0 / 255.0
                // Validar que el valor es razonable (0-100%)
                if value >= 0 && value <= 100 {
                    return value
                }
            }
        }
        return nil
    }

    /// Lee el nivel de combustible del tanque izquierdo
    public func readFuelLevelLeftMazda() async throws -> Double {
        if let level = await readFuelSenderMazda(pids: Self.fuelSenderPIDsLeft) {
            return level
        }
        throw OBDError.noData
    }

    /// Lee el nivel de combustible del tanque derecho
    public func readFuelLevelRightMazda() async throws -> Double {
        if let level = await readFuelSenderMazda(pids: Self.fuelSenderPIDsRight) {
            return level
        }
        throw OBDError.noData
    }

    /// Lee ambas sondas de combustible y devuelve el estado completo
    /// Siempre incluye el nivel estándar OBD como referencia
    public func readDualFuelLevel() async throws -> DualFuelLevelReading {
        // SIEMPRE leer nivel estándar primero (más confiable)
        let standardLevel = try? await readFuelLevel()

        // Intentar leer sondas individuales (puede fallar si ECU no soporta)
        let leftLevel = await readFuelSenderMazda(pids: Self.fuelSenderPIDsLeft)
        let rightLevel = await readFuelSenderMazda(pids: Self.fuelSenderPIDsRight)

        return DualFuelLevelReading(
            leftSender: leftLevel,
            rightSender: rightLevel,
            standardReading: standardLevel.map { Double($0) }
        )
    }

    // MARK: - DTCs

    public func readDTCs() async throws -> [String] {
        let response = try await sendCommand("03", timeout: 5.0)
        if response.contains("NO DATA") { return [] }
        let bytes = parseHexResponse(response)
        return parseDTCBytes(bytes)
    }

    public func readPendingDTCs() async throws -> [String] {
        let response = try await sendCommand("07", timeout: 5.0)
        if response.contains("NO DATA") { return [] }
        let bytes = parseHexResponse(response)
        return parseDTCBytes(bytes)
    }

    private func parseDTCBytes(_ bytes: [UInt8]) -> [String] {
        var dtcs: [String] = []
        var i = 0

        while i + 1 < bytes.count {
            let byte1 = bytes[i]
            let byte2 = bytes[i + 1]

            if byte1 == 0 && byte2 == 0 {
                i += 2
                continue
            }

            let firstChar: String
            switch (byte1 >> 6) & 0x03 {
            case 0: firstChar = "P"
            case 1: firstChar = "C"
            case 2: firstChar = "B"
            default: firstChar = "U"
            }

            let secondDigit = (byte1 >> 4) & 0x03
            let thirdDigit = byte1 & 0x0F
            let fourthDigit = (byte2 >> 4) & 0x0F
            let fifthDigit = byte2 & 0x0F

            let dtc = "\(firstChar)\(String(format: "%X%X%X%X", secondDigit, thirdDigit, fourthDigit, fifthDigit))"

            if dtc != "P0000" {
                dtcs.append(dtc)
            }
            i += 2
        }
        return dtcs
    }

    public func clearDTCs() async throws {
        log("Iniciando borrado de DTCs...")

        // Primero leemos los DTCs actuales
        let dtcsBefore = try await readDTCs()
        let pendingBefore = try await readPendingDTCs()
        log("DTCs antes de borrar: \(dtcsBefore.count) activos, \(pendingBefore.count) pendientes")

        // Enviar comando de borrado (Mode 04)
        let response = try await sendCommand("04", timeout: 5.0)
        log("Respuesta al borrado: \(response)")

        // Esperar un momento para que el ECU procese
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Verificar que se borraron
        let dtcsAfter = try await readDTCs()
        let pendingAfter = try await readPendingDTCs()
        log("DTCs después de borrar: \(dtcsAfter.count) activos, \(pendingAfter.count) pendientes")

        if !dtcsAfter.isEmpty {
            log("ADVERTENCIA: Algunos DTCs permanecen después del borrado: \(dtcsAfter)")
        }

        // Publicar resultado
        await MainActor.run {
            self.dtcClearResult = DTCClearResult(
                success: dtcsAfter.isEmpty,
                dtcsCleared: dtcsBefore.count + pendingBefore.count,
                dtcsRemaining: dtcsAfter + pendingAfter,
                timestamp: Date()
            )
        }
    }

    /// Resultado del borrado de DTCs
    public struct DTCClearResult {
        public let success: Bool
        public let dtcsCleared: Int
        public let dtcsRemaining: [String]
        public let timestamp: Date

        public var message: String {
            if success {
                return "Se borraron \(dtcsCleared) código(s) correctamente"
            } else {
                return "Algunos códigos no se pudieron borrar: \(dtcsRemaining.joined(separator: ", "))"
            }
        }
    }

    @Published public var dtcClearResult: DTCClearResult?

    // MARK: - VIN

    public func readVIN() async throws -> String {
        let response = try await sendCommand("0902", timeout: 5.0)
        if response.contains("NO DATA") { throw OBDError.noData }
        let bytes = parseHexResponse(response)
        let vinBytes = bytes.count > 17 ? Array(bytes.dropFirst()) : bytes
        if let vin = String(bytes: vinBytes.prefix(17), encoding: .ascii) {
            return vin.trimmingCharacters(in: .whitespaces)
        }
        throw OBDError.invalidResponse
    }

    public func testConnection() async -> Bool {
        do {
            _ = try await sendCommand("0100", timeout: 3.0)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Diagnóstico Completo del Adaptador

    public func runFullDiagnostic() async -> DiagnosticResults {
        log("=== Iniciando diagnóstico completo ===")
        var results = DiagnosticResults()

        // Test 1: Estado del Bluetooth
        results.bluetoothAvailable = centralManager?.state == .poweredOn
        log("Bluetooth disponible: \(results.bluetoothAvailable)")

        // Test 2: Conexión al adaptador
        results.adapterConnected = connectedPeripheral != nil && writeCharacteristic != nil
        log("Adaptador conectado: \(results.adapterConnected)")

        guard results.adapterConnected else {
            results.summary = "No hay conexión con el adaptador"
            return results
        }

        // Test 3: Reset del adaptador
        do {
            let atzResp = try await sendCommand("ATZ", timeout: 8.0)
            results.atzResponse = atzResp
            results.atzOK = !atzResp.isEmpty
            log("ATZ: \(atzResp)")
        } catch {
            results.atzResponse = "Error: \(error.localizedDescription)"
            log("ATZ falló: \(error.localizedDescription)")
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Test 4: Versión del adaptador
        do {
            _ = try await sendCommand("ATE0", timeout: 2.0)
            let atiResp = try await sendCommand("ATI", timeout: 3.0)
            results.atiResponse = atiResp
            results.adapterVersion = atiResp
            log("ATI: \(atiResp)")
        } catch {
            results.atiResponse = "Error: \(error.localizedDescription)"
            log("ATI falló: \(error.localizedDescription)")
        }

        // Test 5: Voltaje de batería
        do {
            let voltResp = try await sendCommand("ATRV", timeout: 2.0)
            results.voltage = voltResp
            log("Voltaje: \(voltResp)")
        } catch {
            results.voltage = "Error"
            log("ATRV falló")
        }

        // Test 6: Protocolo actual
        do {
            let dpnResp = try await sendCommand("ATDPN", timeout: 2.0)
            results.protocolNumber = dpnResp
            log("Protocolo: \(dpnResp)")
        } catch {
            results.protocolNumber = "Error"
        }

        // Test 7: Auto-protocolo y conexión al vehículo
        _ = try? await sendCommand("ATSP0", timeout: 2.0)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        do {
            let pid0100Resp = try await sendCommand("0100", timeout: 10.0)
            results.pid0100Response = pid0100Resp
            results.vehicleResponding = isValidOBDResponse(pid0100Resp)
            log("0100: \(pid0100Resp)")
        } catch {
            results.pid0100Response = "Error: \(error.localizedDescription)"
            log("0100 falló: \(error.localizedDescription)")
        }

        // Test 8: Si el vehículo responde, intentar leer RPM
        if results.vehicleResponding {
            do {
                let rpmResp = try await sendCommand("010C", timeout: 5.0)
                results.pid010CResponse = rpmResp
                log("RPM (010C): \(rpmResp)")
            } catch {
                results.pid010CResponse = "Error"
            }
        }

        // Test 9: Probar diferentes protocolos
        results.protocolTests = []
        let testProtocols = [
            ("ATSP6", "CAN 500k 11bit"),
            ("ATSP7", "CAN 500k 29bit"),
            ("ATSP5", "KWP Fast"),
            ("ATSP3", "ISO 9141")
        ]

        if !results.vehicleResponding {
            log("Probando protocolos alternativos...")
            for (cmd, name) in testProtocols {
                _ = try? await sendCommand(cmd, timeout: 2.0)
                try? await Task.sleep(nanoseconds: 1_500_000_000)

                do {
                    let testResp = try await sendCommand("0100", timeout: 8.0)
                    let success = isValidOBDResponse(testResp)
                    results.protocolTests.append(ProtocolTestResult(name: name, response: testResp, success: success))
                    log("\(name): \(testResp) - \(success ? "OK" : "FAIL")")

                    if success {
                        results.vehicleResponding = true
                        results.workingProtocol = name
                        break
                    }
                } catch {
                    results.protocolTests.append(ProtocolTestResult(name: name, response: "Timeout", success: false))
                }
            }
        }

        // Generar resumen
        results.generateSummary()
        log("=== Diagnóstico completado ===")
        log("Resumen: \(results.summary)")

        DispatchQueue.main.async { [weak self] in
            self?.diagnosticResults = results
        }

        return results
    }

    // MARK: - Envío de comandos AT en crudo (para testing)

    public func sendRawCommand(_ command: String) async throws -> String {
        log("Raw CMD: \(command)")
        let response = try await sendCommand(command, timeout: 5.0)
        log("Raw RSP: \(response)")
        return response
    }

    // MARK: - Diagnóstico de características BLE

    public func getBLEDiagnosticInfo() -> String {
        var info = "=== BLE Diagnostic Info ===\n"

        if let peripheral = connectedPeripheral {
            info += "Peripheral: \(peripheral.name ?? "Unknown")\n"
            info += "UUID: \(peripheral.identifier)\n"
            info += "State: \(peripheral.state.rawValue)\n\n"

            if let services = peripheral.services {
                for service in services {
                    info += "Service: \(service.uuid)\n"
                    if let chars = service.characteristics {
                        for char in chars {
                            let props = describeProperties(char.properties)
                            info += "  Char: \(char.uuid) [\(props)]\n"
                            if char == writeCharacteristic {
                                info += "    ^ WRITE SELECTED\n"
                            }
                            if char == notifyCharacteristic {
                                info += "    ^ NOTIFY SELECTED\n"
                            }
                        }
                    }
                }
            }
        } else {
            info += "No peripheral connected\n"
        }

        return info
    }

    private func describeProperties(_ props: CBCharacteristicProperties) -> String {
        var desc: [String] = []
        if props.contains(.read) { desc.append("R") }
        if props.contains(.write) { desc.append("W") }
        if props.contains(.writeWithoutResponse) { desc.append("WnR") }
        if props.contains(.notify) { desc.append("N") }
        if props.contains(.indicate) { desc.append("I") }
        return desc.joined(separator: ",")
    }

    // Test de escritura directo a una característica específica
    public func testWriteToCharacteristic(serviceUUID: String, charUUID: String, data: String) async -> String {
        guard let peripheral = connectedPeripheral,
              let services = peripheral.services else {
            return "Error: No hay peripheral conectado"
        }

        let serviceUUIDObj = CBUUID(string: serviceUUID)
        let charUUIDObj = CBUUID(string: charUUID)

        guard let service = services.first(where: { $0.uuid == serviceUUIDObj }),
              let chars = service.characteristics,
              let char = chars.first(where: { $0.uuid == charUUIDObj }) else {
            return "Error: Característica no encontrada"
        }

        let testData = (data + "\r").data(using: .ascii)!

        log("Test write to \(charUUID): \(data)")

        // Intentar write
        if char.properties.contains(.write) {
            peripheral.writeValue(testData, for: char, type: .withResponse)
            return "Enviado con writeWithResponse a \(charUUID)"
        } else if char.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(testData, for: char, type: .withoutResponse)
            return "Enviado con writeWithoutResponse a \(charUUID)"
        }

        return "Error: Característica no soporta escritura"
    }

    // Cambiar característica de escritura activa
    public func switchWriteCharacteristic(to uuid: String) -> Bool {
        guard let peripheral = connectedPeripheral,
              let services = peripheral.services else {
            return false
        }

        let targetUUID = CBUUID(string: uuid)

        for service in services {
            if let chars = service.characteristics {
                for char in chars where char.uuid == targetUUID {
                    if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                        writeCharacteristic = char
                        log("Write characteristic cambiado a: \(uuid)")
                        return true
                    }
                }
            }
        }
        return false
    }

    // Cambiar característica de notificación activa
    public func switchNotifyCharacteristic(to uuid: String) -> Bool {
        guard let peripheral = connectedPeripheral,
              let services = peripheral.services else {
            return false
        }

        let targetUUID = CBUUID(string: uuid)

        for service in services {
            if let chars = service.characteristics {
                for char in chars where char.uuid == targetUUID {
                    if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                        // Desuscribir de la anterior
                        if let oldChar = notifyCharacteristic {
                            peripheral.setNotifyValue(false, for: oldChar)
                        }
                        // Suscribir a la nueva
                        notifyCharacteristic = char
                        peripheral.setNotifyValue(true, for: char)
                        log("Notify characteristic cambiado a: \(uuid)")
                        return true
                    }
                }
            }
        }
        return false
    }

    // Reiniciar conexión BLE manteniendo el mismo peripheral
    public func reconnectBLE() {
        guard let peripheral = connectedPeripheral else { return }

        log("Reconectando BLE...")

        // Limpiar características
        writeCharacteristic = nil
        notifyCharacteristic = nil

        // Redescubrir servicios
        peripheral.discoverServices(nil)
    }
}

// MARK: - CBCentralManagerDelegate

extension OBDConnectionManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            lastError = nil
            // Intentar auto-conexión cuando el Bluetooth esté listo
            if pendingAutoConnect || (isAutoConnectEnabled && savedAdapterUUID != nil && connectionState == .disconnected) {
                pendingAutoConnect = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.attemptAutoConnect()
                }
            }
        case .poweredOff:
            lastError = .bluetoothNotAvailable
            connectionState = .disconnected
            isAutoConnecting = false
        case .unauthorized:
            lastError = .bluetoothNotAuthorized
        case .unsupported:
            lastError = .bluetoothNotSupported
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Desconocido"

        // Si estamos en auto-conexión, buscar el adaptador guardado
        if isAutoConnecting, let savedUUID = savedAdapterUUID, peripheral.identifier == savedUUID {
            connect(toPeripheral: peripheral)
            return
        }

        // Lista ampliada de keywords para detectar adaptadores OBD
        let obdKeywords = [
            // Genéricos
            "OBD", "OBDII", "OBD2", "ELM", "ELM327", "ODB",
            // Chips específicos
            "STN", "STN1110", "STN2120",
            // Marcas conocidas
            "Carista", "Vgate", "Veepeak", "BAFX", "LELink", "vLinker",
            "Konnwei", "Kufatec", "BlueDriver", "Torque", "ScanTool",
            "OBDLink", "OBDII-Link", "Autel", "Ancel", "Foxwell",
            "Launch", "Thinkcar", "MUCAR", "NONDA", "Carly", "AUTOPHIX",
            // Keywords parciales
            "BT", "Car", "iOS-Vlink", "Wireless", "Scanner", "Diag",
            "Auto", "Vehicle", "V-Link", "V-Gate", "V-Scan"
        ]
        let nameUpper = name.uppercased()
        let isOBDDevice = obdKeywords.contains { nameUpper.contains($0.uppercased()) }

        if isOBDDevice || name != "Desconocido" {
            let device = OBDDevice(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                peripheral: peripheral
            )

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !self.discoveredDevices.contains(where: { $0.id == device.id }) {
                    self.discoveredDevices.append(device)
                }
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        connectionState = .connectedToAdapter
        isAutoConnecting = false

        // Guardar este adaptador para auto-conexión futura
        saveCurrentAdapter()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = .connectionFailed(error?.localizedDescription ?? "Error desconocido")
        connectionState = .disconnected
        isAutoConnecting = false
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            lastError = .disconnected
        }
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate

extension OBDConnectionManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            lastError = .initializationFailed("No se encontraron servicios")
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }

        log("Servicio: \(service.uuid) - \(characteristics.count) características")

        // Detectar si es un servicio STN/Carista (FFF0) o ELM327 (FFE0)
        let isSTNService = service.uuid == OBDServiceUUIDs.stnService ||
                          service.uuid == CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
        let isELMService = service.uuid == OBDServiceUUIDs.elm327Service ||
                          service.uuid == CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")

        if isSTNService {
            log("Detectado servicio STN/Carista (FFF0)")
        } else if isELMService {
            log("Detectado servicio ELM327 (FFE0)")
        }

        for characteristic in characteristics {
            let props = characteristic.properties
            let uuid = characteristic.uuid
            log("  Característica: \(uuid) - Props: \(props.rawValue)")

            // Para STN/Carista: FFF1=Read/Notify, FFF2=Write
            if isSTNService {
                if uuid == OBDServiceUUIDs.stnReadCharacteristic || uuid == CBUUID(string: "FFF1") {
                    // FFF1 es para recibir datos (notify)
                    if props.contains(.notify) || props.contains(.indicate) || props.contains(.read) {
                        notifyCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                        log("  -> STN Notify/Read (FFF1): \(uuid)")
                    }
                } else if uuid == OBDServiceUUIDs.stnWriteCharacteristic || uuid == CBUUID(string: "FFF2") {
                    // FFF2 es para enviar comandos (write)
                    if props.contains(.write) || props.contains(.writeWithoutResponse) {
                        writeCharacteristic = characteristic
                        log("  -> STN Write (FFF2): \(uuid)")
                    }
                }
            }
            // Para ELM327: FFE1 sirve para todo
            else if isELMService {
                if uuid == OBDServiceUUIDs.elm327Characteristic || uuid == CBUUID(string: "FFE1") {
                    if props.contains(.write) || props.contains(.writeWithoutResponse) {
                        writeCharacteristic = characteristic
                        log("  -> ELM Write (FFE1): \(uuid)")
                    }
                    if props.contains(.notify) || props.contains(.indicate) {
                        notifyCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                        log("  -> ELM Notify (FFE1): \(uuid)")
                    }
                }
            }
            // Fallback genérico para otros servicios
            else {
                if props.contains(.write) || props.contains(.writeWithoutResponse) {
                    if writeCharacteristic == nil {
                        writeCharacteristic = characteristic
                        log("  -> Write (genérica): \(uuid)")
                    }
                }
                if props.contains(.notify) || props.contains(.indicate) {
                    if notifyCharacteristic == nil {
                        notifyCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                        log("  -> Notify (genérica): \(uuid)")
                    }
                }
            }
        }

        // Verificar que tenemos las características necesarias
        if let wc = writeCharacteristic, let nc = notifyCharacteristic {
            log("Características configuradas:")
            log("  Write: \(wc.uuid)")
            log("  Notify: \(nc.uuid)")
            log("Iniciando adaptador...")
            initializeAdapter()
        } else {
            log("ADVERTENCIA: Faltan características")
            log("  Write: \(writeCharacteristic?.uuid.uuidString ?? "NO")")
            log("  Notify: \(notifyCharacteristic?.uuid.uuidString ?? "NO")")
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        handleResponse(data)
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Silently handle write errors
    }
}

// MARK: - Tipos de Datos

public enum ConnectionState: String, Sendable {
    case disconnected = "Desconectado"
    case scanning = "Buscando..."
    case connecting = "Conectando..."
    case connectedToAdapter = "Conectado al adaptador"
    case initializing = "Inicializando..."
    case connectedToVehicle = "Conectado al vehículo"

    public var isConnected: Bool {
        switch self {
        case .connectedToAdapter, .connectedToVehicle, .initializing:
            return true
        default:
            return false
        }
    }
}

public struct OBDDevice: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let peripheral: CBPeripheral?

    public var signalStrength: SignalStrength {
        if rssi >= -50 { return .excellent }
        if rssi >= -60 { return .good }
        if rssi >= -70 { return .fair }
        return .weak
    }
}

public enum SignalStrength: String {
    case excellent = "Excelente"
    case good = "Buena"
    case fair = "Regular"
    case weak = "Débil"

    public var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak: return 1
        }
    }
}

public struct OBDAdapterInfo: Sendable {
    public let version: String
    public var chipType: String {
        if version.uppercased().contains("ELM327") { return "ELM327" }
        if version.uppercased().contains("STN") { return "STN1110" }
        if version.uppercased().contains("OBDLINK") { return "OBDLink" }
        return "Compatible"
    }
}

public enum VehicleProtocol: String, Sendable {
    case auto = "Auto"
    case iso9141_2 = "ISO 9141-2"
    case iso14230_4_kwp_slow = "KWP Slow"
    case iso14230_4_kwp_fast = "KWP Fast"
    case iso15765_4_can_11bit_500k = "CAN 500k"
    case iso15765_4_can_29bit_500k = "CAN 500k 29-bit"
    case iso15765_4_can_11bit_250k = "CAN 250k"
    case iso15765_4_can_29bit_250k = "CAN 250k 29-bit"
    case sae_j1850_pwm = "J1850 PWM"
    case sae_j1850_vpw = "J1850 VPW"

    public static func from(elm327Code: String) -> VehicleProtocol {
        let code = elm327Code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: "A", with: "")
        switch code {
        case "0": return .auto
        case "1": return .sae_j1850_pwm
        case "2": return .sae_j1850_vpw
        case "3": return .iso9141_2
        case "4": return .iso14230_4_kwp_slow
        case "5": return .iso14230_4_kwp_fast
        case "6": return .iso15765_4_can_11bit_500k
        case "7": return .iso15765_4_can_29bit_500k
        case "8": return .iso15765_4_can_11bit_250k
        case "9": return .iso15765_4_can_29bit_250k
        default: return .auto
        }
    }

    public static let rx8Default: VehicleProtocol = .iso15765_4_can_11bit_500k
}

public enum OBDError: Error, LocalizedError, Sendable {
    case bluetoothNotAvailable
    case bluetoothNotAuthorized
    case bluetoothNotSupported
    case deviceNotFound
    case connectionFailed(String)
    case notConnected
    case timeout
    case invalidCommand
    case invalidResponse
    case noData
    case disconnected
    case initializationFailed(String)
    case canError
    case busError

    public var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable: return "Bluetooth no disponible"
        case .bluetoothNotAuthorized: return "Permiso de Bluetooth denegado"
        case .bluetoothNotSupported: return "Bluetooth LE no soportado"
        case .deviceNotFound: return "Dispositivo no encontrado"
        case .connectionFailed(let reason): return "Error: \(reason)"
        case .notConnected: return "No conectado"
        case .timeout: return "Tiempo agotado"
        case .invalidCommand: return "Comando inválido"
        case .invalidResponse: return "Respuesta inválida"
        case .noData: return "Sin datos"
        case .disconnected: return "Desconectado"
        case .initializationFailed(let reason): return "Init error: \(reason)"
        case .canError: return "Error CAN"
        case .busError: return "Error BUS"
        }
    }
}

// MARK: - Tipos de Adaptador

public enum AdapterType: String, Sendable {
    case elm327 = "ELM327"
    case elm327Clone = "ELM327 Clone"
    case stn1110 = "STN1110"
    case stn2120 = "STN2120"
    case carista = "Carista"
    case obdLink = "OBDLink"
    case unknown = "Desconocido"

    public static func detect(from version: String) -> AdapterType {
        let upper = version.uppercased()

        if upper.contains("STN2120") { return .stn2120 }
        if upper.contains("STN1110") || upper.contains("STN11") { return .stn1110 }
        if upper.contains("CARISTA") { return .carista }
        if upper.contains("OBDLINK") { return .obdLink }

        if upper.contains("ELM327") {
            // Detectar clones vs originales
            if upper.contains("V1.5") || upper.contains("V2.") {
                // Versiones altas suelen ser clones (ELM327 real es v1.4a máximo)
                return .elm327Clone
            }
            return .elm327
        }

        // STN chips a veces se identifican como ELM pero soportan comandos ST
        if upper.contains("STN") || upper.contains("ST ") {
            return .stn1110
        }

        return .unknown
    }

    public var supportsSTCommands: Bool {
        switch self {
        case .stn1110, .stn2120, .carista, .obdLink:
            return true
        default:
            return false
        }
    }

    public var description: String {
        switch self {
        case .elm327:
            return "ELM327 original - Soporta OBD-II estándar"
        case .elm327Clone:
            return "Clon ELM327 - Compatibilidad variable"
        case .stn1110:
            return "STN1110 - Chip profesional con comandos extendidos"
        case .stn2120:
            return "STN2120 - Chip avanzado con soporte CAN FD"
        case .carista:
            return "Carista OBD2 - Basado en STN, buena compatibilidad"
        case .obdLink:
            return "OBDLink - Adaptador profesional de alta velocidad"
        case .unknown:
            return "Adaptador desconocido"
        }
    }
}

// MARK: - Resultados de Diagnóstico

public struct DiagnosticResults: Sendable {
    public var bluetoothAvailable: Bool = false
    public var adapterConnected: Bool = false
    public var atzOK: Bool = false
    public var atzResponse: String = ""
    public var atiResponse: String = ""
    public var adapterVersion: String = ""
    public var voltage: String = ""
    public var protocolNumber: String = ""
    public var pid0100Response: String = ""
    public var pid010CResponse: String = ""
    public var vehicleResponding: Bool = false
    public var workingProtocol: String = ""
    public var protocolTests: [ProtocolTestResult] = []
    public var summary: String = ""

    public init() {}

    public mutating func generateSummary() {
        var issues: [String] = []

        if !bluetoothAvailable {
            issues.append("Bluetooth no disponible")
        }
        if !adapterConnected {
            issues.append("Adaptador no conectado")
        }
        if !atzOK {
            issues.append("Reset del adaptador falló")
        }
        if !vehicleResponding {
            issues.append("El vehículo no responde - Verifica contacto puesto")
        }

        if issues.isEmpty {
            summary = "Todo OK - Conexión establecida con el vehículo"
        } else {
            summary = issues.joined(separator: ". ")
        }
    }

    public var isFullyOperational: Bool {
        bluetoothAvailable && adapterConnected && atzOK && vehicleResponding
    }
}

public struct ProtocolTestResult: Sendable {
    public let name: String
    public let response: String
    public let success: Bool

    public init(name: String, response: String, success: Bool) {
        self.name = name
        self.response = response
        self.success = success
    }
}

// MARK: - Dual Fuel Level Reading (RX-8 Saddle Tank)

/// Lectura del sistema de combustible dual del RX-8
/// El RX-8 tiene un depósito "saddle tank" dividido en dos secciones
/// con una sonda de nivel independiente en cada lado.
public struct DualFuelLevelReading: Sendable {
    /// Nivel de la sonda izquierda (0-100%), nil si no disponible
    public let leftSender: Double?
    /// Nivel de la sonda derecha (0-100%), nil si no disponible
    public let rightSender: Double?
    /// Lectura estándar OBD (PID 0x2F) como referencia
    public let standardReading: Double?
    /// Timestamp de la lectura
    public let timestamp: Date

    // Historial para detección de sonda atascada
    private static var leftHistory: [Double] = []
    private static var rightHistory: [Double] = []
    private static let historySize = 30  // ~30 segundos de historial

    public init(leftSender: Double?, rightSender: Double?, standardReading: Double?, timestamp: Date = Date()) {
        self.leftSender = leftSender
        self.rightSender = rightSender
        self.standardReading = standardReading
        self.timestamp = timestamp
    }

    /// Nivel de combustible calculado combinando ambas sondas
    /// Usa lógica inteligente para compensar sondas defectuosas
    public var calculatedLevel: Double {
        // Si tenemos ambas sondas, promediar
        if let left = leftSender, let right = rightSender {
            // Si una está en valor extremo sospechoso y la otra no, usar la válida
            if isSuspiciousValue(left) && !isSuspiciousValue(right) {
                return right
            }
            if isSuspiciousValue(right) && !isSuspiciousValue(left) {
                return left
            }
            // Ambas válidas: promediar (el tanque tiene forma irregular)
            return (left + right) / 2.0
        }

        // Solo una sonda disponible
        if let left = leftSender { return left }
        if let right = rightSender { return right }

        // Fallback a lectura estándar
        return standardReading ?? 0
    }

    /// Estado de salud del sistema de combustible
    public var senderStatus: FuelSenderStatus {
        guard let left = leftSender, let right = rightSender else {
            if leftSender == nil && rightSender == nil {
                return .bothUnavailable
            }
            return leftSender == nil ? .leftUnavailable : .rightUnavailable
        }

        // Detectar sonda atascada en valor extremo
        if isSuspiciousValue(left) && !isSuspiciousValue(right) {
            return .leftSuspect(reason: left < 5 ? "Atascada en vacío" : "Atascada en lleno")
        }
        if isSuspiciousValue(right) && !isSuspiciousValue(left) {
            return .rightSuspect(reason: right < 5 ? "Atascada en vacío" : "Atascada en lleno")
        }

        // Detectar discrepancia grande entre sondas
        let difference = abs(left - right)
        if difference > 30 {
            // Más de 30% de diferencia es sospechoso
            return .mismatch(difference: difference)
        }

        return .normal
    }

    /// Mensaje de advertencia para el usuario
    public var warningMessage: String? {
        switch senderStatus {
        case .normal:
            return nil
        case .leftUnavailable:
            return "Sonda izquierda no responde"
        case .rightUnavailable:
            return "Sonda derecha no responde"
        case .bothUnavailable:
            return "Ambas sondas no responden"
        case .leftSuspect(let reason):
            return "⚠️ Sonda izquierda: \(reason)"
        case .rightSuspect(let reason):
            return "⚠️ Sonda derecha: \(reason)"
        case .mismatch(let diff):
            return "⚠️ Discrepancia entre sondas: \(Int(diff))%"
        case .stuckLeft, .stuckRight:
            return "⚠️ Sonda posiblemente atascada"
        }
    }

    /// Verifica si un valor es sospechoso (extremos)
    private func isSuspiciousValue(_ value: Double) -> Bool {
        // Valores muy cerca de 0 o 100 son sospechosos si la otra sonda difiere mucho
        return value < 2 || value > 98
    }

    /// Descripción legible del nivel
    public var levelDescription: String {
        let level = calculatedLevel
        if level < 10 {
            return "Reserva"
        } else if level < 25 {
            return "Bajo"
        } else if level < 50 {
            return "1/4 - 1/2"
        } else if level < 75 {
            return "1/2 - 3/4"
        } else {
            return "Lleno"
        }
    }

    /// Litros estimados (depósito RX-8: 60L total, ~55L útiles)
    public var estimatedLiters: Double {
        return calculatedLevel * 0.55  // 55L capacidad útil
    }

    /// Autonomía estimada basada en consumo promedio
    /// - Parameter avgConsumption: Consumo medio en L/100km
    public func estimatedRange(avgConsumption: Double) -> Double {
        guard avgConsumption > 0 else { return 0 }
        return (estimatedLiters / avgConsumption) * 100
    }
}

/// Estado del sistema de sondas de combustible
public enum FuelSenderStatus: Sendable, Equatable {
    case normal
    case leftUnavailable
    case rightUnavailable
    case bothUnavailable
    case leftSuspect(reason: String)
    case rightSuspect(reason: String)
    case mismatch(difference: Double)
    case stuckLeft
    case stuckRight

    public var isHealthy: Bool {
        if case .normal = self { return true }
        return false
    }

    public var requiresAttention: Bool {
        switch self {
        case .normal:
            return false
        case .leftUnavailable, .rightUnavailable, .bothUnavailable:
            return true
        case .leftSuspect, .rightSuspect, .mismatch, .stuckLeft, .stuckRight:
            return true
        }
    }
}
