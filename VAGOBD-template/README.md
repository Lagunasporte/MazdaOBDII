# VAG Diagnostic Tool

> Herramienta de diagnostico OBD2 para vehiculos del Grupo VAG

## Caracteristicas

### App iOS - Diagnostico Tecnico Completo
- **Monitor en tiempo real** de todos los parametros del motor
- **Lectura/borrado de codigos DTC** con explicaciones especificas VAG
- **Historial de diagnosticos** con exportacion
- **Guias de reparacion** especificas por modelo

### App CarPlay - Conduccion
- **Relojes analogicos** estilo racing
- **Temperaturas criticas** en tiempo real
- **Alertas configurables** (temp aceite, coolant, etc.)
- **Modo circuito** con logging de datos

## Hardware Compatible

| Adaptador | Conexion | Recomendado |
|-----------|----------|-------------|
| OBDLink MX+ | Bluetooth | Excelente |
| Veepeak BLE | BLE 4.0 | Bueno |
| LELink BLE | BLE 4.0 | Bueno |

## Vehiculos Soportados

### Volkswagen
- Golf (Mk4 - Mk8)
- Polo
- Passat
- Tiguan
- Jetta
- Arteon

### Audi
- A3, A4, A5, A6, A7, A8
- Q3, Q5, Q7, Q8
- TT, R8
- RS series

### SEAT
- Ibiza
- Leon
- Ateca
- Tarraco

### Skoda
- Fabia
- Octavia
- Superb
- Kodiaq

## Arquitectura

```
VAGDiagTool/
├── App/
│   ├── iOS/              # UI tecnica para mecanicos
│   └── CarPlay/          # UI relojes conduccion
├── Sources/
│   └── VAGOBD/
│       ├── Connection/   # Bluetooth/WiFi OBD2
│       ├── PIDs/         # PIDs especificos VAG
│       ├── DTCs/         # Codigos de error VAG
│       ├── Models/       # Modelos de datos
│       └── Diagnostics/  # Logica diagnostico
└── Tests/
```

## Protocolos VAG Soportados

- **OBD-II estándar** (ISO 15765-4 CAN)
- **VAG-COM (KWP2000)** para vehiculos anteriores a 2008
- **UDS (ISO 14229)** para vehiculos modernos

## Licencia

MIT License - Hecho para la comunidad VAG
