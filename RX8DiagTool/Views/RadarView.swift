import SwiftUI
import CoreLocation

// MARK: - Vista de Avisador de Radares (Responsive)

struct RadarView: View {
    @EnvironmentObject var radarManager: SpeedCameraManager
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                CarPlayRadarView(geometry: geometry)
            } else {
                MobileRadarView()
            }
        }
        .background(Color.black)
    }
}

// MARK: - Vista CarPlay Radar (Horizontal)

struct CarPlayRadarView: View {
    @EnvironmentObject var radarManager: SpeedCameraManager
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: 12) {
            // Columna izquierda: Velocidad actual
            VStack(spacing: 4) {
                Text("VELOCIDAD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                Text(String(format: "%.0f", radarManager.currentSpeed))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(speedColor)
                    .minimumScaleFactor(0.5)

                Text("km/h")
                    .font(.caption)
                    .foregroundColor(.gray)

                // GPS indicator
                HStack(spacing: 4) {
                    Image(systemName: radarManager.currentLocation != nil ? "location.fill" : "location.slash")
                        .font(.caption2)
                        .foregroundColor(radarManager.currentLocation != nil ? .green : .red)
                    Text(radarManager.currentLocation != nil ? "GPS OK" : "Sin GPS")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: geometry.size.width * 0.25)

            // Columna central: Estado de alerta
            VStack(spacing: 8) {
                RadarAlertIndicator()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width * 0.45)

            // Columna derecha: Info y control
            VStack(spacing: 8) {
                // Toggle activar/desactivar
                Toggle(isOn: $radarManager.isEnabled) {
                    HStack {
                        Image(systemName: radarManager.isEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(radarManager.isEnabled ? .green : .gray)
                        Text(radarManager.isEnabled ? "Activo" : "Inactivo")
                            .font(.caption)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))

                Divider().background(Color.gray)

                // Radares cercanos
                if !radarManager.nearbyCameras.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CERCANOS")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        ForEach(radarManager.nearbyCameras.prefix(3)) { camera in
                            HStack {
                                Image(systemName: cameraIcon(for: camera.type))
                                    .font(.caption2)
                                    .foregroundColor(.orange)

                                if let speed = camera.maxSpeed {
                                    Text("\(speed)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }

                                Spacer()

                                Text(formatDistance(to: camera))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Zona libre")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Total cargados
                Text("\(radarManager.totalCamerasLoaded) radares")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: geometry.size.width * 0.25)
            .padding(.vertical, 8)
        }
        .padding(12)
    }

    var speedColor: Color {
        if radarManager.currentSpeed > 140 { return .red }
        if radarManager.currentSpeed > 120 { return .orange }
        return .white
    }

    func cameraIcon(for type: SpeedCamera.CameraType) -> String {
        switch type {
        case .fixed: return "camera.fill"
        case .mobile: return "camera"
        case .trafficLight: return "traffic.light"
        case .average: return "arrow.left.arrow.right"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    func formatDistance(to camera: SpeedCamera) -> String {
        guard let location = radarManager.currentLocation else { return "-" }
        let distance = location.distance(from: CLLocation(latitude: camera.latitude, longitude: camera.longitude))
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Vista Móvil Radar (Vertical)

struct MobileRadarView: View {
    @EnvironmentObject var radarManager: SpeedCameraManager
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Estado principal
                    MainRadarStatusCard()

                    // Alerta actual
                    RadarAlertCard()

                    // Radares cercanos
                    NearbyCamerasCard()

                    // Controles
                    RadarControlsCard()

                    // Estadísticas
                    RadarStatsCard()
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Avisador Radares")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                RadarSettingsView()
            }
        }
    }
}

// MARK: - Componentes

struct MainRadarStatusCard: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        VStack(spacing: 16) {
            // Velocidad actual grande
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", radarManager.currentSpeed))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(speedColor)

                Text("km/h")
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            // Estado GPS y Background
            HStack(spacing: 8) {
                Image(systemName: radarManager.currentLocation != nil ? "location.fill" : "location.slash")
                    .foregroundColor(radarManager.currentLocation != nil ? .green : .red)

                Text(radarManager.currentLocation != nil ? "GPS conectado" : "Esperando GPS...")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Indicador de modo background
                if radarManager.backgroundEnabled && radarManager.locationPermissionStatus == .authorizedAlways {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                // Toggle
                Toggle("", isOn: $radarManager.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .labelsHidden()

                Text(radarManager.isEnabled ? "Activo" : "Inactivo")
                    .font(.caption)
                    .foregroundColor(radarManager.isEnabled ? .green : .gray)
            }

            // Aviso si background no está disponible
            if radarManager.isEnabled && radarManager.backgroundEnabled && radarManager.locationPermissionStatus == .authorizedWhenInUse {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Solo funciona en primer plano")
                        .font(.caption2)
                        .foregroundColor(.orange)

                    Button("Activar") {
                        radarManager.requestAlwaysPermission()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [alertBackgroundColor.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(24)
    }

    var speedColor: Color {
        if case .approaching = radarManager.alertState {
            return .orange
        }
        if radarManager.currentSpeed > 140 { return .red }
        if radarManager.currentSpeed > 120 { return .orange }
        return .white
    }

    var alertBackgroundColor: Color {
        switch radarManager.alertState {
        case .approaching: return .orange
        case .passing: return .red
        case .passed: return .green
        case .none: return .clear
        }
    }
}

struct RadarAlertCard: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        Group {
            switch radarManager.alertState {
            case .approaching(let camera, let distance):
                AlertBannerRadar(
                    title: "¡RADAR ADELANTE!",
                    subtitle: "A \(Int(distance))m",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    speedLimit: camera.maxSpeed
                )

            case .passing(let camera):
                AlertBannerRadar(
                    title: "¡PASANDO RADAR!",
                    subtitle: "Reduce velocidad",
                    icon: "camera.fill",
                    color: .red,
                    speedLimit: camera.maxSpeed
                )

            case .passed:
                AlertBannerRadar(
                    title: "Radar superado",
                    subtitle: "Zona segura",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    speedLimit: nil
                )

            case .none:
                EmptyView()
            }
        }
    }
}

struct AlertBannerRadar: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let speedLimit: Int?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            if let limit = speedLimit {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)

                    Circle()
                        .stroke(Color.red, lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Text("\(limit)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(20)
        .background(color)
        .cornerRadius(16)
    }
}

struct RadarAlertIndicator: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        VStack(spacing: 8) {
            switch radarManager.alertState {
            case .approaching(let camera, let distance):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .symbolEffect(.pulse, options: .repeating)

                Text("RADAR")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Text("\(Int(distance))m")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                if let limit = camera.maxSpeed {
                    SpeedLimitSign(limit: limit)
                }

            case .passing(let camera):
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)

                Text("¡PASANDO!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                if let limit = camera.maxSpeed {
                    SpeedLimitSign(limit: limit)
                }

            case .passed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)

                Text("Superado")
                    .font(.subheadline)
                    .foregroundColor(.green)

            case .none:
                if radarManager.isEnabled {
                    Image(systemName: "shield.checkmark")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("Zona segura")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("Desactivado")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct SpeedLimitSign: View {
    let limit: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)

            Circle()
                .stroke(Color.red, lineWidth: 5)
                .frame(width: 50, height: 50)

            Text("\(limit)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

struct NearbyCamerasCard: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.orange)
                Text("Radares Cercanos")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(radarManager.nearbyCameras.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
            }

            if radarManager.nearbyCameras.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("No hay radares cercanos")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(radarManager.nearbyCameras) { camera in
                    CameraRowView(camera: camera)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct CameraRowView: View {
    @EnvironmentObject var radarManager: SpeedCameraManager
    let camera: SpeedCamera

    var body: some View {
        HStack {
            // Icono tipo
            Image(systemName: cameraIcon)
                .foregroundColor(.orange)
                .frame(width: 30)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(cameraTypeName)
                    .font(.subheadline)
                    .foregroundColor(.white)

                if let speed = camera.maxSpeed {
                    Text("Límite: \(speed) km/h")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Distancia
            Text(distanceText)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(distanceColor)
        }
        .padding(.vertical, 8)
    }

    var cameraIcon: String {
        switch camera.type {
        case .fixed: return "camera.fill"
        case .mobile: return "camera"
        case .trafficLight: return "traffic.light"
        case .average: return "arrow.left.arrow.right"
        case .unknown: return "questionmark.circle"
        }
    }

    var cameraTypeName: String {
        switch camera.type {
        case .fixed: return "Radar Fijo"
        case .mobile: return "Zona Móvil"
        case .trafficLight: return "Cámara Semáforo"
        case .average: return "Radar de Tramo"
        case .unknown: return "Radar"
        }
    }

    var distance: Double {
        guard let location = radarManager.currentLocation else { return 0 }
        return location.distance(from: CLLocation(latitude: camera.latitude, longitude: camera.longitude))
    }

    var distanceText: String {
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    var distanceColor: Color {
        if distance < 200 { return .red }
        if distance < 500 { return .orange }
        return .white
    }
}

struct RadarControlsCard: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        VStack(spacing: 12) {
            // País detectado
            if !radarManager.currentCountry.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("País: \(radarManager.currentCountry)")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
            }

            // Progreso de descarga
            if !radarManager.downloadProgress.isEmpty {
                HStack {
                    if radarManager.isLoading {
                        ProgressView()
                            .tint(.orange)
                            .scaleEffect(0.8)
                    }
                    Text(radarManager.downloadProgress)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
            }

            // Botón descargar TODO el país
            Button(action: {
                Task {
                    await radarManager.downloadCamerasForCurrentCountry()
                }
            }) {
                HStack {
                    if radarManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "flag.fill")
                    }
                    Text(radarManager.isLoading ? "Descargando..." : "Descargar radares del país")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(radarManager.isLoading || radarManager.currentLocation == nil)

            // Botón descargar solo zona cercana
            Button(action: {
                Task {
                    await radarManager.downloadCamerasForCurrentArea(radiusKm: 50)
                }
            }) {
                HStack {
                    Image(systemName: "location.circle")
                    Text("Solo zona cercana (50km)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(radarManager.isLoading || radarManager.currentLocation == nil)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct RadarStatsCard: View {
    @EnvironmentObject var radarManager: SpeedCameraManager

    var body: some View {
        VStack(spacing: 12) {
            // País descargado
            if !radarManager.downloadedCountry.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Datos de: \(radarManager.downloadedCountry)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                }
            }

            HStack(spacing: 20) {
                StatItemRadar(
                    icon: "camera.fill",
                    value: "\(radarManager.totalCamerasLoaded)",
                    label: "Cargados"
                )

                StatItemRadar(
                    icon: "ruler",
                    value: "\(Int(radarManager.alertDistance))m",
                    label: "Distancia alerta"
                )

                if let lastUpdate = radarManager.lastUpdate {
                    StatItemRadar(
                        icon: "clock",
                        value: lastUpdate.formatted(date: .abbreviated, time: .shortened),
                        label: "Actualizado"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct StatItemRadar: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.orange)

            Text(value)
                .font(.headline)
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings View

struct RadarSettingsView: View {
    @EnvironmentObject var radarManager: SpeedCameraManager
    @Environment(\.dismiss) var dismiss
    @State private var alertDistanceValue: Double = 500

    var body: some View {
        NavigationStack {
            Form {
                Section("Alertas") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Distancia de alerta")
                            Spacer()
                            Text("\(Int(alertDistanceValue))m")
                                .foregroundColor(.orange)
                        }

                        Slider(value: $alertDistanceValue, in: 200...1000, step: 50)
                            .tint(.orange)
                    }

                    Toggle("Sonido de alerta", isOn: $radarManager.soundEnabled)

                    Toggle("Vibración", isOn: $radarManager.vibrationEnabled)
                }

                Section("Segundo plano") {
                    Toggle("Funcionar en segundo plano", isOn: $radarManager.backgroundEnabled)
                        .onChange(of: radarManager.backgroundEnabled) { _, newValue in
                            radarManager.updateBackgroundMode()
                            if newValue && radarManager.locationPermissionStatus == .authorizedWhenInUse {
                                radarManager.requestAlwaysPermission()
                            }
                        }

                    // Estado del permiso
                    HStack {
                        Text("Permiso de ubicación")
                        Spacer()
                        Text(permissionStatusText)
                            .font(.caption)
                            .foregroundColor(permissionStatusColor)
                    }

                    if radarManager.backgroundEnabled && radarManager.locationPermissionStatus == .authorizedWhenInUse {
                        Button(action: {
                            radarManager.requestAlwaysPermission()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Permitir ubicación siempre")
                            }
                        }

                        Text("Para alertas en segundo plano, permite el acceso a la ubicación 'Siempre' en Ajustes > Privacidad > Ubicación.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if radarManager.locationPermissionStatus == .authorizedAlways && radarManager.backgroundEnabled {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Alertas en segundo plano activas")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Section("Datos") {
                    HStack {
                        Text("Radares cargados")
                        Spacer()
                        Text("\(radarManager.totalCamerasLoaded)")
                            .foregroundColor(.gray)
                    }

                    Button(role: .destructive) {
                        radarManager.clearCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Borrar caché de radares")
                        }
                    }
                }

                Section {
                    Text("Los datos de radares provienen de OpenStreetMap y pueden no estar completos. Conduce siempre respetando los límites de velocidad.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Configuración Radares")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        radarManager.alertDistance = alertDistanceValue
                        dismiss()
                    }
                }
            }
            .onAppear {
                alertDistanceValue = radarManager.alertDistance
            }
        }
    }

    var permissionStatusText: String {
        switch radarManager.locationPermissionStatus {
        case .authorizedAlways:
            return "Siempre"
        case .authorizedWhenInUse:
            return "Solo en uso"
        case .denied:
            return "Denegado"
        case .restricted:
            return "Restringido"
        case .notDetermined:
            return "No determinado"
        @unknown default:
            return "Desconocido"
        }
    }

    var permissionStatusColor: Color {
        switch radarManager.locationPermissionStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        default:
            return .red
        }
    }
}
