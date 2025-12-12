import Foundation
import Combine

/// Virtual OBD Adapter for development and testing
/// Simulates VAG vehicle responses
@MainActor
public class VirtualOBDAdapter: ObservableObject {

    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var rpm: Double = 850
    @Published public var speed: Double = 0
    @Published public var coolantTemp: Double = 85
    @Published public var oilTemp: Double = 90
    @Published public var intakeTemp: Double = 25
    @Published public var throttlePosition: Double = 0
    @Published public var boostPressure: Double = 0
    @Published public var fuelLevel: Double = 65
    @Published public var maf: Double = 3.5
    @Published public var voltage: Double = 12.6

    // MARK: - Simulation Properties
    private var simulationTimer: Timer?
    private var isEngineRunning = true

    // MARK: - Vehicle Configuration
    public var vehicleConfig: VAGVehicleConfig

    public struct VAGVehicleConfig {
        var brand: VAGOBD.Brand
        var engineType: EngineType
        var displacement: Double
        var hasTurbo: Bool
        var hasDSG: Bool

        public init(
            brand: VAGOBD.Brand = .volkswagen,
            engineType: EngineType = .tsi,
            displacement: Double = 2.0,
            hasTurbo: Bool = true,
            hasDSG: Bool = true
        ) {
            self.brand = brand
            self.engineType = engineType
            self.displacement = displacement
            self.hasTurbo = hasTurbo
            self.hasDSG = hasDSG
        }
    }

    public enum EngineType: String, CaseIterable {
        case tsi = "TSI"
        case tfsi = "TFSI"
        case tdi = "TDI"
        case fsi = "FSI"
        case mpi = "MPI"

        public var maxRPM: Double {
            switch self {
            case .tsi, .tfsi, .fsi: return 7000
            case .tdi: return 5000
            case .mpi: return 6500
            }
        }

        public var maxBoost: Double {
            switch self {
            case .tsi, .tfsi: return 1.5
            case .tdi: return 2.2
            case .fsi, .mpi: return 0
            }
        }
    }

    // MARK: - Singleton
    public static let shared = VirtualOBDAdapter()

    private init() {
        vehicleConfig = VAGVehicleConfig()
    }

    // MARK: - Connection Simulation
    public func connect() async {
        // Simulate connection delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        isConnected = true
        startSimulation()
    }

    public func disconnect() {
        stopSimulation()
        isConnected = false
    }

    // MARK: - Simulation
    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSimulatedValues()
            }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func updateSimulatedValues() {
        guard isEngineRunning else {
            rpm = 0
            return
        }

        // Simulate idle with slight variation
        let baseRPM = 850.0
        let rpmVariation = Double.random(in: -30...30)
        rpm = baseRPM + rpmVariation + (throttlePosition * 50)

        // Clamp RPM
        rpm = min(rpm, vehicleConfig.engineType.maxRPM)

        // Simulate temperatures warming up
        if coolantTemp < 90 {
            coolantTemp += 0.1
        } else {
            coolantTemp = 90 + Double.random(in: -2...2)
        }

        if oilTemp < 95 {
            oilTemp += 0.08
        } else {
            oilTemp = 95 + Double.random(in: -3...3)
        }

        // Boost pressure based on throttle and RPM
        if vehicleConfig.hasTurbo && throttlePosition > 30 && rpm > 2000 {
            let targetBoost = (throttlePosition / 100) * vehicleConfig.engineType.maxBoost
            boostPressure = boostPressure + (targetBoost - boostPressure) * 0.1
        } else {
            boostPressure = max(0, boostPressure - 0.05)
        }

        // MAF based on RPM and throttle
        maf = (rpm / 1000) * (1 + throttlePosition / 100) * 2.5

        // Voltage variation
        voltage = 12.6 + Double.random(in: -0.2...0.3)

        // Fuel consumption
        if fuelLevel > 0 {
            fuelLevel -= 0.0001 * (rpm / 1000)
        }
    }

    // MARK: - Command Simulation
    public func sendCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw OBDError.notConnected
        }

        // Simulate response delay
        try await Task.sleep(nanoseconds: 50_000_000)

        return simulateResponse(for: command)
    }

    private func simulateResponse(for command: String) -> String {
        let cmd = command.uppercased().trimmingCharacters(in: .whitespaces)

        // AT commands
        if cmd.hasPrefix("AT") {
            return simulateATCommand(cmd)
        }

        // OBD Mode 01 - Current Data
        if cmd.hasPrefix("01") {
            return simulateMode01(cmd)
        }

        // OBD Mode 03 - DTCs
        if cmd.hasPrefix("03") {
            return simulateMode03()
        }

        // OBD Mode 09 - Vehicle Info
        if cmd.hasPrefix("09") {
            return simulateMode09(cmd)
        }

        // VAG Mode 22 - Extended PIDs
        if cmd.hasPrefix("22") {
            return simulateMode22(cmd)
        }

        return "NO DATA>"
    }

    private func simulateATCommand(_ cmd: String) -> String {
        switch cmd {
        case "ATZ":
            return "ELM327 v1.5>"
        case "ATE0", "ATL0", "ATS0", "ATH1", "ATSP0", "ATSTFF":
            return "OK>"
        case "ATRV":
            return String(format: "%.1fV>", voltage)
        case "ATDPN":
            return "6>" // CAN 11-bit 500kbps
        default:
            return "OK>"
        }
    }

    private func simulateMode01(_ cmd: String) -> [UInt8] {
        let pidHex = String(cmd.dropFirst(2).prefix(2))
        guard let pid = UInt8(pidHex, radix: 16) else {
            return []
        }

        switch pid {
        case 0x05: // Coolant temp
            let value = UInt8(coolantTemp + 40)
            return [0x41, 0x05, value]
        case 0x0C: // RPM
            let rpmValue = UInt16(rpm * 4)
            return [0x41, 0x0C, UInt8(rpmValue >> 8), UInt8(rpmValue & 0xFF)]
        case 0x0D: // Speed
            return [0x41, 0x0D, UInt8(speed)]
        case 0x0F: // Intake temp
            let value = UInt8(intakeTemp + 40)
            return [0x41, 0x0F, value]
        case 0x10: // MAF
            let mafValue = UInt16(maf * 100)
            return [0x41, 0x10, UInt8(mafValue >> 8), UInt8(mafValue & 0xFF)]
        case 0x11: // Throttle position
            let value = UInt8(throttlePosition * 255 / 100)
            return [0x41, 0x11, value]
        case 0x2F: // Fuel level
            let value = UInt8(fuelLevel * 255 / 100)
            return [0x41, 0x2F, value]
        case 0x5C: // Oil temp
            let value = UInt8(oilTemp + 40)
            return [0x41, 0x5C, value]
        default:
            return []
        }
    }

    private func simulateMode01(_ cmd: String) -> String {
        let bytes = simulateMode01(cmd) as [UInt8]
        if bytes.isEmpty {
            return "NO DATA>"
        }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ") + ">"
    }

    private func simulateMode03() -> String {
        // Simulate some DTCs
        return "43 01 33 01 71 00 00>"  // P0133, P0171
    }

    private func simulateMode09(_ cmd: String) -> String {
        let pidHex = String(cmd.dropFirst(2).prefix(2))

        switch pidHex {
        case "02": // VIN
            // WVWZZZ3CZWE123456
            return "49 02 01 57 56 57 5A 5A 5A 33 43 5A 57 45 31 32 33 34 35 36>"
        default:
            return "NO DATA>"
        }
    }

    private func simulateMode22(_ cmd: String) -> String {
        let pidHex = String(cmd.dropFirst(2))
        guard let pid = UInt16(pidHex, radix: 16) else {
            return "NO DATA>"
        }

        switch pid {
        case 0x2203: // Boost pressure
            let value = UInt16(boostPressure * 1000)
            return String(format: "62 22 03 %02X %02X>", value >> 8, value & 0xFF)
        case 0x2033: // Oil pressure
            let oilPressure = rpm > 1000 ? 3.5 : 1.2
            let value = UInt16(oilPressure * 1000)
            return String(format: "62 20 33 %02X %02X>", value >> 8, value & 0xFF)
        default:
            return "NO DATA>"
        }
    }

    // MARK: - Test Scenarios
    public func simulateDriving() {
        Task {
            // Accelerate
            for i in 0..<50 {
                throttlePosition = Double(i * 2)
                speed = Double(i * 3)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            // Cruise
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Decelerate
            for i in (0..<50).reversed() {
                throttlePosition = Double(i)
                speed = Double(i * 3)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            throttlePosition = 0
            speed = 0
        }
    }

    public func simulateOverheating() {
        Task {
            for _ in 0..<100 {
                coolantTemp += 0.5
                oilTemp += 0.3
                try? await Task.sleep(nanoseconds: 500_000_000)

                if coolantTemp > 120 {
                    break
                }
            }
        }
    }

    public func resetToNormal() {
        coolantTemp = 85
        oilTemp = 90
        intakeTemp = 25
        throttlePosition = 0
        speed = 0
        rpm = 850
        boostPressure = 0
    }
}
