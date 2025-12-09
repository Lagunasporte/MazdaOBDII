import SwiftUI

// MARK: - Relojes Estéticos para CarPlay y Dashboard
// Diseño racing inspirado en el RX-8

// MARK: - Reloj Circular Principal (Tacómetro/Velocímetro)

struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let warningValue: Double?
    let criticalValue: Double?
    let accentColor: Color

    @State private var animatedValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = size * 0.08
            let radius = (size - lineWidth) / 2

            ZStack {
                // Fondo del arco
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

                // Arco de progreso con gradiente
                Circle()
                    .trim(from: 0, to: min(animatedValue / maxValue, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: gaugeGradientColors,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * animatedValue / maxValue)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animatedValue)

                // Marcas de escala
                ForEach(0..<11) { i in
                    ScaleMark(
                        index: i,
                        radius: radius - lineWidth,
                        isWarning: isWarningMark(i),
                        isCritical: isCriticalMark(i)
                    )
                }

                // Valor central
                VStack(spacing: 4) {
                    Text(formattedValue)
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(valueColor)
                        .monospacedDigit()

                    Text(unit)
                        .font(.system(size: size * 0.08))
                        .foregroundColor(.gray)

                    Text(title)
                        .font(.system(size: size * 0.06))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { _, newValue in
            withAnimation {
                animatedValue = newValue
            }
        }
    }

    var formattedValue: String {
        if maxValue >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    var gaugeGradientColors: [Color] {
        if let critical = criticalValue, value >= critical {
            return [.red, .red]
        }
        if let warning = warningValue, value >= warning {
            return [accentColor, .orange, .red]
        }
        return [accentColor, accentColor.opacity(0.8)]
    }

    var valueColor: Color {
        if let critical = criticalValue, value >= critical {
            return .red
        }
        if let warning = warningValue, value >= warning {
            return .orange
        }
        return .white
    }

    func isWarningMark(_ index: Int) -> Bool {
        guard let warning = warningValue else { return false }
        let markValue = (Double(index) / 10.0) * maxValue
        return markValue >= warning && markValue < (criticalValue ?? maxValue)
    }

    func isCriticalMark(_ index: Int) -> Bool {
        guard let critical = criticalValue else { return false }
        let markValue = (Double(index) / 10.0) * maxValue
        return markValue >= critical
    }
}

struct ScaleMark: View {
    let index: Int
    let radius: CGFloat
    let isWarning: Bool
    let isCritical: Bool

    var body: some View {
        Rectangle()
            .fill(markColor)
            .frame(width: 2, height: index % 5 == 0 ? 12 : 6)
            .offset(y: -radius + 6)
            .rotationEffect(.degrees(Double(index) * 36 - 90))
    }

    var markColor: Color {
        if isCritical { return .red }
        if isWarning { return .orange }
        return .gray.opacity(0.5)
    }
}

// MARK: - Tacómetro RX-8 Style

struct RX8Tachometer: View {
    let rpm: Int
    let redline: Int

    var body: some View {
        CircularGauge(
            value: Double(rpm),
            maxValue: 10000,
            title: "RPM",
            unit: "x100",
            warningValue: Double(redline - 1000),
            criticalValue: Double(redline),
            accentColor: .orange
        )
    }
}

// MARK: - Velocímetro

struct Speedometer: View {
    let speed: Double

    var body: some View {
        CircularGauge(
            value: speed,
            maxValue: 280,
            title: "Velocidad",
            unit: "km/h",
            warningValue: nil,
            criticalValue: nil,
            accentColor: .blue
        )
    }
}

// MARK: - Medidor de Temperatura

struct TemperatureGauge: View {
    let value: Double
    let type: TempType
    let warningThreshold: Double
    let criticalThreshold: Double

    enum TempType {
        case coolant
        case oil

        var title: String {
            switch self {
            case .coolant: return "Refrigerante"
            case .oil: return "Aceite"
            }
        }

        var icon: String {
            switch self {
            case .coolant: return "thermometer.medium"
            case .oil: return "drop.fill"
            }
        }

        var color: Color {
            switch self {
            case .coolant: return .teal
            case .oil: return .yellow
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Barra vertical de temperatura
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Fondo
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    // Nivel
                    RoundedRectangle(cornerRadius: 8)
                        .fill(temperatureGradient)
                        .frame(height: geo.size.height * min(value / 150, 1.0))

                    // Marcas de umbral
                    VStack {
                        Spacer()
                            .frame(height: geo.size.height * (1 - criticalThreshold / 150))
                        Rectangle()
                            .fill(Color.red)
                            .frame(height: 2)
                        Spacer()
                    }

                    VStack {
                        Spacer()
                            .frame(height: geo.size.height * (1 - warningThreshold / 150))
                        Rectangle()
                            .fill(Color.orange)
                            .frame(height: 2)
                        Spacer()
                    }
                }
            }
            .frame(width: 30, height: 100)

            // Valor
            Text(String(format: "%.0f°", value))
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(valueColor)

            // Título
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.title)
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
    }

    var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [type.color, type.color.opacity(0.5)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var valueColor: Color {
        if value >= criticalThreshold { return .red }
        if value >= warningThreshold { return .orange }
        if value < 70 { return .blue }
        return .white
    }
}

// MARK: - Barra de Consumo Horizontal

struct ConsumptionBar: View {
    let instantConsumption: Double
    let averageConsumption: Double

    var body: some View {
        VStack(spacing: 12) {
            // Título
            HStack {
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(.green)
                Text("Consumo")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Barra principal
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Fondo con gradiente de eficiencia
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(0.3)

                    // Indicador instantáneo
                    let position = min(instantConsumption / 25, 1.0) * geo.size.width
                    RoundedRectangle(cornerRadius: 4)
                        .fill(consumptionColor)
                        .frame(width: 4, height: 24)
                        .offset(x: position - 2)
                        .animation(.spring(response: 0.3), value: instantConsumption)

                    // Indicador de media
                    let avgPosition = min(averageConsumption / 25, 1.0) * geo.size.width
                    Triangle()
                        .fill(Color.white)
                        .frame(width: 12, height: 8)
                        .offset(x: avgPosition - 6, y: -16)
                }
            }
            .frame(height: 24)

            // Valores
            HStack {
                VStack(alignment: .leading) {
                    Text("Instantáneo")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f L/100km", instantConsumption))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(consumptionColor)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Media")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f L/100km", averageConsumption))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Escala
            HStack {
                Text("5")
                Spacer()
                Text("10")
                Spacer()
                Text("15")
                Spacer()
                Text("20")
                Spacer()
                Text("25")
            }
            .font(.caption2)
            .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }

    var consumptionColor: Color {
        if instantConsumption < 10 { return .green }
        if instantConsumption < 13 { return .teal }
        if instantConsumption < 16 { return .yellow }
        if instantConsumption < 20 { return .orange }
        return .red
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Panel de Instrumentos Completo

struct InstrumentCluster: View {
    let rpm: Int
    let speed: Double
    let coolantTemp: Double
    let oilTemp: Double
    let fuelLevel: Double
    let consumption: Double

    var body: some View {
        VStack(spacing: 20) {
            // Fila superior: Tacómetro y Velocímetro
            HStack(spacing: 20) {
                RX8Tachometer(rpm: rpm, redline: 9000)
                    .frame(width: 160, height: 160)

                Speedometer(speed: speed)
                    .frame(width: 160, height: 160)
            }

            // Fila inferior: Temperaturas y Combustible
            HStack(spacing: 30) {
                TemperatureGauge(
                    value: coolantTemp,
                    type: .coolant,
                    warningThreshold: 100,
                    criticalThreshold: 105
                )

                // Nivel de combustible
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: fuelLevel / 100)
                            .stroke(fuelColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: "fuelpump.fill")
                            .foregroundColor(fuelColor)
                    }

                    Text(String(format: "%.0f%%", fuelLevel))
                        .font(.caption)
                        .foregroundColor(.white)
                }

                TemperatureGauge(
                    value: oilTemp,
                    type: .oil,
                    warningThreshold: 120,
                    criticalThreshold: 130
                )
            }

            // Consumo
            ConsumptionBar(instantConsumption: consumption, averageConsumption: 13.5)
        }
        .padding()
        .background(Color.black)
    }

    var fuelColor: Color {
        if fuelLevel < 10 { return .red }
        if fuelLevel < 25 { return .orange }
        return .green
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        InstrumentCluster(
            rpm: 3500,
            speed: 80,
            coolantTemp: 88,
            oilTemp: 95,
            fuelLevel: 65,
            consumption: 12.5
        )
    }
}
