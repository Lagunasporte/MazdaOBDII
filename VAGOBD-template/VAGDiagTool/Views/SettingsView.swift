import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @AppStorage("selectedBrand") private var selectedBrand = "Volkswagen"
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("enableAlerts") private var enableAlerts = true
    @AppStorage("coolantAlertTemp") private var coolantAlertTemp = 100.0
    @AppStorage("oilAlertTemp") private var oilAlertTemp = 120.0
    @AppStorage("boostAlertPressure") private var boostAlertPressure = 2.0
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        NavigationView {
            Form {
                // Vehicle Section
                Section(header: Text("Vehículo")) {
                    Picker("Marca", selection: $selectedBrand) {
                        ForEach(VAGOBD.Brand.allCases, id: \.rawValue) { brand in
                            Text(brand.rawValue).tag(brand.rawValue)
                        }
                    }

                    NavigationLink(destination: VehicleInfoView()) {
                        HStack {
                            Label("Información del vehículo", systemImage: "car")
                            Spacer()
                        }
                    }
                }

                // Connection Section
                Section(header: Text("Conexión")) {
                    Toggle("Usar simulador", isOn: $connectionManager.useSimulator)

                    NavigationLink(destination: AdapterSettingsView()) {
                        Label("Configuración adaptador", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    if connectionManager.isConnected {
                        HStack {
                            Text("Estado")
                            Spacer()
                            Text("Conectado")
                                .foregroundColor(.green)
                        }
                    }
                }

                // Alerts Section
                Section(header: Text("Alertas")) {
                    Toggle("Activar alertas", isOn: $enableAlerts)

                    if enableAlerts {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperatura refrigerante: \(Int(coolantAlertTemp))°C")
                            Slider(value: $coolantAlertTemp, in: 90...120, step: 5)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperatura aceite: \(Int(oilAlertTemp))°C")
                            Slider(value: $oilAlertTemp, in: 100...140, step: 5)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Presión turbo: \(String(format: "%.1f", boostAlertPressure)) bar")
                            Slider(value: $boostAlertPressure, in: 1.0...3.0, step: 0.1)
                        }
                    }
                }

                // Units Section
                Section(header: Text("Unidades")) {
                    Toggle("Usar sistema métrico", isOn: $useMetricUnits)

                    HStack {
                        Text("Velocidad")
                        Spacer()
                        Text(useMetricUnits ? "km/h" : "mph")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Temperatura")
                        Spacer()
                        Text(useMetricUnits ? "°C" : "°F")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Presión")
                        Spacer()
                        Text(useMetricUnits ? "bar" : "psi")
                            .foregroundColor(.secondary)
                    }
                }

                // Appearance Section
                Section(header: Text("Apariencia")) {
                    Toggle("Modo oscuro", isOn: $darkMode)
                }

                // Data Section
                Section(header: Text("Datos")) {
                    NavigationLink(destination: DiagnosticHistoryView()) {
                        Label("Historial de diagnósticos", systemImage: "clock.arrow.circlepath")
                    }

                    NavigationLink(destination: TripHistoryView()) {
                        Label("Historial de viajes", systemImage: "map")
                    }

                    Button(action: {
                        // Export data
                    }) {
                        Label("Exportar datos", systemImage: "square.and.arrow.up")
                    }
                }

                // About Section
                Section(header: Text("Acerca de")) {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: AboutView()) {
                        Text("Acerca de VAG Diag Tool")
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text("Código fuente")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

// MARK: - Vehicle Info View
struct VehicleInfoView: View {
    @EnvironmentObject var diagnosticService: DiagnosticService

    var body: some View {
        List {
            if let vehicle = diagnosticService.vehicleInfo {
                Section(header: Text("Vehículo")) {
                    InfoRow(label: "VIN", value: vehicle.vin)
                    InfoRow(label: "Marca", value: vehicle.brand.rawValue)
                    InfoRow(label: "Modelo", value: vehicle.model)
                    InfoRow(label: "Año", value: "\(vehicle.year)")
                }

                Section(header: Text("Motor")) {
                    InfoRow(label: "Código motor", value: vehicle.engineCode)
                    InfoRow(label: "Tipo", value: vehicle.engineType.rawValue)
                    InfoRow(label: "Cilindrada", value: String(format: "%.1f L", vehicle.displacement))
                    InfoRow(label: "Potencia", value: "\(vehicle.power) kW (\(vehicle.powerHP) CV)")
                    InfoRow(label: "Par", value: "\(vehicle.torque) Nm")
                }

                Section(header: Text("Transmisión")) {
                    InfoRow(label: "Tipo", value: vehicle.transmission.rawValue)
                    InfoRow(label: "Combustible", value: vehicle.fuelType.rawValue)
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No hay información del vehículo")
                                .foregroundColor(.secondary)
                            Button("Leer VIN") {
                                Task {
                                    _ = try? await diagnosticService.readVIN()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }

            // ECU Info
            if !diagnosticService.ecuInfo.isEmpty {
                Section(header: Text("Unidades de control")) {
                    ForEach(diagnosticService.ecuInfo) { ecu in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ecu.name)
                                .font(.headline)
                            Text("Dirección: \(ecu.address)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Software: \(ecu.softwareVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Información del vehículo")
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Adapter Settings View
struct AdapterSettingsView: View {
    @State private var selectedProtocol: OBDProtocol = .auto

    var body: some View {
        Form {
            Section(header: Text("Protocolo")) {
                Picker("Protocolo OBD", selection: $selectedProtocol) {
                    ForEach(OBDProtocol.allCases, id: \.rawValue) { proto in
                        Text(proto.description).tag(proto)
                    }
                }
            }

            Section(header: Text("Información")) {
                Text("El protocolo automático detecta el tipo de bus CAN de tu vehículo. Solo cambia esta configuración si tienes problemas de conexión.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Adaptadores compatibles")) {
                VStack(alignment: .leading, spacing: 8) {
                    AdapterRow(name: "OBDLink MX+", recommended: true)
                    AdapterRow(name: "Veepeak OBDCheck BLE+", recommended: false)
                    AdapterRow(name: "LELink Bluetooth", recommended: false)
                    AdapterRow(name: "Vgate iCar Pro", recommended: false)
                }
            }
        }
        .navigationTitle("Adaptador OBD")
    }
}

struct AdapterRow: View {
    let name: String
    let recommended: Bool

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            if recommended {
                Text("Recomendado")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Diagnostic History View
struct DiagnosticHistoryView: View {
    var body: some View {
        List {
            Text("Historial de diagnósticos")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Historial")
    }
}

// MARK: - Trip History View
struct TripHistoryView: View {
    var body: some View {
        List {
            Text("Historial de viajes")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Viajes")
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "car.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("VAG Diag Tool")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Herramienta de diagnóstico OBD2 para vehículos del Grupo VAG")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Vehículos soportados")
                        .font(.headline)

                    ForEach(VAGOBD.Brand.allCases, id: \.rawValue) { brand in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(brand.rawValue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Créditos")
                        .font(.headline)

                    Text("SwiftOBD2 - Librería OBD2")
                        .font(.caption)
                    Text("Ross-Tech - Referencia códigos VAG")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text("MIT License")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Acerca de")
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(ConnectionManager())
        .environmentObject(DiagnosticService.shared)
}
