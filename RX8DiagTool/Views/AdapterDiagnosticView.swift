import SwiftUI

// MARK: - Vista de Diagnóstico del Adaptador OBD

struct AdapterDiagnosticView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var isRunningDiagnostic = false
    @State private var rawCommand = ""
    @State private var rawResponse = ""
    @State private var showDebugLog = false
    @State private var showBLEInfo = false

    var body: some View {
        NavigationStack {
            List {
                // Estado actual
                Section {
                    HStack {
                        Image(systemName: connectionManager.connectionState.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(connectionManager.connectionState.isConnected ? .green : .red)
                        Text("Estado")
                        Spacer()
                        Text(connectionManager.connectionState.rawValue)
                            .foregroundColor(.gray)
                    }

                    if let adapter = connectionManager.adapterInfo {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("Adaptador")
                            Spacer()
                            Text(adapter.version)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }

                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.orange)
                        Text("Tipo detectado")
                        Spacer()
                        Text(connectionManager.detectedAdapterType.rawValue)
                            .foregroundColor(.gray)
                    }

                    if let proto = connectionManager.vehicleProtocol {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.purple)
                            Text("Protocolo")
                            Spacer()
                            Text(proto.rawValue)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Estado de Conexión")
                }

                // Diagnóstico completo
                Section {
                    Button {
                        runDiagnostic()
                    } label: {
                        HStack {
                            if isRunningDiagnostic {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Ejecutando diagnóstico...")
                            } else {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.green)
                                Text("Ejecutar diagnóstico completo")
                            }
                        }
                    }
                    .disabled(isRunningDiagnostic || !connectionManager.connectionState.isConnected)

                    if let results = connectionManager.diagnosticResults {
                        DiagnosticResultsView(results: results)
                    }
                } header: {
                    Text("Diagnóstico")
                } footer: {
                    Text("El diagnóstico prueba la comunicación con el adaptador y el vehículo")
                }

                // Consola de comandos
                Section {
                    TextField("Comando AT (ej: ATI, 0100)", text: $rawCommand)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Button {
                        sendRawCommand()
                    } label: {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(.orange)
                            Text("Enviar comando")
                        }
                    }
                    .disabled(rawCommand.isEmpty || !connectionManager.connectionState.isConnected)

                    if !rawResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Respuesta:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(rawResponse)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Consola de Comandos")
                } footer: {
                    Text("Envía comandos AT directamente al adaptador para testing")
                }

                // Comandos rápidos
                Section {
                    QuickCommandButton(command: "ATZ", description: "Reset adaptador") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "ATI", description: "Info del adaptador") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "ATRV", description: "Voltaje batería") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "ATDPN", description: "Protocolo actual") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "0100", description: "PIDs soportados") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "010C", description: "RPM") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                    QuickCommandButton(command: "0105", description: "Temp. refrigerante") { cmd in
                        rawCommand = cmd
                        sendRawCommand()
                    }
                } header: {
                    Text("Comandos Rápidos")
                }

                // Diagnóstico BLE
                Section {
                    Button {
                        showBLEInfo = true
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.purple)
                            Text("Ver características BLE")
                        }
                    }

                    Button {
                        connectionManager.reconnectBLE()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("Redescubrir servicios BLE")
                        }
                    }
                    .disabled(!connectionManager.connectionState.isConnected)
                } header: {
                    Text("Diagnóstico BLE")
                } footer: {
                    Text("Si no recibes respuestas, prueba redescubrir servicios BLE")
                }

                // Log de debug
                Section {
                    Button {
                        showDebugLog = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                            Text("Ver log de debug")
                            Spacer()
                            Text("\(connectionManager.debugLog.count) entradas")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }

                    Toggle("Modo verbose", isOn: $connectionManager.isVerboseMode)

                    Button(role: .destructive) {
                        connectionManager.clearDebugLog()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Limpiar log")
                        }
                    }
                } header: {
                    Text("Debug")
                }

                // Adaptadores compatibles
                Section {
                    AdapterInfoRow(name: "ELM327 v1.4/v1.5", status: .compatible)
                    AdapterInfoRow(name: "STN1110/STN2120", status: .compatible)
                    AdapterInfoRow(name: "Carista OBD2", status: .compatible)
                    AdapterInfoRow(name: "OBDLink MX+", status: .compatible)
                    AdapterInfoRow(name: "Vgate iCar Pro", status: .compatible)
                    AdapterInfoRow(name: "Veepeak OBDCheck", status: .compatible)
                    AdapterInfoRow(name: "BAFX Products", status: .compatible)
                    AdapterInfoRow(name: "LELink OBD2", status: .compatible)
                    AdapterInfoRow(name: "Clones ELM327 baratos", status: .partial)
                } header: {
                    Text("Adaptadores Compatibles")
                } footer: {
                    Text("Los adaptadores con chip STN1110 o ELM327 genuino ofrecen mejor compatibilidad")
                }
            }
            .navigationTitle("Diagnóstico Adaptador")
            .sheet(isPresented: $showDebugLog) {
                DebugLogView(logs: connectionManager.debugLog)
            }
            .sheet(isPresented: $showBLEInfo) {
                BLEInfoView()
            }
        }
    }

    private func runDiagnostic() {
        isRunningDiagnostic = true
        Task {
            _ = await connectionManager.runFullDiagnostic()
            await MainActor.run {
                isRunningDiagnostic = false
            }
        }
    }

    private func sendRawCommand() {
        guard !rawCommand.isEmpty else { return }
        Task {
            do {
                let response = try await connectionManager.sendRawCommand(rawCommand)
                await MainActor.run {
                    rawResponse = response
                }
            } catch {
                await MainActor.run {
                    rawResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Subvistas

struct DiagnosticResultsView: View {
    let results: DiagnosticResults

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResultRow(label: "Bluetooth", value: results.bluetoothAvailable ? "OK" : "Error", ok: results.bluetoothAvailable)
            ResultRow(label: "Adaptador", value: results.adapterConnected ? "Conectado" : "No", ok: results.adapterConnected)
            ResultRow(label: "Reset (ATZ)", value: results.atzOK ? "OK" : "Error", ok: results.atzOK)
            ResultRow(label: "Vehículo", value: results.vehicleResponding ? "Responde" : "Sin respuesta", ok: results.vehicleResponding)

            if !results.voltage.isEmpty && results.voltage != "Error" {
                ResultRow(label: "Voltaje", value: results.voltage, ok: true)
            }

            if !results.workingProtocol.isEmpty {
                ResultRow(label: "Protocolo", value: results.workingProtocol, ok: true)
            }

            Divider()

            Text(results.summary)
                .font(.caption)
                .foregroundColor(results.isFullyOperational ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    let ok: Bool

    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(ok ? .green : .red)
                .font(.caption)
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct QuickCommandButton: View {
    let command: String
    let description: String
    let action: (String) -> Void

    var body: some View {
        Button {
            action(command)
        } label: {
            HStack {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

enum AdapterStatus {
    case compatible, partial, incompatible

    var color: Color {
        switch self {
        case .compatible: return .green
        case .partial: return .orange
        case .incompatible: return .red
        }
    }

    var icon: String {
        switch self {
        case .compatible: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .incompatible: return "xmark.circle.fill"
        }
    }
}

struct AdapterInfoRow: View {
    let name: String
    let status: AdapterStatus

    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
            Text(name)
            Spacer()
        }
    }
}

struct DebugLogView: View {
    @Environment(\.dismiss) var dismiss
    let logs: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logs.reversed(), id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIPasteboard.general.string = logs.joined(separator: "\n")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

struct BLEInfoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var connectionManager: OBDConnectionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(connectionManager.getBLEDiagnosticInfo())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)

                    Divider()

                    Text("Solución de problemas:")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 8) {
                        BLETipRow(tip: "Si no hay respuestas (RX), la característica de notificación puede ser incorrecta")
                        BLETipRow(tip: "Adaptadores STN/Carista usan FFF0 (servicio), FFF1 (write), FFF2 (notify)")
                        BLETipRow(tip: "ELM327 estándar usa FFE0 (servicio), FFE1 (read/write/notify)")
                        BLETipRow(tip: "Prueba 'Redescubrir servicios BLE' si no funciona")
                        BLETipRow(tip: "El log debe mostrar 'RX raw' cuando lleguen datos")
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Características BLE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIPasteboard.general.string = connectionManager.getBLEDiagnosticInfo()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

struct BLETipRow: View {
    let tip: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            Text(tip)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    AdapterDiagnosticView()
        .environmentObject(OBDConnectionManager())
}
