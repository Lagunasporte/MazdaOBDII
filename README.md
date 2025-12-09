# RX-8 Diagnostic Tool 🔴

> La navaja suiza definitiva para mecánicos y entusiastas del Mazda RX-8

## Características

### 📱 App iOS - Diagnóstico Técnico Completo
- **Monitor en tiempo real** de todos los parámetros del motor 13B-MSP Renesis
- **Test de compresión** con análisis de apex seals
- **Lectura/borrado de códigos DTC** con explicaciones específicas del rotativo
- **Monitor del sistema OMP** (Oil Metering Pump)
- **Historial de diagnósticos** con exportación
- **Guías de reparación** específicas del RX-8

### 🚗 App CarPlay - Conducción
- **Relojes analógicos** estilo racing
- **Temperaturas críticas** en tiempo real
- **Alertas configurables** (temp aceite, coolant, etc.)
- **Modo circuito** con logging de datos

## Hardware Compatible

| Adaptador | Conexión | Recomendado |
|-----------|----------|-------------|
| OBDLink MX+ | Bluetooth | ⭐⭐⭐ |
| Veepeak BLE | BLE 4.0 | ⭐⭐ |
| LELink BLE | BLE 4.0 | ⭐⭐ |

## Vehículos Soportados

- Mazda RX-8 Serie 1 (2003-2008) - SE3P
- Mazda RX-8 Serie 2 (2009-2012) - SE3P

## Arquitectura

```
RX8DiagTool/
├── App/
│   ├── iOS/              # UI técnica para mecánicos
│   └── CarPlay/          # UI relojes conducción
├── Sources/
│   └── RX8OBD/
│       ├── Connection/   # Bluetooth/WiFi OBD2
│       ├── PIDs/         # PIDs específicos RX-8
│       ├── DTCs/         # Códigos de error
│       ├── Models/       # Modelos de datos
│       └── Diagnostics/  # Lógica diagnóstico rotativo
└── Tests/
```

## Especificaciones Técnicas RX-8

### Valores de Compresión Normales (Motor Caliente)
| Lectura | Estado |
|---------|--------|
| > 8.5 kg/cm² | Excelente |
| 8.0 - 8.4 kg/cm² | Muy bueno |
| 7.5 - 7.9 kg/cm² | Aceptable |
| 7.0 - 7.4 kg/cm² | Revisar pronto |
| < 7.0 kg/cm² | Requiere rebuild |

### Temperaturas Operativas
| Parámetro | Normal | Alerta | Crítico |
|-----------|--------|--------|---------|
| Refrigerante | 85-95°C | >100°C | >105°C |
| Aceite Motor | 90-110°C | >120°C | >130°C |
| Admisión | 20-45°C | >55°C | >65°C |

## Licencia

MIT License - Hecho con ❤️ para la comunidad RX-8

## Créditos

- PIDs CAN Bus: [topolittle/RX8-CAN-BUS](https://github.com/topolittle/RX8-CAN-BUS)
- Librería OBD2: [SwiftOBD2](https://github.com/kkonteh97/SwiftOBD2)
- Comunidad: [RX8Club.com](https://www.rx8club.com)
