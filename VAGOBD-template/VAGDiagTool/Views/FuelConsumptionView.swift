import SwiftUI

struct FuelConsumptionView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @StateObject private var fuelConsumption = FuelConsumption.shared

    @State private var selectedUnit: FuelEconomyDisplay.Unit = .lPer100km

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if connectionManager.isConnected {
                        // Main Consumption Display
                        InstantConsumptionCard(
                            value: fuelConsumption.instantConsumption,
                            unit: selectedUnit
                        )

                        // Statistics Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ConsumptionStatCard(
                                title: "Consumo medio",
                                value: FuelEconomyDisplay.format(fuelConsumption.averageConsumption, unit: selectedUnit),
                                icon: "chart.line.uptrend.xyaxis"
                            )

                            ConsumptionStatCard(
                                title: "Consumo viaje",
                                value: FuelEconomyDisplay.format(fuelConsumption.tripConsumption, unit: selectedUnit),
                                icon: "car"
                            )

                            ConsumptionStatCard(
                                title: "Distancia viaje",
                                value: String(format: "%.1f km", fuelConsumption.tripDistance),
                                icon: "road.lanes"
                            )

                            ConsumptionStatCard(
                                title: "Combustible usado",
                                value: String(format: "%.2f L", fuelConsumption.totalFuelUsed),
                                icon: "fuelpump"
                            )
                        }

                        // Range Estimate
                        RangeEstimateCard(
                            range: fuelConsumption.estimatedRange,
                            fuelLevel: EngineData.shared.fuelLevel
                        )

                        // Unit Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unidad de medida")
                                .font(.headline)

                            Picker("Unidad", selection: $selectedUnit) {
                                ForEach(FuelEconomyDisplay.Unit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Trip Controls
                        TripControlsCard(fuelConsumption: fuelConsumption)

                    } else {
                        NotConnectedFuelView()
                    }
                }
                .padding()
            }
            .navigationTitle("Consumo")
        }
    }
}

// MARK: - Instant Consumption Card
struct InstantConsumptionCard: View {
    let value: Double
    let unit: FuelEconomyDisplay.Unit

    var displayValue: Double {
        FuelEconomyDisplay.convert(value, to: unit)
    }

    var color: Color {
        if unit == .lPer100km || unit == .kmPerL {
            if value < 6 { return .green }
            if value < 10 { return .orange }
            return .red
        } else {
            // MPG - higher is better
            let mpg = FuelEconomyDisplay.convert(value, to: .mpgUS)
            if mpg > 35 { return .green }
            if mpg > 25 { return .orange }
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Consumo instantáneo")
                .font(.headline)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: min(value / 20, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", displayValue))
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    Text(unit.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            // Efficiency indicator
            HStack(spacing: 20) {
                EfficiencyIndicator(label: "Eco", isActive: value < 6, color: .green)
                EfficiencyIndicator(label: "Normal", isActive: value >= 6 && value < 10, color: .orange)
                EfficiencyIndicator(label: "Sport", isActive: value >= 10, color: .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Efficiency Indicator
struct EfficiencyIndicator: View {
    let label: String
    let isActive: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption)
                .foregroundColor(isActive ? color : .secondary)
        }
    }
}

// MARK: - Consumption Stat Card
struct ConsumptionStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Range Estimate Card
struct RangeEstimateCard: View {
    let range: Double
    let fuelLevel: Double

    var rangeColor: Color {
        if range > 100 { return .green }
        if range > 50 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(.blue)
                Text("Autonomía estimada")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", range))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(rangeColor)
                Text("km")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            // Fuel gauge
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (fuelLevel / 100))
                }
            }
            .frame(height: 16)

            HStack {
                Text("E")
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
                Text(String(format: "%.0f%%", fuelLevel))
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("F")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Trip Controls Card
struct TripControlsCard: View {
    @ObservedObject var fuelConsumption: FuelConsumption

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                Text("Control de viaje")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: {
                    fuelConsumption.startNewTrip(fuelLevel: EngineData.shared.fuelLevel)
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Nuevo viaje")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    fuelConsumption.resetAverages()
                }) {
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                        Text("Reset media")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Not Connected View
struct NotConnectedFuelView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fuelpump.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No conectado")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Conecta el adaptador OBD2 para ver el consumo de combustible en tiempo real")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Preview
#Preview {
    FuelConsumptionView()
        .environmentObject(ConnectionManager())
}
