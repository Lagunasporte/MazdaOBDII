// RX-8 Diagnostic Tool - Core Library
// La navaja suiza para diagnóstico del Mazda RX-8

import Foundation

/// Punto de entrada principal de la librería RX8OBD
public struct RX8OBD {
    public static let version = "1.0.0"
    public static let supportedVehicles = ["Mazda RX-8 SE3P (2003-2012)"]

    /// Motor soportado
    public static let engineType = "13B-MSP Renesis"

    /// Inicializa la librería
    public init() {}
}

// Re-exportar módulos públicos
// Los consumidores pueden importar RX8OBD y acceder a todo

/*
 Estructura del paquete:

 RX8OBD/
 ├── Models/
 │   ├── RotaryEngine.swift      - Estado del motor, compresión, alertas
 │   ├── VehicleInfo.swift       - Info del vehículo, VIN, mantenimiento
 │   └── FuelConsumption.swift   - Tracking de consumo (ordenador abordo)
 │
 ├── PIDs/
 │   └── RX8PIDs.swift           - PIDs CAN, OBD2 estándar y extendidos Mazda
 │
 ├── DTCs/
 │   └── RX8DTCCodes.swift       - Códigos de error con explicaciones RX-8
 │
 ├── Diagnostics/
 │   └── DiagnosticMode.swift    - Modo diagnóstico inteligente
 │
 └── Connection/
     └── OBDConnection.swift     - Comunicación Bluetooth/WiFi OBD2


 App/
 ├── iOS/
 │   ├── RX8DiagApp.swift        - App principal
 │   └── Views/
 │       ├── DiagnosticView.swift
 │       ├── DTCView.swift
 │       ├── FuelConsumptionView.swift
 │       └── SettingsView.swift
 │
 └── CarPlay/
     ├── CarPlaySceneDelegate.swift
     └── GaugeViews.swift        - Relojes estéticos

*/
