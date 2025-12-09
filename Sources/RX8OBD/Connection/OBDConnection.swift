import Foundation
import CoreBluetooth
import Combine

// MARK: - Gestor de Conexión OBD2
// Soporta Bluetooth LE y WiFi para adaptadores ELM327

public class OBDConnectionManager: NSObject, ObservableObject {

    // MARK: - Estados Publicados
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var adapterInfo: OBDAdapterInfo?
    @Published public var vehicleProtocol: VehicleProtocol?
    @Published public var signalStrength: Int = 0 // 0-100
    @Published public var isScanning: Bool = false
    @Published public var discoveredDevices: [OBDDevice] = []
    @Published public var lastError: OBDError?

    // MARK: - Bluetooth
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    // UUIDs comunes de adaptadores OBD2 BLE
    private let obdServiceUUIDs = [
        CBUUID(string: "FFF0"),      // Común en muchos adaptadores
        CBUUID(string: "FFE0"),      // Veepeak, LELink
        CBUUID(string: "18F0"),      // OBDLink
        CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2") // vLinker
    ]

    private let writeCharacteristicUUIDs = [
        CBUUID(string: "FFF2"),
        CBUUID(string: "FFE1"),
        CBUUID(string: "18F1")
    ]

    private let notifyCharacteristicUUIDs = [
        CBUUID(string: "FFF1"),
        CBUUID(string: "FFE1"),
        CBUUID(string: "18F2")
    ]

    // MARK: - Buffer y Cola de Comandos
    private var responseBuffer = Data()
    private var commandQueue: [(command: String, completion: (Result<String, OBDError>) -> Void)] = []
    private var isProcessingCommand = false
    private var responseCompletion: ((Result<String, OBDError>) -> Void)?
    private var responseTimer: Timer?

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Inicialización

    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Escaneo de Dispositivos

    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = .bluetoothNotAvailable
            return
        }

        isScanning = true
        discoveredDevices.removeAll()

        // Escanear por UUIDs específicos de OBD2 y también sin filtro
        centralManager.scanForPeripherals(
            withServices: nil, // Sin filtro para encontrar más dispositivos
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Detener escaneo después de 30 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }

    public func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - Conexión

    public func connect(to device: OBDDevice) {
        guard let peripheral = device.peripheral else {
            lastError = .deviceNotFound
            return
        }

        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }

    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

    private func cleanup() {
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        responseBuffer.removeAll()
        commandQueue.removeAll()
        isProcessingCommand = false
        connectionState = .disconnected
        adapterInfo = nil
        vehicleProtocol = nil
    }

    // MARK: - Inicialización del Adaptador ELM327

    public func initializeAdapter() async throws {
        connectionState = .initializing

        // Reset del adaptador
        let _ = try await sendCommand("ATZ", timeout: 3.0)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Desactivar echo
        let _ = try await sendCommand("ATE0")

        // Desactivar espacios
        let _ = try await sendCommand("ATS0")

        // Desactivar headers
        let _ = try await sendCommand("ATH0")

        // Obtener versión
        let version = try await sendCommand("ATI")
        adapterInfo = OBDAdapterInfo(version: version.trimmingCharacters(in: .whitespacesAndNewlines))

        // Auto-detectar protocolo
        let _ = try await sendCommand("ATSP0") // Auto
        let protocolResponse = try await sendCommand("ATDPN")
        vehicleProtocol = VehicleProtocol.from(elm327Code: protocolResponse)

        // Establecer header para Mazda PCM
        let _ = try await sendCommand("ATSH7E0")

        connectionState = .connectedToVehicle
    }

    // MARK: - Envío de Comandos

    public func sendCommand(_ command: String, timeout: TimeInterval = 2.0) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            sendCommand(command, timeout: timeout) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func sendCommand(_ command: String, timeout: TimeInterval = 2.0, completion: @escaping (Result<String, OBDError>) -> Void) {
        commandQueue.append((command, completion))
        processNextCommand()
    }

    private func processNextCommand() {
        guard !isProcessingCommand, !commandQueue.isEmpty else { return }
        guard let writeChar = writeCharacteristic, let peripheral = connectedPeripheral else {
            let pending = commandQueue.removeFirst()
            pending.completion(.failure(.notConnected))
            return
        }

        isProcessingCommand = true
        let (command, completion) = commandQueue.removeFirst()
        responseCompletion = completion
        responseBuffer.removeAll()

        // Agregar retorno de carro
        let commandWithCR = command + "\r"
        guard let data = commandWithCR.data(using: .utf8) else {
            isProcessingCommand = false
            completion(.failure(.invalidCommand))
            return
        }

        // Enviar comando
        peripheral.writeValue(data, for: writeChar, type: .withResponse)

        // Timeout
        responseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
    }

    private func handleTimeout() {
        isProcessingCommand = false
        responseCompletion?(.failure(.timeout))
        responseCompletion = nil
        processNextCommand()
    }

    private func handleResponse(_ data: Data) {
        responseBuffer.append(data)

        // Verificar si la respuesta está completa (termina con >)
        if let responseString = String(data: responseBuffer, encoding: .utf8),
           responseString.contains(">") {

            responseTimer?.invalidate()
            responseTimer = nil

            // Limpiar respuesta
            let cleanResponse = responseString
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)

            isProcessingCommand = false
            responseCompletion?(.success(cleanResponse))
            responseCompletion = nil

            processNextCommand()
        }
    }

    // MARK: - Lectura de PIDs

    public func readPID(mode: UInt8, pid: UInt8) async throws -> Data {
        let command = String(format: "%02X%02X", mode, pid)
        let response = try await sendCommand(command)
        return parseOBDResponse(response)
    }

    public func readExtendedPID(code: String, header: String) async throws -> Data {
        // Cambiar header si es necesario
        if header != "7E0" {
            let _ = try await sendCommand("ATSH\(header)")
        }

        let response = try await sendCommand(code)

        // Restaurar header por defecto
        if header != "7E0" {
            let _ = try await sendCommand("ATSH7E0")
        }

        return parseOBDResponse(response)
    }

    public func readCANMessage(canID: UInt16) async throws -> Data {
        // Configurar filtro CAN
        let idHex = String(format: "%03X", canID)
        let _ = try await sendCommand("ATCF\(idHex)")
        let _ = try await sendCommand("ATCM7FF") // Máscara

        let response = try await sendCommand("ATMA", timeout: 1.0) // Monitor
        let _ = try await sendCommand("") // Detener monitor

        return parseCANResponse(response)
    }

    private func parseOBDResponse(_ response: String) -> Data {
        // Eliminar espacios y parsear hex
        let hexString = response.replacingOccurrences(of: " ", with: "")

        var data = Data()
        var index = hexString.startIndex

        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let byteString = String(hexString[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }

        // Saltar bytes de cabecera (típicamente 2-3 bytes)
        if data.count > 2 {
            return data.dropFirst(2)
        }
        return data
    }

    private func parseCANResponse(_ response: String) -> Data {
        // Similar pero para mensajes CAN
        return parseOBDResponse(response)
    }

    // MARK: - Lectura/Borrado de DTCs

    public func readDTCs() async throws -> [String] {
        let response = try await sendCommand("03") // Mode 03: Read DTCs
        let data = parseOBDResponse(response)
        return DTCParser.parseDTCResponse(data)
    }

    public func readPendingDTCs() async throws -> [String] {
        let response = try await sendCommand("07") // Mode 07: Pending DTCs
        let data = parseOBDResponse(response)
        return DTCParser.parseDTCResponse(data)
    }

    public func clearDTCs() async throws {
        let _ = try await sendCommand("04") // Mode 04: Clear DTCs
    }

    // MARK: - VIN

    public func readVIN() async throws -> String {
        let response = try await sendCommand("0902") // Mode 09, PID 02
        let data = parseOBDResponse(response)

        // VIN son 17 caracteres ASCII después del byte de cuenta
        if data.count > 1 {
            let vinData = data.dropFirst()
            return String(data: vinData, encoding: .ascii) ?? ""
        }
        return ""
    }
}

// MARK: - CBCentralManagerDelegate

extension OBDConnectionManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            break
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
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"

        // Filtrar solo dispositivos que parezcan OBD2
        let obdKeywords = ["OBD", "ELM", "OBDII", "Vgate", "Veepeak", "BAFX", "LELink", "Carista", "OBDLink", "vLinker"]
        let isOBDDevice = obdKeywords.contains { name.uppercased().contains($0.uppercased()) }

        if isOBDDevice || advertisementData[CBAdvertisementDataServiceUUIDsKey] != nil {
            let device = OBDDevice(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                peripheral: peripheral
            )

            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil) // Descubrir todos los servicios
        connectionState = .connectedToAdapter
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = .connectionFailed(error?.localizedDescription ?? "Unknown error")
        connectionState = .disconnected
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanup()
        if error != nil {
            lastError = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OBDConnectionManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Buscar característica de escritura
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }

            // Buscar característica de notificación
            if characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // Si tenemos ambas características, intentar inicializar
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            Task {
                do {
                    try await initializeAdapter()
                } catch {
                    lastError = .initializationFailed(error.localizedDescription)
                }
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        handleResponse(data)
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
        case .connectedToAdapter, .connectedToVehicle:
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
        if version.contains("ELM327") { return "ELM327" }
        if version.contains("STN") { return "STN1110" }
        if version.contains("OBDLink") { return "OBDLink" }
        return "Unknown"
    }
}

public enum VehicleProtocol: String, Sendable {
    case auto = "Auto"
    case iso9141_2 = "ISO 9141-2"
    case iso14230_4_kwp_slow = "ISO 14230-4 KWP (Slow)"
    case iso14230_4_kwp_fast = "ISO 14230-4 KWP (Fast)"
    case iso15765_4_can_11bit_500k = "ISO 15765-4 CAN (11bit, 500kbps)"
    case iso15765_4_can_29bit_500k = "ISO 15765-4 CAN (29bit, 500kbps)"
    case iso15765_4_can_11bit_250k = "ISO 15765-4 CAN (11bit, 250kbps)"
    case iso15765_4_can_29bit_250k = "ISO 15765-4 CAN (29bit, 250kbps)"
    case sae_j1850_pwm = "SAE J1850 PWM"
    case sae_j1850_vpw = "SAE J1850 VPW"

    public static func from(elm327Code: String) -> VehicleProtocol {
        let code = elm327Code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch code {
        case "0": return .auto
        case "1": return .sae_j1850_pwm
        case "2": return .sae_j1850_vpw
        case "3": return .iso9141_2
        case "4": return .iso14230_4_kwp_slow
        case "5": return .iso14230_4_kwp_fast
        case "6", "A6": return .iso15765_4_can_11bit_500k
        case "7", "A7": return .iso15765_4_can_29bit_500k
        case "8", "A8": return .iso15765_4_can_11bit_250k
        case "9", "A9": return .iso15765_4_can_29bit_250k
        default: return .auto
        }
    }

    /// El RX-8 usa CAN 11-bit 500kbps
    public static let rx8Default: VehicleProtocol = .iso15765_4_can_11bit_500k
}

public enum OBDError: Error, Sendable {
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

    public var localizedDescription: String {
        switch self {
        case .bluetoothNotAvailable:
            return "Bluetooth no disponible. Activa Bluetooth en Ajustes."
        case .bluetoothNotAuthorized:
            return "Permiso de Bluetooth denegado. Autoriza en Ajustes > Privacidad."
        case .bluetoothNotSupported:
            return "Este dispositivo no soporta Bluetooth LE."
        case .deviceNotFound:
            return "Dispositivo OBD2 no encontrado."
        case .connectionFailed(let reason):
            return "Error de conexión: \(reason)"
        case .notConnected:
            return "No conectado al adaptador OBD2."
        case .timeout:
            return "Tiempo de espera agotado. Verifica la conexión."
        case .invalidCommand:
            return "Comando inválido."
        case .invalidResponse:
            return "Respuesta inválida del vehículo."
        case .noData:
            return "Sin datos. El vehículo puede no soportar este PID."
        case .disconnected:
            return "Conexión perdida con el adaptador."
        case .initializationFailed(let reason):
            return "Error de inicialización: \(reason)"
        case .canError:
            return "Error en bus CAN."
        case .busError:
            return "Error en bus OBD."
        }
    }
}
