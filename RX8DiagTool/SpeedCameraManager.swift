import Foundation
import CoreLocation
import AudioToolbox
import SwiftUI

// MARK: - Modelo de Radar/Cámara de Velocidad

public struct SpeedCamera: Codable, Identifiable, Equatable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let maxSpeed: Int?  // Límite de velocidad si está disponible
    public let type: CameraType
    public let direction: Double?  // Dirección en grados si está disponible

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public enum CameraType: String, Codable {
        case fixed = "fixed"           // Radar fijo
        case mobile = "mobile"         // Zona de radar móvil
        case trafficLight = "traffic"  // Cámara de semáforo
        case average = "average"       // Radar de tramo
        case unknown = "unknown"
    }

    public static func == (lhs: SpeedCamera, rhs: SpeedCamera) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Estado de Alerta de Radar

public enum RadarAlertState: Equatable {
    case none
    case approaching(camera: SpeedCamera, distance: Double)
    case passing(camera: SpeedCamera)
    case passed(camera: SpeedCamera)
}

// MARK: - Speed Camera Manager

@MainActor
public class SpeedCameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published public var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published public var currentLocation: CLLocation?
    @Published public var currentSpeed: Double = 0  // km/h
    @Published public var alertState: RadarAlertState = .none
    @Published public var nearbyCameras: [SpeedCamera] = []
    @Published public var isLoading: Bool = false
    @Published public var lastUpdate: Date?
    @Published public var totalCamerasLoaded: Int = 0
    @Published public var locationPermissionStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Configuration

    @AppStorage("radarAlertDistance") public var alertDistance: Double = 500  // metros
    @AppStorage("radarSoundEnabled") public var soundEnabled: Bool = true
    @AppStorage("radarVibrationEnabled") public var vibrationEnabled: Bool = true

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var cameras: [SpeedCamera] = []
    private var lastAlertedCameraId: String?
    private var lastAlertTime: Date?
    private var passedCameras: Set<String> = []

    // Cache
    private let cacheFileName = "speed_cameras_cache.json"
    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFileName)
    }

    // MARK: - Initialization

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10  // Actualizar cada 10 metros
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false

        loadCachedCameras()
    }

    // MARK: - Public Methods

    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func startMonitoring() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("Location services not enabled")
            return
        }

        let status = locationManager.authorizationStatus
        locationPermissionStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            requestLocationPermission()
        case .denied, .restricted:
            print("Location permission denied")
        @unknown default:
            break
        }
    }

    public func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        alertState = .none
        passedCameras.removeAll()
    }

    /// Descarga radares de OpenStreetMap para el área actual
    public func downloadCamerasForCurrentArea(radiusKm: Double = 50) async {
        guard let location = currentLocation else {
            print("No current location available")
            return
        }

        isLoading = true

        do {
            let newCameras = try await fetchCamerasFromOSM(
                center: location.coordinate,
                radiusKm: radiusKm
            )

            // Merge con cámaras existentes (evitar duplicados)
            var cameraDict = Dictionary(uniqueKeysWithValues: cameras.map { ($0.id, $0) })
            for camera in newCameras {
                cameraDict[camera.id] = camera
            }
            cameras = Array(cameraDict.values)
            totalCamerasLoaded = cameras.count
            lastUpdate = Date()

            // Guardar en caché
            saveCamerasToCache()

            print("Loaded \(newCameras.count) new cameras, total: \(cameras.count)")
        } catch {
            print("Error downloading cameras: \(error)")
        }

        isLoading = false
    }

    /// Carga radares de ejemplo para España (principales autovías)
    public func loadDefaultSpainCameras() {
        // Radares conocidos de ejemplo en España
        let defaultCameras: [SpeedCamera] = [
            // A-7 (Autovía del Mediterráneo)
            SpeedCamera(id: "es_a7_1", latitude: 41.3851, longitude: 2.1734, maxSpeed: 120, type: .fixed, direction: nil),
            SpeedCamera(id: "es_a7_2", latitude: 41.2891, longitude: 2.0734, maxSpeed: 120, type: .fixed, direction: nil),

            // A-2 (Autovía del Nordeste)
            SpeedCamera(id: "es_a2_1", latitude: 41.4036, longitude: 2.1744, maxSpeed: 120, type: .fixed, direction: nil),

            // M-30 Madrid
            SpeedCamera(id: "es_m30_1", latitude: 40.4168, longitude: -3.7038, maxSpeed: 90, type: .fixed, direction: nil),
            SpeedCamera(id: "es_m30_2", latitude: 40.4268, longitude: -3.6838, maxSpeed: 90, type: .fixed, direction: nil),

            // A-1 (Autovía del Norte)
            SpeedCamera(id: "es_a1_1", latitude: 40.5168, longitude: -3.6538, maxSpeed: 120, type: .fixed, direction: nil),
        ]

        cameras.append(contentsOf: defaultCameras)
        totalCamerasLoaded = cameras.count
        saveCamerasToCache()
    }

    // MARK: - Private Methods - Detection Logic

    private func checkForNearbyRadars() {
        guard let location = currentLocation else { return }

        // Actualizar velocidad GPS
        if location.speed >= 0 {
            currentSpeed = location.speed * 3.6  // m/s a km/h
        }

        // Encontrar cámaras cercanas (dentro del radio de alerta + 200m buffer)
        let searchRadius = alertDistance + 200
        let nearby = cameras.filter { camera in
            let distance = location.distance(from: CLLocation(latitude: camera.latitude, longitude: camera.longitude))
            return distance <= searchRadius
        }.sorted { camera1, camera2 in
            let d1 = location.distance(from: CLLocation(latitude: camera1.latitude, longitude: camera1.longitude))
            let d2 = location.distance(from: CLLocation(latitude: camera2.latitude, longitude: camera2.longitude))
            return d1 < d2
        }

        nearbyCameras = Array(nearby.prefix(5))  // Máximo 5 cercanas

        // Lógica de alertas
        processAlerts(for: nearby, from: location)
    }

    private func processAlerts(for cameras: [SpeedCamera], from location: CLLocation) {
        guard !cameras.isEmpty else {
            // Si no hay cámaras cerca, limpiar estado
            if case .approaching = alertState {
                // Si estábamos aproximándonos, hemos pasado
                if case .approaching(let camera, _) = alertState {
                    alertState = .passed(camera: camera)
                    playPassedSound()

                    // Limpiar después de 3 segundos
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if case .passed = self.alertState {
                            self.alertState = .none
                        }
                    }
                }
            } else if alertState != .none, case .passed = alertState {
                // Mantener estado passed por un momento
            } else {
                alertState = .none
            }
            return
        }

        // Encontrar la cámara más cercana
        guard let closestCamera = cameras.first else { return }
        let distance = location.distance(from: CLLocation(latitude: closestCamera.latitude, longitude: closestCamera.longitude))

        // Si la cámara ya fue "pasada" recientemente, ignorar
        if passedCameras.contains(closestCamera.id) {
            // Limpiar cámaras pasadas si estamos lejos
            if distance > alertDistance * 1.5 {
                passedCameras.remove(closestCamera.id)
            }
            return
        }

        // Determinar si nos aproximamos o alejamos
        if distance <= alertDistance {
            // Estamos en zona de alerta
            let isNewAlert = lastAlertedCameraId != closestCamera.id

            if isNewAlert {
                // Nueva cámara detectada
                alertState = .approaching(camera: closestCamera, distance: distance)
                lastAlertedCameraId = closestCamera.id

                playApproachingSound()

                lastAlertTime = Date()
            } else {
                // Actualizar distancia
                alertState = .approaching(camera: closestCamera, distance: distance)

                // Sonido de advertencia periódico (cada 5 segundos si sigue cerca)
                if let lastTime = lastAlertTime,
                   Date().timeIntervalSince(lastTime) > 5,
                   distance < alertDistance * 0.5 {
                    playApproachingSound()
                    lastAlertTime = Date()
                }
            }

            // Detectar si hemos pasado (distancia muy corta y luego aumenta)
            if distance < 50 {
                alertState = .passing(camera: closestCamera)
            }

        } else if distance > alertDistance && lastAlertedCameraId == closestCamera.id {
            // Acabamos de pasar la cámara
            passedCameras.insert(closestCamera.id)
            alertState = .passed(camera: closestCamera)
            playPassedSound()

            lastAlertedCameraId = nil

            // Limpiar estado después de 3 segundos
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .passed(let c) = self.alertState, c.id == closestCamera.id {
                    self.alertState = .none
                }
            }
        }
    }

    // MARK: - Sound Effects

    private func playApproachingSound() {
        guard soundEnabled else { return }

        // Sonido ascendente (3 tonos subiendo)
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1255)  // Tono bajo
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioServicesPlaySystemSound(1256)  // Tono medio
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            AudioServicesPlaySystemSound(1257)  // Tono alto
        }

        if vibrationEnabled {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func playPassedSound() {
        guard soundEnabled else { return }

        // Sonido descendente (2 tonos bajando)
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1257)  // Tono alto
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AudioServicesPlaySystemSound(1255)  // Tono bajo
        }
    }

    // MARK: - OpenStreetMap API

    private func fetchCamerasFromOSM(center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [SpeedCamera] {
        // Calcular bounding box
        let latDelta = radiusKm / 111.0  // ~111km por grado de latitud
        let lonDelta = radiusKm / (111.0 * cos(center.latitude * .pi / 180))

        let minLat = center.latitude - latDelta
        let maxLat = center.latitude + latDelta
        let minLon = center.longitude - lonDelta
        let maxLon = center.longitude + lonDelta

        // Query Overpass API para cámaras de velocidad
        let query = """
        [out:json][timeout:25];
        (
          node["highway"="speed_camera"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["enforcement"="maxspeed"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["enforcement"="speed_camera"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out body;
        """

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://overpass-api.de/api/interpreter?data=\(encodedQuery)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parsear respuesta
        let osmResponse = try JSONDecoder().decode(OSMResponse.self, from: data)

        return osmResponse.elements.compactMap { element -> SpeedCamera? in
            guard let lat = element.lat, let lon = element.lon else { return nil }

            let id = "osm_\(element.id)"
            let maxSpeed = element.tags?["maxspeed"].flatMap { Int($0.replacingOccurrences(of: " km/h", with: "")) }
            let direction = element.tags?["direction"].flatMap { Double($0) }

            var type: SpeedCamera.CameraType = .fixed
            if let enforcement = element.tags?["enforcement"] {
                if enforcement.contains("average") {
                    type = .average
                } else if enforcement.contains("traffic") {
                    type = .trafficLight
                }
            }

            return SpeedCamera(
                id: id,
                latitude: lat,
                longitude: lon,
                maxSpeed: maxSpeed,
                type: type,
                direction: direction
            )
        }
    }

    // MARK: - Cache Management

    private func loadCachedCameras() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheURL)
            cameras = try JSONDecoder().decode([SpeedCamera].self, from: data)
            totalCamerasLoaded = cameras.count
            print("Loaded \(cameras.count) cameras from cache")
        } catch {
            print("Error loading camera cache: \(error)")
        }
    }

    private func saveCamerasToCache() {
        do {
            let data = try JSONEncoder().encode(cameras)
            try data.write(to: cacheURL)
            print("Saved \(cameras.count) cameras to cache")
        } catch {
            print("Error saving camera cache: \(error)")
        }
    }

    public func clearCache() {
        cameras.removeAll()
        totalCamerasLoaded = 0
        try? FileManager.default.removeItem(at: cacheURL)
    }
}

// MARK: - CLLocationManagerDelegate

extension SpeedCameraManager: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location
            self.checkForNearbyRadars()
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.locationPermissionStatus = manager.authorizationStatus

            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                if self.isEnabled {
                    manager.startUpdatingLocation()
                }
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - OSM Response Models

private struct OSMResponse: Codable {
    let elements: [OSMElement]
}

private struct OSMElement: Codable {
    let id: Int64
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
}

// MARK: - Helper Extensions

extension CLLocation {
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return self.distance(from: location)
    }
}
