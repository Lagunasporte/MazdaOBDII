import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// Beautiful dashboard for Mazda RX-8 rotary engine monitoring
// Designed to match the iOS app aesthetic with orange RX-8 branding

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var carPlayDashboard = RX8CarPlayDashboard()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        print("CarPlay: Connected to Renesis Monitor RX8")
        self.interfaceController = interfaceController

        // Subscribe to shared data provider updates
        setupDataSubscription()

        // Create and set root template
        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true) { success, error in
            if let error = error {
                print("CarPlay: Error setting root template: \(error)")
            } else {
                print("CarPlay: Dashboard loaded successfully")
            }
        }

        // Start updates at 1Hz (CarPlay refresh rate)
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

    // MARK: - Root Template (Tab Bar with 4 tabs)

    private func createRootTemplate() -> CPTemplate {
        let gaugesTab = createGaugesTab()
        let engineTab = createEngineTab()
        let fuelTab = createFuelTab()
        let alertsTab = createAlertsTab()

        let tabBar = CPTabBarTemplate(templates: [gaugesTab, engineTab, fuelTab, alertsTab])
        return tabBar
    }

    // MARK: - Tab 1: Main Gauges (Grid Layout)

    private func createGaugesTab() -> CPGridTemplate {
        let gridButtons = [
            // RPM Gauge
            createGaugeButton(
                title: "RPM",
                value: "\(carPlayDashboard.rpm)",
                icon: rpmIcon,
                isHighlighted: carPlayDashboard.rpm > 7000
            ),
            // Speed
            createGaugeButton(
                title: NSLocalizedString("carplay.speed", comment: ""),
                value: String(format: "%.0f", carPlayDashboard.speed),
                icon: "speedometer",
                isHighlighted: false
            ),
            // Coolant Temperature
            createGaugeButton(
                title: NSLocalizedString("carplay.coolant", comment: ""),
                value: String(format: "%.0f°", carPlayDashboard.coolantTemp),
                icon: coolantIcon,
                isHighlighted: carPlayDashboard.coolantTemp > 100
            ),
            // Oil Temperature
            createGaugeButton(
                title: NSLocalizedString("carplay.oil", comment: ""),
                value: carPlayDashboard.oilTemp > 50 ? String(format: "%.0f°", carPlayDashboard.oilTemp) : "--",
                icon: oilIcon,
                isHighlighted: carPlayDashboard.oilTemp > 120
            ),
            // Battery Voltage
            createGaugeButton(
                title: NSLocalizedString("carplay.voltage", comment: ""),
                value: String(format: "%.1fV", carPlayDashboard.batteryVoltage),
                icon: voltageIcon,
                isHighlighted: carPlayDashboard.batteryVoltage < 12.0 && carPlayDashboard.batteryVoltage > 0
            ),
            // Fuel Level
            createGaugeButton(
                title: NSLocalizedString("carplay.fuel", comment: ""),
                value: String(format: "%.0f%%", carPlayDashboard.fuelLevel),
                icon: fuelIcon,
                isHighlighted: carPlayDashboard.fuelLevel < 15
            )
        ]

        let template = CPGridTemplate(title: "Renesis Monitor", gridButtons: gridButtons)
        template.tabTitle = "Gauges"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.bottom.50percent")

        return template
    }

    private func createGaugeButton(title: String, value: String, icon: String, isHighlighted: Bool) -> CPGridButton {
        // Create SF Symbol image with appropriate rendering
        var image = UIImage(systemName: icon) ?? UIImage(systemName: "questionmark.circle")!

        // Use orange tint for highlighted/warning states
        if isHighlighted {
            image = image.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
        }

        // Title variants: first is preferred, second is fallback for smaller displays
        let fullTitle = "\(value)\n\(title)"
        let shortTitle = value

        return CPGridButton(titleVariants: [fullTitle, shortTitle], image: image) { [weak self] _ in
            // Show detail view when tapped
            self?.showGaugeDetail(for: title)
        }
    }

    // MARK: - Tab 2: Engine Details (List Layout)

    private func createEngineTab() -> CPListTemplate {
        // Section 1: Temperatures
        let tempItems = [
            createDetailItem(
                title: NSLocalizedString("carplay.coolant_temp", comment: ""),
                value: String(format: "%.1f °C", carPlayDashboard.coolantTemp),
                icon: coolantIcon,
                status: coolantStatus
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.oil_temp", comment: ""),
                value: carPlayDashboard.oilTemp > 50 ? String(format: "%.1f °C", carPlayDashboard.oilTemp) : "-- °C",
                icon: oilIcon,
                status: oilStatus
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.intake_temp", comment: ""),
                value: String(format: "%.1f °C", carPlayDashboard.intakeTemp),
                icon: "wind",
                status: .normal
            )
        ]
        let tempSection = CPListSection(
            items: tempItems,
            header: NSLocalizedString("carplay.section.temperatures", comment: ""),
            sectionIndexTitle: nil
        )

        // Section 2: Performance
        let perfItems = [
            createDetailItem(
                title: "RPM",
                value: "\(carPlayDashboard.rpm)",
                icon: rpmIcon,
                status: rpmStatus
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.throttle", comment: ""),
                value: String(format: "%.0f%%", carPlayDashboard.throttle),
                icon: "pedal.accelerator",
                status: .normal
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.engine_load", comment: ""),
                value: String(format: "%.0f%%", carPlayDashboard.engineLoad),
                icon: "engine.combustion",
                status: .normal
            )
        ]
        let perfSection = CPListSection(
            items: perfItems,
            header: NSLocalizedString("carplay.section.performance", comment: ""),
            sectionIndexTitle: nil
        )

        // Section 3: Fuel System
        let fuelItems = [
            createDetailItem(
                title: "STFT",
                value: String(format: "%+.1f%%", carPlayDashboard.stft),
                icon: fuelTrimIcon(carPlayDashboard.stft),
                status: fuelTrimStatus(carPlayDashboard.stft)
            ),
            createDetailItem(
                title: "LTFT",
                value: String(format: "%+.1f%%", carPlayDashboard.ltft),
                icon: fuelTrimIcon(carPlayDashboard.ltft),
                status: fuelTrimStatus(carPlayDashboard.ltft)
            )
        ]
        let fuelSection = CPListSection(
            items: fuelItems,
            header: NSLocalizedString("carplay.section.fuel_system", comment: ""),
            sectionIndexTitle: nil
        )

        let template = CPListTemplate(title: NSLocalizedString("carplay.engine_title", comment: ""), sections: [tempSection, perfSection, fuelSection])
        template.tabTitle = NSLocalizedString("carplay.tab.engine", comment: "")
        template.tabImage = UIImage(systemName: "engine.combustion")

        return template
    }

    // MARK: - Tab 3: Fuel & Consumption

    private func createFuelTab() -> CPListTemplate {
        // Section 1: Current Trip
        let tripItems = [
            createDetailItem(
                title: NSLocalizedString("carplay.instant_consumption", comment: ""),
                value: carPlayDashboard.speed > 5
                    ? String(format: "%.1f L/100km", carPlayDashboard.consumption)
                    : String(format: "%.1f L/h", carPlayDashboard.consumptionPerHour),
                icon: "fuelpump.fill",
                status: .normal
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.average_consumption", comment: ""),
                value: String(format: "%.1f L/100km", carPlayDashboard.avgConsumption),
                icon: "chart.line.uptrend.xyaxis",
                status: .normal
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.estimated_range", comment: ""),
                value: String(format: "%.0f km", carPlayDashboard.range),
                icon: "road.lanes",
                status: rangeStatus
            )
        ]
        let tripSection = CPListSection(
            items: tripItems,
            header: NSLocalizedString("carplay.section.trip", comment: ""),
            sectionIndexTitle: nil
        )

        // Section 2: Fuel Tank
        let tankItems = [
            createDetailItem(
                title: NSLocalizedString("carplay.fuel_level", comment: ""),
                value: String(format: "%.0f%%", carPlayDashboard.fuelLevel),
                icon: fuelIcon,
                status: fuelLevelStatus
            ),
            createDetailItem(
                title: NSLocalizedString("carplay.fuel_remaining", comment: ""),
                value: String(format: "%.1f L", carPlayDashboard.fuelLiters),
                icon: "drop.fill",
                status: .normal
            )
        ]
        let tankSection = CPListSection(
            items: tankItems,
            header: NSLocalizedString("carplay.section.tank", comment: ""),
            sectionIndexTitle: nil
        )

        let template = CPListTemplate(title: NSLocalizedString("carplay.fuel_title", comment: ""), sections: [tripSection, tankSection])
        template.tabTitle = NSLocalizedString("carplay.tab.fuel", comment: "")
        template.tabImage = UIImage(systemName: "fuelpump")

        return template
    }

    // MARK: - Tab 4: Alerts

    private func createAlertsTab() -> CPListTemplate {
        var sections: [CPListSection] = []

        // Active Alerts Section
        if !carPlayDashboard.alerts.isEmpty {
            let alertItems = carPlayDashboard.alerts.map { alert -> CPListItem in
                let item = CPListItem(text: alert.message, detailText: formatAlertTime(alert.timestamp))
                item.setImage(UIImage(systemName: alertIcon(for: alert.severity)))
                return item
            }
            let alertSection = CPListSection(
                items: alertItems,
                header: "⚠️ " + NSLocalizedString("carplay.section.active_alerts", comment: ""),
                sectionIndexTitle: nil
            )
            sections.append(alertSection)
        }

        // System Status Section
        let statusItems = [
            createStatusItem(
                title: NSLocalizedString("carplay.status.engine", comment: ""),
                isOK: carPlayDashboard.coolantTemp < 100 && carPlayDashboard.oilTemp < 120
            ),
            createStatusItem(
                title: NSLocalizedString("carplay.status.electrical", comment: ""),
                isOK: carPlayDashboard.batteryVoltage >= 12.0 || carPlayDashboard.batteryVoltage == 0
            ),
            createStatusItem(
                title: NSLocalizedString("carplay.status.fuel_system", comment: ""),
                isOK: abs(carPlayDashboard.stft) < 15 && abs(carPlayDashboard.ltft) < 10
            )
        ]
        let statusSection = CPListSection(
            items: statusItems,
            header: NSLocalizedString("carplay.section.system_status", comment: ""),
            sectionIndexTitle: nil
        )
        sections.append(statusSection)

        // If no alerts, show all clear message
        if carPlayDashboard.alerts.isEmpty {
            let okItem = CPListItem(
                text: NSLocalizedString("carplay.all_systems_ok", comment: ""),
                detailText: NSLocalizedString("carplay.no_active_alerts", comment: "")
            )
            okItem.setImage(UIImage(systemName: "checkmark.shield.fill"))
            let okSection = CPListSection(items: [okItem], header: nil, sectionIndexTitle: nil)
            sections.insert(okSection, at: 0)
        }

        let template = CPListTemplate(title: NSLocalizedString("carplay.alerts_title", comment: ""), sections: sections)
        template.tabTitle = NSLocalizedString("carplay.tab.alerts", comment: "")

        // Show warning badge if alerts exist
        if carPlayDashboard.alerts.isEmpty {
            template.tabImage = UIImage(systemName: "checkmark.circle")
        } else {
            template.tabImage = UIImage(systemName: "exclamationmark.triangle.fill")
        }

        return template
    }

    // MARK: - Helper: Create Detail Item with Status

    private enum ItemStatus {
        case normal
        case warning
        case critical
    }

    private func createDetailItem(title: String, value: String, icon: String, status: ItemStatus) -> CPListItem {
        let item = CPListItem(text: title, detailText: value)

        var image = UIImage(systemName: icon) ?? UIImage(systemName: "questionmark.circle")!

        switch status {
        case .normal:
            // Default system color
            break
        case .warning:
            image = image.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
        case .critical:
            image = image.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        }

        item.setImage(image)
        return item
    }

    private func createStatusItem(title: String, isOK: Bool) -> CPListItem {
        let item = CPListItem(
            text: title,
            detailText: isOK ? "OK" : NSLocalizedString("carplay.status.check", comment: "")
        )
        let icon = isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        var image = UIImage(systemName: icon)!
        image = image.withTintColor(isOK ? .systemGreen : .systemOrange, renderingMode: .alwaysOriginal)
        item.setImage(image)
        return item
    }

    // MARK: - Gauge Detail View

    private func showGaugeDetail(for gauge: String) {
        // Could show more detailed information when a gauge is tapped
        // For now, just a simple action
    }

    // MARK: - Status Icons and Colors

    private var rpmIcon: String {
        if carPlayDashboard.rpm > 8000 { return "gauge.with.dots.needle.100percent" }
        if carPlayDashboard.rpm > 6000 { return "gauge.with.dots.needle.67percent" }
        if carPlayDashboard.rpm > 3000 { return "gauge.with.dots.needle.50percent" }
        return "gauge.with.dots.needle.33percent"
    }

    private var rpmStatus: ItemStatus {
        if carPlayDashboard.rpm > 8500 { return .critical }
        if carPlayDashboard.rpm > 7500 { return .warning }
        return .normal
    }

    private var coolantIcon: String {
        if carPlayDashboard.coolantTemp > 100 { return "thermometer.high" }
        if carPlayDashboard.coolantTemp < 70 { return "thermometer.low" }
        return "thermometer.medium"
    }

    private var coolantStatus: ItemStatus {
        if carPlayDashboard.coolantTemp > 105 { return .critical }
        if carPlayDashboard.coolantTemp > 100 { return .warning }
        return .normal
    }

    private var oilIcon: String {
        if carPlayDashboard.oilTemp > 120 { return "drop.triangle.fill" }
        if carPlayDashboard.oilTemp < 80 && carPlayDashboard.oilTemp > 50 { return "drop" }
        return "drop.fill"
    }

    private var oilStatus: ItemStatus {
        if carPlayDashboard.oilTemp > 130 { return .critical }
        if carPlayDashboard.oilTemp > 120 { return .warning }
        return .normal
    }

    private var voltageIcon: String {
        if carPlayDashboard.batteryVoltage < 12.0 && carPlayDashboard.batteryVoltage > 0 {
            return "battery.25percent"
        }
        if carPlayDashboard.batteryVoltage > 14.5 {
            return "battery.100percent.bolt"
        }
        return "battery.100percent"
    }

    private var fuelIcon: String {
        if carPlayDashboard.fuelLevel < 15 { return "fuelpump.exclamationmark.fill" }
        if carPlayDashboard.fuelLevel < 25 { return "fuelpump.fill" }
        return "fuelpump.fill"
    }

    private var fuelLevelStatus: ItemStatus {
        if carPlayDashboard.fuelLevel < 10 { return .critical }
        if carPlayDashboard.fuelLevel < 20 { return .warning }
        return .normal
    }

    private var rangeStatus: ItemStatus {
        if carPlayDashboard.range < 30 { return .critical }
        if carPlayDashboard.range < 50 { return .warning }
        return .normal
    }

    private func fuelTrimIcon(_ value: Double) -> String {
        if abs(value) > 15 { return "exclamationmark.triangle" }
        if abs(value) > 10 { return "arrow.left.arrow.right" }
        return "equal.circle"
    }

    private func fuelTrimStatus(_ value: Double) -> ItemStatus {
        if abs(value) > 20 { return .critical }
        if abs(value) > 15 { return .warning }
        return .normal
    }

    private func alertIcon(for severity: RX8CarPlayDashboard.AlertSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    // MARK: - Updates

    private func startUpdates() {
        // Update every second - CarPlay's comfortable refresh rate
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

        // Recreate all tabs with updated data
        let gaugesTab = createGaugesTab()
        let engineTab = createEngineTab()
        let fuelTab = createFuelTab()
        let alertsTab = createAlertsTab()

        tabBar.updateTemplates([gaugesTab, engineTab, fuelTab, alertsTab])
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
    public var consumptionPerHour: Double = 0
    public var avgConsumption: Double = 0
    public var fuelLiters: Double = 0

    public init(instantConsumption: Double = 0, estimatedRange: Double = 0, fuelLevel: Double = 0) {
        self.instantConsumption = instantConsumption
        self.estimatedRange = estimatedRange
        self.fuelLevel = fuelLevel
        // Calculate liters from percentage (RX-8 has 60L tank)
        self.fuelLiters = fuelLevel * 0.6
    }
}

// MARK: - CarPlay Dashboard Data Model

class RX8CarPlayDashboard: ObservableObject {
    // Main Gauges
    @Published var rpm: Int = 0
    @Published var speed: Double = 0
    @Published var coolantTemp: Double = 0
    @Published var oilTemp: Double = 0
    @Published var batteryVoltage: Double = 0
    @Published var intakeTemp: Double = 0

    // Fuel Data
    @Published var fuelLevel: Double = 0
    @Published var fuelLiters: Double = 0
    @Published var consumption: Double = 0
    @Published var consumptionPerHour: Double = 0
    @Published var avgConsumption: Double = 0
    @Published var range: Double = 0

    // Engine Details
    @Published var throttle: Double = 0
    @Published var engineLoad: Double = 0
    @Published var stft: Double = 0
    @Published var ltft: Double = 0

    // Alerts
    @Published var alerts: [CarPlayAlert] = []

    // MARK: - Alert Model

    struct CarPlayAlert: Identifiable {
        let id = UUID()
        let severity: AlertSeverity
        let message: String
        let timestamp: Date
    }

    enum AlertSeverity {
        case info
        case warning
        case critical
    }

    // MARK: - Update from Engine State

    func update(from engineState: RotaryEngineState) {
        // Main gauges
        rpm = engineState.rpm
        speed = engineState.vehicleSpeed
        coolantTemp = engineState.coolantTemperature
        oilTemp = engineState.oilTemperature
        batteryVoltage = engineState.batteryVoltage
        intakeTemp = engineState.intakeAirTemperature

        // Engine details
        throttle = engineState.throttlePosition
        engineLoad = engineState.engineLoad
        stft = engineState.shortTermFuelTrim
        ltft = engineState.longTermFuelTrim

        // Check for alerts
        checkAlerts(engineState)
    }

    func updateFuel(from data: CarPlayFuelData) {
        consumption = data.instantConsumption
        range = data.estimatedRange
        fuelLevel = data.fuelLevel
        fuelLiters = data.fuelLiters
        avgConsumption = data.avgConsumption
        consumptionPerHour = data.consumptionPerHour
    }

    // MARK: - Alert Checking

    private func checkAlerts(_ state: RotaryEngineState) {
        var newAlerts: [CarPlayAlert] = []

        // Critical: Very high coolant temp
        if state.coolantTemperature > 108 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "🔥 " + String(format: NSLocalizedString("carplay.alert.coolant_critical", comment: ""), Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "⚠️ " + String(format: NSLocalizedString("carplay.alert.coolant_high", comment: ""), Int(state.coolantTemperature)),
                timestamp: Date()
            ))
        }

        // Critical: Very high oil temp
        if state.oilTemperature > 135 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "🔥 " + String(format: NSLocalizedString("carplay.alert.oil_critical", comment: ""), Int(state.oilTemperature)),
                timestamp: Date()
            ))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "⚠️ " + String(format: NSLocalizedString("carplay.alert.oil_high", comment: ""), Int(state.oilTemperature)),
                timestamp: Date()
            ))
        }

        // Low battery voltage (only when engine is running)
        if state.batteryVoltage > 0 && state.batteryVoltage < 11.5 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "🔋 " + String(format: NSLocalizedString("carplay.alert.voltage_critical", comment: ""), state.batteryVoltage),
                timestamp: Date()
            ))
        } else if state.batteryVoltage > 0 && state.batteryVoltage < 12.5 && state.rpm > 1000 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "🔋 " + String(format: NSLocalizedString("carplay.alert.voltage_low", comment: ""), state.batteryVoltage),
                timestamp: Date()
            ))
        }

        // High RPM warning for rotary engine
        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "🔴 " + String(format: NSLocalizedString("carplay.alert.high_rpm", comment: ""), state.rpm),
                timestamp: Date()
            ))
        }

        // Fuel trim warnings (engine running)
        if state.rpm > 800 {
            if abs(state.shortTermFuelTrim) > 25 {
                newAlerts.append(CarPlayAlert(
                    severity: .warning,
                    message: "⛽ " + String(format: NSLocalizedString("carplay.alert.stft_high", comment: ""), state.shortTermFuelTrim),
                    timestamp: Date()
                ))
            }
            if abs(state.longTermFuelTrim) > 15 {
                newAlerts.append(CarPlayAlert(
                    severity: .warning,
                    message: "⛽ " + String(format: NSLocalizedString("carplay.alert.ltft_high", comment: ""), state.longTermFuelTrim),
                    timestamp: Date()
                ))
            }
        }

        // Low fuel warning
        if fuelLevel > 0 && fuelLevel < 10 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "⛽ " + NSLocalizedString("carplay.alert.fuel_low", comment: ""),
                timestamp: Date()
            ))
        }

        alerts = newAlerts
    }
}
