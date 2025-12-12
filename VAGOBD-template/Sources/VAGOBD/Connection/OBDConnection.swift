import Foundation
import CoreBluetooth
import Combine

// MARK: - OBD Connection Protocol
public protocol OBDConnectionDelegate: AnyObject {
    func connectionDidConnect()
    func connectionDidDisconnect()
    func connectionDidReceiveData(_ data: String)
    func connectionDidFail(with error: OBDError)
}

// MARK: - OBD Error Types
public enum OBDError: Error, LocalizedError {
    case notConnected
    case timeout
    case invalidResponse
    case bluetoothUnavailable
    case deviceNotFound
    case communicationError(String)
    case protocolError(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No conectado al adaptador OBD2"
        case .timeout:
            return "Tiempo de espera agotado"
        case .invalidResponse:
            return "Respuesta inválida del vehículo"
        case .bluetoothUnavailable:
            return "Bluetooth no disponible"
        case .deviceNotFound:
            return "Adaptador OBD2 no encontrado"
        case .communicationError(let msg):
            return "Error de comunicación: \(msg)"
        case .protocolError(let msg):
            return "Error de protocolo: \(msg)"
        }
    }
}

// MARK: - Connection State
public enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case ready
}

// MARK: - OBD Protocol
public enum OBDProtocol: String, CaseIterable {
    case auto = "0"
    case j1850PWM = "1"
    case j1850VPW = "2"
    case iso9141_2 = "3"
    case kwp2000Slow = "4"
    case kwp2000Fast = "5"
    case canISO15765_11bit500k = "6"
    case canISO15765_29bit500k = "7"
    case canISO15765_11bit250k = "8"
    case canISO15765_29bit250k = "9"
    case canSAEJ1939 = "A"

    public var description: String {
        switch self {
        case .auto: return "Automático"
        case .j1850PWM: return "SAE J1850 PWM"
        case .j1850VPW: return "SAE J1850 VPW"
        case .iso9141_2: return "ISO 9141-2"
        case .kwp2000Slow: return "KWP2000 Slow"
        case .kwp2000Fast: return "KWP2000 Fast"
        case .canISO15765_11bit500k: return "CAN 11-bit 500kbps"
        case .canISO15765_29bit500k: return "CAN 29-bit 500kbps"
        case .canISO15765_11bit250k: return "CAN 11-bit 250kbps"
        case .canISO15765_29bit250k: return "CAN 29-bit 250kbps"
        case .canSAEJ1939: return "SAE J1939 CAN"
        }
    }
}

// MARK: - OBD Connection Manager
@MainActor
public class OBDConnection: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public private(set) var connectedDevice: String?
    @Published public private(set) var currentProtocol: OBDProtocol = .auto
    @Published public private(set) var voltage: Double = 0.0

    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?

    private var responseBuffer = ""
    private var responseContinuation: CheckedContinuation<String, Error>?

    private let elmServiceUUID = CBUUID(string: "FFF0")
    private let elmWriteUUID = CBUUID(string: "FFF2")
    private let elmReadUUID = CBUUID(string: "FFF1")

    public weak var delegate: OBDConnectionDelegate?

    // MARK: - Singleton
    public static let shared = OBDConnection()

    private override init() {
        super.init()
    }

    // MARK: - Public Methods
    public func startScanning() {
        state = .scanning
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public func stopScanning() {
        centralManager?.stopScan()
        state = .disconnected
    }

    public func connect(to peripheral: CBPeripheral) {
        state = .connecting
        connectedPeripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        resetConnection()
    }

    // MARK: - OBD Commands
    public func sendCommand(_ command: String) async throws -> String {
        guard state == .ready else {
            throw OBDError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.responseContinuation = continuation
            self.responseBuffer = ""

            let cmdWithReturn = command + "\r"
            if let data = cmdWithReturn.data(using: .utf8),
               let characteristic = writeCharacteristic {
                connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            }

            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.responseContinuation != nil {
                    self.responseContinuation?.resume(throwing: OBDError.timeout)
                    self.responseContinuation = nil
                }
            }
        }
    }

    public func initializeAdapter() async throws {
        // Reset adapter
        _ = try await sendCommand("ATZ")
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Disable echo
        _ = try await sendCommand("ATE0")

        // Disable line feeds
        _ = try await sendCommand("ATL0")

        // Disable spaces
        _ = try await sendCommand("ATS0")

        // Set protocol to auto
        _ = try await sendCommand("ATSP0")

        // Set timeout
        _ = try await sendCommand("ATSTFF")

        // Enable headers for VAG specific commands
        _ = try await sendCommand("ATH1")

        // Read voltage
        let voltageResponse = try await sendCommand("ATRV")
        if let volts = Double(voltageResponse.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces)) {
            voltage = volts
        }

        state = .ready
    }

    public func readPID(mode: UInt8, pid: UInt8) async throws -> [UInt8] {
        let command = String(format: "%02X%02X", mode, pid)
        let response = try await sendCommand(command)
        return parseResponse(response)
    }

    public func readExtendedPID(pid: UInt16) async throws -> [UInt8] {
        // VAG specific extended PID read (mode 22)
        let command = String(format: "22%04X", pid)
        let response = try await sendCommand(command)
        return parseResponse(response)
    }

    // MARK: - Private Methods
    private func parseResponse(_ response: String) -> [UInt8] {
        let cleaned = response
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")

        var bytes: [UInt8] = []
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
            let byteString = String(cleaned[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }

        return bytes
    }

    private func resetConnection() {
        state = .disconnected
        connectedDevice = nil
        connectedPeripheral = nil
        writeCharacteristic = nil
        readCharacteristic = nil
        responseBuffer = ""
    }
}

// MARK: - CBCentralManagerDelegate
extension OBDConnection: CBCentralManagerDelegate {

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                central.scanForPeripherals(withServices: nil, options: nil)
            case .poweredOff:
                self.state = .disconnected
                self.delegate?.connectionDidFail(with: .bluetoothUnavailable)
            default:
                break
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Filter for OBD adapters (common names)
        let name = peripheral.name ?? ""
        let obdNames = ["OBD", "ELM", "Viecar", "Veepeak", "OBDII", "V-LINK", "IOS-Vlink"]

        if obdNames.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
            Task { @MainActor in
                central.stopScan()
                self.connect(to: peripheral)
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectedDevice = peripheral.name
            peripheral.delegate = self
            peripheral.discoverServices([self.elmServiceUUID])
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.resetConnection()
            self.delegate?.connectionDidDisconnect()
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.state = .disconnected
            self.delegate?.connectionDidFail(with: .deviceNotFound)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension OBDConnection: CBPeripheralDelegate {

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics([elmWriteUUID, elmReadUUID], for: service)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        Task { @MainActor in
            for characteristic in characteristics {
                if characteristic.uuid == self.elmWriteUUID {
                    self.writeCharacteristic = characteristic
                } else if characteristic.uuid == self.elmReadUUID {
                    self.readCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }

            if self.writeCharacteristic != nil && self.readCharacteristic != nil {
                self.state = .connected
                self.delegate?.connectionDidConnect()

                // Initialize adapter
                try? await self.initializeAdapter()
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let response = String(data: data, encoding: .utf8) else { return }

        Task { @MainActor in
            self.responseBuffer += response

            if self.responseBuffer.contains(">") {
                let finalResponse = self.responseBuffer
                self.responseBuffer = ""
                self.responseContinuation?.resume(returning: finalResponse)
                self.responseContinuation = nil
                self.delegate?.connectionDidReceiveData(finalResponse)
            }
        }
    }
}
