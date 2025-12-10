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

    // Shared engine monitor from main app
    private var engineMonitor: EngineMonitor {
        EngineMonitor.shared
    }

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        // Subscribe to engine state updates
        setupEngineMonitorSubscription()

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

    // MARK: - Engine Monitor Subscription

    private func setupEngineMonitorSubscription() {
        // Subscribe to engine state changes from the shared EngineMonitor
        engineMonitor.$engineState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.carPlayDashboard.update(from: state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Templates

    private func createDashboardTemplate() -> CPTemplate {
        let template = CPInformationTemplate(
            title: "carplay.dashboard.title".localized,
            layout: .twoColumn,
            items: createDashboardItems(),
            actions: createDashboardActions()
        )

        return template
    }

    private func createDashboardItems() -> [CPInformationItem] {
        return [
            CPInformationItem(title: "carplay.rpm".localized, detail: "\(carPlayDashboard.rpm)"),
            CPInformationItem(title: "carplay.speed".localized, detail: String(format: "%.0f km/h", carPlayDashboard.speed)),
            CPInformationItem(title: "carplay.coolant".localized, detail: String(format: "%.0f °C", carPlayDashboard.coolantTemp)),
            CPInformationItem(title: "carplay.oil_temp".localized, detail: String(format: "%.0f °C", carPlayDashboard.oilTemp)),
            CPInformationItem(title: "carplay.consumption".localized, detail: String(format: "%.1f L/100", carPlayDashboard.consumption)),
            CPInformationItem(title: "carplay.range".localized, detail: String(format: "%.0f km", carPlayDashboard.range))
        ]
    }

    private func createDashboardActions() -> [CPTextButton] {
        return [
            CPTextButton(title: "carplay.gauges".localized, textStyle: .normal) { [weak self] _ in
                self?.showGaugesTemplate()
            },
            CPTextButton(title: "carplay.alerts".localized, textStyle: .normal) { [weak self] _ in
                self?.showAlertsTemplate()
            },
            CPTextButton(title: "carplay.dtc".localized, textStyle: .normal) { [weak self] _ in
                self?.showDTCTemplate()
            }
        ]
    }

    // MARK: - Gauge Template (Instruments)

    private func showGaugesTemplate() {
        let gridButtons = [
            createGaugeButton(
                title: "carplay.rpm".localized,
                value: "\(carPlayDashboard.rpm)",
                icon: "gauge.with.dots.needle.bottom.50percent"
            ),
            createGaugeButton(
                title: "carplay.speed".localized,
                value: String(format: "%.0f", carPlayDashboard.speed),
                icon: "speedometer"
            ),
            createGaugeButton(
                title: "carplay.coolant".localized,
                value: String(format: "%.0f°C", carPlayDashboard.coolantTemp),
                icon: "thermometer"
            ),
            createGaugeButton(
                title: "carplay.oil_temp".localized,
                value: String(format: "%.0f°C", carPlayDashboard.oilTemp),
                icon: "drop.fill"
            ),
            createGaugeButton(
                title: "carplay.consumption".localized,
                value: String(format: "%.1f", carPlayDashboard.consumption),
                icon: "fuelpump"
            ),
            createGaugeButton(
                title: "carplay.voltage".localized,
                value: String(format: "%.1fV", carPlayDashboard.batteryVoltage),
                icon: "bolt.fill"
            )
        ]

        let gridTemplate = CPGridTemplate(title: "carplay.instruments".localized, gridButtons: gridButtons)
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
                text: "carplay.no_alerts".localized,
                detailText: "carplay.all_systems_ok".localized
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
        let listTemplate = CPListTemplate(title: "carplay.alerts".localized, sections: [section])
        interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
    }

    // MARK: - DTC Template

    private func showDTCTemplate() {
        var items: [CPListItem] = []

        let activeDTCs = carPlayDashboard.activeDTCs
        if activeDTCs.isEmpty {
            items.append(CPListItem(
                text: "carplay.no_dtc".localized,
                detailText: "carplay.engine_ok".localized
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
        let listTemplate = CPListTemplate(title: "carplay.dtc".localized, sections: [section])
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
            title: "carplay.dashboard.title".localized,
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
    @Published var boostPressure: Double = 0

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
        consumption = engineState.instantConsumption
        range = engineState.estimatedRange

        // Check alerts
        checkAlerts(engineState)
    }

    func updateDTCs(_ dtcs: [DTCCode]) {
        activeDTCs = dtcs
    }

    private func checkAlerts(_ state: RotaryEngineState) {
        var newAlerts: [CarPlayAlert] = []

        // High coolant temperature
        if state.coolantTemperature > 105 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: "carplay.alert.coolant_high".localized, Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: "carplay.alert.coolant_warning".localized, Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        }

        // High oil temperature
        if state.oilTemperature > 130 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: "carplay.alert.oil_high".localized, Int(state.oilTemperature)),
                timestamp: Date()
            ))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(
                type: .temperature,
                message: String(format: "carplay.alert.oil_warning".localized, Int(state.oilTemperature)),
                timestamp: Date()
            ))
        }

        // Low battery voltage
        if state.batteryVoltage < 11.5 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: "carplay.alert.battery_low".localized, state.batteryVoltage),
                timestamp: Date()
            ))
        } else if state.batteryVoltage < 12.0 && state.batteryVoltage > 0 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: "carplay.alert.battery_warning".localized, state.batteryVoltage),
                timestamp: Date()
            ))
        }

        // High RPM warning for rotary engine
        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(
                type: .system,
                message: String(format: "carplay.alert.rpm_high".localized, state.rpm),
                timestamp: Date()
            ))
        }

        // Low oil pressure (if we have that data)
        if state.oilPressure < 1.5 && state.rpm > 1000 {
            newAlerts.append(CarPlayAlert(
                type: .pressure,
                message: String(format: "carplay.alert.oil_pressure_low".localized, state.oilPressure),
                timestamp: Date()
            ))
        }

        alerts = newAlerts
    }
}

// MARK: - String Localization Extension for CarPlay

extension String {
    var localized: String {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        let languageCode: String

        if savedLanguage == "system" {
            languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            languageCode = savedLanguage
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        }

        return NSLocalizedString(self, comment: "")
    }
}
