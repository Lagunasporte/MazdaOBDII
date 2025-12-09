import Foundation
import CoreBluetooth
import Combine

// MARK: - Gestor de Conexión OBD2
// Compatible con ELM327 v1.4+ vía Bluetooth

public class OBDConnectionManager: NSObject, ObservableObject {

    // MARK: - Estados Publicados
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var adapterInfo: OBDAdapterInfo?
    @Published public var vehicleProtocol: VehicleProtocol?
    @Published public var isScanning: Bool = false
    @Published public var discoveredDevices: [OBDDevice] = []
    @Published public var lastError: OBDError?
    @Published public var lastResponse: String = ""

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

    // MARK: - Inicialización

    public override init() {
        super.init()
        DispatchQueue.main.async { [weak self] in
            self?.centralManager = CBCentralManager(delegate: self, queue: .main)
        }
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
    }

    // MARK: - Inicialización del Adaptador ELM327 v1.4

    public func initializeAdapter() {
        connectionState = .initializing

        Task { @MainActor in
            do {
                // Reset
                _ = try await sendCommand("ATZ", timeout: 4.0)
                try await Task.sleep(nanoseconds: 1_000_000_000)

                // Echo off
                _ = try await sendCommand("ATE0", timeout: 2.0)
                try await Task.sleep(nanoseconds: 200_000_000)

                // Linefeed off
                _ = try await sendCommand("ATL0", timeout: 2.0)

                // Spaces off
                _ = try await sendCommand("ATS0", timeout: 2.0)

                // Headers off
                _ = try await sendCommand("ATH0", timeout: 2.0)

                // Versión
                let version = try await sendCommand("ATI", timeout: 2.0)
                adapterInfo = OBDAdapterInfo(version: version)

                // Auto protocolo
                _ = try await sendCommand("ATSP0", timeout: 2.0)
                try await Task.sleep(nanoseconds: 500_000_000)

                // Test conexión con vehículo
                let testResponse = try await sendCommand("0100", timeout: 5.0)

                if testResponse.contains("NO DATA") || testResponse.contains("UNABLE") || testResponse.contains("ERROR") {
                    _ = try await sendCommand("ATSP6", timeout: 2.0)
                    try await Task.sleep(nanoseconds: 500_000_000)
                }

                let protocolResponse = try await sendCommand("ATDPN", timeout: 2.0)
                vehicleProtocol = VehicleProtocol.from(elm327Code: protocolResponse)

                connectionState = .connectedToVehicle

            } catch {
                lastError = .initializationFailed(error.localizedDescription)
                connectionState = .connectedToAdapter
            }
        }
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

        let writeType: CBCharacteristicWriteType = writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
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
        guard let str = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else {
            return
        }

        responseBuffer += str

        if responseBuffer.contains(">") {
            responseTimer?.invalidate()
            responseTimer = nil

            let response = cleanResponse(responseBuffer)
            lastResponse = response

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
        _ = try await sendCommand("04", timeout: 5.0)
    }

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
}

// MARK: - CBCentralManagerDelegate

extension OBDConnectionManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            lastError = nil
        case .poweredOff:
            lastError = .bluetoothNotAvailable
            connectionState = .disconnected
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

        let obdKeywords = ["OBD", "ELM", "OBDII", "Vgate", "Veepeak", "BAFX", "LELink", "vLinker", "BT"]
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
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = .connectionFailed(error?.localizedDescription ?? "Error desconocido")
        connectionState = .disconnected
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

        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                if writeCharacteristic == nil {
                    writeCharacteristic = characteristic
                }
            }
            if characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.properties.contains(.read) && notifyCharacteristic == nil {
                notifyCharacteristic = characteristic
            }
        }

        if writeCharacteristic != nil && notifyCharacteristic != nil {
            initializeAdapter()
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

public struct DTCParser {
    public static func parseDTCResponse(_ data: Data) -> [String] {
        var dtcs: [String] = []
        let bytes = Array(data)
        var i = 0
        while i + 1 < bytes.count {
            let byte1 = bytes[i]
            let byte2 = bytes[i + 1]
            if byte1 == 0 && byte2 == 0 { i += 2; continue }
            let firstChar: String
            switch (byte1 >> 6) & 0x03 {
            case 0: firstChar = "P"
            case 1: firstChar = "C"
            case 2: firstChar = "B"
            default: firstChar = "U"
            }
            let dtc = "\(firstChar)\(String(format: "%X%X%X%X", (byte1 >> 4) & 0x03, byte1 & 0x0F, (byte2 >> 4) & 0x0F, byte2 & 0x0F))"
            if dtc != "P0000" { dtcs.append(dtc) }
            i += 2
        }
        return dtcs
    }
}
