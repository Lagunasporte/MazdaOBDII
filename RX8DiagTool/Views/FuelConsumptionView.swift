import SwiftUI

// MARK: - Vista de Consumo de Combustible
// El RX-8 no tiene ordenador de abordo - esta funcionalidad es muy valiosa

struct FuelConsumptionView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var showTripHistory = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Consumo instantáneo - Grande y destacado
                    InstantConsumptionCard()

                    // Estadísticas del viaje actual
                    CurrentTripCard()

                    // Autonomía
                    RangeCard()

                    // Parciales de consumo
                    PartialsSection()

                    // Promedios
                    AveragesCard()

                    // Coste del combustible
                    FuelCostCard()
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Consumo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showTripHistory) {
                TripHistoryView()
            }
            .sheet(isPresented: $showSettings) {
                FuelSettingsView()
            }
        }
    }
}

// MARK: - Consumo Instantáneo

struct InstantConsumptionCard: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor

    var body: some View {
        VStack(spacing: 8) {
            Text("Consumo Instantáneo")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", fuelTracker.instantConsumption))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(consumptionColor)

                VStack(alignment: .leading) {
                    Text(consumptionUnit)
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }

            // Barra de eficiencia
            ConsumptionIndicatorBar(value: fuelTracker.instantConsumption)

            // Indicador de eficiencia
            HStack {
                Image(systemName: efficiencyIcon)
                    .foregroundColor(consumptionColor)
                Text(efficiencyText)
                    .font(.caption)
                    .foregroundColor(consumptionColor)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [consumptionColor.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(24)
    }

    var consumptionUnit: String {
        // En ralentí mostrar L/h
        if engineMonitor.currentState.vehicleSpeed < 3 {
            return "L/h"
        }
        return "L/100km"
    }

    var consumptionColor: Color {
        let value = fuelTracker.instantConsumption
        if value < 10 { return .green }
        if value < 13 { return .teal }
        if value < 16 { return .yellow }
        if value < 20 { return .orange }
        return .red
    }

    var efficiencyIcon: String {
        let value = fuelTracker.instantConsumption
        if value < 11 { return "leaf.fill" }
        if value < 14 { return "leaf" }
        if value < 18 { return "car.fill" }
        return "flame.fill"
    }

    var efficiencyText: String {
        let value = fuelTracker.instantConsumption
        if value < 11 { return "Excelente eficiencia" }
        if value < 14 { return "Buena eficiencia" }
        if value < 18 { return "Consumo normal" }
        return "Consumo elevado"
    }
}

struct ConsumptionIndicatorBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Fondo con gradiente
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.3)
                    .frame(height: 12)

                // Indicador
                let position = min(value / 25, 1.0) * geo.size.width
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .offset(x: position - 8)
            }
        }
        .frame(height: 16)
        .padding(.horizontal)
    }
}

// MARK: - Viaje Actual

struct CurrentTripCard: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "road.lanes")
                    .foregroundColor(.blue)
                Text("Viaje Actual")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 24) {
                TripStatItem(
                    icon: "road.lanes",
                    value: String(format: "%.1f", fuelTracker.distanceTrip),
                    unit: "km",
                    label: "Distancia"
                )

                TripStatItem(
                    icon: "fuelpump",
                    value: String(format: "%.2f", fuelTracker.fuelUsedTrip),
                    unit: "L",
                    label: "Consumido"
                )

                TripStatItem(
                    icon: "gauge",
                    value: String(format: "%.1f", fuelTracker.tripConsumption),
                    unit: "L/100",
                    label: "Media"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct TripStatItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Autonomía

struct RangeCard: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @State private var showFuelInput = false
    @State private var manualFuelInput: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // Título y autonomía
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "fuelpump.fill")
                            .foregroundColor(.green)
                        Text("Autonomía Estimada")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    if fuelTracker.estimatedRange > 0 {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.0f", fuelTracker.estimatedRange))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("km")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("-- km")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Indicador de nivel
                FuelLevelIndicator(
                    level: fuelTracker.fuelLevel,
                    available: fuelTracker.fuelLevelAvailable || fuelTracker.manualFuelLevel != nil
                )
            }

            // Información del combustible
            HStack(spacing: 16) {
                // Mostrar nivel si está disponible o es manual
                if fuelTracker.fuelLevelAvailable || fuelTracker.manualFuelLevel != nil {
                    VStack(alignment: .leading) {
                        Text("Nivel")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.0f", fuelTracker.fuelLevel))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Restante")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", fuelTracker.fuelLevelLiters))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("L")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    // Sin sensor - mostrar mensaje
                    VStack(alignment: .leading) {
                        Text("Sin sensor de nivel")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Introduce litros manualmente")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Botón para establecer nivel manual
                Button(action: { showFuelInput = true }) {
                    HStack {
                        Image(systemName: "fuelpump.circle")
                        Text(fuelTracker.fuelLevelAvailable || fuelTracker.manualFuelLevel != nil ? "Cambiar" : "Añadir")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
            }

            // Consumo usado para el cálculo
            HStack {
                Image(systemName: "gauge.medium")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text("Consumo usado: \(String(format: "%.1f", effectiveConsumption)) L/100km")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }

            // Tiempo de motor encendido
            if fuelTracker.runtimeSeconds > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Motor encendido: \(fuelTracker.runtimeFormatted)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .alert("Nivel de Combustible", isPresented: $showFuelInput) {
            TextField("Litros", text: $manualFuelInput)
                .keyboardType(.decimalPad)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if let liters = Double(manualFuelInput) {
                    fuelTracker.setManualFuelLevel(liters)
                }
            }
        } message: {
            Text("Introduce los litros de combustible restantes (tanque: \(Int(fuelTracker.tankCapacity))L)")
        }
    }

    var effectiveConsumption: Double {
        if fuelTracker.tripConsumption > 0 && fuelTracker.distanceTrip > 5 {
            return fuelTracker.tripConsumption
        } else if fuelTracker.averageConsumption > 0 {
            return fuelTracker.averageConsumption
        }
        return 13.0
    }
}

struct FuelLevelIndicator: View {
    let level: Double // 0-100 (porcentaje de combustible restante)
    var available: Bool = true // Si el nivel está disponible

    var body: some View {
        ZStack {
            // Tanque vacío
            RoundedRectangle(cornerRadius: 8)
                .stroke(available ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: 50, height: 80)

            if available {
                // Nivel de combustible (llena desde abajo)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [levelColor.opacity(0.8), levelColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: max(4, 74 * level / 100))
                }
                .frame(width: 50, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Icono y porcentaje
                VStack(spacing: 2) {
                    Image(systemName: "fuelpump")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("\(Int(level))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                // Sin datos - mostrar interrogación
                VStack(spacing: 2) {
                    Image(systemName: "fuelpump")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    var levelColor: Color {
        if level > 50 { return .green }
        if level > 25 { return .yellow }
        if level > 10 { return .orange }
        return .red
    }
}

// MARK: - Parciales de Consumo

struct PartialsSection: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @State private var showingResetConfirmation = false
    @State private var partialToReset: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.purple)
                Text("Parciales de Consumo")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Parcial 1 - Viaje actual
            PartialCard(
                partial: fuelTracker.partial1,
                onReset: {
                    partialToReset = 1
                    showingResetConfirmation = true
                }
            )

            // Parcial 2 - Acumulado
            PartialCard(
                partial: fuelTracker.partial2,
                onReset: {
                    partialToReset = 2
                    showingResetConfirmation = true
                }
            )

            // Nota explicativa
            Text("El viaje se considera el mismo si el motor para menos de 2 horas")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .alert("¿Resetear parcial?", isPresented: $showingResetConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Resetear", role: .destructive) {
                fuelTracker.resetPartial(partialToReset)
            }
        } message: {
            Text("Se borrarán todos los datos del \(partialToReset == 1 ? "viaje actual" : "acumulado")")
        }
    }
}

struct PartialCard: View {
    let partial: TripPartial
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Header con nombre y reset
            HStack {
                Text(partial.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(partial.id == 1 ? .blue : .purple)

                if let start = partial.startTime {
                    Text(partial.dateRangeFormatted)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Stats principales
            HStack(spacing: 16) {
                PartialStatItem(
                    value: String(format: "%.1f", partial.distance),
                    unit: "km",
                    label: "Distancia"
                )

                PartialStatItem(
                    value: String(format: "%.2f", partial.fuelUsed),
                    unit: "L",
                    label: "Consumido"
                )

                PartialStatItem(
                    value: partial.avgConsumption > 0 ? String(format: "%.1f", partial.avgConsumption) : "--",
                    unit: "L/100",
                    label: "Media"
                )

                PartialStatItem(
                    value: String(format: "%.2f", partial.fuelCost),
                    unit: "€",
                    label: "Coste"
                )
            }

            // Stats secundarios
            if partial.distance > 0 {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Media: \(String(format: "%.0f", partial.avgSpeed)) km/h")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "gauge.high")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Máx: \(String(format: "%.0f", partial.maxSpeed)) km/h")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(partial.drivingTimeFormatted)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(12)
        .background(partial.id == 1 ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PartialStatItem: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Promedios

struct AveragesCard: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consumo de Referencia RX-8")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ReferenceConsumptionItem(
                    label: "Ciudad",
                    value: 15.0,
                    icon: "building.2"
                )

                ReferenceConsumptionItem(
                    label: "Mixto",
                    value: 13.0,
                    icon: "road.lanes"
                )

                ReferenceConsumptionItem(
                    label: "Autopista",
                    value: 10.0,
                    icon: "car.side"
                )
            }

            Divider()
                .background(Color.gray)

            HStack {
                VStack(alignment: .leading) {
                    Text("Tu Media")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f L/100km", fuelTracker.averageConsumption))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                ComparisonBadge(
                    userValue: fuelTracker.averageConsumption,
                    referenceValue: 13.0
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct ReferenceConsumptionItem: View {
    let label: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.caption)

            Text(String(format: "%.0f", value))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray5).opacity(0.3))
        .cornerRadius(8)
    }
}

struct ComparisonBadge: View {
    let userValue: Double
    let referenceValue: Double

    var difference: Double {
        userValue - referenceValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difference <= 0 ? "arrow.down" : "arrow.up")
            Text(String(format: "%+.1f", difference))
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(difference <= 0 ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
        .foregroundColor(difference <= 0 ? .green : .orange)
        .cornerRadius(8)
    }
}

// MARK: - Coste del Combustible

struct FuelCostCard: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "eurosign.circle")
                        .foregroundColor(.yellow)
                    Text("Coste del Viaje")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.2f", fuelTracker.fuelCost))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("€")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("CO₂ Emitido")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.0f", fuelTracker.co2Emissions * fuelTracker.distanceTrip / 1000))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("kg")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}


// MARK: - Historial de Viajes

struct TripHistoryView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // TODO: Implementar historial
                Text("Historial de viajes")
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Configuración de Combustible

struct FuelSettingsView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @Environment(\.dismiss) var dismiss
    @State private var tankCapacity: String = "60"
    @State private var fuelPrice: String = "1.50"

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehículo") {
                    HStack {
                        Text("Capacidad del tanque")
                        Spacer()
                        TextField("60", text: $tankCapacity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("L")
                            .foregroundColor(.gray)
                    }
                }

                Section("Combustible") {
                    Picker("Tipo", selection: .constant(FuelType.gasoline95)) {
                        ForEach(FuelType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    HStack {
                        Text("Precio por litro")
                        Spacer()
                        TextField("1.50", text: $fuelPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("€")
                            .foregroundColor(.gray)
                    }
                }

                Section {
                    Text("El RX-8 tiene un tanque de 60 litros. El consumo típico es de 12-15 L/100km en uso mixto.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        if let capacity = Double(tankCapacity) {
                            fuelTracker.tankCapacity = capacity
                        }
                        if let price = Double(fuelPrice) {
                            fuelTracker.fuelPricePerLiter = price
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
