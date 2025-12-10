import SwiftUI

// MARK: - Vista de Consumo de Combustible
// Responsive: Vertical = Móvil, Horizontal = CarPlay

struct FuelConsumptionView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showSettings = false

    // Detectar si estamos en modo landscape (CarPlay)
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                // MODO CARPLAY - Layout horizontal optimizado
                CarPlayFuelView(geometry: geometry)
            } else {
                // MODO MÓVIL - Layout vertical con scroll
                MobileFuelView(showSettings: $showSettings)
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showSettings) {
            FuelSettingsView()
        }
    }
}

// MARK: - Vista CarPlay (Horizontal)

struct CarPlayFuelView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: 12) {
            // Columna izquierda: Consumo instantáneo grande
            VStack(spacing: 8) {
                Text("CONSUMO")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                Text(consumptionText)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(consumptionColor)
                    .minimumScaleFactor(0.5)

                Text(consumptionUnit)
                    .font(.caption)
                    .foregroundColor(.gray)

                // Barra de eficiencia compacta
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(index: i))
                            .frame(height: 8)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(width: geometry.size.width * 0.3)

            // Columna central: Stats del viaje
            VStack(spacing: 6) {
                Text("VIAJE ACTUAL")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                CarPlayStatRow(icon: "road.lanes", label: "Dist", value: formatDistance(fuelTracker.distanceTrip), unit: "km")
                CarPlayStatRow(icon: "fuelpump", label: "Usado", value: formatFuel(fuelTracker.fuelUsedTrip), unit: "L")
                CarPlayStatRow(icon: "gauge", label: "Media", value: formatConsumption(fuelTracker.tripConsumption), unit: "L/100")

                Divider().background(Color.gray.opacity(0.5))

                Text("PARCIAL")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)

                CarPlayStatRow(icon: "sum", label: "Dist", value: formatDistance(fuelTracker.partial2.distance), unit: "km")
                CarPlayStatRow(icon: "drop", label: "Usado", value: formatFuel(fuelTracker.partial2.fuelUsed), unit: "L")
            }
            .frame(width: geometry.size.width * 0.35)
            .padding(.vertical, 8)

            // Columna derecha: Autonomía y nivel
            VStack(spacing: 8) {
                Text("AUTONOMÍA")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                Text(rangeText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(fuelTracker.fuelLevelAvailable ? .white : .gray)
                    .minimumScaleFactor(0.5)

                Text("km")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                // Indicador de nivel compacto
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .foregroundColor(fuelLevelColor)
                        .font(.caption)

                    Text(fuelLevelText)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(fuelTracker.fuelLevelAvailable ? .white : .gray)

                    if fuelTracker.fuelLevelAvailable {
                        Text("% (\(formatLiters(fuelTracker.fuelLevelLiters))L)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Warning si hay
                if let warning = engineMonitor.currentState.fuelSenderWarning {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(warning)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.orange)
                }
            }
            .frame(width: geometry.size.width * 0.3)
        }
        .padding(12)
    }

    var consumptionText: String {
        fuelTracker.instantConsumption > 0 ? String(format: "%.1f", fuelTracker.instantConsumption) : "-"
    }

    var consumptionUnit: String {
        engineMonitor.currentState.vehicleSpeed < 3 ? "L/h" : "L/100km"
    }

    var consumptionColor: Color {
        let value = fuelTracker.instantConsumption
        if value <= 0 { return .gray }
        if value < 10 { return .green }
        if value < 13 { return .teal }
        if value < 16 { return .yellow }
        if value < 20 { return .orange }
        return .red
    }

    func barColor(index: Int) -> Color {
        let value = fuelTracker.instantConsumption
        let threshold = Double(index + 1) * 5 // 5, 10, 15, 20, 25
        if value <= 0 { return Color.gray.opacity(0.3) }
        if value >= threshold { return consumptionColor }
        return Color.gray.opacity(0.3)
    }

    var rangeText: String {
        guard fuelTracker.fuelLevelAvailable, fuelTracker.estimatedRange > 0 else { return "-" }
        return String(format: "%.0f", fuelTracker.estimatedRange)
    }

    var fuelLevelText: String {
        guard fuelTracker.fuelLevelAvailable else { return "-" }
        return String(format: "%.0f", fuelTracker.fuelLevel)
    }

    var fuelLevelColor: Color {
        guard fuelTracker.fuelLevelAvailable else { return .gray }
        let level = fuelTracker.fuelLevel
        if level > 50 { return .green }
        if level > 25 { return .yellow }
        if level > 10 { return .orange }
        return .red
    }

    func formatDistance(_ value: Double) -> String {
        value > 0 ? String(format: "%.1f", value) : "-"
    }

    func formatFuel(_ value: Double) -> String {
        value > 0 ? String(format: "%.2f", value) : "-"
    }

    func formatConsumption(_ value: Double) -> String {
        value > 0 ? String(format: "%.1f", value) : "-"
    }

    func formatLiters(_ value: Double) -> String {
        value > 0 ? String(format: "%.1f", value) : "-"
    }
}

struct CarPlayStatRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.blue)
                .frame(width: 14)

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(value == "-" ? .gray : .white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Vista Móvil (Vertical)

struct MobileFuelView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Consumo instantáneo
                    InstantConsumptionCardV2()

                    // Viaje actual
                    CurrentTripCardV2()

                    // Autonomía
                    RangeCardV2()

                    // Parciales - Nuevo diseño
                    PartialsSectionV2()

                    // Promedios
                    AveragesCardV2()

                    // Coste
                    FuelCostCardV2()
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
        }
    }
}

// MARK: - Componentes V2 (Rediseñados)

struct InstantConsumptionCardV2: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor

    var hasData: Bool {
        fuelTracker.instantConsumption > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Consumo Instantáneo")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(hasData ? String(format: "%.1f", fuelTracker.instantConsumption) : "-")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(hasData ? consumptionColor : .gray)

                VStack(alignment: .leading) {
                    Text(consumptionUnit)
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }

            // Barra de eficiencia
            if hasData {
                ConsumptionBarV2(value: fuelTracker.instantConsumption)

                HStack {
                    Image(systemName: efficiencyIcon)
                        .foregroundColor(consumptionColor)
                    Text(efficiencyText)
                        .font(.caption)
                        .foregroundColor(consumptionColor)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [consumptionColor.opacity(hasData ? 0.3 : 0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(24)
    }

    var consumptionUnit: String {
        engineMonitor.currentState.vehicleSpeed < 3 ? "L/h" : "L/100km"
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

struct ConsumptionBarV2: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
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

struct CurrentTripCardV2: View {
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

            // Grid de 3 columnas con anchos fijos
            HStack(spacing: 0) {
                StatColumnV2(
                    icon: "road.lanes",
                    value: fuelTracker.distanceTrip > 0 ? String(format: "%.1f", fuelTracker.distanceTrip) : "-",
                    unit: "km",
                    label: "Distancia"
                )

                StatColumnV2(
                    icon: "fuelpump",
                    value: fuelTracker.fuelUsedTrip > 0 ? String(format: "%.2f", fuelTracker.fuelUsedTrip) : "-",
                    unit: "L",
                    label: "Consumido"
                )

                StatColumnV2(
                    icon: "gauge",
                    value: fuelTracker.tripConsumption > 0 ? String(format: "%.1f", fuelTracker.tripConsumption) : "-",
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

// MARK: - Columna de Stat V2 (Nunca se descuadra)

struct StatColumnV2: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)

            // Valor con fuente monoespaciada en contenedor fijo
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(value == "-" ? .gray : .white)
                .frame(height: 24)

            // Unidad
            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(height: 14)

            // Label
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Autonomía V2

struct RangeCardV2: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor
    @State private var showFuelSenderConfig = false

    var hasData: Bool {
        fuelTracker.fuelLevelAvailable
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "fuelpump.fill")
                            .foregroundColor(hasData ? .green : .gray)
                        Text("Autonomía Estimada")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(hasData && fuelTracker.estimatedRange > 0 ? String(format: "%.0f", fuelTracker.estimatedRange) : "-")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(hasData ? .white : .gray)
                        Text("km")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Indicador de nivel
                FuelLevelIndicatorV2(
                    level: fuelTracker.fuelLevel,
                    available: hasData
                )
            }

            // Info combustible
            HStack(spacing: 16) {
                if hasData {
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
                    VStack(alignment: .leading) {
                        Text("Sin datos de nivel")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Configura las sondas")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: { showFuelSenderConfig = true }) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        Text("Sondas")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
                }
            }

            // Warning
            if let warning = engineMonitor.currentState.fuelSenderWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            // Info adicional
            if hasData {
                HStack {
                    Image(systemName: "gauge.medium")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Consumo: \(String(format: "%.1f", effectiveConsumption)) L/100km")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }

            if fuelTracker.runtimeSeconds > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Motor: \(fuelTracker.runtimeFormatted)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .sheet(isPresented: $showFuelSenderConfig) {
            FuelSenderConfigView()
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

struct FuelLevelIndicatorV2: View {
    let level: Double
    var available: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(available ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: 50, height: 80)

            if available {
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

                VStack(spacing: 2) {
                    Image(systemName: "fuelpump")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("\(Int(level))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "fuelpump")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("-")
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

// MARK: - Parciales V2 (Nuevo diseño que nunca se descuadra)

struct PartialsSectionV2: View {
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

            // Parcial 1
            PartialCardV2(
                partial: fuelTracker.partial1,
                color: .blue,
                onReset: {
                    partialToReset = 1
                    showingResetConfirmation = true
                }
            )

            // Parcial 2
            PartialCardV2(
                partial: fuelTracker.partial2,
                color: .purple,
                onReset: {
                    partialToReset = 2
                    showingResetConfirmation = true
                }
            )

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

struct PartialCardV2: View {
    let partial: TripPartial
    let color: Color
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text(partial.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                if partial.startTime != nil {
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

            // Stats en grid de 2x2 - NUNCA se descuadra
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                PartialStatBoxV2(label: "Distancia", value: formatValue(partial.distance, decimals: 1), unit: "km")
                PartialStatBoxV2(label: "Consumido", value: formatValue(partial.fuelUsed, decimals: 2), unit: "L")
                PartialStatBoxV2(label: "Media", value: formatValue(partial.avgConsumption, decimals: 1), unit: "L/100")
                PartialStatBoxV2(label: "Coste", value: formatValue(partial.fuelCost, decimals: 2), unit: "€")
            }

            // Stats secundarios
            if partial.distance > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(partial.avgSpeed)) km/h")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "gauge.high")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Máx \(Int(partial.maxSpeed))")
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
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    func formatValue(_ value: Double, decimals: Int) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.\(decimals)f", value)
    }
}

struct PartialStatBoxV2: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(value == "-" ? .gray : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Promedios V2

struct AveragesCardV2: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consumo de Referencia RX-8")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ReferenceItemV2(label: "Ciudad", value: 15.0, icon: "building.2")
                ReferenceItemV2(label: "Mixto", value: 13.0, icon: "road.lanes")
                ReferenceItemV2(label: "Autopista", value: 10.0, icon: "car.side")
            }

            Divider().background(Color.gray)

            HStack {
                VStack(alignment: .leading) {
                    Text("Tu Media")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(fuelTracker.averageConsumption > 0 ? String(format: "%.1f L/100km", fuelTracker.averageConsumption) : "- L/100km")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(fuelTracker.averageConsumption > 0 ? .white : .gray)
                }

                Spacer()

                if fuelTracker.averageConsumption > 0 {
                    ComparisonBadgeV2(
                        userValue: fuelTracker.averageConsumption,
                        referenceValue: 13.0
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct ReferenceItemV2: View {
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

struct ComparisonBadgeV2: View {
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

// MARK: - Coste V2

struct FuelCostCardV2: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker

    var hasData: Bool {
        fuelTracker.fuelCost > 0
    }

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
                    Text(hasData ? String(format: "%.2f", fuelTracker.fuelCost) : "-")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(hasData ? .white : .gray)
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
                    let co2 = fuelTracker.co2Emissions * fuelTracker.distanceTrip / 1000
                    Text(co2 > 0 ? String(format: "%.0f", co2) : "-")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(co2 > 0 ? .white : .gray)
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

// MARK: - Configuración de Sondas

struct FuelSenderConfigView: View {
    @EnvironmentObject var fuelTracker: FuelConsumptionTracker
    @EnvironmentObject var engineMonitor: EngineMonitor
    @Environment(\.dismiss) var dismiss
    @AppStorage("fuelSenderMode") private var senderMode: String = "both"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("El RX-8 tiene un depósito 'saddle tank' dividido en dos secciones con sondas independientes. Si una falla, puedes usar solo la otra.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section("Lecturas Actuales") {
                    SenderRowV2(
                        icon: "l.circle.fill",
                        color: .blue,
                        name: "Sonda Izquierda",
                        value: engineMonitor.currentState.fuelLevelLeftSender
                    )

                    SenderRowV2(
                        icon: "r.circle.fill",
                        color: .purple,
                        name: "Sonda Derecha",
                        value: engineMonitor.currentState.fuelLevelRightSender
                    )

                    SenderRowV2(
                        icon: "car.fill",
                        color: .green,
                        name: "OBD Estándar",
                        value: fuelTracker.fuelLevel > 0 ? fuelTracker.fuelLevel : nil
                    )
                }

                Section("Sonda a Utilizar") {
                    Picker("Modo", selection: $senderMode) {
                        Label("Solo Izquierda", systemImage: "l.circle.fill").tag("left")
                        Label("Solo Derecha", systemImage: "r.circle.fill").tag("right")
                        Label("Ambas (Promedio)", systemImage: "circle.lefthalf.filled").tag("both")
                        Label("OBD Estándar", systemImage: "car.fill").tag("standard")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    HStack {
                        Text("Nivel Calculado")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(calculatedLevel > 0 ? String(format: "%.0f%%", calculatedLevel) : "-")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(calculatedLevel > 0 ? .green : .gray)
                    }

                    HStack {
                        Text("Litros Restantes")
                        Spacer()
                        Text(calculatedLevel > 0 ? String(format: "%.1f L", calculatedLevel * 0.6) : "-")
                            .foregroundColor(calculatedLevel > 0 ? .white : .gray)
                    }

                    HStack {
                        Text("Autonomía Estimada")
                        Spacer()
                        let range = calculatedLevel > 0 ? (calculatedLevel * 0.6 / 13.0) * 100 : 0
                        Text(range > 0 ? String(format: "%.0f km", range) : "-")
                            .foregroundColor(range > 0 ? .white : .gray)
                    }
                }

                Section {
                    Text("Si tu indicador de combustible está atascado, probablemente una de las sondas esté defectuosa. Selecciona solo la sonda que funcione correctamente.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Sondas de Combustible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        applyConfiguration()
                        dismiss()
                    }
                }
            }
            .onChange(of: senderMode) { _, _ in
                applyConfiguration()
            }
        }
    }

    var calculatedLevel: Double {
        let left = engineMonitor.currentState.fuelLevelLeftSender
        let right = engineMonitor.currentState.fuelLevelRightSender
        let standard = fuelTracker.fuelLevel

        switch senderMode {
        case "left":
            return left ?? 0
        case "right":
            return right ?? 0
        case "both":
            if let l = left, let r = right {
                return (l + r) / 2
            }
            return left ?? right ?? 0
        case "standard":
            return standard > 0 ? standard : 0
        default:
            return standard > 0 ? standard : 0
        }
    }

    func applyConfiguration() {
        if calculatedLevel > 0 {
            fuelTracker.updateFuelLevel(calculatedLevel)
        }
    }
}

struct SenderRowV2: View {
    let icon: String
    let color: Color
    let name: String
    let value: Double?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(name)
            Spacer()
            if let v = value {
                Text(String(format: "%.0f%%", v))
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            } else {
                Text("-")
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Settings

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
