import Foundation
import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var engineData: EngineData { EngineData.shared }

    // MARK: - CPTemplateApplicationSceneDelegate
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let rootTemplate = createDashboardTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)

        // Start data refresh timer
        startDataRefresh()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Templates
    private func createDashboardTemplate() -> CPTemplate {
        let tabBar = CPTabBarTemplate(templates: [
            createGaugesTemplate(),
            createTemperaturesTemplate(),
            createAlertsTemplate()
        ])
        return tabBar
    }

    private func createGaugesTemplate() -> CPTemplate {
        let section = CPListSection(items: [
            createGaugeItem(title: "RPM", value: "\(Int(engineData.rpm))", detail: "rpm"),
            createGaugeItem(title: "Velocidad", value: "\(Int(engineData.speed))", detail: "km/h"),
            createGaugeItem(title: "Turbo", value: String(format: "%.2f", engineData.boostPressure), detail: "bar"),
            createGaugeItem(title: "Acelerador", value: String(format: "%.0f", engineData.throttlePosition), detail: "%")
        ])

        let template = CPListTemplate(title: "Gauges", sections: [section])
        template.tabTitle = "Gauges"
        template.tabImage = UIImage(systemName: "gauge")

        return template
    }

    private func createTemperaturesTemplate() -> CPTemplate {
        let section = CPListSection(items: [
            createTemperatureItem(title: "Refrigerante", value: engineData.coolantTemp, status: engineData.coolantStatus),
            createTemperatureItem(title: "Aceite Motor", value: engineData.oilTemp, status: engineData.oilTempStatus),
            createTemperatureItem(title: "Admisión", value: engineData.intakeTemp, status: .normal),
            createTemperatureItem(title: "DSG", value: engineData.dsgOilTemp, status: .normal)
        ])

        let template = CPListTemplate(title: "Temperaturas", sections: [section])
        template.tabTitle = "Temp"
        template.tabImage = UIImage(systemName: "thermometer")

        return template
    }

    private func createAlertsTemplate() -> CPTemplate {
        var items: [CPListItem] = []

        if engineData.coolantStatus == .warning || engineData.coolantStatus == .critical {
            items.append(createAlertItem(
                title: "Temperatura refrigerante alta",
                detail: String(format: "%.0f°C", engineData.coolantTemp),
                severity: engineData.coolantStatus
            ))
        }

        if engineData.oilTempStatus == .warning || engineData.oilTempStatus == .critical {
            items.append(createAlertItem(
                title: "Temperatura aceite alta",
                detail: String(format: "%.0f°C", engineData.oilTemp),
                severity: engineData.oilTempStatus
            ))
        }

        if engineData.boostStatus == .warning || engineData.boostStatus == .critical {
            items.append(createAlertItem(
                title: "Presión turbo alta",
                detail: String(format: "%.2f bar", engineData.boostPressure),
                severity: engineData.boostStatus
            ))
        }

        if items.isEmpty {
            items.append(CPListItem(
                text: "Sin alertas",
                detailText: "Todo funcionando correctamente"
            ))
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Alertas", sections: [section])
        template.tabTitle = "Alertas"
        template.tabImage = UIImage(systemName: "exclamationmark.triangle")

        return template
    }

    // MARK: - List Items
    private func createGaugeItem(title: String, value: String, detail: String) -> CPListItem {
        let item = CPListItem(text: title, detailText: "\(value) \(detail)")
        return item
    }

    private func createTemperatureItem(title: String, value: Double, status: AlertLevel) -> CPListItem {
        let item = CPListItem(
            text: title,
            detailText: String(format: "%.0f°C", value)
        )

        // Set accessory based on status
        switch status {
        case .normal:
            item.accessoryType = .none
        case .warning:
            item.accessoryType = .disclosureIndicator
        case .critical:
            item.accessoryType = .disclosureIndicator
        }

        return item
    }

    private func createAlertItem(title: String, detail: String, severity: AlertLevel) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail)
        item.accessoryType = .disclosureIndicator
        return item
    }

    // MARK: - Data Refresh
    private var refreshTimer: Timer?

    private func startDataRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTemplates()
        }
    }

    private func refreshTemplates() {
        guard let interfaceController = interfaceController else { return }

        // Rebuild templates with updated data
        let rootTemplate = createDashboardTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)
    }
}

// MARK: - Scene Configuration
extension CarPlaySceneDelegate {

    static func configureCarPlayScene() -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "CarPlay", sessionRole: .carTemplateApplication)
        config.delegateClass = CarPlaySceneDelegate.self
        return config
    }
}
