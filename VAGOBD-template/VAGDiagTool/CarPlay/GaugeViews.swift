import SwiftUI

// MARK: - Circular Gauge View
struct CircularGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    let warningThreshold: Double?
    let criticalThreshold: Double?

    init(
        title: String,
        value: Double,
        maxValue: Double,
        unit: String,
        color: Color = .blue,
        warningThreshold: Double? = nil,
        criticalThreshold: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.unit = unit
        self.color = color
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
    }

    private var currentColor: Color {
        if let critical = criticalThreshold, value >= critical {
            return .red
        }
        if let warning = warningThreshold, value >= warning {
            return .orange
        }
        return color
    }

    private var progress: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .rotationEffect(.degrees(90))

                // Value arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + (progress * 0.7))
                    .stroke(
                        currentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))

                // Value display
                VStack(spacing: 2) {
                    Text(formatValue())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(currentColor)

                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    private func formatValue() -> String {
        if maxValue >= 1000 {
            return String(format: "%.0f", value)
        } else if maxValue >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Speedometer View
struct SpeedometerView: View {
    let speed: Double
    let maxSpeed: Double = 260

    var body: some View {
        ZStack {
            // Tick marks
            ForEach(0..<13) { index in
                TickMark(
                    index: index,
                    value: speed,
                    maxValue: maxSpeed
                )
            }

            // Speed needle
            SpeedNeedle(speed: speed, maxSpeed: maxSpeed)

            // Center display
            VStack(spacing: 4) {
                Text(String(format: "%.0f", speed))
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("km/h")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 250, height: 250)
    }
}

struct TickMark: View {
    let index: Int
    let value: Double
    let maxValue: Double

    var body: some View {
        let angle = -135.0 + (Double(index) * 22.5) // 270 degrees / 12 ticks
        let tickValue = (maxValue / 12) * Double(index)
        let isActive = value >= tickValue

        VStack {
            Rectangle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: index % 2 == 0 ? 4 : 2, height: index % 2 == 0 ? 20 : 12)

            if index % 2 == 0 {
                Text("\(Int(tickValue))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .offset(y: -100)
        .rotationEffect(.degrees(angle))
    }
}

struct SpeedNeedle: View {
    let speed: Double
    let maxSpeed: Double

    private var rotation: Double {
        -135.0 + ((speed / maxSpeed) * 270.0)
    }

    var body: some View {
        Triangle()
            .fill(Color.red)
            .frame(width: 8, height: 80)
            .offset(y: -40)
            .rotationEffect(.degrees(rotation))
            .animation(.easeInOut(duration: 0.3), value: speed)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tachometer View
struct TachometerView: View {
    let rpm: Double
    let maxRPM: Double
    let redline: Double

    init(rpm: Double, maxRPM: Double = 8000, redline: Double = 6500) {
        self.rpm = rpm
        self.maxRPM = maxRPM
        self.redline = redline
    }

    private var color: Color {
        if rpm >= redline {
            return .red
        } else if rpm >= redline * 0.9 {
            return .orange
        }
        return .blue
    }

    var body: some View {
        ZStack {
            // Background
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                .rotationEffect(.degrees(90))

            // Redline zone
            Circle()
                .trim(from: 0.15 + ((redline / maxRPM) * 0.7), to: 0.85)
                .stroke(Color.red.opacity(0.3), lineWidth: 16)
                .rotationEffect(.degrees(90))

            // RPM arc
            Circle()
                .trim(from: 0.15, to: 0.15 + ((rpm / maxRPM) * 0.7))
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(90))

            // Display
            VStack(spacing: 4) {
                Text(String(format: "%.0f", rpm))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text("RPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Temperature Gauge
struct TemperatureGaugeView: View {
    let title: String
    let value: Double
    let minValue: Double
    let maxValue: Double
    let warningValue: Double
    let criticalValue: Double

    private var progress: Double {
        let range = maxValue - minValue
        let adjusted = value - minValue
        return min(max(adjusted / range, 0), 1)
    }

    private var color: Color {
        if value >= criticalValue { return .red }
        if value >= warningValue { return .orange }
        if value < (minValue + (maxValue - minValue) * 0.3) { return .blue }
        return .green
    }

    var body: some View {
        VStack(spacing: 8) {
            // Thermometer style gauge
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    // Warning zone
                    VStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: geometry.size.height * 0.2)
                        Spacer()
                    }

                    // Value fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .green, .orange, .red],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: geometry.size.height * progress)
                }
            }
            .frame(width: 30, height: 100)

            Text(String(format: "%.0f°C", value))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Boost Gauge
struct BoostGaugeView: View {
    let boost: Double
    let maxBoost: Double

    private var isPositive: Bool { boost > 0 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                // Vacuum zone (left half)
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 10)
                    .rotationEffect(.degrees(0))

                // Boost zone (right half)
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(Color.green.opacity(0.3), lineWidth: 10)
                    .rotationEffect(.degrees(0))

                // Current value
                let normalizedBoost = (boost + 1) / (maxBoost + 1) // Normalize from -1 to maxBoost
                let trimEnd = 0.25 + (normalizedBoost * 0.5)

                Circle()
                    .trim(from: 0.25, to: trimEnd)
                    .stroke(
                        isPositive ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(0))

                VStack(spacing: 2) {
                    Text(String(format: "%.2f", boost))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isPositive ? .green : .blue)

                    Text("bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text("Turbo")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Dashboard Grid View
struct DashboardGridView: View {
    @ObservedObject var engineData: EngineData

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            CircularGaugeView(
                title: "Refrigerante",
                value: engineData.coolantTemp,
                maxValue: 130,
                unit: "°C",
                color: .blue,
                warningThreshold: 100,
                criticalThreshold: 110
            )

            CircularGaugeView(
                title: "Aceite",
                value: engineData.oilTemp,
                maxValue: 150,
                unit: "°C",
                color: .orange,
                warningThreshold: 120,
                criticalThreshold: 140
            )

            CircularGaugeView(
                title: "Turbo",
                value: engineData.boostPressure,
                maxValue: 2.5,
                unit: "bar",
                color: .green,
                warningThreshold: 2.0,
                criticalThreshold: 2.3
            )

            CircularGaugeView(
                title: "Voltaje",
                value: engineData.batteryVoltage,
                maxValue: 16,
                unit: "V",
                color: .yellow
            )
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            CircularGaugeView(
                title: "RPM",
                value: 3500,
                maxValue: 8000,
                unit: "rpm",
                color: .blue
            )
            .frame(width: 150, height: 180)

            CircularGaugeView(
                title: "Temp",
                value: 95,
                maxValue: 130,
                unit: "°C",
                color: .orange,
                warningThreshold: 100,
                criticalThreshold: 110
            )
            .frame(width: 150, height: 180)
        }

        BoostGaugeView(boost: 1.2, maxBoost: 2.5)
    }
    .padding()
    .background(Color.black)
}
