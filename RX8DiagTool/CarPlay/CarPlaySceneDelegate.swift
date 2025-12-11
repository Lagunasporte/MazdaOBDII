import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// Dashboard premium para Mazda RX-8 - Máximo aprovechamiento visual de CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var dashboard = RX8CarPlayDashboard()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        setupDataSubscription()
        interfaceController.setRootTemplate(createRootTemplate(), animated: true, completion: nil)
        startUpdates()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        stopUpdates()
        cancellables.removeAll()
    }

    private func setupDataSubscription() {
        CarPlayDataProvider.shared.$engineState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dashboard.update(from: $0) }
            .store(in: &cancellables)

        CarPlayDataProvider.shared.$fuelData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dashboard.updateFuel(from: $0) }
            .store(in: &cancellables)
    }

    // MARK: - Root Template

    private func createRootTemplate() -> CPTemplate {
        CPTabBarTemplate(templates: [
            createMainDashboard(),
            createEngineDashboard(),
            createFuelDashboard(),
            createStatusDashboard()
        ])
    }

    // MARK: - Tab 1: DASHBOARD PRINCIPAL
    // Los 6 datos más importantes para el RX-8

    private func createMainDashboard() -> CPGridTemplate {
        let template = CPGridTemplate(title: "RX-8 MONITOR", gridButtons: [
            // Fila 1: Motor
            gauge(
                icon: "gauge.with.needle.fill",
                value: dashboard.rpm,
                unit: "RPM",
                color: rpmColor,
                size: .large
            ),
            gauge(
                icon: "speedometer",
                value: Int(dashboard.speed),
                unit: "km/h",
                color: .systemBlue,
                size: .large
            ),
            gauge(
                icon: "thermometer.sun.fill",
                value: Int(dashboard.coolantTemp),
                unit: "°C",
                subtitle: "REFRIG",
                color: coolantColor,
                size: .large
            ),
            // Fila 2: Críticos
            gauge(
                icon: "drop.fill",
                value: dashboard.oilTemp > 50 ? Int(dashboard.oilTemp) : nil,
                unit: "°C",
                subtitle: "ACEITE",
                color: oilColor,
                size: .large
            ),
            gauge(
                icon: "bolt.batteryblock.fill",
                value: dashboard.batteryVoltage,
                decimals: 1,
                unit: "V",
                color: voltageColor,
                size: .large
            ),
            gauge(
                icon: "fuelpump.circle.fill",
                value: Int(dashboard.fuelLevel),
                unit: "%",
                subtitle: "FUEL",
                color: fuelColor,
                size: .large
            )
        ])

        template.tabTitle = "Dashboard"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.bottom.50percent.badge.plus")
        return template
    }

    // MARK: - Tab 2: MOTOR DETALLADO
    // Datos específicos del motor rotativo

    private func createEngineDashboard() -> CPGridTemplate {
        let template = CPGridTemplate(title: "MOTOR ROTATIVO", gridButtons: [
            // Fila 1: Temperaturas
            gauge(
                icon: "thermometer.high",
                value: Int(dashboard.coolantTemp),
                unit: "°C",
                subtitle: "COOLANT",
                color: coolantColor,
                size: .large
            ),
            gauge(
                icon: "drop.triangle.fill",
                value: dashboard.oilTemp > 50 ? Int(dashboard.oilTemp) : nil,
                unit: "°C",
                subtitle: "OIL",
                color: oilColor,
                size: .large
            ),
            gauge(
                icon: "wind",
                value: Int(dashboard.intakeTemp),
                unit: "°C",
                subtitle: "INTAKE",
                color: .systemCyan,
                size: .large
            ),
            // Fila 2: Fuel Trims (crítico para rotativo)
            gauge(
                icon: "arrow.up.arrow.down.circle.fill",
                value: dashboard.stft,
                decimals: 1,
                unit: "%",
                subtitle: "STFT",
                color: fuelTrimColor(dashboard.stft),
                showSign: true,
                size: .large
            ),
            gauge(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                value: dashboard.ltft,
                decimals: 1,
                unit: "%",
                subtitle: "LTFT",
                color: fuelTrimColor(dashboard.ltft),
                showSign: true,
                size: .large
            ),
            gauge(
                icon: "engine.combustion.fill",
                value: Int(dashboard.engineLoad),
                unit: "%",
                subtitle: "CARGA",
                color: loadColor,
                size: .large
            )
        ])

        template.tabTitle = "Motor"
        template.tabImage = UIImage(systemName: "engine.combustion.fill")
        return template
    }

    // MARK: - Tab 3: CONSUMO
    // Todo sobre combustible y autonomía

    private func createFuelDashboard() -> CPGridTemplate {
        let consumptionDisplay: String
        let consumptionUnit: String
        if dashboard.speed > 5 {
            consumptionDisplay = String(format: "%.1f", dashboard.consumption)
            consumptionUnit = "L/100"
        } else {
            consumptionDisplay = String(format: "%.1f", dashboard.consumptionPerHour)
            consumptionUnit = "L/h"
        }

        let template = CPGridTemplate(title: "CONSUMO", gridButtons: [
            // Fila 1: Consumo actual
            CPGridButton(
                titleVariants: ["\(consumptionDisplay)\n\(consumptionUnit)"],
                image: coloredIcon("fuelpump.fill", color: consumptionColor, size: 44)
            ) { _ in },

            gauge(
                icon: "chart.xyaxis.line",
                value: dashboard.avgConsumption,
                decimals: 1,
                unit: "L/100",
                subtitle: "MEDIA",
                color: .systemBlue,
                size: .large
            ),
            gauge(
                icon: "road.lanes.curved.right",
                value: Int(dashboard.range),
                unit: "km",
                subtitle: "AUTONOMÍA",
                color: rangeColor,
                size: .large
            ),
            // Fila 2: Depósito
            gauge(
                icon: "fuelpump.circle.fill",
                value: Int(dashboard.fuelLevel),
                unit: "%",
                subtitle: "NIVEL",
                color: fuelColor,
                size: .large
            ),
            gauge(
                icon: "drop.halffull",
                value: dashboard.fuelLiters,
                decimals: 1,
                unit: "L",
                subtitle: "QUEDAN",
                color: .systemTeal,
                size: .large
            ),
            gauge(
                icon: "bolt.fill",
                value: dashboard.batteryVoltage,
                decimals: 2,
                unit: "V",
                subtitle: "BATERÍA",
                color: voltageColor,
                size: .large
            )
        ])

        template.tabTitle = "Consumo"
        template.tabImage = UIImage(systemName: "fuelpump.fill")
        return template
    }

    // MARK: - Tab 4: ESTADO DEL SISTEMA
    // Resumen de salud del vehículo

    private func createStatusDashboard() -> CPGridTemplate {
        let hasAlerts = !dashboard.alerts.isEmpty

        let template = CPGridTemplate(title: hasAlerts ? "⚠ ALERTAS" : "✓ SISTEMA OK", gridButtons: [
            // Estado de cada sistema
            statusGauge(
                title: "MOTOR",
                icon: "engine.combustion.fill",
                ok: dashboard.coolantTemp < 100 && dashboard.oilTemp < 120
            ),
            statusGauge(
                title: "ELÉCTRICO",
                icon: "bolt.batteryblock.fill",
                ok: dashboard.batteryVoltage >= 12.0 || dashboard.batteryVoltage == 0
            ),
            statusGauge(
                title: "FUEL SYS",
                icon: "fuelpump.arrowtriangle.right.fill",
                ok: abs(dashboard.stft) < 15 && abs(dashboard.ltft) < 10
            ),
            statusGauge(
                title: "DEPÓSITO",
                icon: "fuelpump.circle.fill",
                ok: dashboard.fuelLevel > 15
            ),
            statusGauge(
                title: "RPM",
                icon: "gauge.with.needle.fill",
                ok: dashboard.rpm < 8000
            ),
            // Resumen general
            CPGridButton(
                titleVariants: [hasAlerts ? "\(dashboard.alerts.count) ALERTA\(dashboard.alerts.count > 1 ? "S" : "")" : "TODO OK"],
                image: coloredIcon(
                    hasAlerts ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
                    color: hasAlerts ? .systemOrange : .systemGreen,
                    size: 48
                )
            ) { _ in }
        ])

        template.tabTitle = hasAlerts ? "⚠ \(dashboard.alerts.count)" : "✓"
        template.tabImage = UIImage(systemName: hasAlerts ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        return template
    }

    // MARK: - Gauge Builders

    private func gauge(icon: String, value: Int?, unit: String, subtitle: String? = nil, color: UIColor, size: GridSize = .large) -> CPGridButton {
        let displayValue = value != nil ? "\(value!)" : "—"
        // Valor arriba, descripción abajo
        let description = subtitle != nil ? "\(unit) \(subtitle!)" : unit
        let title = "\(displayValue)\n\(description)"

        return CPGridButton(titleVariants: [title, displayValue], image: coloredIcon(icon, color: color, size: size == .large ? 40 : 32)) { _ in }
    }

    private func gauge(icon: String, value: Double, decimals: Int, unit: String, subtitle: String? = nil, color: UIColor, showSign: Bool = false, size: GridSize = .large) -> CPGridButton {
        let format = showSign ? "%+.\(decimals)f" : "%.\(decimals)f"
        let displayValue = String(format: format, value)
        // Valor arriba, descripción abajo
        let description = subtitle != nil ? "\(unit) \(subtitle!)" : unit
        let title = "\(displayValue)\n\(description)"

        return CPGridButton(titleVariants: [title, displayValue], image: coloredIcon(icon, color: color, size: size == .large ? 40 : 32)) { _ in }
    }

    private func statusGauge(title: String, icon: String, ok: Bool) -> CPGridButton {
        let status = ok ? "OK" : "CHECK"
        let color = ok ? UIColor.systemGreen : UIColor.systemOrange
        let displayIcon = ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        // Estado arriba, sistema abajo
        return CPGridButton(titleVariants: ["\(status)\n\(title)", status], image: coloredIcon(displayIcon, color: color, size: 40)) { _ in }
    }

    private enum GridSize { case large, small }

    private func coloredIcon(_ name: String, color: UIColor, size: CGFloat) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        let image = UIImage(systemName: name, withConfiguration: config) ?? UIImage(systemName: "circle.fill", withConfiguration: config)!
        return image.withTintColor(color, renderingMode: .alwaysOriginal)
    }

    // MARK: - Color Logic (RX-8 specific thresholds)

    private var rpmColor: UIColor {
        switch dashboard.rpm {
        case 8500...: return .systemRed
        case 7500..<8500: return .systemOrange
        case 6000..<7500: return .systemYellow
        default: return .systemGreen
        }
    }

    private var coolantColor: UIColor {
        switch dashboard.coolantTemp {
        case 105...: return .systemRed
        case 98..<105: return .systemOrange
        case 85..<98: return .systemGreen
        case 70..<85: return .systemTeal
        default: return .systemBlue
        }
    }

    private var oilColor: UIColor {
        guard dashboard.oilTemp > 50 else { return .systemGray }
        switch dashboard.oilTemp {
        case 130...: return .systemRed
        case 115..<130: return .systemOrange
        case 90..<115: return .systemGreen
        case 70..<90: return .systemTeal
        default: return .systemBlue
        }
    }

    private var voltageColor: UIColor {
        guard dashboard.batteryVoltage > 0 else { return .systemGray }
        switch dashboard.batteryVoltage {
        case ..<11.5: return .systemRed
        case 11.5..<12.2: return .systemOrange
        case 12.2..<14.8: return .systemGreen
        default: return .systemYellow
        }
    }

    private var fuelColor: UIColor {
        switch dashboard.fuelLevel {
        case ..<10: return .systemRed
        case 10..<20: return .systemOrange
        case 20..<30: return .systemYellow
        default: return .systemGreen
        }
    }

    private var rangeColor: UIColor {
        switch dashboard.range {
        case ..<30: return .systemRed
        case 30..<50: return .systemOrange
        case 50..<80: return .systemYellow
        default: return .systemGreen
        }
    }

    private var consumptionColor: UIColor {
        switch dashboard.consumption {
        case 20...: return .systemRed
        case 15..<20: return .systemOrange
        case 12..<15: return .systemYellow
        default: return .systemGreen
        }
    }

    private var loadColor: UIColor {
        switch dashboard.engineLoad {
        case 90...: return .systemRed
        case 75..<90: return .systemOrange
        case 50..<75: return .systemYellow
        default: return .systemGreen
        }
    }

    private func fuelTrimColor(_ value: Double) -> UIColor {
        let abs = abs(value)
        switch abs {
        case 20...: return .systemRed
        case 15..<20: return .systemOrange
        case 10..<15: return .systemYellow
        default: return .systemGreen
        }
    }

    // MARK: - Updates

    private func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDashboard()
        }
    }

    private func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshDashboard() {
        guard let controller = interfaceController,
              let tabBar = controller.rootTemplate as? CPTabBarTemplate else { return }

        tabBar.updateTemplates([
            createMainDashboard(),
            createEngineDashboard(),
            createFuelDashboard(),
            createStatusDashboard()
        ])
    }
}

// MARK: - Data Provider

public class CarPlayDataProvider: ObservableObject {
    public static let shared = CarPlayDataProvider()

    @Published public var engineState = RotaryEngineState()
    @Published public var fuelData = CarPlayFuelData()
    @Published public var activeDTCs: [DTCCode] = []

    private init() {}

    public func updateEngineState(_ state: RotaryEngineState) {
        DispatchQueue.main.async { self.engineState = state }
    }

    public func updateFuelData(consumption: Double, range: Double, fuelLevel: Double) {
        DispatchQueue.main.async {
            self.fuelData = CarPlayFuelData(instantConsumption: consumption, estimatedRange: range, fuelLevel: fuelLevel)
        }
    }

    public func updateDTCs(_ dtcs: [DTCCode]) {
        DispatchQueue.main.async { self.activeDTCs = dtcs }
    }
}

public struct CarPlayFuelData {
    public var instantConsumption: Double = 0
    public var estimatedRange: Double = 0
    public var fuelLevel: Double = 0
    public var consumptionPerHour: Double = 0
    public var avgConsumption: Double = 0
    public var fuelLiters: Double = 0

    public init(instantConsumption: Double = 0, estimatedRange: Double = 0, fuelLevel: Double = 0) {
        self.instantConsumption = instantConsumption
        self.estimatedRange = estimatedRange
        self.fuelLevel = fuelLevel
        self.fuelLiters = fuelLevel * 0.6
    }
}

// MARK: - Dashboard Model

class RX8CarPlayDashboard {
    var rpm: Int = 0
    var speed: Double = 0
    var coolantTemp: Double = 0
    var oilTemp: Double = 0
    var batteryVoltage: Double = 0
    var intakeTemp: Double = 0
    var fuelLevel: Double = 0
    var fuelLiters: Double = 0
    var consumption: Double = 0
    var consumptionPerHour: Double = 0
    var avgConsumption: Double = 0
    var range: Double = 0
    var throttle: Double = 0
    var engineLoad: Double = 0
    var stft: Double = 0
    var ltft: Double = 0
    var alerts: [Alert] = []

    struct Alert {
        let severity: Severity
        let message: String
        enum Severity { case info, warning, critical }
    }

    func update(from state: RotaryEngineState) {
        rpm = state.rpm
        speed = state.vehicleSpeed
        coolantTemp = state.coolantTemperature
        oilTemp = state.oilTemperature
        batteryVoltage = state.batteryVoltage
        intakeTemp = state.intakeAirTemperature
        throttle = state.throttlePosition
        engineLoad = state.engineLoad
        stft = state.shortTermFuelTrim
        ltft = state.longTermFuelTrim
        checkAlerts(state)
    }

    func updateFuel(from data: CarPlayFuelData) {
        consumption = data.instantConsumption
        range = data.estimatedRange
        fuelLevel = data.fuelLevel
        fuelLiters = data.fuelLiters
        avgConsumption = data.avgConsumption
        consumptionPerHour = data.consumptionPerHour
    }

    private func checkAlerts(_ state: RotaryEngineState) {
        var newAlerts: [Alert] = []

        if state.coolantTemperature > 108 {
            newAlerts.append(Alert(severity: .critical, message: "Refrigerante crítico"))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(Alert(severity: .warning, message: "Refrigerante alto"))
        }

        if state.oilTemperature > 135 {
            newAlerts.append(Alert(severity: .critical, message: "Aceite crítico"))
        } else if state.oilTemperature > 120 {
            newAlerts.append(Alert(severity: .warning, message: "Aceite caliente"))
        }

        if state.batteryVoltage > 0 && state.batteryVoltage < 11.5 {
            newAlerts.append(Alert(severity: .critical, message: "Batería crítica"))
        }

        if state.rpm > 8500 {
            newAlerts.append(Alert(severity: .warning, message: "RPM alto"))
        }

        if state.rpm > 800 && abs(state.shortTermFuelTrim) > 25 {
            newAlerts.append(Alert(severity: .warning, message: "STFT anormal"))
        }

        if state.rpm > 800 && abs(state.longTermFuelTrim) > 15 {
            newAlerts.append(Alert(severity: .warning, message: "LTFT anormal"))
        }

        if fuelLevel > 0 && fuelLevel < 10 {
            newAlerts.append(Alert(severity: .warning, message: "Combustible bajo"))
        }

        alerts = newAlerts
    }
}
