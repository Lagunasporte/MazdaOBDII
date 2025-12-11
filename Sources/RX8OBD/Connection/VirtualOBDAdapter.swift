import Foundation
import Combine

// MARK: - Virtual OBD Adapter for Demo Mode
// Simulates a real RX-8 driving on a conventional road

public class VirtualOBDAdapter: ObservableObject {

    public static let shared = VirtualOBDAdapter()

    // MARK: - Published State
    @Published public var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "simulatorModeEnabled")
            if isEnabled && isRunning {
                // Already running, do nothing
            } else if !isEnabled && isRunning {
                stopSimulation()
            }
        }
    }
    @Published public var isRunning: Bool = false
    @Published public var drivingMode: DrivingMode = .cruising

    // MARK: - Simulated Engine State
    @Published public private(set) var rpm: Int = 0
    @Published public private(set) var speed: Double = 0
    @Published public private(set) var coolantTemp: Double = 20
    @Published public private(set) var oilTemp: Double = 20
    @Published public private(set) var intakeTemp: Double = 25
    @Published public private(set) var throttlePosition: Double = 0
    @Published public private(set) var engineLoad: Double = 0
    @Published public private(set) var batteryVoltage: Double = 12.6
    @Published public private(set) var fuelLevel: Double = 75
    @Published public private(set) var mafAirFlow: Double = 0
    @Published public private(set) var shortTermFuelTrim: Double = 0
    @Published public private(set) var longTermFuelTrim: Double = 2.5
    @Published public private(set) var ignitionTiming: Double = 10
    @Published public private(set) var manifoldPressure: Double = 101
    @Published public private(set) var catalystTemp: Double = 200
    @Published public private(set) var o2Voltage: Double = 0.45

    // MARK: - Simulation Parameters
    private var simulationTimer: Timer?
    private var warmupProgress: Double = 0 // 0-1, tiempo de calentamiento
    private var tripDistanceKm: Double = 0
    private var tripFuelUsed: Double = 0
    private var lastUpdateTime: Date = Date()

    // Driving behavior parameters
    private var targetSpeed: Double = 0
    private var targetRPM: Int = 800
    private var accelerating: Bool = false
    private var braking: Bool = false
    private var drivingPhase: DrivingPhase = .warmup
    private var phaseTimer: Double = 0
    private var randomEventTimer: Double = 0

    // MARK: - Virtual Device Info
    public let virtualDeviceID = UUID(uuidString: "00000000-DE00-0A08-0000-000000000000")!
    public let virtualDeviceName = "RX-8 Simulator"

    // MARK: - Initialization

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "simulatorModeEnabled")
    }

    // MARK: - Driving Modes

    public enum DrivingMode: String, CaseIterable {
        case warmup = "Calentamiento"
        case city = "Ciudad"
        case highway = "Autopista"
        case cruising = "Carretera"
        case spirited = "Deportivo"
        case idle = "Ralentí"

        var description: String {
            switch self {
            case .warmup: return "Motor calentándose"
            case .city: return "Tráfico urbano"
            case .highway: return "Autopista a velocidad constante"
            case .cruising: return "Carretera convencional"
            case .spirited: return "Conducción deportiva"
            case .idle: return "Motor en ralentí"
            }
        }
    }

    private enum DrivingPhase {
        case warmup
        case accelerating
        case cruising
        case decelerating
        case stopped
        case cornering
    }

    // MARK: - Simulation Control

    public func startSimulation() {
        guard !isRunning else { return }

        isRunning = true
        warmupProgress = 0
        tripDistanceKm = 0
        tripFuelUsed = 0
        lastUpdateTime = Date()
        phaseTimer = 0
        randomEventTimer = 0

        // Initial state - engine just started
        rpm = 1200 // Cold start high idle
        speed = 0
        coolantTemp = 20
        oilTemp = 20
        intakeTemp = 25
        batteryVoltage = 14.2
        fuelLevel = 75 // 75% tank
        throttlePosition = 0
        engineLoad = 15
        drivingPhase = .warmup

        // Start simulation timer at 10Hz (100ms)
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
    }

    public func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isRunning = false

        // Reset to off state
        rpm = 0
        speed = 0
        throttlePosition = 0
        engineLoad = 0
        batteryVoltage = 12.4
    }

    public func setDrivingMode(_ mode: DrivingMode) {
        drivingMode = mode

        switch mode {
        case .idle:
            targetSpeed = 0
            targetRPM = 800
        case .warmup:
            targetSpeed = 0
            targetRPM = 1100
        case .city:
            targetSpeed = Double.random(in: 30...60)
            targetRPM = Int.random(in: 2000...4000)
        case .cruising:
            targetSpeed = Double.random(in: 80...100)
            targetRPM = Int.random(in: 3000...4500)
        case .highway:
            targetSpeed = Double.random(in: 110...130)
            targetRPM = Int.random(in: 3500...5000)
        case .spirited:
            targetSpeed = Double.random(in: 60...120)
            targetRPM = Int.random(in: 5000...8000)
        }
    }

    // MARK: - Simulation Engine

    private func updateSimulation() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        // Update timers
        phaseTimer += deltaTime
        randomEventTimer += deltaTime

        // Update warmup progress (takes ~5 minutes to fully warm up)
        if warmupProgress < 1.0 {
            warmupProgress += deltaTime / 300.0 // 5 minutes
            warmupProgress = min(warmupProgress, 1.0)
        }

        // Random driving events
        if randomEventTimer > Double.random(in: 5...15) {
            randomEventTimer = 0
            triggerRandomEvent()
        }

        // Update based on driving mode
        updateDrivingBehavior(deltaTime: deltaTime)

        // Update temperatures
        updateTemperatures(deltaTime: deltaTime)

        // Update fuel consumption
        updateFuelConsumption(deltaTime: deltaTime)

        // Update other sensors
        updateSensors(deltaTime: deltaTime)

        // Update trip data
        tripDistanceKm += (speed / 3600.0) * deltaTime // km traveled
    }

    private func triggerRandomEvent() {
        guard drivingMode != .idle && drivingMode != .warmup else { return }

        let event = Int.random(in: 0...10)

        switch event {
        case 0...3:
            // Speed change
            drivingPhase = Bool.random() ? .accelerating : .decelerating
            phaseTimer = 0
        case 4...5:
            // Corner/curve
            drivingPhase = .cornering
            phaseTimer = 0
        case 6...7:
            // Brief stop (traffic light)
            if drivingMode == .city {
                drivingPhase = .stopped
                phaseTimer = 0
            }
        default:
            // Continue cruising
            drivingPhase = .cruising
        }
    }

    private func updateDrivingBehavior(deltaTime: Double) {
        // Phase transitions
        if phaseTimer > Double.random(in: 3...10) {
            phaseTimer = 0

            switch drivingPhase {
            case .stopped:
                drivingPhase = .accelerating
            case .accelerating:
                drivingPhase = .cruising
            case .decelerating:
                drivingPhase = speed < 5 ? .stopped : .cruising
            case .cornering:
                drivingPhase = .accelerating
            case .cruising, .warmup:
                break // Keep cruising
            }
        }

        // Update speed and RPM based on phase
        switch drivingPhase {
        case .warmup:
            // Gradual warmup
            targetSpeed = 0
            rpm = Int(1200 - (400 * warmupProgress)) // Drop from 1200 to 800
            speed = 0
            throttlePosition = 0

            // Exit warmup when engine is warm enough
            if warmupProgress > 0.3 {
                drivingPhase = .accelerating
                setDrivingMode(drivingMode)
            }

        case .accelerating:
            // Accelerate towards target
            let accelRate = drivingMode == .spirited ? 15.0 : 8.0
            speed = min(targetSpeed, speed + accelRate * deltaTime)

            // RPM follows speed with throttle input
            let baseRPM = calculateRPMFromSpeed(speed)
            rpm = min(8500, baseRPM + Int.random(in: 200...800))
            throttlePosition = min(100, 30 + (speed / targetSpeed) * 50 + Double.random(in: -5...10))
            engineLoad = min(85, 20 + throttlePosition * 0.6)

        case .cruising:
            // Maintain speed with small variations
            speed = targetSpeed + Double.random(in: -2...2)
            speed = max(0, speed)

            rpm = calculateRPMFromSpeed(speed) + Int.random(in: -100...100)
            throttlePosition = 15 + (speed / 130) * 20 + Double.random(in: -3...3)
            engineLoad = 20 + (speed / 130) * 30

        case .decelerating:
            // Coast down
            let decelRate = drivingMode == .city ? 10.0 : 5.0
            speed = max(0, speed - decelRate * deltaTime)

            rpm = max(800, calculateRPMFromSpeed(speed) - 200)
            throttlePosition = max(0, throttlePosition - 20 * deltaTime)
            engineLoad = max(10, engineLoad - 15 * deltaTime)

        case .stopped:
            speed = 0
            rpm = Int.random(in: 750...850) // Idle variation
            throttlePosition = 0
            engineLoad = Double.random(in: 12...18)

        case .cornering:
            // Slight speed reduction in corners
            speed = max(20, speed - 5 * deltaTime)
            rpm = calculateRPMFromSpeed(speed) + Int.random(in: 0...300)
            throttlePosition = 10 + Double.random(in: -5...10)
            engineLoad = 25 + Double.random(in: -5...10)
        }

        // Clamp values
        rpm = max(0, min(9000, rpm))
        speed = max(0, min(260, speed))
        throttlePosition = max(0, min(100, throttlePosition))
        engineLoad = max(0, min(100, engineLoad))
    }

    private func calculateRPMFromSpeed(_ speed: Double) -> Int {
        // RX-8 6-speed manual gear ratios approximation
        // Simulates being in appropriate gear

        if speed < 5 { return 800 }
        if speed < 20 { return Int(800 + speed * 100) } // 1st gear
        if speed < 40 { return Int(2000 + (speed - 20) * 75) } // 2nd gear
        if speed < 60 { return Int(3000 + (speed - 40) * 50) } // 3rd gear
        if speed < 90 { return Int(3500 + (speed - 60) * 40) } // 4th gear
        if speed < 120 { return Int(3500 + (speed - 90) * 35) } // 5th gear
        return Int(3800 + (speed - 120) * 30) // 6th gear
    }

    private func updateTemperatures(deltaTime: Double) {
        // Target temperatures based on driving
        let coolantTarget = 88.0 + (engineLoad / 100.0) * 10.0 // 88-98°C
        let oilTarget = 90.0 + (engineLoad / 100.0) * 20.0 // 90-110°C
        let intakeTarget = 25.0 + (rpm > 5000 ? 10.0 : 0) + (warmupProgress * 5) // 25-40°C

        // Warmup affects heating rate
        let heatingRate = warmupProgress < 0.5 ? 0.1 : 0.05
        let coolingRate = 0.02

        // Coolant temperature
        if coolantTemp < coolantTarget {
            coolantTemp += heatingRate * deltaTime * 10
        } else {
            coolantTemp -= coolingRate * deltaTime * 10
        }
        coolantTemp = max(20, min(110, coolantTemp))
        coolantTemp += Double.random(in: -0.3...0.3) // Sensor noise

        // Oil temperature (lags behind coolant)
        if oilTemp < oilTarget {
            oilTemp += (heatingRate * 0.7) * deltaTime * 10
        } else {
            oilTemp -= (coolingRate * 0.5) * deltaTime * 10
        }
        oilTemp = max(20, min(130, oilTemp))
        oilTemp += Double.random(in: -0.5...0.5)

        // Intake temperature
        intakeTemp = intakeTarget + Double.random(in: -2...2)
        intakeTemp = max(10, min(60, intakeTemp))

        // Catalyst temperature (depends on exhaust flow)
        let catTarget = 300 + (engineLoad * 5) + (Double(rpm) * 0.05)
        if catalystTemp < catTarget {
            catalystTemp += deltaTime * 20
        } else {
            catalystTemp -= deltaTime * 10
        }
        catalystTemp = max(100, min(850, catalystTemp))
    }

    private func updateFuelConsumption(deltaTime: Double) {
        // RX-8 consumption: ~12-15 L/100km cruising, up to 25+ spirited
        var instantConsumption: Double // L/100km

        if speed < 5 {
            // Idle: ~1.5 L/h
            let idleLitersPerHour = 1.5
            let fuelUsed = (idleLitersPerHour / 3600.0) * deltaTime
            tripFuelUsed += fuelUsed
            fuelLevel -= (fuelUsed / 60.0) * 100 // 60L tank
        } else {
            // Calculate based on speed and load
            let baseConsumption = 12.0 // L/100km at cruise
            let loadFactor = 1 + (engineLoad / 100.0) * 0.8
            let speedFactor = 1 + max(0, (speed - 90) / 100) * 0.3
            instantConsumption = baseConsumption * loadFactor * speedFactor

            // High RPM penalty
            if rpm > 6000 {
                instantConsumption *= 1.3
            }

            // Calculate fuel used
            let distanceKm = (speed / 3600.0) * deltaTime
            let fuelUsed = (instantConsumption / 100.0) * distanceKm
            tripFuelUsed += fuelUsed
            fuelLevel -= (fuelUsed / 60.0) * 100 // 60L tank
        }

        // Clamp fuel level
        fuelLevel = max(0, min(100, fuelLevel))
    }

    private func updateSensors(deltaTime: Double) {
        // Battery voltage
        if rpm > 500 {
            // Alternator charging
            batteryVoltage = 13.8 + (Double(rpm) / 9000.0) * 0.6 + Double.random(in: -0.1...0.1)
        } else {
            batteryVoltage = 12.4 + Double.random(in: -0.1...0.1)
        }
        batteryVoltage = max(11.5, min(14.8, batteryVoltage))

        // MAF air flow (g/s)
        // RX-8: roughly 5-50 g/s depending on load
        mafAirFlow = 3 + (Double(rpm) / 1000.0) * 4 * (1 + engineLoad / 100.0)
        mafAirFlow += Double.random(in: -0.5...0.5)
        mafAirFlow = max(0, min(80, mafAirFlow))

        // Fuel trims
        // Slight variation around baseline
        shortTermFuelTrim = Double.random(in: -3...3)
        longTermFuelTrim = 2.5 + Double.random(in: -1...1) // Slightly rich is normal for rotary

        // Ignition timing
        // RX-8 typically 5-15° advance
        ignitionTiming = 8 + (Double(rpm) / 1000.0) * 1.5 - (engineLoad / 100.0) * 3
        ignitionTiming += Double.random(in: -0.5...0.5)
        ignitionTiming = max(-5, min(25, ignitionTiming))

        // Manifold pressure (kPa)
        // ~30-40 at idle, up to 95+ at WOT
        manifoldPressure = 35 + (throttlePosition / 100.0) * 65
        manifoldPressure += Double.random(in: -2...2)
        manifoldPressure = max(20, min(105, manifoldPressure))

        // O2 sensor voltage (oscillates around 0.45V in closed loop)
        if warmupProgress > 0.3 {
            o2Voltage = 0.45 + sin(Date().timeIntervalSince1970 * 2) * 0.35
            o2Voltage += Double.random(in: -0.05...0.05)
        } else {
            o2Voltage = 0.1 // Cold, not switching
        }
        o2Voltage = max(0, min(1, o2Voltage))
    }

    // MARK: - Get Current State as RotaryEngineState

    public func getCurrentState() -> RotaryEngineState {
        var state = RotaryEngineState()

        state.rpm = rpm
        state.vehicleSpeed = speed
        state.coolantTemperature = coolantTemp
        state.oilTemperature = oilTemp
        state.intakeAirTemperature = intakeTemp
        state.throttlePosition = throttlePosition
        state.engineLoad = engineLoad
        state.batteryVoltage = batteryVoltage
        state.fuelLevel = fuelLevel
        state.mafAirFlow = mafAirFlow
        state.shortTermFuelTrim = shortTermFuelTrim
        state.longTermFuelTrim = longTermFuelTrim
        state.ignitionTiming = ignitionTiming
        state.manifoldPressure = manifoldPressure
        state.catalystTemperature = catalystTemp
        state.o2SensorBank1Sensor1 = o2Voltage
        state.o2SensorBank1Sensor2 = o2Voltage * 0.8

        return state
    }

    // MARK: - OBD Command Simulation

    public func simulateCommand(_ command: String) -> String {
        let cmd = command.uppercased().trimmingCharacters(in: .whitespaces)

        // AT commands (adapter commands)
        if cmd.hasPrefix("AT") {
            return simulateATCommand(cmd)
        }

        // Mode 01 - Current Data
        if cmd.hasPrefix("01") {
            return simulateMode01(cmd)
        }

        // Mode 03 - DTCs
        if cmd == "03" {
            return "43 00" // No DTCs
        }

        // Mode 07 - Pending DTCs
        if cmd == "07" {
            return "47 00" // No pending DTCs
        }

        // Mode 09 - Vehicle Info
        if cmd.hasPrefix("09") {
            return simulateMode09(cmd)
        }

        // Mode 22 - Enhanced data
        if cmd.hasPrefix("22") {
            return simulateMode22(cmd)
        }

        return "NO DATA"
    }

    private func simulateATCommand(_ cmd: String) -> String {
        switch cmd {
        case "ATZ":
            return "ELM327 v2.1 [SIMULATOR]"
        case "ATI":
            return "ELM327 v2.1"
        case "ATE0", "ATE1", "ATL0", "ATL1", "ATH0", "ATH1", "ATS0", "ATS1":
            return "OK"
        case "ATSP0", "ATSP6", "ATTP6":
            return "OK"
        case "ATDPN":
            return "6" // CAN 500kbps
        case "ATRV":
            return String(format: "%.1fV", batteryVoltage)
        case "ATWS":
            return "ELM327 v2.1"
        default:
            if cmd.hasPrefix("ATST") || cmd.hasPrefix("ATAT") || cmd.hasPrefix("ATCAF") {
                return "OK"
            }
            return "OK"
        }
    }

    private func simulateMode01(_ cmd: String) -> String {
        guard cmd.count >= 4 else { return "NO DATA" }

        let pidStr = String(cmd.suffix(2))
        guard let pid = UInt8(pidStr, radix: 16) else { return "NO DATA" }

        switch pid {
        case 0x00: // PIDs supported 01-20
            return "41 00 BF 9F E8 91"
        case 0x04: // Engine load
            let value = UInt8(engineLoad * 2.55)
            return String(format: "41 04 %02X", value)
        case 0x05: // Coolant temp
            let value = UInt8(coolantTemp + 40)
            return String(format: "41 05 %02X", value)
        case 0x06: // STFT Bank 1
            let value = UInt8((shortTermFuelTrim + 100) * 1.28)
            return String(format: "41 06 %02X", value)
        case 0x07: // LTFT Bank 1
            let value = UInt8((longTermFuelTrim + 100) * 1.28)
            return String(format: "41 07 %02X", value)
        case 0x0C: // RPM
            let value = UInt16(rpm * 4)
            return String(format: "41 0C %02X %02X", value >> 8, value & 0xFF)
        case 0x0D: // Speed
            let value = UInt8(speed)
            return String(format: "41 0D %02X", value)
        case 0x0E: // Timing advance
            let value = UInt8((ignitionTiming + 64) * 2)
            return String(format: "41 0E %02X", value)
        case 0x0F: // Intake temp
            let value = UInt8(intakeTemp + 40)
            return String(format: "41 0F %02X", value)
        case 0x10: // MAF
            let value = UInt16(mafAirFlow * 100)
            return String(format: "41 10 %02X %02X", value >> 8, value & 0xFF)
        case 0x11: // Throttle position
            let value = UInt8(throttlePosition * 2.55)
            return String(format: "41 11 %02X", value)
        case 0x0B: // MAP
            let value = UInt8(manifoldPressure)
            return String(format: "41 0B %02X", value)
        case 0x2F: // Fuel level
            let value = UInt8(fuelLevel * 2.55)
            return String(format: "41 2F %02X", value)
        case 0x3C: // Catalyst temp B1S1
            let value = UInt16((catalystTemp + 40) * 10)
            return String(format: "41 3C %02X %02X", value >> 8, value & 0xFF)
        case 0x14: // O2 B1S1
            let mv = UInt8(o2Voltage * 200)
            return String(format: "41 14 %02X 80", mv)
        case 0x5C: // Oil temp
            let value = UInt8(oilTemp + 40)
            return String(format: "41 5C %02X", value)
        case 0x42: // Control module voltage
            let value = UInt16(batteryVoltage * 1000)
            return String(format: "41 42 %02X %02X", value >> 8, value & 0xFF)
        default:
            return "NO DATA"
        }
    }

    private func simulateMode09(_ cmd: String) -> String {
        guard cmd.count >= 4 else { return "NO DATA" }

        let pidStr = String(cmd.suffix(2))

        switch pidStr {
        case "02": // VIN
            // Simulated VIN: JM1FE173370DEMO01
            return "49 02 01 4A 4D 31 46 45 31 37 33 33 37 30 44 45 4D 4F 30 31"
        case "04": // Calibration ID
            return "49 04 01 52 58 38 44 45 4D 4F"
        default:
            return "NO DATA"
        }
    }

    private func simulateMode22(_ cmd: String) -> String {
        guard cmd.count >= 6 else { return "NO DATA" }

        // Oil temperature via Mazda Mode 22
        if cmd.contains("5C") || cmd.contains("1254") {
            let value = UInt8(oilTemp + 40)
            return String(format: "62 11 5C %02X", value)
        }

        return "NO DATA"
    }
}

// MARK: - UserDefaults Keys Extension

extension VirtualOBDAdapter {
    static let enabledKey = "simulatorModeEnabled"
}
