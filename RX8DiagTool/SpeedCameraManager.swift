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

// MARK: - Country Bounding Box

private struct CountryBoundingBox {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let name: String

    // Divide el bounding box en regiones más pequeñas para queries
    func regions(maxSize: Double = 2.0) -> [(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)] {
        var result: [(Double, Double, Double, Double)] = []

        var lat = minLat
        while lat < maxLat {
            var lon = minLon
            while lon < maxLon {
                result.append((
                    lat,
                    min(lat + maxSize, maxLat),
                    lon,
                    min(lon + maxSize, maxLon)
                ))
                lon += maxSize
            }
            lat += maxSize
        }

        return result
    }
}

// MARK: - Speed Camera Manager

@MainActor
public class SpeedCameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published public var isEnabled: Bool = UserDefaults.standard.bool(forKey: "radarEnabled") {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "radarEnabled")
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
    @Published public var currentCountry: String = ""
    @Published public var currentCountryCode: String = ""
    @Published public var downloadProgress: String = ""
    @Published public var downloadedCountry: String = ""

    // MARK: - Configuration

    @AppStorage("radarAlertDistance") public var alertDistance: Double = 500  // metros
    @AppStorage("radarSoundEnabled") public var soundEnabled: Bool = true
    @AppStorage("radarVibrationEnabled") public var vibrationEnabled: Bool = true

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var cameras: [SpeedCamera] = []
    private var lastAlertedCameraId: String?
    private var lastAlertTime: Date?
    private var passedCameras: Set<String> = []

    // Cache
    private let cacheFileName = "speed_cameras_cache.json"
    private let cacheMetaFileName = "speed_cameras_meta.json"

    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFileName)
    }

    private var cacheMetaURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheMetaFileName)
    }

    // Bounding boxes de países europeos
    private let countryBoundingBoxes: [String: CountryBoundingBox] = [
        "ES": CountryBoundingBox(minLat: 35.9, maxLat: 43.8, minLon: -9.3, maxLon: 4.4, name: "España"),
        "FR": CountryBoundingBox(minLat: 41.3, maxLat: 51.1, minLon: -5.1, maxLon: 9.6, name: "Francia"),
        "PT": CountryBoundingBox(minLat: 36.9, maxLat: 42.2, minLon: -9.5, maxLon: -6.2, name: "Portugal"),
        "IT": CountryBoundingBox(minLat: 35.5, maxLat: 47.1, minLon: 6.6, maxLon: 18.5, name: "Italia"),
        "DE": CountryBoundingBox(minLat: 47.3, maxLat: 55.1, minLon: 5.9, maxLon: 15.0, name: "Alemania"),
        "GB": CountryBoundingBox(minLat: 49.9, maxLat: 60.9, minLon: -8.6, maxLon: 1.8, name: "Reino Unido"),
        "BE": CountryBoundingBox(minLat: 49.5, maxLat: 51.5, minLon: 2.5, maxLon: 6.4, name: "Bélgica"),
        "NL": CountryBoundingBox(minLat: 50.8, maxLat: 53.5, minLon: 3.4, maxLon: 7.2, name: "Países Bajos"),
        "CH": CountryBoundingBox(minLat: 45.8, maxLat: 47.8, minLon: 6.0, maxLon: 10.5, name: "Suiza"),
        "AT": CountryBoundingBox(minLat: 46.4, maxLat: 49.0, minLon: 9.5, maxLon: 17.2, name: "Austria"),
        "PL": CountryBoundingBox(minLat: 49.0, maxLat: 54.8, minLon: 14.1, maxLon: 24.2, name: "Polonia"),
        "CZ": CountryBoundingBox(minLat: 48.5, maxLat: 51.1, minLon: 12.1, maxLon: 18.9, name: "Chequia"),
        "AD": CountryBoundingBox(minLat: 42.4, maxLat: 42.7, minLon: 1.4, maxLon: 1.8, name: "Andorra"),
        "MC": CountryBoundingBox(minLat: 43.7, maxLat: 43.8, minLon: 7.4, maxLon: 7.5, name: "Mónaco"),
        "LU": CountryBoundingBox(minLat: 49.4, maxLat: 50.2, minLon: 5.7, maxLon: 6.5, name: "Luxemburgo"),
    ]

    // MARK: - Initialization

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10  // Actualizar cada 10 metros
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false

        loadCachedCameras()
        loadCacheMeta()

        // Auto-iniciar si estaba activado
        if isEnabled {
            startMonitoring()
        }
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

    /// Detecta el país actual basándose en la ubicación GPS
    public func detectCurrentCountry() async {
        guard let location = currentLocation else {
            print("No current location available")
            return
        }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                currentCountry = placemark.country ?? "Desconocido"
                currentCountryCode = placemark.isoCountryCode ?? ""
                print("País detectado: \(currentCountry) (\(currentCountryCode))")
            }
        } catch {
            print("Error detectando país: \(error)")
        }
    }

    /// Descarga todos los radares del país donde se encuentra el usuario
    public func downloadCamerasForCurrentCountry() async {
        guard let location = currentLocation else {
            print("No current location available")
            return
        }

        // Primero detectar el país
        await detectCurrentCountry()

        guard !currentCountryCode.isEmpty else {
            print("No se pudo detectar el país")
            downloadProgress = "Error: No se pudo detectar el país"
            return
        }

        await downloadCamerasForCountry(countryCode: currentCountryCode)
    }

    /// Descarga todos los radares de un país específico
    public func downloadCamerasForCountry(countryCode: String) async {
        guard let boundingBox = countryBoundingBoxes[countryCode] else {
            print("País no soportado: \(countryCode)")
            downloadProgress = "País no soportado"
            return
        }

        isLoading = true
        downloadProgress = "Preparando descarga de \(boundingBox.name)..."

        // Dividir el país en regiones para no sobrecargar la API
        let regions = boundingBox.regions(maxSize: 2.0)
        var allCameras: [SpeedCamera] = []
        var downloadedRegions = 0

        for region in regions {
            downloadedRegions += 1
            downloadProgress = "Descargando región \(downloadedRegions)/\(regions.count)..."

            do {
                let camerasInRegion = try await fetchCamerasFromOSMRegion(
                    minLat: region.0,
                    maxLat: region.1,
                    minLon: region.2,
                    maxLon: region.3
                )
                allCameras.append(contentsOf: camerasInRegion)

                // Pequeña pausa para no sobrecargar la API
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 segundos

            } catch {
                print("Error descargando región \(downloadedRegions): \(error)")
                // Continuar con la siguiente región
            }
        }

        // Eliminar duplicados
        var cameraDict = Dictionary(uniqueKeysWithValues: allCameras.map { ($0.id, $0) })

        // Añadir cámaras existentes de otros países
        for camera in cameras {
            if !camera.id.hasPrefix("osm_") || cameraDict[camera.id] == nil {
                // Mantener cámaras que no son de OSM o que no están en la nueva descarga
                // Para cámaras OSM, verificar si están en el nuevo país
                let cameraLocation = CLLocation(latitude: camera.latitude, longitude: camera.longitude)
                let inNewCountry = camera.latitude >= boundingBox.minLat &&
                                   camera.latitude <= boundingBox.maxLat &&
                                   camera.longitude >= boundingBox.minLon &&
                                   camera.longitude <= boundingBox.maxLon

                if !inNewCountry {
                    cameraDict[camera.id] = camera
                }
            }
        }

        cameras = Array(cameraDict.values)
        totalCamerasLoaded = cameras.count
        lastUpdate = Date()
        downloadedCountry = boundingBox.name

        // Guardar en caché
        saveCamerasToCache()
        saveCacheMeta(country: boundingBox.name, countryCode: countryCode)

        downloadProgress = "Completado: \(allCameras.count) radares en \(boundingBox.name)"
        print("Descargados \(allCameras.count) radares de \(boundingBox.name), total: \(cameras.count)")

        isLoading = false
    }

    /// Descarga radares de OpenStreetMap para el área actual
    public func downloadCamerasForCurrentArea(radiusKm: Double = 50) async {
        guard let location = currentLocation else {
            print("No current location available")
            return
        }

        isLoading = true
        downloadProgress = "Descargando área cercana..."

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

            downloadProgress = "Completado: \(newCameras.count) radares cercanos"
            print("Loaded \(newCameras.count) new cameras, total: \(cameras.count)")
        } catch {
            print("Error downloading cameras: \(error)")
            downloadProgress = "Error: \(error.localizedDescription)"
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

    private func fetchCamerasFromOSMRegion(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) async throws -> [SpeedCamera] {
        // Query Overpass API para cámaras de velocidad en la región
        let query = """
        [out:json][timeout:60];
        (
          node["highway"="speed_camera"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["enforcement"="maxspeed"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["enforcement"="speed_camera"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["traffic_calming"="bump"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out body;
        """

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://overpass-api.de/api/interpreter?data=\(encodedQuery)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

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

    private func fetchCamerasFromOSM(center: CLLocationCoordinate2D, radiusKm: Double) async throws -> [SpeedCamera] {
        // Calcular bounding box
        let latDelta = radiusKm / 111.0  // ~111km por grado de latitud
        let lonDelta = radiusKm / (111.0 * cos(center.latitude * .pi / 180))

        let minLat = center.latitude - latDelta
        let maxLat = center.latitude + latDelta
        let minLon = center.longitude - lonDelta
        let maxLon = center.longitude + lonDelta

        return try await fetchCamerasFromOSMRegion(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
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

    private func loadCacheMeta() {
        guard FileManager.default.fileExists(atPath: cacheMetaURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheMetaURL)
            if let meta = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                downloadedCountry = meta["country"] ?? ""
                if let dateString = meta["date"] {
                    let formatter = ISO8601DateFormatter()
                    lastUpdate = formatter.date(from: dateString)
                }
            }
        } catch {
            print("Error loading cache meta: \(error)")
        }
    }

    private func saveCacheMeta(country: String, countryCode: String) {
        let formatter = ISO8601DateFormatter()
        let meta: [String: String] = [
            "country": country,
            "countryCode": countryCode,
            "date": formatter.string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: meta)
            try data.write(to: cacheMetaURL)
        } catch {
            print("Error saving cache meta: \(error)")
        }
    }

    public func clearCache() {
        cameras.removeAll()
        totalCamerasLoaded = 0
        downloadedCountry = ""
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: cacheMetaURL)
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
