# Plan de Desarrollo - VAG Diagnostic Tool

## Estructura del Proyecto

```
VAGDiagTool/
├── App/
│   ├── iOS/                    # App iOS principal
│   │   ├── VAGDiagApp.swift    # Entry point
│   │   └── Views/
│   │       ├── DiagnosticView.swift
│   │       ├── DTCView.swift
│   │       ├── SettingsView.swift
│   │       └── FuelConsumptionView.swift
│   └── CarPlay/                # App CarPlay
│       ├── CarPlaySceneDelegate.swift
│       └── GaugeViews.swift
├── Sources/
│   └── VAGOBD/
│       ├── VAGOBD.swift        # Libreria principal
│       ├── Connection/         # Conexion OBD2
│       ├── PIDs/               # PIDs VAG
│       ├── DTCs/               # Codigos de error
│       ├── Models/             # Modelos de datos
│       └── Diagnostics/        # Logica diagnostico
└── Tests/
```

---

## Modulos a Desarrollar

### 1. Connection (Conexion OBD2)
**Archivos:**
- `OBDConnection.swift` - Gestión conexión Bluetooth/WiFi
- `VirtualOBDAdapter.swift` - Simulador para desarrollo

**Funcionalidad:**
- Conexión con adaptadores ELM327
- Soporte Bluetooth Classic y BLE
- Protocolo CAN (ISO 15765-4)
- Protocolo KWP2000 para vehículos antiguos (<2008)
- UDS (ISO 14229) para vehículos modernos

---

### 2. PIDs (Parámetros VAG)
**Archivo:** `VAGPIDs.swift`

**PIDs estándar OBD2:**
| PID | Descripción | Unidad |
|-----|-------------|--------|
| 0x05 | Temp. refrigerante | °C |
| 0x0C | RPM motor | rpm |
| 0x0D | Velocidad | km/h |
| 0x0F | Temp. admisión | °C |
| 0x10 | MAF (flujo aire) | g/s |
| 0x11 | Posición acelerador | % |
| 0x5C | Temp. aceite | °C |

**PIDs específicos VAG (modo 22):**
| PID | Descripción | Unidad |
|-----|-------------|--------|
| 0x2203 | Presión turbo | bar |
| 0x2204 | Temp. turbo | °C |
| 0x2033 | Presión aceite | bar |
| 0xF40C | Regeneración DPF | % |
| 0x205A | Nivel AdBlue | % |

---

### 3. DTCs (Códigos de Error VAG)
**Archivo:** `VAGDTCCodes.swift`

**Formato códigos VAG:**
- P0xxx - Códigos genéricos OBD2
- P1xxx - Códigos específicos fabricante
- P2xxx - Códigos genéricos adicionales
- P3xxx - Códigos específicos fabricante

**Ejemplos códigos VAG comunes:**
```swift
struct VAGDTCCode {
    let code: String
    let description: String
    let severity: Severity
    let solution: String
}

// Ejemplos:
// P0299 - Turbo/Supercargador baja presión
// P0401 - EGR flujo insuficiente
// P2002 - Filtro partículas eficiencia baja
// P0087 - Presión raíl combustible baja
// P2015 - Sensor posición actuador admisión
```

---

### 4. Models (Modelos de Datos)
**Archivos:**
- `VehicleInfo.swift` - Info del vehículo
- `EngineData.swift` - Datos motor en tiempo real
- `FuelConsumption.swift` - Consumo combustible

**Estructura VehicleInfo:**
```swift
struct VAGVehicleInfo {
    let vin: String
    let brand: Brand          // VW, Audi, SEAT, Skoda
    let model: String
    let year: Int
    let engineCode: String    // Ej: "CJAA", "CBBB"
    let engineType: EngineType // TSI, TDI, TFSI, etc.
    let displacement: Double   // Ej: 2.0
    let power: Int            // kW
}
```

**Tipos de motor VAG:**
```swift
enum EngineType {
    case tsi      // Gasolina turbo inyección directa
    case tfsi     // Gasolina turbo stratified injection
    case tdi      // Diesel turbo inyección directa
    case fsi      // Gasolina inyección directa
    case mpi      // Gasolina inyección multipunto
    case etron    // Eléctrico
    case hybrid   // Híbrido
}
```

---

### 5. Diagnostics (Lógica de Diagnóstico)
**Archivo:** `DiagnosticMode.swift`

**Funcionalidades:**
- Lectura códigos DTC activos
- Lectura códigos DTC pendientes
- Borrado de códigos DTC
- Freeze frame data
- Test de actuadores (con precaución)

**Diagnósticos específicos VAG:**
```swift
protocol VAGDiagnostics {
    // Lectura DTCs
    func readDTCs() async throws -> [VAGDTCCode]
    func clearDTCs() async throws

    // Adaptaciones
    func readAdaptationValues(channel: Int) async throws -> Double

    // Info básica
    func readVIN() async throws -> String
    func readECUInfo() async throws -> ECUInfo

    // Service reset
    func resetServiceInterval() async throws
}
```

---

### 6. App iOS - Views

**DiagnosticView.swift:**
- Dashboard principal
- Indicadores en tiempo real (RPM, velocidad, temperaturas)
- Alertas configurables

**DTCView.swift:**
- Lista de códigos de error
- Descripción detallada de cada código
- Botón borrar códigos

**SettingsView.swift:**
- Configuración conexión Bluetooth
- Selección vehículo/motor
- Unidades (métrico/imperial)
- Alertas personalizadas

**FuelConsumptionView.swift:**
- Consumo instantáneo
- Consumo medio
- Historial de consumo

---

### 7. App CarPlay

**CarPlaySceneDelegate.swift:**
- Configuración escena CarPlay
- Templates de información

**GaugeViews.swift:**
- Velocímetro circular
- Tacómetro
- Indicador temperatura
- Indicador presión turbo

---

## Especificaciones Técnicas VAG

### Temperaturas Operativas
| Parámetro | Normal | Alerta | Crítico |
|-----------|--------|--------|---------|
| Refrigerante | 85-95°C | >100°C | >110°C |
| Aceite Motor | 90-110°C | >120°C | >140°C |
| Aceite Caja DSG | 80-100°C | >110°C | >120°C |
| Turbo EGT | <850°C | >900°C | >950°C |

### Presiones
| Parámetro | Normal | Alerta |
|-----------|--------|--------|
| Turbo (1.4 TSI) | 0.8-1.2 bar | >1.5 bar |
| Turbo (2.0 TSI) | 1.0-1.8 bar | >2.0 bar |
| Turbo (2.0 TDI) | 1.5-2.2 bar | >2.5 bar |
| Aceite ralentí | >0.8 bar | <0.5 bar |
| Aceite 3000rpm | >2.0 bar | <1.5 bar |

---

## Orden de Implementación Sugerido

1. **Fase 1 - Base**
   - [ ] OBDConnection.swift
   - [ ] VehicleInfo.swift
   - [ ] VAGPIDs.swift básicos

2. **Fase 2 - Diagnóstico**
   - [ ] VAGDTCCodes.swift
   - [ ] DiagnosticMode.swift
   - [ ] DTCView.swift

3. **Fase 3 - App iOS**
   - [ ] DiagnosticView.swift
   - [ ] SettingsView.swift
   - [ ] FuelConsumptionView.swift

4. **Fase 4 - CarPlay**
   - [ ] CarPlaySceneDelegate.swift
   - [ ] GaugeViews.swift

5. **Fase 5 - Avanzado**
   - [ ] PIDs específicos VAG (modo 22)
   - [ ] Adaptaciones
   - [ ] Service reset

---

## Recursos y Referencias

- **VCDS/VAG-COM:** Referencia de PIDs propietarios
- **Ross-Tech Wiki:** Documentación códigos VAG
- **OBD2 Specs:** ISO 15765-4, ISO 14229
- **SwiftOBD2:** Librería base para conexión
