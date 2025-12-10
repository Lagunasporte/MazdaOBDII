import Foundation
import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        }
    }
}

// MARK: - Localization Manager

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            updateBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
        updateBundle()
    }

    private func updateBundle() {
        let languageCode: String

        if currentLanguage == .system {
            languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            languageCode = currentLanguage.rawValue
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            // Fallback to English
            self.bundle = bundle
        } else {
            self.bundle = .main
        }

        // Force UI update
        objectWillChange.send()
    }

    func localizedString(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
}

// MARK: - String Extension for Localization

extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys for type-safe access
struct L10n {
    // MARK: - Common
    struct Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let save = "common.save"
        static let delete = "common.delete"
        static let close = "common.close"
        static let done = "common.done"
        static let error = "common.error"
        static let warning = "common.warning"
        static let success = "common.success"
        static let loading = "common.loading"
        static let retry = "common.retry"
        static let settings = "common.settings"
        static let back = "common.back"
        static let next = "common.next"
        static let yes = "common.yes"
        static let no = "common.no"
    }

    // MARK: - Tabs
    struct Tabs {
        static let dashboard = "tabs.dashboard"
        static let diagnostics = "tabs.diagnostics"
        static let dtcs = "tabs.dtcs"
        static let consumption = "tabs.consumption"
        static let settings = "tabs.settings"
        static let radar = "tabs.radar"
        static let blackbox = "tabs.blackbox"
    }

    // MARK: - Dashboard
    struct Dashboard {
        static let rpm = "dashboard.rpm"
        static let speed = "dashboard.speed"
        static let coolantTemp = "dashboard.coolant_temp"
        static let oilTemp = "dashboard.oil_temp"
        static let oilPressure = "dashboard.oil_pressure"
        static let batteryVoltage = "dashboard.battery_voltage"
        static let intakeTemp = "dashboard.intake_temp"
        static let throttle = "dashboard.throttle"
        static let load = "dashboard.load"
        static let maf = "dashboard.maf"
        static let fuelLevel = "dashboard.fuel_level"
        static let afr = "dashboard.afr"
        static let notConnected = "dashboard.not_connected"
        static let connecting = "dashboard.connecting"
        static let connected = "dashboard.connected"
        static let activeAlerts = "dashboard.active_alerts"
        static let noAlerts = "dashboard.no_alerts"
    }

    // MARK: - Connection
    struct Connection {
        static let scanningAdapters = "connection.scanning_adapters"
        static let connectAdapter = "connection.connect_adapter"
        static let disconnect = "connection.disconnect"
        static let reconnect = "connection.reconnect"
        static let adapterFound = "connection.adapter_found"
        static let noAdapterFound = "connection.no_adapter_found"
        static let connectionFailed = "connection.failed"
        static let connectionLost = "connection.lost"
        static let autoConnecting = "connection.auto_connecting"
    }

    // MARK: - Diagnostics
    struct Diagnostics {
        static let scanDTCs = "diagnostics.scan_dtcs"
        static let clearDTCs = "diagnostics.clear_dtcs"
        static let currentDTCs = "diagnostics.current_dtcs"
        static let pendingDTCs = "diagnostics.pending_dtcs"
        static let noDTCsFound = "diagnostics.no_dtcs_found"
        static let dtcCleared = "diagnostics.dtc_cleared"
        static let freezeFrame = "diagnostics.freeze_frame"
        static let realTimeMonitor = "diagnostics.realtime_monitor"
        static let o2Test = "diagnostics.o2_test"
        static let vehicleInfo = "diagnostics.vehicle_info"
        static let rotaryDiagnostics = "diagnostics.rotary_diagnostics"
        static let actuatorTools = "diagnostics.actuator_tools"
        static let pidTester = "diagnostics.pid_tester"
    }

    // MARK: - Alerts
    struct Alerts {
        static let coolantHigh = "alerts.coolant_high"
        static let coolantCritical = "alerts.coolant_critical"
        static let oilTempHigh = "alerts.oil_temp_high"
        static let oilTempCritical = "alerts.oil_temp_critical"
        static let oilPressureLow = "alerts.oil_pressure_low"
        static let batteryLow = "alerts.battery_low"
        static let rpmHigh = "alerts.rpm_high"
        static let checkEngine = "alerts.check_engine"
    }

    // MARK: - Settings
    struct Settings {
        static let title = "settings.title"
        static let language = "settings.language"
        static let units = "settings.units"
        static let unitMetric = "settings.unit_metric"
        static let unitImperial = "settings.unit_imperial"
        static let temperature = "settings.temperature"
        static let tempCelsius = "settings.temp_celsius"
        static let tempFahrenheit = "settings.temp_fahrenheit"
        static let alertSettings = "settings.alert_settings"
        static let pollingInterval = "settings.polling_interval"
        static let dataMode = "settings.data_mode"
        static let dataModeEssential = "settings.data_mode_essential"
        static let dataModeNormal = "settings.data_mode_normal"
        static let dataModeFull = "settings.data_mode_full"
        static let autoConnect = "settings.auto_connect"
        static let keepScreenOn = "settings.keep_screen_on"
        static let hapticFeedback = "settings.haptic_feedback"
        static let dataLogging = "settings.data_logging"
        static let exportData = "settings.export_data"
        static let adapterTest = "settings.adapter_test"
        static let about = "settings.about"
    }

    // MARK: - Subscription
    struct Subscription {
        static let trialTitle = "subscription.trial_title"
        static let trialDaysRemaining = "subscription.trial_days_remaining"
        static let trialExpired = "subscription.trial_expired"
        static let premium = "subscription.premium"
        static let premiumFeatures = "subscription.premium_features"
        static let subscribe = "subscription.subscribe"
        static let restore = "subscription.restore"
        static let monthly = "subscription.monthly"
        static let yearly = "subscription.yearly"
        static let lifetime = "subscription.lifetime"
        static let bestValue = "subscription.best_value"
        static let privacyPolicy = "subscription.privacy_policy"
        static let termsOfService = "subscription.terms_of_service"
    }

    // MARK: - Vehicle Info
    struct Vehicle {
        static let vin = "vehicle.vin"
        static let odometer = "vehicle.odometer"
        static let ecuInfo = "vehicle.ecu_info"
        static let calibrationId = "vehicle.calibration_id"
        static let monitorStatus = "vehicle.monitor_status"
        static let dtcCount = "vehicle.dtc_count"
    }

    // MARK: - Units
    struct Units {
        static let kmh = "units.kmh"
        static let mph = "units.mph"
        static let celsius = "units.celsius"
        static let fahrenheit = "units.fahrenheit"
        static let kpa = "units.kpa"
        static let psi = "units.psi"
        static let liters = "units.liters"
        static let gallons = "units.gallons"
        static let km = "units.km"
        static let miles = "units.miles"
    }
}
