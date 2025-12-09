import CarPlay
import SwiftUI

// MARK: - CarPlay Scene Delegate
// UI estética orientada a relojes e información de conducción

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var engineMonitor: EngineMonitor?
    private var updateTimer: Timer?

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        // Crear template principal
        let rootTemplate = createDashboardTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)

        // Iniciar actualizaciones
        startUpdates()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        stopUpdates()
    }

    // MARK: - Templates

    private func createDashboardTemplate() -> CPTemplate {
        // Usar CPInformationTemplate para mostrar datos
        let template = CPInformationTemplate(
            title: "RX-8 Dashboard",
            layout: .twoColumn,
            items: createDashboardItems(),
            actions: createDashboardActions()
        )

        return template
    }

    private func createDashboardItems() -> [CPInformationItem] {
        return [
            CPInformationItem(title: "RPM", detail: "0"),
            CPInformationItem(title: "Velocidad", detail: "0 km/h"),
            CPInformationItem(title: "Refrigerante", detail: "-- °C"),
            CPInformationItem(title: "Aceite", detail: "-- °C"),
            CPInformationItem(title: "Consumo", detail: "-- L/100"),
            CPInformationItem(title: "Autonomía", detail: "-- km")
        ]
    }

    private func createDashboardActions() -> [CPTextButton] {
        return [
            CPTextButton(title: "Gauges", textStyle: .normal) { [weak self] _ in
                self?.showGaugesTemplate()
            },
            CPTextButton(title: "Alertas", textStyle: .normal) { [weak self] _ in
                self?.showAlertsTemplate()
            }
        ]
    }

    // MARK: - Gauge Template (Relojes)

    private func showGaugesTemplate() {
        // CPInstrumentClusterController no está disponible para apps de terceros
        // Usamos CPGridTemplate para mostrar relojes visuales

        let gridButtons = [
            createGaugeButton(title: "RPM", value: "0", icon: "gauge.with.dots.needle.bottom.50percent"),
            createGaugeButton(title: "Velocidad", value: "0", icon: "speedometer"),
            createGaugeButton(title: "Temp Motor", value: "0°C", icon: "thermometer"),
            createGaugeButton(title: "Temp Aceite", value: "0°C", icon: "drop.fill"),
            createGaugeButton(title: "Consumo", value: "0.0", icon: "fuelpump"),
            createGaugeButton(title: "Voltaje", value: "0V", icon: "bolt.fill")
        ]

        let gridTemplate = CPGridTemplate(title: "Instrumentos", gridButtons: gridButtons)
        interfaceController?.pushTemplate(gridTemplate, animated: true, completion: nil)
    }

    private func createGaugeButton(title: String, value: String, icon: String) -> CPGridButton {
        // Crear imagen del sistema
        let image = UIImage(systemName: icon) ?? UIImage()

        return CPGridButton(titleVariants: ["\(title)\n\(value)"], image: image) { _ in
            // Acción al pulsar el botón
        }
    }

    // MARK: - Alerts Template

    private func showAlertsTemplate() {
        let items = [
            CPListItem(text: "Sin alertas activas", detailText: "Todos los sistemas OK"),
        ]

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: "Alertas", sections: [section])
        interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
    }

    // MARK: - Updates

    private func startUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDashboard()
        }
    }

    private func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateDashboard() {
        // Actualizar valores del dashboard
        // En implementación real, leer de engineMonitor
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

    @Published var alerts: [CarPlayAlert] = []

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

        var icon: String {
            switch self {
            case .temperature: return "thermometer.high"
            case .pressure: return "gauge.with.dots.needle.33percent"
            case .system: return "exclamationmark.triangle"
            }
        }
    }

    func update(from engineState: RotaryEngineState) {
        rpm = engineState.rpm
        speed = engineState.vehicleSpeed
        coolantTemp = engineState.coolantTemperature
        oilTemp = engineState.oilTemperature
        batteryVoltage = engineState.batteryVoltage

        // Verificar alertas
        checkAlerts(engineState)
    }

    private func checkAlerts(_ state: RotaryEngineState) {
        alerts.removeAll()

        if state.coolantTemperature > 100 {
            alerts.append(CarPlayAlert(
                type: .temperature,
                message: "Refrigerante: \(Int(state.coolantTemperature))°C",
                timestamp: Date()
            ))
        }

        if state.oilTemperature > 120 {
            alerts.append(CarPlayAlert(
                type: .temperature,
                message: "Aceite: \(Int(state.oilTemperature))°C",
                timestamp: Date()
            ))
        }

        if state.batteryVoltage < 12 {
            alerts.append(CarPlayAlert(
                type: .system,
                message: "Batería baja: \(String(format: "%.1f", state.batteryVoltage))V",
                timestamp: Date()
            ))
        }
    }
}
