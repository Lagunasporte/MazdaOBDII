import Foundation
import Combine

// MARK: - Diagnostic Service
@MainActor
public class DiagnosticService: ObservableObject {

    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var isScanning = false
    @Published public var activeDTCs: [VAGDTCCode] = []
    @Published public var pendingDTCs: [VAGDTCCode] = []
    @Published public var storedDTCs: [VAGDTCCode] = []
    @Published public var vehicleInfo: VAGVehicleInfo?
    @Published public var ecuInfo: [ECUInfo] = []
    @Published public var lastScanDate: Date?
    @Published public var errorMessage: String?

    // MARK: - Private Properties
    private let connection: OBDConnection
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton
    public static let shared = DiagnosticService()

    private init() {
        self.connection = OBDConnection.shared

        // Observe connection state
        connection.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isConnected = state == .ready
            }
            .store(in: &cancellables)
    }

    // MARK: - Connection Methods
    public func connect() async throws {
        connection.startScanning()

        // Wait for connection
        for _ in 0..<30 {  // 30 second timeout
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if connection.state == .ready {
                return
            }
        }

        throw OBDError.timeout
    }

    public func disconnect() {
        connection.disconnect()
    }

    // MARK: - DTC Methods
    public func readAllDTCs() async throws {
        isScanning = true
        errorMessage = nil

        defer { isScanning = false }

        // Read active DTCs (Mode 03)
        let activeResponse = try await connection.sendCommand("03")
        activeDTCs = DTCParser.parseDTCResponse(activeResponse)

        // Read pending DTCs (Mode 07)
        let pendingResponse = try await connection.sendCommand("07")
        pendingDTCs = DTCParser.parseDTCResponse(pendingResponse)

        // Read stored/permanent DTCs (Mode 0A)
        let storedResponse = try await connection.sendCommand("0A")
        storedDTCs = DTCParser.parseDTCResponse(storedResponse)

        lastScanDate = Date()
    }

    public func clearDTCs() async throws {
        isScanning = true
        errorMessage = nil

        defer { isScanning = false }

        // Mode 04 - Clear DTCs
        let response = try await connection.sendCommand("04")

        if response.contains("44") || response.contains("OK") {
            activeDTCs.removeAll()
            pendingDTCs.removeAll()
            // Note: Permanent DTCs (Mode 0A) cannot be cleared manually
        } else {
            throw OBDError.communicationError("No se pudieron borrar los códigos")
        }
    }

    public func readFreezeFrame(dtc: VAGDTCCode) async throws -> FreezeFrameData? {
        // Mode 02 - Freeze Frame Data
        let response = try await connection.sendCommand("0200")  // Frame 0

        guard !response.contains("NO DATA") else { return nil }

        return FreezeFrameData(
            dtc: dtc,
            timestamp: Date(),
            rpm: 0,  // Parse from response
            speed: 0,
            coolantTemp: 0,
            engineLoad: 0,
            fuelTrim: 0
        )
    }

    // MARK: - Vehicle Info Methods
    public func readVIN() async throws -> String {
        // Mode 09 PID 02 - VIN
        let response = try await connection.sendCommand("0902")

        // Parse VIN from response
        let cleaned = response
            .replacingOccurrences(of: "49 02 01 ", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")

        // Convert hex to ASCII
        var vin = ""
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            guard let endIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) else { break }
            let hexByte = String(cleaned[index..<endIndex])
            if let byte = UInt8(hexByte, radix: 16), byte >= 32, byte <= 126 {
                vin.append(Character(UnicodeScalar(byte)))
            }
            index = endIndex
        }

        return vin
    }

    public func readECUInfo() async throws -> [ECUInfo] {
        var ecus: [ECUInfo] = []

        // Mode 09 PID 0A - ECU Name
        let ecuNameResponse = try await connection.sendCommand("090A")

        // Mode 09 PID 04 - Calibration ID
        let calIdResponse = try await connection.sendCommand("0904")

        // Mode 09 PID 06 - CVN
        let cvnResponse = try await connection.sendCommand("0906")

        // Parse and create ECU info
        let ecu = ECUInfo(
            name: "Engine Control Module",
            address: "01",
            softwareVersion: parseECUResponse(ecuNameResponse),
            calibrationId: parseECUResponse(calIdResponse),
            cvn: parseECUResponse(cvnResponse)
        )
        ecus.append(ecu)

        self.ecuInfo = ecus
        return ecus
    }

    private func parseECUResponse(_ response: String) -> String {
        let cleaned = response
            .replacingOccurrences(of: "49", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ">", with: "")

        // Skip first 4 chars (mode and pid response)
        guard cleaned.count > 4 else { return "Unknown" }

        let dataStart = cleaned.index(cleaned.startIndex, offsetBy: 4)
        let hexData = String(cleaned[dataStart...])

        // Convert hex to ASCII
        var result = ""
        var index = hexData.startIndex

        while index < hexData.endIndex {
            guard let endIndex = hexData.index(index, offsetBy: 2, limitedBy: hexData.endIndex) else { break }
            let hexByte = String(hexData[index..<endIndex])
            if let byte = UInt8(hexByte, radix: 16), byte >= 32, byte <= 126 {
                result.append(Character(UnicodeScalar(byte)))
            }
            index = endIndex
        }

        return result.isEmpty ? "Unknown" : result
    }

    // MARK: - Live Data Methods
    public func startLiveData(pids: [UInt8], interval: TimeInterval = 0.5) -> AsyncStream<[UInt8: Double]> {
        AsyncStream { continuation in
            Task {
                while isConnected {
                    var values: [UInt8: Double] = [:]

                    for pid in pids {
                        do {
                            let data = try await connection.readPID(mode: 0x01, pid: pid)

                            if let definition = VAGPIDs.standardPIDs[pid],
                               let value = definition.formula(Array(data.dropFirst(2))) {
                                values[pid] = value
                            }
                        } catch {
                            // Continue with next PID
                        }
                    }

                    continuation.yield(values)

                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - VAG Specific Methods
    public func readAdaptationValue(channel: Int) async throws -> Double {
        // VAG adaptation read (requires specific protocol)
        let command = String(format: "22F%03X", channel)
        let response = try await connection.sendCommand(command)

        guard !response.contains("NO DATA") else {
            throw OBDError.invalidResponse
        }

        // Parse response
        let bytes = parseHexResponse(response)
        guard bytes.count >= 2 else {
            throw OBDError.invalidResponse
        }

        return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
    }

    public func resetServiceInterval() async throws {
        // This requires VAG-specific UDS commands
        // Service reset is typically done through Mode 0x2F or proprietary VAG commands

        // Example for oil service reset (varies by model)
        let response = try await connection.sendCommand("2F010203")

        if response.contains("7F") {
            throw OBDError.communicationError("Service reset no soportado o requiere autorización")
        }
    }

    private func parseHexResponse(_ response: String) -> [UInt8] {
        let cleaned = response
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")

        var bytes: [UInt8] = []
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            guard let endIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) else { break }
            if let byte = UInt8(String(cleaned[index..<endIndex]), radix: 16) {
                bytes.append(byte)
            }
            index = endIndex
        }

        return bytes
    }
}

// MARK: - ECU Info
public struct ECUInfo: Identifiable {
    public let id = UUID()
    public let name: String
    public let address: String
    public let softwareVersion: String
    public let calibrationId: String
    public let cvn: String
}

// MARK: - Freeze Frame Data
public struct FreezeFrameData: Identifiable {
    public let id = UUID()
    public let dtc: VAGDTCCode
    public let timestamp: Date
    public let rpm: Double
    public let speed: Double
    public let coolantTemp: Double
    public let engineLoad: Double
    public let fuelTrim: Double
}

// MARK: - Diagnostic Report
public struct DiagnosticReport: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let vin: String
    public let activeDTCCount: Int
    public let pendingDTCCount: Int
    public let storedDTCCount: Int
    public let dtcCodes: [String]
    public let mileage: Double?
    public let notes: String?

    public init(
        vin: String,
        activeDTCs: [VAGDTCCode],
        pendingDTCs: [VAGDTCCode],
        storedDTCs: [VAGDTCCode],
        mileage: Double? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = Date()
        self.vin = vin
        self.activeDTCCount = activeDTCs.count
        self.pendingDTCCount = pendingDTCs.count
        self.storedDTCCount = storedDTCs.count
        self.dtcCodes = activeDTCs.map { $0.code } + pendingDTCs.map { $0.code } + storedDTCs.map { $0.code }
        self.mileage = mileage
        self.notes = notes
    }

    public var summary: String {
        var parts: [String] = []
        if activeDTCCount > 0 { parts.append("\(activeDTCCount) activos") }
        if pendingDTCCount > 0 { parts.append("\(pendingDTCCount) pendientes") }
        if storedDTCCount > 0 { parts.append("\(storedDTCCount) almacenados") }
        return parts.isEmpty ? "Sin códigos" : parts.joined(separator: ", ")
    }
}
