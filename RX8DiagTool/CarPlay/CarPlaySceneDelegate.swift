import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// Interfaz profesional y limpia para monitorización del motor rotativo RX-8

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var carPlayDashboard = RX8CarPlayDashboard()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        print("CarPlay: Connected")
        self.interfaceController = interfaceController
        setupDataSubscription()

        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true) { success, error in
            if let error = error {
                print("CarPlay: Error - \(error)")
            }
        }
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
            .sink { [weak self] state in
                self?.carPlayDashboard.update(from: state)
            }
            .store(in: &cancellables)

        CarPlayDataProvider.shared.$fuelData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.carPlayDashboard.updateFuel(from: data)
            }
            .store(in: &cancellables)
    }

    // MARK: - Root Template

    private func createRootTemplate() -> CPTemplate {
        let tabBar = CPTabBarTemplate(templates: [
            createDashboardTab(),
            createEngineTab(),
            createFuelTab(),
            createAlertsTab()
        ])
        return tabBar
    }

    // MARK: - Tab 1: Dashboard (Grid de instrumentos)

    private func createDashboardTab() -> CPGridTemplate {
        let gridButtons = [
            createInstrument(
                icon: "gauge.with.needle",
                value: "\(carPlayDashboard.rpm)",
                unit: "RPM",
                color: rpmColor
            ),
            createInstrument(
                icon: "speedometer",
                value: String(format: "%.0f", carPlayDashboard.speed),
                unit: "km/h",
                color: .systemBlue
            ),
            createInstrument(
                icon: "thermometer.medium",
                value: String(format: "%.0f°", carPlayDashboard.coolantTemp),
                unit: "Refrig",
                color: coolantColor
            ),
            createInstrument(
                icon: "drop.fill",
                value: carPlayDashboard.oilTemp > 50 ? String(format: "%.0f°", carPlayDashboard.oilTemp) : "—",
                unit: "Aceite",
                color: oilColor
            ),
            createInstrument(
                icon: "bolt.fill",
                value: String(format: "%.1f", carPlayDashboard.batteryVoltage),
                unit: "V",
                color: voltageColor
            ),
            createInstrument(
                icon: "fuelpump.fill",
                value: String(format: "%.0f", carPlayDashboard.fuelLevel),
                unit: "%",
                color: fuelColor
            )
        ]

        let template = CPGridTemplate(title: "Renesis Monitor", gridButtons: gridButtons)
        template.tabTitle = "Dashboard"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.bottom.50percent")
        return template
    }

    private func createInstrument(icon: String, value: String, unit: String, color: UIColor) -> CPGridButton {
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        var image = UIImage(systemName: icon, withConfiguration: config) ?? UIImage(systemName: "circle")!
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)

        return CPGridButton(titleVariants: ["\(value) \(unit)", value], image: image) { _ in }
    }

    // MARK: - Tab 2: Motor

    private func createEngineTab() -> CPListTemplate {
        let tempItems = [
            createDataItem(icon: "thermometer.high", title: "Refrigerante",
                          value: String(format: "%.1f °C", carPlayDashboard.coolantTemp),
                          color: coolantColor),
            createDataItem(icon: "drop.fill", title: "Aceite",
                          value: carPlayDashboard.oilTemp > 50 ? String(format: "%.1f °C", carPlayDashboard.oilTemp) : "— °C",
                          color: oilColor),
            createDataItem(icon: "wind", title: "Admisión",
                          value: String(format: "%.1f °C", carPlayDashboard.intakeTemp),
                          color: .systemCyan)
        ]

        let perfItems = [
            createDataItem(icon: "gauge.with.needle", title: "RPM",
                          value: "\(carPlayDashboard.rpm)",
                          color: rpmColor),
            createDataItem(icon: "pedal.accelerator", title: "Acelerador",
                          value: String(format: "%.0f %%", carPlayDashboard.throttle),
                          color: .systemBlue),
            createDataItem(icon: "engine.combustion", title: "Carga",
                          value: String(format: "%.0f %%", carPlayDashboard.engineLoad),
                          color: .systemPurple)
        ]

        let fuelTrimItems = [
            createDataItem(icon: "arrow.up.arrow.down", title: "STFT",
                          value: String(format: "%+.1f %%", carPlayDashboard.stft),
                          color: fuelTrimColor(carPlayDashboard.stft)),
            createDataItem(icon: "chart.line.flattrend.xyaxis", title: "LTFT",
                          value: String(format: "%+.1f %%", carPlayDashboard.ltft),
                          color: fuelTrimColor(carPlayDashboard.ltft))
        ]

        let template = CPListTemplate(title: "Motor", sections: [
            CPListSection(items: tempItems, header: "Temperaturas", sectionIndexTitle: nil),
            CPListSection(items: perfItems, header: "Rendimiento", sectionIndexTitle: nil),
            CPListSection(items: fuelTrimItems, header: "Fuel Trim", sectionIndexTitle: nil)
        ])
        template.tabTitle = "Motor"
        template.tabImage = UIImage(systemName: "engine.combustion")
        return template
    }

    // MARK: - Tab 3: Consumo

    private func createFuelTab() -> CPListTemplate {
        let consumptionValue = carPlayDashboard.speed > 5
            ? String(format: "%.1f L/100km", carPlayDashboard.consumption)
            : String(format: "%.1f L/h", carPlayDashboard.consumptionPerHour)

        let tripItems = [
            createDataItem(icon: "fuelpump", title: "Consumo",
                          value: consumptionValue,
                          color: consumptionColor),
            createDataItem(icon: "chart.xyaxis.line", title: "Media",
                          value: String(format: "%.1f L/100km", carPlayDashboard.avgConsumption),
                          color: .systemBlue),
            createDataItem(icon: "road.lanes", title: "Autonomía",
                          value: String(format: "%.0f km", carPlayDashboard.range),
                          color: rangeColor)
        ]

        let tankItems = [
            createDataItem(icon: "fuelpump.fill", title: "Nivel",
                          value: String(format: "%.0f %%", carPlayDashboard.fuelLevel),
                          color: fuelColor),
            createDataItem(icon: "drop.halffull", title: "Restante",
                          value: String(format: "%.1f L", carPlayDashboard.fuelLiters),
                          color: .systemTeal)
        ]

        let electricItems = [
            createDataItem(icon: "bolt.fill", title: "Batería",
                          value: String(format: "%.2f V", carPlayDashboard.batteryVoltage),
                          color: voltageColor)
        ]

        let template = CPListTemplate(title: "Consumo", sections: [
            CPListSection(items: tripItems, header: "Viaje", sectionIndexTitle: nil),
            CPListSection(items: tankItems, header: "Depósito", sectionIndexTitle: nil),
            CPListSection(items: electricItems, header: "Eléctrico", sectionIndexTitle: nil)
        ])
        template.tabTitle = "Consumo"
        template.tabImage = UIImage(systemName: "fuelpump")
        return template
    }

    // MARK: - Tab 4: Estado

    private func createAlertsTab() -> CPListTemplate {
        var sections: [CPListSection] = []

        // Alertas activas (si las hay)
        if !carPlayDashboard.alerts.isEmpty {
            let alertItems = carPlayDashboard.alerts.map { alert -> CPListItem in
                let item = CPListItem(text: alert.message, detailText: formatTime(alert.timestamp))
                item.setImage(alertImage(alert.severity))
                return item
            }
            sections.append(CPListSection(items: alertItems, header: "Alertas Activas", sectionIndexTitle: nil))
        }

        // Estado de sistemas
        let statusItems = [
            createStatusItem(title: "Motor", ok: carPlayDashboard.coolantTemp < 100 && carPlayDashboard.oilTemp < 120),
            createStatusItem(title: "Eléctrico", ok: carPlayDashboard.batteryVoltage >= 12.0 || carPlayDashboard.batteryVoltage == 0),
            createStatusItem(title: "Combustible", ok: abs(carPlayDashboard.stft) < 15 && abs(carPlayDashboard.ltft) < 10),
            createStatusItem(title: "Depósito", ok: carPlayDashboard.fuelLevel > 15)
        ]
        sections.append(CPListSection(items: statusItems, header: "Estado del Sistema", sectionIndexTitle: nil))

        let hasAlerts = !carPlayDashboard.alerts.isEmpty
        let template = CPListTemplate(title: hasAlerts ? "Alertas" : "Sistema OK", sections: sections)
        template.tabTitle = hasAlerts ? "!" : "OK"
        template.tabImage = UIImage(systemName: hasAlerts ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        return template
    }

    // MARK: - Item Builders

    private func createDataItem(icon: String, title: String, value: String, color: UIColor) -> CPListItem {
        let item = CPListItem(text: title, detailText: value)
        var image = UIImage(systemName: icon) ?? UIImage(systemName: "circle")!
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)
        item.setImage(image)
        return item
    }

    private func createStatusItem(title: String, ok: Bool) -> CPListItem {
        let item = CPListItem(text: title, detailText: ok ? "OK" : "Revisar")
        let icon = ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let color = ok ? UIColor.systemGreen : UIColor.systemOrange
        var image = UIImage(systemName: icon)!
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)
        item.setImage(image)
        return item
    }

    private func alertImage(_ severity: RX8CarPlayDashboard.AlertSeverity) -> UIImage {
        let icon: String
        let color: UIColor
        switch severity {
        case .critical:
            icon = "exclamationmark.octagon.fill"
            color = .systemRed
        case .warning:
            icon = "exclamationmark.triangle.fill"
            color = .systemOrange
        case .info:
            icon = "info.circle.fill"
            color = .systemBlue
        }
        return UIImage(systemName: icon)!.withTintColor(color, renderingMode: .alwaysOriginal)
    }

    // MARK: - Colors

    private var rpmColor: UIColor {
        if carPlayDashboard.rpm > 8000 { return .systemRed }
        if carPlayDashboard.rpm > 7000 { return .systemOrange }
        return .systemGreen
    }

    private var coolantColor: UIColor {
        if carPlayDashboard.coolantTemp > 105 { return .systemRed }
        if carPlayDashboard.coolantTemp > 98 { return .systemOrange }
        if carPlayDashboard.coolantTemp < 70 { return .systemBlue }
        return .systemGreen
    }

    private var oilColor: UIColor {
        if carPlayDashboard.oilTemp > 130 { return .systemRed }
        if carPlayDashboard.oilTemp > 120 { return .systemOrange }
        if carPlayDashboard.oilTemp < 80 && carPlayDashboard.oilTemp > 50 { return .systemBlue }
        if carPlayDashboard.oilTemp <= 50 { return .systemGray }
        return .systemGreen
    }

    private var voltageColor: UIColor {
        if carPlayDashboard.batteryVoltage < 11.5 && carPlayDashboard.batteryVoltage > 0 { return .systemRed }
        if carPlayDashboard.batteryVoltage < 12.5 && carPlayDashboard.batteryVoltage > 0 { return .systemOrange }
        return .systemGreen
    }

    private var fuelColor: UIColor {
        if carPlayDashboard.fuelLevel < 10 { return .systemRed }
        if carPlayDashboard.fuelLevel < 20 { return .systemOrange }
        return .systemGreen
    }

    private var rangeColor: UIColor {
        if carPlayDashboard.range < 30 { return .systemRed }
        if carPlayDashboard.range < 50 { return .systemOrange }
        return .systemGreen
    }

    private var consumptionColor: UIColor {
        if carPlayDashboard.consumption > 20 { return .systemOrange }
        return .systemGreen
    }

    private func fuelTrimColor(_ value: Double) -> UIColor {
        if abs(value) > 20 { return .systemRed }
        if abs(value) > 15 { return .systemOrange }
        return .systemGreen
    }

    // MARK: - Updates

    private func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshAllTabs()
        }
    }

    private func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshAllTabs() {
        guard let interfaceController = interfaceController,
              let tabBar = interfaceController.rootTemplate as? CPTabBarTemplate else { return }

        tabBar.updateTemplates([
            createDashboardTab(),
            createEngineTab(),
            createFuelTab(),
            createAlertsTab()
        ])
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

// MARK: - Fuel Data

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

class RX8CarPlayDashboard: ObservableObject {
    @Published var rpm: Int = 0
    @Published var speed: Double = 0
    @Published var coolantTemp: Double = 0
    @Published var oilTemp: Double = 0
    @Published var batteryVoltage: Double = 0
    @Published var intakeTemp: Double = 0
    @Published var fuelLevel: Double = 0
    @Published var fuelLiters: Double = 0
    @Published var consumption: Double = 0
    @Published var consumptionPerHour: Double = 0
    @Published var avgConsumption: Double = 0
    @Published var range: Double = 0
    @Published var throttle: Double = 0
    @Published var engineLoad: Double = 0
    @Published var stft: Double = 0
    @Published var ltft: Double = 0
    @Published var alerts: [CarPlayAlert] = []

    struct CarPlayAlert: Identifiable {
        let id = UUID()
        let severity: AlertSeverity
        let message: String
        let timestamp: Date
    }

    enum AlertSeverity { case info, warning, critical }

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
        var newAlerts: [CarPlayAlert] = []

        if state.coolantTemperature > 108 {
            newAlerts.append(CarPlayAlert(severity: .critical, message: "Refrigerante: \(Int(state.coolantTemperature))°C", timestamp: Date()))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "Refrigerante alto: \(Int(state.coolantTemperature))°C", timestamp: Date()))
        }

        if state.oilTemperature > 135 {
            newAlerts.append(CarPlayAlert(severity: .critical, message: "Aceite: \(Int(state.oilTemperature))°C", timestamp: Date()))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "Aceite caliente: \(Int(state.oilTemperature))°C", timestamp: Date()))
        }

        if state.batteryVoltage > 0 && state.batteryVoltage < 11.5 {
            newAlerts.append(CarPlayAlert(severity: .critical, message: "Batería: \(String(format: "%.1f", state.batteryVoltage))V", timestamp: Date()))
        }

        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "RPM: \(state.rpm)", timestamp: Date()))
        }

        if state.rpm > 800 && abs(state.shortTermFuelTrim) > 25 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "STFT: \(String(format: "%+.1f", state.shortTermFuelTrim))%", timestamp: Date()))
        }

        if state.rpm > 800 && abs(state.longTermFuelTrim) > 15 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "LTFT: \(String(format: "%+.1f", state.longTermFuelTrim))%", timestamp: Date()))
        }

        if fuelLevel > 0 && fuelLevel < 10 {
            newAlerts.append(CarPlayAlert(severity: .warning, message: "Combustible bajo", timestamp: Date()))
        }

        alerts = newAlerts
    }
}
