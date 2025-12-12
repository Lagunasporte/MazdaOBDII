import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var engineData: EngineData

    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection Status
                    ConnectionStatusCard()

                    if connectionManager.isConnected {
                        // Main Gauges
                        MainGaugesSection()

                        // Temperature Section
                        TemperatureSection()

                        // Pressure Section
                        PressureSection()

                        // Additional Info
                        AdditionalInfoSection()
                    } else {
                        ConnectPromptView()
                    }
                }
                .padding()
            }
            .navigationTitle("VAG Diag")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if connectionManager.isConnected {
                        Button(action: { Task { await refreshData() } }) {
                            Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                    }
                }
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        // Simulate refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        HStack {
            Circle()
                .fill(connectionManager.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            Text(connectionManager.isConnected ? "Conectado" : "Desconectado")
                .font(.headline)

            Spacer()

            if connectionManager.isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(connectionManager.isConnected ? "Desconectar" : "Conectar") {
                    Task {
                        if connectionManager.isConnected {
                            connectionManager.disconnect()
                        } else {
                            await connectionManager.connect()
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Connect Prompt View
struct ConnectPromptView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Conecta tu adaptador OBD2")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Asegúrate de que el adaptador está conectado al puerto OBD2 del vehículo y el contacto está dado.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Toggle("Usar simulador", isOn: $connectionManager.useSimulator)
                .padding(.horizontal)

            Button(action: {
                Task {
                    await connectionManager.connect()
                }
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Buscar adaptador")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(connectionManager.isConnecting)

            if let error = connectionManager.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(32)
    }
}

// MARK: - Main Gauges Section
struct MainGaugesSection: View {
    @EnvironmentObject var engineData: EngineData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motor")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                GaugeCard(
                    title: "RPM",
                    value: engineData.rpm,
                    maxValue: 8000,
                    unit: "rpm",
                    color: .blue,
                    format: "%.0f"
                )

                GaugeCard(
                    title: "Velocidad",
                    value: engineData.speed,
                    maxValue: 260,
                    unit: "km/h",
                    color: .green,
                    format: "%.0f"
                )

                GaugeCard(
                    title: "Acelerador",
                    value: engineData.throttlePosition,
                    maxValue: 100,
                    unit: "%",
                    color: .orange,
                    format: "%.1f"
                )

                GaugeCard(
                    title: "Carga Motor",
                    value: engineData.engineLoad,
                    maxValue: 100,
                    unit: "%",
                    color: .purple,
                    format: "%.1f"
                )
            }
        }
    }
}

// MARK: - Temperature Section
struct TemperatureSection: View {
    @EnvironmentObject var engineData: EngineData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperaturas")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TemperatureCard(
                    title: "Refrigerante",
                    value: engineData.coolantTemp,
                    status: engineData.coolantStatus
                )

                TemperatureCard(
                    title: "Aceite Motor",
                    value: engineData.oilTemp,
                    status: engineData.oilTempStatus
                )

                TemperatureCard(
                    title: "Admisión",
                    value: engineData.intakeTemp,
                    status: .normal
                )

                TemperatureCard(
                    title: "Ambiente",
                    value: engineData.ambientTemp,
                    status: .normal
                )
            }
        }
    }
}

// MARK: - Pressure Section
struct PressureSection: View {
    @EnvironmentObject var engineData: EngineData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presiones")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PressureCard(
                    title: "Turbo",
                    value: engineData.boostPressure,
                    unit: "bar",
                    status: engineData.boostStatus
                )

                PressureCard(
                    title: "Aceite",
                    value: engineData.oilPressure,
                    unit: "bar",
                    status: engineData.oilPressureStatus
                )
            }
        }
    }
}

// MARK: - Additional Info Section
struct AdditionalInfoSection: View {
    @EnvironmentObject var engineData: EngineData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información adicional")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack {
                InfoItem(title: "Voltaje", value: String(format: "%.1f V", engineData.batteryVoltage))
                Spacer()
                InfoItem(title: "Combustible", value: String(format: "%.0f%%", engineData.fuelLevel))
                Spacer()
                InfoItem(title: "MAF", value: String(format: "%.1f g/s", engineData.maf))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Gauge Card
struct GaugeCard: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    let format: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(String(format: format, value))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Temperature Card
struct TemperatureCard: View {
    let title: String
    let value: Double
    let status: AlertLevel

    var statusColor: Color {
        switch status {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", value))
                    .font(.title)
                    .fontWeight(.bold)
                Text("°C")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Pressure Card
struct PressureCard: View {
    let title: String
    let value: Double
    let unit: String
    let status: AlertLevel

    var statusColor: Color {
        switch status {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.2f", value))
                    .font(.title)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Info Item
struct InfoItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview
#Preview {
    DiagnosticView()
        .environmentObject(ConnectionManager())
        .environmentObject(EngineData.shared)
}
