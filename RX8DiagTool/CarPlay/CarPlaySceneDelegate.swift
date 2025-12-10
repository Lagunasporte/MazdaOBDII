import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// UI estética orientada a relojes e información de conducción

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var carPlayDashboard = RX8CarPlayDashboard()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        // Subscribe to shared data provider updates
        setupDataSubscription()

        // Create main template
        let rootTemplate = createDashboardTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)

        // Start updates
        startUpdates()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        stopUpdates()
        cancellables.removeAll()
    }

    // MARK: - Data Subscription

    private func setupDataSubscription() {
        // Subscribe to shared CarPlay data provider
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

    // MARK: - Templates

    private func createDashboardTemplate() -> CPTemplate {
        let template = CPInformationTemplate(
            title: NSLocalizedString("carplay.dashboard.title", comment: ""),
            layout: .twoColumn,
            items: createDashboardItems(),
            actions: createDashboardActions()
        )

        return template
    }

    private func createDashboardItems() -> [CPInformationItem] {
        return [
            CPInformationItem(title: NSLocalizedString("carplay.rpm", comment: ""), detail: "\(carPlayDashboard.rpm)"),
            CPInformationItem(title: NSLocalizedString("carplay.speed", comment: ""), detail: String(format: "%.0f km/h", carPlayDashboard.speed)),
            CPInformationItem(title: NSLocalizedString("carplay.coolant", comment: ""), detail: String(format: "%.0f °C", carPlayDashboard.coolantTemp)),
            CPInformationItem(title: NSLocalizedString("carplay.oil_temp", comment: ""), detail: String(format: "%.0f °C", carPlayDashboard.oilTemp)),
            CPInformationItem(title: NSLocalizedString("carplay.consumption", comment: ""), detail: String(format: "%.1f L/100", carPlayDashboard.consumption)),
            CPInformationItem(title: NSLocalizedString("carplay.range", comment: ""), detail: String(format: "%.0f km", carPlayDashboard.range))
        ]
    }

    private func createDashboardActions() -> [CPTextButton] {
        return [
            CPTextButton(title: NSLocalizedString("carplay.gauges", comment: ""), textStyle: .normal) { [weak self] _ in
                self?.showGaugesTemplate()
            },
            CPTextButton(title: NSLocalizedString("carplay.alerts", comment: ""), textStyle: .normal) { [weak self] _ in
                self?.showAlertsTemplate()
            },
            CPTextButton(title: NSLocalizedString("carplay.dtc", comment: ""), textStyle: .normal) { [weak self] _ in
                self?.showDTCTemplate()
            }
        ]
    }

    // MARK: - Gauge Template (Instruments)

    private func showGaugesTemplate() {
        let gridButtons = [
            createGaugeButton(
                title: NSLocalizedString("carplay.rpm", comment: ""),
                value: "\(carPlayDashboard.rpm)",
                icon: "gauge.with.dots.needle.bottom.50percent"
            ),
            createGaugeButton(
                title: NSLocalizedString("carplay.speed", comment: ""),
                value: String(format: "%.0f", carPlayDashboard.speed),
                icon: "speedometer"
            ),
            createGaugeButton(
                title: NSLocalizedString("carplay.coolant", comment: ""),
                value: String(format: "%.0f°C", carPlayDashboard.coolantTemp),
                icon: "thermometer"
            ),
            createGaugeButton(
                title: NSLocalizedString("carplay.oil_temp", comment: ""),
                value: String(format: "%.0f°C", carPlayDashboard.oilTemp),
                icon: "drop.fill"
            ),
            createGaugeButton(
                title: NSLocalizedString("carplay.consumption", comment: ""),
                value: String(format: "%.1f", carPlayDashboard.consumption),
                icon: "fuelpump"
            ),
            createGaugeButton(
                title: NSLocalizedString("carplay.voltage", comment: ""),
                value: String(format: "%.1fV", carPlayDashboard.batteryVoltage),
                icon: "bolt.fill"
            )
        ]

        let gridTemplate = CPGridTemplate(title: NSLocalizedString("carplay.instruments", comment: ""), gridButtons: gridButtons)
        interfaceController?.pushTemplate(gridTemplate, animated: true, completion: nil)
    }

    private func createGaugeButton(title: String, value: String, icon: String) -> CPGridButton {
        let image = UIImage(systemName: icon) ?? UIImage()

        return CPGridButton(titleVariants: ["\(title)\n\(value)"], image: image) { _ in
            // Action when tapping the button
        }
    }

    // MARK: - Alerts Template

    private func showAlertsTemplate() {
        var items: [CPListItem] = []

        if carPlayDashboard.alerts.isEmpty {
            items.append(CPListItem(
                text: NSLocalizedString("carplay.no_alerts", comment: ""),
                detailText: NSLocalizedString("carplay.all_systems_ok", comment: "")
            ))
        } else {
            for alert in carPlayDashboard.alerts {
                let item = CPListItem(
                    text: alert.message,
                    detailText: formatAlertTime(alert.timestamp)
                )
                item.setImage(UIImage(systemName: alert.type.icon))
                items.append(item)
            }
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: NSLocalizedString("carplay.alerts", comment: ""), sections: [section])
        interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
    }

    // MARK: - DTC Template

    private func showDTCTemplate() {
        var items: [CPListItem] = []

        let activeDTCs = carPlayDashboard.activeDTCs
        if activeDTCs.isEmpty {
            items.append(CPListItem(
                text: NSLocalizedString("carplay.no_dtc", comment: ""),
                detailText: NSLocalizedString("carplay.engine_ok", comment: "")
            ))
        } else {
            for dtc in activeDTCs {
                let item = CPListItem(
                    text: dtc.code,
                    detailText: dtc.localizedName
                )
                // Set severity color indicator
                switch dtc.severity {
                case .critical:
                    item.setImage(UIImage(systemName: "exclamationmark.octagon.fill"))
                case .high:
                    item.setImage(UIImage(systemName: "exclamationmark.triangle.fill"))
                case .medium:
                    item.setImage(UIImage(systemName: "exclamationmark.circle.fill"))
                case .low:
                    item.setImage(UIImage(systemName: "info.circle.fill"))
                }
                items.append(item)
            }
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: NSLocalizedString("carplay.dtc", comment: ""), sections: [section])
        interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
    }

    // MARK: - Updates

    private func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateDashboard()
        }
    }

    private func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateDashboard() {
        // Update the root template with fresh data
        guard let interfaceController = interfaceController else { return }

        // Create updated template
        let updatedTemplate = CPInformationTemplate(
            title: NSLocalizedString("carplay.dashboard.title", comment: ""),
            layout: .twoColumn,
            items: createDashboardItems(),
            actions: createDashboardActions()
        )

        // Update root template
        interfaceController.setRootTemplate(updatedTemplate, animated: false, completion: nil)
    }

    // MARK: - Helpers

    private func formatAlertTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CarPlay Data Provider (Singleton)
// This class bridges the main app data to CarPlay

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
                message: String(format: NSLocalizedString("carplay.alert.coolant_high", comment: ""), Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: NSLocalizedString("carplay.alert.coolant_warning", comment: ""), Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        }

        // High oil temperature
        if state.oilTemperature > 130 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: NSLocalizedString("carplay.alert.oil_high", comment: ""), Int(state.oilTemperature)),
                timestamp: Date()
            ))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: NSLocalizedString("carplay.alert.oil_warning", comment: ""), Int(state.oilTemperature)),
                timestamp: Date()
            ))
        }

        // Low battery voltage
        if state.batteryVoltage < 11.5 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: NSLocalizedString("carplay.alert.battery_low", comment: ""), state.batteryVoltage),
                timestamp: Date()
            ))
        } else if state.batteryVoltage < 12.0 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: NSLocalizedString("carplay.alert.battery_warning", comment: ""), state.batteryVoltage),
                timestamp: Date()
            ))
        }

        // High RPM warning for rotary engine
        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: NSLocalizedString("carplay.alert.rpm_high", comment: ""), state.rpm),
                timestamp: Date()
            ))
        }

        alerts = newAlerts
    }
}
