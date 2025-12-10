import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// Dashboard for Mazda RX-8 rotary engine monitoring

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

        // Subscribe to shared data provider updates
        setupDataSubscription()

        // Create and set root template
        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true) { success, error in
            if let error = error {
                print("CarPlay: Error setting root template: \(error)")
            } else {
                print("CarPlay: Root template set successfully")
            }
        }

        // Start updates
        startUpdates()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("CarPlay: Disconnected")
        self.interfaceController = nil
        stopUpdates()
        cancellables.removeAll()
    }

    // MARK: - Data Subscription

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

    // MARK: - Root Template (Tab Bar)

    private func createRootTemplate() -> CPTemplate {
        // Create a tab bar with main sections
        let dashboardTab = createDashboardTab()
        let alertsTab = createAlertsTab()

        let tabBar = CPTabBarTemplate(templates: [dashboardTab, alertsTab])
        return tabBar
    }

    // MARK: - Dashboard Tab

    private func createDashboardTab() -> CPListTemplate {
        let items = createDashboardItems()
        let section = CPListSection(items: items, header: "Engine Data", sectionIndexTitle: nil)

        let template = CPListTemplate(title: "RX-8 Dashboard", sections: [section])
        template.tabTitle = "Dashboard"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.bottom.50percent")

        return template
    }

    private func createDashboardItems() -> [CPListItem] {
        return [
            createListItem(
                title: "RPM",
                value: "\(carPlayDashboard.rpm)",
                icon: "gauge.with.dots.needle.bottom.50percent"
            ),
            createListItem(
                title: "Speed",
                value: String(format: "%.0f km/h", carPlayDashboard.speed),
                icon: "speedometer"
            ),
            createListItem(
                title: "Coolant",
                value: String(format: "%.0f °C", carPlayDashboard.coolantTemp),
                icon: "thermometer"
            ),
            createListItem(
                title: "Oil Temp",
                value: String(format: "%.0f °C", carPlayDashboard.oilTemp),
                icon: "drop.fill"
            ),
            createListItem(
                title: "Consumption",
                value: String(format: "%.1f L/100km", carPlayDashboard.consumption),
                icon: "fuelpump"
            ),
            createListItem(
                title: "Battery",
                value: String(format: "%.1f V", carPlayDashboard.batteryVoltage),
                icon: "bolt.fill"
            )
        ]
    }

    private func createListItem(title: String, value: String, icon: String) -> CPListItem {
        let item = CPListItem(text: title, detailText: value)
        item.setImage(UIImage(systemName: icon))
        return item
    }

    // MARK: - Alerts Tab

    private func createAlertsTab() -> CPListTemplate {
        var items: [CPListItem] = []

        if carPlayDashboard.alerts.isEmpty {
            let item = CPListItem(text: "No Active Alerts", detailText: "All systems OK")
            item.setImage(UIImage(systemName: "checkmark.circle.fill"))
            items.append(item)
        } else {
            for alert in carPlayDashboard.alerts {
                let item = CPListItem(text: alert.message, detailText: formatAlertTime(alert.timestamp))
                item.setImage(UIImage(systemName: alert.type.icon))
                items.append(item)
            }
        }

        let section = CPListSection(items: items, header: "Alerts", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Alerts", sections: [section])
        template.tabTitle = "Alerts"
        template.tabImage = UIImage(systemName: "exclamationmark.triangle")

        return template
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
        guard let interfaceController = interfaceController,
              let tabBar = interfaceController.rootTemplate as? CPTabBarTemplate else { return }

        // Update dashboard tab
        let newDashboardTab = createDashboardTab()
        let newAlertsTab = createAlertsTab()

        tabBar.updateTemplates([newDashboardTab, newAlertsTab])
    }

    // MARK: - Helpers

    private func formatAlertTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CarPlay Data Provider (Singleton)

public class CarPlayDataProvider: ObservableObject {
    public static let shared = CarPlayDataProvider()

    @Published public var engineState = RotaryEngineState()
    @Published public var fuelData = CarPlayFuelData()
    @Published public var activeDTCs: [DTCCode] = []

    private init() {}

    public func updateEngineState(_ state: RotaryEngineState) {
        DispatchQueue.main.async {
            self.engineState = state
        }
    }

    public func updateFuelData(consumption: Double, range: Double, fuelLevel: Double) {
        DispatchQueue.main.async {
            self.fuelData = CarPlayFuelData(
                instantConsumption: consumption,
                estimatedRange: range,
                fuelLevel: fuelLevel
            )
        }
    }

    public func updateDTCs(_ dtcs: [DTCCode]) {
        DispatchQueue.main.async {
            self.activeDTCs = dtcs
        }
    }
}

// MARK: - CarPlay Fuel Data

public struct CarPlayFuelData {
    public var instantConsumption: Double = 0
    public var estimatedRange: Double = 0
    public var fuelLevel: Double = 0

    public init(instantConsumption: Double = 0, estimatedRange: Double = 0, fuelLevel: Double = 0) {
        self.instantConsumption = instantConsumption
        self.estimatedRange = estimatedRange
        self.fuelLevel = fuelLevel
    }
}

// MARK: - CarPlay Dashboard Provider

class RX8CarPlayDashboard: ObservableObject {
    @Published var rpm: Int = 0
    @Published var speed: Double = 0
    @Published var coolantTemp: Double = 0
    @Published var oilTemp: Double = 0
    @Published var consumption: Double = 0
    @Published var range: Double = 0
    @Published var batteryVoltage: Double = 0
    @Published var intakeTemp: Double = 0
    @Published var fuelLevel: Double = 0

    @Published var alerts: [CarPlayAlert] = []
    @Published var activeDTCs: [DTCCode] = []

    struct CarPlayAlert: Identifiable {
        let id = UUID()
        let type: AlertType
        let message: String
        let timestamp: Date
    }

    enum AlertType {
        case temperature
        case pressure
        case system
        case dtc

        var icon: String {
            switch self {
            case .temperature: return "thermometer.high"
            case .pressure: return "gauge.with.dots.needle.33percent"
            case .system: return "exclamationmark.triangle"
            case .dtc: return "engine.combustion"
            }
        }
    }

    func update(from engineState: RotaryEngineState) {
        rpm = engineState.rpm
        speed = engineState.vehicleSpeed
        coolantTemp = engineState.coolantTemperature
        oilTemp = engineState.oilTemperature
        batteryVoltage = engineState.batteryVoltage
        intakeTemp = engineState.intakeAirTemperature

        // Check alerts
        checkAlerts(engineState)

        // Update active DTCs from provider
        activeDTCs = CarPlayDataProvider.shared.activeDTCs
    }

    func updateFuel(from data: CarPlayFuelData) {
        consumption = data.instantConsumption
        range = data.estimatedRange
        fuelLevel = data.fuelLevel
    }

    private func checkAlerts(_ state: RotaryEngineState) {
        var newAlerts: [CarPlayAlert] = []

        // High coolant temperature
        if state.coolantTemperature > 105 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: "CRITICAL: Coolant \(Int(state.coolantTemperature))°C!",
                timestamp: Date()
            ))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: "Warning: Coolant \(Int(state.coolantTemperature))°C",
                timestamp: Date()
            ))
        }

        // High oil temperature
        if state.oilTemperature > 130 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: "CRITICAL: Oil \(Int(state.oilTemperature))°C!",
                timestamp: Date()
            ))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: "Warning: Oil \(Int(state.oilTemperature))°C",
                timestamp: Date()
            ))
        }

        // Low battery voltage
        if state.batteryVoltage < 11.5 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: "CRITICAL: Battery \(String(format: "%.1f", state.batteryVoltage))V!",
                timestamp: Date()
            ))
        } else if state.batteryVoltage < 12.0 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: "Warning: Battery \(String(format: "%.1f", state.batteryVoltage))V",
                timestamp: Date()
            ))
        }

        // High RPM warning for rotary engine
        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: "Warning: High RPM \(state.rpm)!",
                timestamp: Date()
            ))
        }

        alerts = newAlerts
    }
}
