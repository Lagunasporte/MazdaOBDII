import CarPlay
import SwiftUI
import Combine

// MARK: - CarPlay Scene Delegate
// Dashboard diseñado para ser lo más parecido posible a la app iOS
// Usa colores naranja RX-8, iconos dinámicos y emojis para máximo impacto visual

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var carPlayDashboard = RX8CarPlayDashboard()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Color naranja RX-8
    private let rx8Orange = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        print("CarPlay: Connected to Renesis Monitor RX8")
        self.interfaceController = interfaceController

        setupDataSubscription()

        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true) { success, error in
            if let error = error {
                print("CarPlay: Error setting root template: \(error)")
            } else {
                print("CarPlay: Dashboard loaded successfully")
            }
        }

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

    // MARK: - Root Template (Tab Bar - 4 tabs como iOS)

    private func createRootTemplate() -> CPTemplate {
        let dashboardTab = createDashboardTab()
        let engineTab = createEngineTab()
        let fuelTab = createFuelTab()
        let alertsTab = createAlertsTab()

        let tabBar = CPTabBarTemplate(templates: [dashboardTab, engineTab, fuelTab, alertsTab])
        return tabBar
    }

    // MARK: - Tab 1: Dashboard Principal (Grid como gauges de iOS)

    private func createDashboardTab() -> CPGridTemplate {
        let gridButtons = [
            // RPM - Principal como en iOS
            createGaugeGridButton(
                emoji: rpmEmoji,
                value: "\(carPlayDashboard.rpm)",
                label: "RPM",
                color: rpmColor
            ),
            // Velocidad
            createGaugeGridButton(
                emoji: "🏎️",
                value: String(format: "%.0f", carPlayDashboard.speed),
                label: "km/h",
                color: .systemBlue
            ),
            // Refrigerante
            createGaugeGridButton(
                emoji: coolantEmoji,
                value: String(format: "%.0f°", carPlayDashboard.coolantTemp),
                label: "Refrig.",
                color: coolantColor
            ),
            // Aceite
            createGaugeGridButton(
                emoji: oilEmoji,
                value: carPlayDashboard.oilTemp > 50 ? String(format: "%.0f°", carPlayDashboard.oilTemp) : "--",
                label: "Aceite",
                color: oilColor
            ),
            // Voltaje
            createGaugeGridButton(
                emoji: voltageEmoji,
                value: String(format: "%.1f", carPlayDashboard.batteryVoltage),
                label: "Voltios",
                color: voltageColor
            ),
            // Combustible
            createGaugeGridButton(
                emoji: fuelEmoji,
                value: String(format: "%.0f%%", carPlayDashboard.fuelLevel),
                label: "Comb.",
                color: fuelColor
            )
        ]

        let template = CPGridTemplate(title: "🔶 Renesis Monitor RX-8", gridButtons: gridButtons)
        template.tabTitle = "Dashboard"
        template.tabImage = UIImage(systemName: "gauge.with.dots.needle.bottom.50percent")

        return template
    }

    private func createGaugeGridButton(emoji: String, value: String, label: String, color: UIColor) -> CPGridButton {
        // Crear icono con el símbolo apropiado
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
        var image = UIImage(systemName: "circle.fill", withConfiguration: config) ?? UIImage()
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)

        // Formato: emoji + valor grande + etiqueta
        let title = "\(emoji) \(value)\n\(label)"

        return CPGridButton(titleVariants: [title, "\(emoji)\(value)"], image: image) { [weak self] _ in
            self?.showDetailForGauge(label)
        }
    }

    // MARK: - Tab 2: Motor (Lista detallada como iOS)

    private func createEngineTab() -> CPListTemplate {
        // Sección: Temperaturas (como las tarjetas de iOS)
        let tempSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: coolantEmoji,
                    title: "🌡️ Refrigerante",
                    value: String(format: "%.1f °C", carPlayDashboard.coolantTemp),
                    status: coolantStatusText,
                    color: coolantColor
                ),
                createColoredListItem(
                    emoji: oilEmoji,
                    title: "🛢️ Temperatura Aceite",
                    value: carPlayDashboard.oilTemp > 50 ? String(format: "%.1f °C", carPlayDashboard.oilTemp) : "-- °C",
                    status: oilStatusText,
                    color: oilColor
                ),
                createColoredListItem(
                    emoji: "🌬️",
                    title: "💨 Temp. Admisión",
                    value: String(format: "%.1f °C", carPlayDashboard.intakeTemp),
                    status: "Normal",
                    color: .systemCyan
                )
            ],
            header: "🌡️ TEMPERATURAS",
            sectionIndexTitle: nil
        )

        // Sección: Rendimiento
        let perfSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: rpmEmoji,
                    title: "⚡ RPM",
                    value: "\(carPlayDashboard.rpm)",
                    status: rpmStatusText,
                    color: rpmColor
                ),
                createColoredListItem(
                    emoji: "🦶",
                    title: "🎚️ Acelerador",
                    value: String(format: "%.0f%%", carPlayDashboard.throttle),
                    status: "",
                    color: .systemBlue
                ),
                createColoredListItem(
                    emoji: "⚙️",
                    title: "📊 Carga Motor",
                    value: String(format: "%.0f%%", carPlayDashboard.engineLoad),
                    status: "",
                    color: .systemPurple
                )
            ],
            header: "⚡ RENDIMIENTO",
            sectionIndexTitle: nil
        )

        // Sección: Fuel Trims (importante para rotativo)
        let fuelTrimSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: stftEmoji,
                    title: "📈 STFT (Corto plazo)",
                    value: String(format: "%+.1f%%", carPlayDashboard.stft),
                    status: fuelTrimStatusText(carPlayDashboard.stft),
                    color: fuelTrimColor(carPlayDashboard.stft)
                ),
                createColoredListItem(
                    emoji: ltftEmoji,
                    title: "📉 LTFT (Largo plazo)",
                    value: String(format: "%+.1f%%", carPlayDashboard.ltft),
                    status: fuelTrimStatusText(carPlayDashboard.ltft),
                    color: fuelTrimColor(carPlayDashboard.ltft)
                )
            ],
            header: "⛽ FUEL TRIMS",
            sectionIndexTitle: nil
        )

        let template = CPListTemplate(title: "🔧 Motor", sections: [tempSection, perfSection, fuelTrimSection])
        template.tabTitle = "Motor"
        template.tabImage = UIImage(systemName: "engine.combustion")

        return template
    }

    // MARK: - Tab 3: Consumo (como vista de consumo iOS)

    private func createFuelTab() -> CPListTemplate {
        // Consumo actual
        let consumptionSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: "⛽",
                    title: "📊 Consumo Instantáneo",
                    value: carPlayDashboard.speed > 5
                        ? String(format: "%.1f L/100km", carPlayDashboard.consumption)
                        : String(format: "%.1f L/h", carPlayDashboard.consumptionPerHour),
                    status: consumptionStatusText,
                    color: consumptionColor
                ),
                createColoredListItem(
                    emoji: "📈",
                    title: "📊 Consumo Medio",
                    value: String(format: "%.1f L/100km", carPlayDashboard.avgConsumption),
                    status: "",
                    color: .systemBlue
                ),
                createColoredListItem(
                    emoji: "🛣️",
                    title: "🔋 Autonomía Estimada",
                    value: String(format: "%.0f km", carPlayDashboard.range),
                    status: rangeStatusText,
                    color: rangeColor
                )
            ],
            header: "🛣️ VIAJE ACTUAL",
            sectionIndexTitle: nil
        )

        // Depósito
        let tankSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: fuelEmoji,
                    title: "⛽ Nivel Combustible",
                    value: String(format: "%.0f%%", carPlayDashboard.fuelLevel),
                    status: fuelLevelStatusText,
                    color: fuelColor
                ),
                createColoredListItem(
                    emoji: "💧",
                    title: "🛢️ Litros Restantes",
                    value: String(format: "%.1f L", carPlayDashboard.fuelLiters),
                    status: "(Depósito 60L)",
                    color: .systemTeal
                )
            ],
            header: "⛽ DEPÓSITO",
            sectionIndexTitle: nil
        )

        // Voltaje
        let electricSection = CPListSection(
            items: [
                createColoredListItem(
                    emoji: voltageEmoji,
                    title: "🔋 Voltaje Batería",
                    value: String(format: "%.2f V", carPlayDashboard.batteryVoltage),
                    status: voltageStatusText,
                    color: voltageColor
                )
            ],
            header: "🔌 ELÉCTRICO",
            sectionIndexTitle: nil
        )

        let template = CPListTemplate(title: "⛽ Consumo", sections: [consumptionSection, tankSection, electricSection])
        template.tabTitle = "Consumo"
        template.tabImage = UIImage(systemName: "fuelpump.fill")

        return template
    }

    // MARK: - Tab 4: Alertas (como la vista de alertas iOS)

    private func createAlertsTab() -> CPListTemplate {
        var sections: [CPListSection] = []

        // Resumen de estado (como iOS)
        let statusItems = [
            createStatusListItem(
                title: "🔥 Motor",
                isOK: carPlayDashboard.coolantTemp < 100 && carPlayDashboard.oilTemp < 120
            ),
            createStatusListItem(
                title: "🔋 Sistema Eléctrico",
                isOK: carPlayDashboard.batteryVoltage >= 12.0 || carPlayDashboard.batteryVoltage == 0
            ),
            createStatusListItem(
                title: "⛽ Sistema Combustible",
                isOK: abs(carPlayDashboard.stft) < 15 && abs(carPlayDashboard.ltft) < 10
            ),
            createStatusListItem(
                title: "🛢️ Nivel Combustible",
                isOK: carPlayDashboard.fuelLevel > 15
            )
        ]

        let statusSection = CPListSection(
            items: statusItems,
            header: overallStatusHeader,
            sectionIndexTitle: nil
        )
        sections.append(statusSection)

        // Alertas activas
        if !carPlayDashboard.alerts.isEmpty {
            let alertItems = carPlayDashboard.alerts.map { alert -> CPListItem in
                let emoji = alertSeverityEmoji(alert.severity)
                let item = CPListItem(
                    text: "\(emoji) \(alert.message)",
                    detailText: "⏰ \(formatAlertTime(alert.timestamp))"
                )
                let icon = alertSeverityIcon(alert.severity)
                var image = UIImage(systemName: icon)!
                image = image.withTintColor(alertSeverityColor(alert.severity), renderingMode: .alwaysOriginal)
                item.setImage(image)
                return item
            }

            let alertSection = CPListSection(
                items: alertItems,
                header: "🚨 ALERTAS ACTIVAS (\(carPlayDashboard.alerts.count))",
                sectionIndexTitle: nil
            )
            sections.insert(alertSection, at: 0)
        }

        let tabIcon: String
        let tabTitle: String

        if carPlayDashboard.alerts.isEmpty {
            tabIcon = "checkmark.circle.fill"
            tabTitle = "✅ OK"
        } else {
            tabIcon = "exclamationmark.triangle.fill"
            tabTitle = "⚠️ \(carPlayDashboard.alerts.count)"
        }

        let template = CPListTemplate(
            title: carPlayDashboard.alerts.isEmpty ? "✅ Sistema OK" : "⚠️ Alertas",
            sections: sections
        )
        template.tabTitle = tabTitle
        template.tabImage = UIImage(systemName: tabIcon)

        return template
    }

    // MARK: - Helper: Crear item de lista con color

    private func createColoredListItem(emoji: String, title: String, value: String, status: String, color: UIColor) -> CPListItem {
        let displayTitle = title
        let displayDetail = status.isEmpty ? value : "\(value)  •  \(status)"

        let item = CPListItem(text: displayTitle, detailText: displayDetail)

        // Usar símbolo con color
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        var image = UIImage(systemName: "circle.fill", withConfiguration: config) ?? UIImage()
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)
        item.setImage(image)

        return item
    }

    private func createStatusListItem(title: String, isOK: Bool) -> CPListItem {
        let status = isOK ? "✅ OK" : "⚠️ Verificar"
        let item = CPListItem(text: title, detailText: status)

        let icon = isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let color = isOK ? UIColor.systemGreen : UIColor.systemOrange

        var image = UIImage(systemName: icon)!
        image = image.withTintColor(color, renderingMode: .alwaysOriginal)
        item.setImage(image)

        return item
    }

    // MARK: - Gauge Detail (cuando se toca un gauge)

    private func showDetailForGauge(_ gauge: String) {
        // En futuras versiones podría mostrar historial o más detalles
    }

    // MARK: - Emojis dinámicos (simulan colores de iOS)

    private var rpmEmoji: String {
        if carPlayDashboard.rpm > 8000 { return "🔴" }
        if carPlayDashboard.rpm > 7000 { return "🟠" }
        if carPlayDashboard.rpm > 5000 { return "🟡" }
        return "🟢"
    }

    private var coolantEmoji: String {
        if carPlayDashboard.coolantTemp > 105 { return "🔴" }
        if carPlayDashboard.coolantTemp > 98 { return "🟠" }
        if carPlayDashboard.coolantTemp < 70 { return "🔵" }
        return "🟢"
    }

    private var oilEmoji: String {
        if carPlayDashboard.oilTemp > 130 { return "🔴" }
        if carPlayDashboard.oilTemp > 120 { return "🟠" }
        if carPlayDashboard.oilTemp < 80 && carPlayDashboard.oilTemp > 50 { return "🔵" }
        if carPlayDashboard.oilTemp <= 50 { return "⚪" }
        return "🟢"
    }

    private var voltageEmoji: String {
        if carPlayDashboard.batteryVoltage < 11.5 && carPlayDashboard.batteryVoltage > 0 { return "🔴" }
        if carPlayDashboard.batteryVoltage < 12.5 && carPlayDashboard.batteryVoltage > 0 { return "🟠" }
        if carPlayDashboard.batteryVoltage > 14.8 { return "🟠" }
        return "🟢"
    }

    private var fuelEmoji: String {
        if carPlayDashboard.fuelLevel < 10 { return "🔴" }
        if carPlayDashboard.fuelLevel < 20 { return "🟠" }
        if carPlayDashboard.fuelLevel < 30 { return "🟡" }
        return "🟢"
    }

    private var stftEmoji: String {
        if abs(carPlayDashboard.stft) > 20 { return "🔴" }
        if abs(carPlayDashboard.stft) > 15 { return "🟠" }
        return "🟢"
    }

    private var ltftEmoji: String {
        if abs(carPlayDashboard.ltft) > 15 { return "🔴" }
        if abs(carPlayDashboard.ltft) > 10 { return "🟠" }
        return "🟢"
    }

    // MARK: - Colores (UIColor para iconos)

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
        if carPlayDashboard.consumption > 20 { return .systemRed }
        if carPlayDashboard.consumption > 15 { return .systemOrange }
        return .systemGreen
    }

    private func fuelTrimColor(_ value: Double) -> UIColor {
        if abs(value) > 20 { return .systemRed }
        if abs(value) > 15 { return .systemOrange }
        return .systemGreen
    }

    // MARK: - Textos de estado

    private var rpmStatusText: String {
        if carPlayDashboard.rpm > 8500 { return "⚠️ Zona roja!" }
        if carPlayDashboard.rpm > 7500 { return "Alto" }
        if carPlayDashboard.rpm < 800 && carPlayDashboard.rpm > 0 { return "Ralentí" }
        return "Normal"
    }

    private var coolantStatusText: String {
        if carPlayDashboard.coolantTemp > 105 { return "🔥 CRÍTICO!" }
        if carPlayDashboard.coolantTemp > 98 { return "⚠️ Alto" }
        if carPlayDashboard.coolantTemp < 70 { return "❄️ Frío" }
        return "✅ Óptimo"
    }

    private var oilStatusText: String {
        if carPlayDashboard.oilTemp > 130 { return "🔥 CRÍTICO!" }
        if carPlayDashboard.oilTemp > 120 { return "⚠️ Alto" }
        if carPlayDashboard.oilTemp < 80 && carPlayDashboard.oilTemp > 50 { return "❄️ Calentando" }
        if carPlayDashboard.oilTemp <= 50 { return "⏳ Sin datos" }
        return "✅ Óptimo"
    }

    private var voltageStatusText: String {
        if carPlayDashboard.batteryVoltage < 11.5 && carPlayDashboard.batteryVoltage > 0 { return "🔴 CRÍTICO!" }
        if carPlayDashboard.batteryVoltage < 12.5 && carPlayDashboard.batteryVoltage > 0 { return "⚠️ Bajo" }
        if carPlayDashboard.batteryVoltage > 14.8 { return "⚡ Cargando alto" }
        return "✅ Normal"
    }

    private var fuelLevelStatusText: String {
        if carPlayDashboard.fuelLevel < 10 { return "🔴 Reserva!" }
        if carPlayDashboard.fuelLevel < 20 { return "⚠️ Bajo" }
        return "✅ OK"
    }

    private var rangeStatusText: String {
        if carPlayDashboard.range < 30 { return "🔴 Repostar!" }
        if carPlayDashboard.range < 50 { return "⚠️ Bajo" }
        return ""
    }

    private var consumptionStatusText: String {
        if carPlayDashboard.consumption > 20 { return "📈 Alto" }
        if carPlayDashboard.consumption > 15 { return "Normal" }
        if carPlayDashboard.consumption > 0 { return "📉 Económico" }
        return ""
    }

    private func fuelTrimStatusText(_ value: Double) -> String {
        if abs(value) > 20 { return "🔴 Anormal!" }
        if abs(value) > 15 { return "⚠️ Revisar" }
        if abs(value) > 10 { return "Aceptable" }
        return "✅ Normal"
    }

    private var overallStatusHeader: String {
        if carPlayDashboard.alerts.isEmpty {
            return "✅ TODOS LOS SISTEMAS OK"
        } else {
            return "⚠️ ESTADO DEL SISTEMA"
        }
    }

    // MARK: - Alert Helpers

    private func alertSeverityEmoji(_ severity: RX8CarPlayDashboard.AlertSeverity) -> String {
        switch severity {
        case .critical: return "🔴"
        case .warning: return "🟠"
        case .info: return "🔵"
        }
    }

    private func alertSeverityIcon(_ severity: RX8CarPlayDashboard.AlertSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func alertSeverityColor(_ severity: RX8CarPlayDashboard.AlertSeverity) -> UIColor {
        switch severity {
        case .critical: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
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

        let dashboardTab = createDashboardTab()
        let engineTab = createEngineTab()
        let fuelTab = createFuelTab()
        let alertsTab = createAlertsTab()

        tabBar.updateTemplates([dashboardTab, engineTab, fuelTab, alertsTab])
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
        self.fuelLiters = fuelLevel * 0.6  // RX-8 = 60L tank
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

    func update(from engineState: RotaryEngineState) {
        rpm = engineState.rpm
        speed = engineState.vehicleSpeed
        coolantTemp = engineState.coolantTemperature
        oilTemp = engineState.oilTemperature
        batteryVoltage = engineState.batteryVoltage
        intakeTemp = engineState.intakeAirTemperature
        throttle = engineState.throttlePosition
        engineLoad = engineState.engineLoad
        stft = engineState.shortTermFuelTrim
        ltft = engineState.longTermFuelTrim

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

    private func checkAlerts(_ state: RotaryEngineState) {
        var newAlerts: [CarPlayAlert] = []

        // Temperatura refrigerante
        if state.coolantTemperature > 108 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "Refrigerante CRÍTICO: \(Int(state.coolantTemperature))°C",
                timestamp: Date()
            ))
        } else if state.coolantTemperature > 100 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "Refrigerante alto: \(Int(state.coolantTemperature))°C",
                timestamp: Date()
            ))
        }

        // Temperatura aceite
        if state.oilTemperature > 135 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "Aceite CRÍTICO: \(Int(state.oilTemperature))°C",
                timestamp: Date()
            ))
        } else if state.oilTemperature > 120 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "Aceite caliente: \(Int(state.oilTemperature))°C",
                timestamp: Date()
            ))
        }

        // Voltaje batería
        if state.batteryVoltage > 0 && state.batteryVoltage < 11.5 {
            newAlerts.append(CarPlayAlert(
                severity: .critical,
                message: "Batería CRÍTICA: \(String(format: "%.1f", state.batteryVoltage))V",
                timestamp: Date()
            ))
        } else if state.batteryVoltage > 0 && state.batteryVoltage < 12.5 && state.rpm > 1000 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "Batería baja: \(String(format: "%.1f", state.batteryVoltage))V",
                timestamp: Date()
            ))
        }

        // RPM alto
        if state.rpm > 8500 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "RPM en zona roja: \(state.rpm)",
                timestamp: Date()
            ))
        }

        // Fuel trims
        if state.rpm > 800 {
            if abs(state.shortTermFuelTrim) > 25 {
                newAlerts.append(CarPlayAlert(
                    severity: .warning,
                    message: "STFT anormal: \(String(format: "%+.1f", state.shortTermFuelTrim))%",
                    timestamp: Date()
                ))
            }
            if abs(state.longTermFuelTrim) > 15 {
                newAlerts.append(CarPlayAlert(
                    severity: .warning,
                    message: "LTFT fuera de rango: \(String(format: "%+.1f", state.longTermFuelTrim))%",
                    timestamp: Date()
                ))
            }
        }

        // Combustible bajo
        if fuelLevel > 0 && fuelLevel < 10 {
            newAlerts.append(CarPlayAlert(
                severity: .warning,
                message: "Combustible en reserva!",
                timestamp: Date()
            ))
        }

        alerts = newAlerts
    }
}
