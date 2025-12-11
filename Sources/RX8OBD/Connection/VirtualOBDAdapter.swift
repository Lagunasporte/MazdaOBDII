import Foundation
import Combine

// MARK: - Virtual OBD Adapter for Demo Mode
// Simulates a realistic 10-minute RX-8 trip that loops

public class VirtualOBDAdapter: ObservableObject {

    public static let shared = VirtualOBDAdapter()

    // MARK: - Published State
    @Published public var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "simulatorModeEnabled")
            if !isEnabled && isRunning {
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

    // MARK: - Trip Progress
    @Published public private(set) var tripElapsedTime: TimeInterval = 0
    @Published public private(set) var currentPhase: TripPhase = .engineStart
    public let tripDuration: TimeInterval = 600 // 10 minutes

    // MARK: - Simulation Parameters
    private var simulationTimer: Timer?
    private var lastUpdateTime: Date = Date()
    private var tripDistanceKm: Double = 0
    private var tripFuelUsed: Double = 0

    // Smooth transition parameters
    private var targetSpeed: Double = 0
    private var targetRPM: Int = 800

    // MARK: - Virtual Device Info
    public let virtualDeviceID = UUID(uuidString: "00000000-DE00-0A08-0000-000000000000")!
    public let virtualDeviceName = "RX-8 Simulator"

    // MARK: - Trip Phases (10 minute realistic journey)
    public enum TripPhase: String, CaseIterable {
        case engineStart = "Arranque"
        case warmupIdle = "Calentando"
        case neighborhoodStart = "Saliendo del barrio"
        case cityStreets = "Calles urbanas"
        case trafficLight1 = "Semáforo"
        case cityAcceleration = "Acelerando en ciudad"
        case enterHighway = "Entrando a carretera"
        case highwayCruise = "Crucero en carretera"
        case overtaking = "Adelantamiento"
        case highwayCruise2 = "Crucero estable"
        case exitHighway = "Saliendo de carretera"
        case cityReturn = "Regreso por ciudad"
        case trafficLight2 = "Semáforo final"
        case parking = "Aparcando"
        case engineOff = "Motor apagado"

        var duration: TimeInterval {
            switch self {
            case .engineStart: return 5
            case .warmupIdle: return 15
            case .neighborhoodStart: return 30
            case .cityStreets: return 45
            case .trafficLight1: return 20
            case .cityAcceleration: return 25
            case .enterHighway: return 35
            case .highwayCruise: return 120
            case .overtaking: return 20
            case .highwayCruise2: return 150
            case .exitHighway: return 30
            case .cityReturn: return 60
            case .trafficLight2: return 15
            case .parking: return 25
            case .engineOff: return 5
            }
        }

        var targetSpeed: Double {
            switch self {
            case .engineStart, .warmupIdle, .trafficLight1, .trafficLight2, .parking, .engineOff: return 0
            case .neighborhoodStart: return 30
            case .cityStreets: return 50
            case .cityAcceleration: return 60
            case .enterHighway: return 80
            case .highwayCruise: return 110
            case .overtaking: return 130
            case .highwayCruise2: return 115
            case .exitHighway: return 70
            case .cityReturn: return 45
            }
        }

        var description: String {
            switch self {
            case .engineStart: return "Arrancando motor..."
            case .warmupIdle: return "Calentando motor en ralentí"
            case .neighborhoodStart: return "Saliendo del garaje, calles residenciales"
            case .cityStreets: return "Conducción urbana normal"
            case .trafficLight1: return "Esperando en semáforo"
            case .cityAcceleration: return "Acelerando tras semáforo"
            case .enterHighway: return "Incorporándose a la carretera"
            case .highwayCruise: return "Crucero estable en carretera"
            case .overtaking: return "Adelantando vehículo lento"
            case .highwayCruise2: return "Continuando viaje"
            case .exitHighway: return "Tomando salida"
            case .cityReturn: return "Volviendo por ciudad"
            case .trafficLight2: return "Último semáforo"
            case .parking: return "Maniobrando para aparcar"
            case .engineOff: return "Apagando motor"
            }
        }
    }

    // MARK: - Driving Modes (for manual override)
    public enum DrivingMode: String, CaseIterable {
        case warmup = "Calentamiento"
        case city = "Ciudad"
        case highway = "Autopista"
        case cruising = "Carretera"
        case spirited = "Deportivo"
        case idle = "Ralentí"

        public var description: String {
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

    // MARK: - Initialization

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "simulatorModeEnabled")
    }

    // MARK: - Simulation Control

    public func startSimulation() {
        guard !isRunning else { return }

        isRunning = true
        tripElapsedTime = 0
        tripDistanceKm = 0
        tripFuelUsed = 0
        lastUpdateTime = Date()
        currentPhase = .engineStart

        // Initial cold engine state
        rpm = 0
        speed = 0
        coolantTemp = 22 + Double.random(in: -3...3) // Ambient temp
        oilTemp = 20 + Double.random(in: -2...2)
        intakeTemp = 24 + Double.random(in: -2...2)
        batteryVoltage = 12.4
        fuelLevel = 68 + Double.random(in: -5...10) // Random starting fuel
        throttlePosition = 0
        engineLoad = 0
        catalystTemp = 25

        // Start simulation timer at 5Hz (200ms) for realistic refresh
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
    }

    public func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isRunning = false

        rpm = 0
        speed = 0
        throttlePosition = 0
        engineLoad = 0
        batteryVoltage = 12.4
    }

    public func setDrivingMode(_ mode: DrivingMode) {
        drivingMode = mode
    }

    // MARK: - Main Simulation Loop

    private func updateSimulation() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        // Update trip time
        tripElapsedTime += deltaTime

        // Loop trip after 10 minutes
        if tripElapsedTime >= tripDuration {
            tripElapsedTime = 0
            currentPhase = .engineStart
            // Reset to cold start conditions
            coolantTemp = max(coolantTemp - 30, 25)
            oilTemp = max(oilTemp - 25, 22)
        }

        // Determine current phase based on elapsed time
        updateCurrentPhase()

        // Update vehicle state based on phase
        updateVehicleState(deltaTime: deltaTime)

        // Update temperatures (realistic heating/cooling)
        updateTemperatures(deltaTime: deltaTime)

        // Update fuel consumption
        updateFuelConsumption(deltaTime: deltaTime)

        // Update other sensors
        updateSensors()

        // Update trip distance
        tripDistanceKm += (speed / 3600.0) * deltaTime
    }

    private func updateCurrentPhase() {
        var accumulatedTime: TimeInterval = 0

        for phase in TripPhase.allCases {
            accumulatedTime += phase.duration
            if tripElapsedTime < accumulatedTime {
                currentPhase = phase
                return
            }
        }
        currentPhase = .engineOff
    }

    private func updateVehicleState(deltaTime: Double) {
        targetSpeed = currentPhase.targetSpeed

        // Add some realistic variation
        let speedVariation = Double.random(in: -2...2)
        let adjustedTargetSpeed = max(0, targetSpeed + speedVariation)

        // Smooth speed transitions
        let accelerationRate: Double
        let decelerationRate: Double

        switch currentPhase {
        case .engineStart:
            rpm = 0
            speed = 0
            throttlePosition = 0
            engineLoad = 0
            batteryVoltage = 12.4
            return

        case .warmupIdle:
            // Cold start high idle, gradually decreasing
            let warmupProgress = min(tripElapsedTime / 20.0, 1.0)
            rpm = Int(1400 - (500 * warmupProgress)) + Int.random(in: -30...30)
            speed = 0
            throttlePosition = 0
            engineLoad = Double.random(in: 12...18)
            return

        case .trafficLight1, .trafficLight2:
            accelerationRate = 0
            decelerationRate = 8.0
            rpm = Int.random(in: 750...850)
            throttlePosition = 0
            engineLoad = Double.random(in: 12...18)

        case .neighborhoodStart, .parking:
            accelerationRate = 4.0
            decelerationRate = 5.0

        case .cityStreets, .cityReturn:
            accelerationRate = 6.0
            decelerationRate = 6.0

        case .cityAcceleration:
            accelerationRate = 10.0
            decelerationRate = 4.0

        case .enterHighway:
            accelerationRate = 12.0
            decelerationRate = 3.0

        case .highwayCruise, .highwayCruise2:
            accelerationRate = 3.0
            decelerationRate = 3.0

        case .overtaking:
            accelerationRate = 15.0
            decelerationRate = 2.0

        case .exitHighway:
            accelerationRate = 2.0
            decelerationRate = 8.0

        case .engineOff:
            rpm = max(0, rpm - 200)
            speed = max(0, speed - 5 * deltaTime)
            if rpm < 100 {
                rpm = 0
                speed = 0
                throttlePosition = 0
                engineLoad = 0
            }
            return
        }

        // Update speed smoothly
        if speed < adjustedTargetSpeed {
            speed = min(adjustedTargetSpeed, speed + accelerationRate * deltaTime)
        } else if speed > adjustedTargetSpeed {
            speed = max(adjustedTargetSpeed, speed - decelerationRate * deltaTime)
        }

        // Calculate RPM based on speed and gear
        rpm = calculateRPM(speed: speed, accelerating: speed < adjustedTargetSpeed)

        // Calculate throttle and load
        if speed > 0 {
            let speedRatio = speed / max(adjustedTargetSpeed, 1)
            throttlePosition = min(100, 15 + speedRatio * 40 + (speed < adjustedTargetSpeed ? 25 : 0))
            throttlePosition += Double.random(in: -3...3)
            throttlePosition = max(0, min(100, throttlePosition))

            engineLoad = 15 + (speed / 130) * 45 + (throttlePosition / 100) * 20
            engineLoad += Double.random(in: -2...2)
            engineLoad = max(10, min(85, engineLoad))
        }
    }

    private func calculateRPM(speed: Double, accelerating: Bool) -> Int {
        // RX-8 6-speed gear simulation
        var baseRPM: Int

        if speed < 1 {
            return Int.random(in: 750...850) // Idle
        } else if speed < 15 {
            // 1st gear
            baseRPM = 1200 + Int(speed * 180)
        } else if speed < 35 {
            // 2nd gear
            baseRPM = 2000 + Int((speed - 15) * 100)
        } else if speed < 55 {
            // 3rd gear
            baseRPM = 2500 + Int((speed - 35) * 75)
        } else if speed < 80 {
            // 4th gear
            baseRPM = 2800 + Int((speed - 55) * 52)
        } else if speed < 110 {
            // 5th gear
            baseRPM = 3200 + Int((speed - 80) * 40)
        } else {
            // 6th gear
            baseRPM = 3500 + Int((speed - 110) * 35)
        }

        // Add acceleration boost
        if accelerating {
            baseRPM += Int.random(in: 200...600)
        }

        // Add natural variation
        baseRPM += Int.random(in: -50...50)

        return max(750, min(8500, baseRPM))
    }

    private func updateTemperatures(deltaTime: Double) {
        // Coolant temperature
        let coolantTarget: Double
        if rpm > 500 {
            // Engine running - target based on load
            coolantTarget = 85 + (engineLoad / 100) * 10 // 85-95°C normal
        } else {
            // Engine off - cool down
            coolantTarget = 25
        }

        // Realistic heating/cooling rates
        let coolantRate: Double
        if coolantTemp < 60 {
            coolantRate = 0.15 // Faster initial heating
        } else if coolantTemp < coolantTarget {
            coolantRate = 0.08 // Slower as approaching target
        } else {
            coolantRate = 0.03 // Very slow cooling with thermostat
        }

        if coolantTemp < coolantTarget {
            coolantTemp += coolantRate * deltaTime * 10
        } else {
            coolantTemp -= coolantRate * 0.5 * deltaTime * 10
        }
        coolantTemp = max(20, min(105, coolantTemp))
        coolantTemp += Double.random(in: -0.2...0.2)

        // Oil temperature (lags behind coolant by ~10-15°C initially, catches up)
        let oilTarget = coolantTemp + (rpm > 4000 ? 15 : 5)
        let oilRate = 0.06

        if oilTemp < oilTarget {
            oilTemp += oilRate * deltaTime * 10
        } else {
            oilTemp -= oilRate * 0.3 * deltaTime * 10
        }
        oilTemp = max(20, min(120, oilTemp))
        oilTemp += Double.random(in: -0.3...0.3)

        // Intake air temperature
        let intakeBase = 25.0
        let intakeHeat = (rpm > 0 ? 5.0 : 0) + (speed > 50 ? -3.0 : 0) // Ram air cooling
        intakeTemp = intakeBase + intakeHeat + Double.random(in: -1...1)
        intakeTemp = max(15, min(50, intakeTemp))

        // Catalyst temperature
        if rpm > 500 {
            let catTarget = 350 + (engineLoad * 4) + (Double(rpm) * 0.03)
            if catalystTemp < catTarget {
                catalystTemp += deltaTime * 25
            } else {
                catalystTemp -= deltaTime * 5
            }
        } else {
            catalystTemp -= deltaTime * 15
        }
        catalystTemp = max(25, min(800, catalystTemp))
    }

    private func updateFuelConsumption(deltaTime: Double) {
        guard rpm > 0 else { return }

        let instantConsumption: Double // L/100km equivalent

        if speed < 5 {
            // Idle consumption: ~1.5-2.0 L/h for RX-8
            let idleLitersPerHour = 1.8
            let fuelUsed = (idleLitersPerHour / 3600.0) * deltaTime
            tripFuelUsed += fuelUsed
            fuelLevel -= (fuelUsed / 60.0) * 100
        } else {
            // RX-8 realistic consumption based on driving style
            // City: 15-18 L/100km, Highway cruise: 10-12 L/100km, Spirited: 20-25 L/100km
            let baseConsumption: Double
            switch currentPhase {
            case .neighborhoodStart, .parking:
                baseConsumption = 16.0
            case .cityStreets, .cityReturn:
                baseConsumption = 15.0
            case .cityAcceleration:
                baseConsumption = 22.0
            case .enterHighway, .exitHighway:
                baseConsumption = 14.0
            case .highwayCruise, .highwayCruise2:
                baseConsumption = 11.0
            case .overtaking:
                baseConsumption = 25.0
            default:
                baseConsumption = 2.0 // Idle equivalent
            }

            // Adjust for RPM
            let rpmFactor = 1.0 + max(0, (Double(rpm) - 4000) / 5000) * 0.3
            instantConsumption = baseConsumption * rpmFactor

            let distanceKm = (speed / 3600.0) * deltaTime
            let fuelUsed = (instantConsumption / 100.0) * distanceKm
            tripFuelUsed += fuelUsed
            fuelLevel -= (fuelUsed / 60.0) * 100
        }

        fuelLevel = max(5, min(100, fuelLevel)) // Never go below 5%
    }

    private func updateSensors() {
        // Battery voltage
        if rpm > 500 {
            batteryVoltage = 13.8 + (Double(rpm) / 9000.0) * 0.6
            batteryVoltage += Double.random(in: -0.1...0.1)
        } else if rpm > 0 {
            batteryVoltage = 12.8 + Double.random(in: -0.2...0.2)
        } else {
            batteryVoltage = 12.4 + Double.random(in: -0.1...0.1)
        }
        batteryVoltage = max(11.8, min(14.6, batteryVoltage))

        // MAF air flow
        if rpm > 0 {
            mafAirFlow = 2.5 + (Double(rpm) / 1000.0) * 4.5 * (1 + engineLoad / 150.0)
            mafAirFlow += Double.random(in: -0.3...0.3)
            mafAirFlow = max(2, min(70, mafAirFlow))
        } else {
            mafAirFlow = 0
        }

        // Fuel trims - slightly positive is normal for rotary
        shortTermFuelTrim = Double.random(in: -2.5...2.5)
        longTermFuelTrim = 2.0 + Double.random(in: -0.5...0.5)

        // Ignition timing
        if rpm > 0 {
            ignitionTiming = 10 + (Double(rpm) / 1000.0) * 2.0 - (engineLoad / 100.0) * 4
            ignitionTiming += Double.random(in: -0.3...0.3)
            ignitionTiming = max(0, min(25, ignitionTiming))
        } else {
            ignitionTiming = 0
        }

        // Manifold pressure
        if rpm > 0 {
            manifoldPressure = 30 + (throttlePosition / 100.0) * 70
            manifoldPressure += Double.random(in: -1...1)
            manifoldPressure = max(25, min(102, manifoldPressure))
        } else {
            manifoldPressure = 101 // Atmospheric
        }

        // O2 sensor
        if rpm > 0 && coolantTemp > 60 {
            // Closed loop - oscillating
            o2Voltage = 0.45 + sin(Date().timeIntervalSince1970 * 3) * 0.35
            o2Voltage += Double.random(in: -0.03...0.03)
        } else if rpm > 0 {
            // Open loop - rich
            o2Voltage = 0.7 + Double.random(in: -0.1...0.1)
        } else {
            o2Voltage = 0.45
        }
        o2Voltage = max(0.1, min(0.9, o2Voltage))
    }

    // MARK: - Get Current State

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
        state.o2SensorBank1Sensor2 = o2Voltage * 0.85

        return state
    }

    // MARK: - OBD Command Simulation

    public func simulateCommand(_ command: String) -> String {
        let cmd = command.uppercased().trimmingCharacters(in: .whitespaces)

        if cmd.hasPrefix("AT") {
            return simulateATCommand(cmd)
        }

        if cmd.hasPrefix("01") {
            return simulateMode01(cmd)
        }

        if cmd == "03" {
            return "43 00"
        }

        if cmd == "07" {
            return "47 00"
        }

        if cmd.hasPrefix("09") {
            return simulateMode09(cmd)
        }

        if cmd.hasPrefix("22") {
            return simulateMode22(cmd)
        }

        return "NO DATA"
    }

    private func simulateATCommand(_ cmd: String) -> String {
        switch cmd {
        case "ATZ": return "ELM327 v2.1 [SIMULATOR]"
        case "ATI": return "ELM327 v2.1"
        case "ATE0", "ATE1", "ATL0", "ATL1", "ATH0", "ATH1", "ATS0", "ATS1": return "OK"
        case "ATSP0", "ATSP6", "ATTP6": return "OK"
        case "ATDPN": return "6"
        case "ATRV": return String(format: "%.1fV", batteryVoltage)
        case "ATWS": return "ELM327 v2.1"
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
        case 0x00: return "41 00 BF 9F E8 91"
        case 0x04:
            let value = UInt8(min(255, engineLoad * 2.55))
            return String(format: "41 04 %02X", value)
        case 0x05:
            let value = UInt8(min(255, coolantTemp + 40))
            return String(format: "41 05 %02X", value)
        case 0x06:
            let value = UInt8(min(255, (shortTermFuelTrim + 100) * 1.28))
            return String(format: "41 06 %02X", value)
        case 0x07:
            let value = UInt8(min(255, (longTermFuelTrim + 100) * 1.28))
            return String(format: "41 07 %02X", value)
        case 0x0C:
            let value = UInt16(min(65535, rpm * 4))
            return String(format: "41 0C %02X %02X", value >> 8, value & 0xFF)
        case 0x0D:
            let value = UInt8(min(255, speed))
            return String(format: "41 0D %02X", value)
        case 0x0E:
            let value = UInt8(min(255, (ignitionTiming + 64) * 2))
            return String(format: "41 0E %02X", value)
        case 0x0F:
            let value = UInt8(min(255, intakeTemp + 40))
            return String(format: "41 0F %02X", value)
        case 0x10:
            let value = UInt16(min(65535, mafAirFlow * 100))
            return String(format: "41 10 %02X %02X", value >> 8, value & 0xFF)
        case 0x11:
            let value = UInt8(min(255, throttlePosition * 2.55))
            return String(format: "41 11 %02X", value)
        case 0x0B:
            let value = UInt8(min(255, manifoldPressure))
            return String(format: "41 0B %02X", value)
        case 0x2F:
            let value = UInt8(min(255, fuelLevel * 2.55))
            return String(format: "41 2F %02X", value)
        case 0x3C:
            let value = UInt16(min(65535, (catalystTemp + 40) * 10))
            return String(format: "41 3C %02X %02X", value >> 8, value & 0xFF)
        case 0x14:
            let mv = UInt8(min(255, o2Voltage * 200))
            return String(format: "41 14 %02X 80", mv)
        case 0x5C:
            let value = UInt8(min(255, oilTemp + 40))
            return String(format: "41 5C %02X", value)
        case 0x42:
            let value = UInt16(min(65535, batteryVoltage * 1000))
            return String(format: "41 42 %02X %02X", value >> 8, value & 0xFF)
        default:
            return "NO DATA"
        }
    }

    private func simulateMode09(_ cmd: String) -> String {
        guard cmd.count >= 4 else { return "NO DATA" }
        let pidStr = String(cmd.suffix(2))

        switch pidStr {
        case "02": return "49 02 01 4A 4D 31 46 45 31 37 33 33 37 30 44 45 4D 4F 30 31"
        case "04": return "49 04 01 52 58 38 44 45 4D 4F"
        default: return "NO DATA"
        }
    }

    private func simulateMode22(_ cmd: String) -> String {
        guard cmd.count >= 6 else { return "NO DATA" }

        if cmd.contains("5C") || cmd.contains("1254") {
            let value = UInt8(min(255, oilTemp + 40))
            return String(format: "62 11 5C %02X", value)
        }

        return "NO DATA"
    }
}
