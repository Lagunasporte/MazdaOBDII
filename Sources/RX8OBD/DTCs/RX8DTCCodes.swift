import Foundation

// MARK: - Códigos de Error DTC Específicos RX-8
// Incluye explicaciones detalladas para motor rotativo

public struct DTCCode: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let code: String
    public let name: String
    public let description: String
    public let category: DTCCategory
    public let severity: DTCSeverity
    public let causes: [String]
    public let symptoms: [String]
    public let solutions: [String]
    public let rotarySpecific: Bool
    public let affectsApexSeals: Bool

    public init(code: String, name: String, description: String, category: DTCCategory,
                severity: DTCSeverity, causes: [String], symptoms: [String], solutions: [String],
                rotarySpecific: Bool = false, affectsApexSeals: Bool = false) {
        self.id = code
        self.code = code
        self.name = name
        self.description = description
        self.category = category
        self.severity = severity
        self.causes = causes
        self.symptoms = symptoms
        self.solutions = solutions
        self.rotarySpecific = rotarySpecific
        self.affectsApexSeals = affectsApexSeals
    }
}

public enum DTCCategory: String, Codable, Sendable, CaseIterable {
    case powertrain = "Tren Motriz (P)"
    case chassis = "Chasis (C)"
    case body = "Carrocería (B)"
    case network = "Red (U)"

    public var prefix: Character {
        switch self {
        case .powertrain: return "P"
        case .chassis: return "C"
        case .body: return "B"
        case .network: return "U"
        }
    }
}

public enum DTCSeverity: String, Codable, Sendable {
    case low = "Bajo"
    case medium = "Medio"
    case high = "Alto"
    case critical = "Crítico"

    public var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }

    public var description: String {
        switch self {
        case .low:
            return "Puede continuar conduciendo, revisar pronto"
        case .medium:
            return "Conducir con precaución, reparar en breve"
        case .high:
            return "Evitar uso prolongado, reparar cuanto antes"
        case .critical:
            return "¡DETENER! Riesgo de daño severo al motor"
        }
    }
}

// MARK: - Base de Datos de DTCs RX-8

public struct RX8DTCDatabase {

    // MARK: - Códigos de Misfire (Críticos para Rotativo)

    public static let p0300 = DTCCode(
        code: "P0300",
        name: "Fallo de Encendido Aleatorio",
        description: "Se detectan fallos de encendido en múltiples cámaras del motor rotativo",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Bobinas de encendido defectuosas (muy común en RX-8)",
            "Bujías desgastadas o incorrectas",
            "Cables de bujía en mal estado",
            "Compresión baja (apex seals desgastados)",
            "Fuga de vacío",
            "Inyectores sucios o defectuosos",
            "Perfil del eje excéntrico no sincronizado (después de rebuild)"
        ],
        symptoms: [
            "Ralentí irregular/inestable",
            "Pérdida de potencia",
            "Aumento del consumo",
            "Olor a combustible sin quemar",
            "Daño progresivo al catalizador"
        ],
        solutions: [
            "Reemplazar las 4 bobinas de encendido (¡siempre las 4 juntas!)",
            "Cambiar las 4 bujías por NGK RE7C-L o RE9B-T",
            "Verificar cables de encendido",
            "Realizar test de compresión",
            "Si motor fue reemplazado: borrar perfil eje excéntrico del PCM"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0301 = DTCCode(
        code: "P0301",
        name: "Fallo Encendido Rotor Delantero",
        description: "Misfire detectado en el rotor delantero (cámara 1)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina leading delantera fallando",
            "Bobina trailing delantera fallando",
            "Bujías delanteras desgastadas",
            "Compresión baja rotor delantero",
            "Inyector delantero obstruido"
        ],
        symptoms: [
            "Vibración en ralentí",
            "Pérdida de potencia",
            "Arranque difícil en caliente"
        ],
        solutions: [
            "Reemplazar bobinas delanteras (leading + trailing)",
            "Cambiar bujías delanteras",
            "Test de compresión del rotor delantero"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0302 = DTCCode(
        code: "P0302",
        name: "Fallo Encendido Rotor Trasero",
        description: "Misfire detectado en el rotor trasero (cámara 2)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina leading trasera fallando",
            "Bobina trailing trasera fallando",
            "Bujías traseras desgastadas",
            "Compresión baja rotor trasero",
            "Inyector trasero obstruido"
        ],
        symptoms: [
            "Vibración en ralentí",
            "Pérdida de potencia",
            "Humo azul (aceite quemándose)"
        ],
        solutions: [
            "Reemplazar bobinas traseras (leading + trailing)",
            "Cambiar bujías traseras",
            "Test de compresión del rotor trasero"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    // MARK: - Códigos de Sensores

    public static let p0101 = DTCCode(
        code: "P0101",
        name: "MAF Rango/Rendimiento",
        description: "El sensor MAF reporta valores fuera del rango esperado",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sensor MAF sucio",
            "Filtro de aire obstruido",
            "Fuga de aire después del MAF",
            "Sensor MAF defectuoso"
        ],
        symptoms: [
            "Ralentí irregular",
            "Pérdida de potencia",
            "Consumo excesivo"
        ],
        solutions: [
            "Limpiar MAF con spray específico",
            "Reemplazar filtro de aire",
            "Inspeccionar manguitos de admisión",
            "Reemplazar MAF si limpieza no funciona"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0107 = DTCCode(
        code: "P0107",
        name: "BARO Sensor Bajo",
        description: "Señal del sensor barométrico por debajo del rango",
        category: .powertrain,
        severity: .low,
        causes: [
            "Sensor BARO defectuoso",
            "Cableado dañado",
            "Problema en PCM"
        ],
        symptoms: [
            "Rendimiento reducido en altitud",
            "Mezcla incorrecta"
        ],
        solutions: [
            "Verificar conexiones del sensor",
            "Reemplazar sensor BARO si defectuoso"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0113 = DTCCode(
        code: "P0113",
        name: "IAT Señal Alta",
        description: "Sensor de temperatura de admisión reporta señal alta (circuito abierto)",
        category: .powertrain,
        severity: .low,
        causes: [
            "Sensor IAT desconectado",
            "Cableado dañado",
            "Sensor IAT defectuoso"
        ],
        symptoms: [
            "Mezcla de combustible incorrecta",
            "Consumo irregular"
        ],
        solutions: [
            "Verificar conexión del sensor",
            "Inspeccionar cableado",
            "Reemplazar sensor IAT"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de Oxígeno

    public static let p0130 = DTCCode(
        code: "P0130",
        name: "Sonda O2 B1S1 Mal Funcionamiento",
        description: "La sonda lambda primaria no responde correctamente",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sonda O2 envejecida",
            "Contaminación por aceite (común en rotativos)",
            "Cableado dañado",
            "Fuga de escape antes de la sonda"
        ],
        symptoms: [
            "Consumo elevado",
            "Emisiones altas",
            "Rendimiento reducido"
        ],
        solutions: [
            "Reemplazar sonda O2 (usar Denso o NTK)",
            "Verificar si hay fugas de escape",
            "Si es recurrente, verificar consumo de aceite"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0420 = DTCCode(
        code: "P0420",
        name: "Eficiencia Catalizador Baja",
        description: "El catalizador no está convirtiendo gases eficientemente",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Catalizador dañado (muy común por misfires)",
            "Bobinas trailing fallando (contamina el cat)",
            "Sondas O2 defectuosas",
            "Fugas de escape"
        ],
        symptoms: [
            "Luz CEL encendida",
            "Olor a huevos podridos",
            "Posible pérdida de potencia"
        ],
        solutions: [
            "PRIMERO: Verificar y reemplazar bobinas de encendido",
            "Reemplazar catalizador si está dañado",
            "Verificar sondas O2",
            "En RX-8 es común que misfires destruyan el cat"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    // MARK: - Códigos del Sistema OMP

    public static let p1520 = DTCCode(
        code: "P1520",
        name: "OMP Sensor Posición",
        description: "Problema con el sensor de posición de la bomba de aceite",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Sensor OMP desajustado",
            "Sensor OMP defectuoso",
            "Cableado dañado",
            "Bomba OMP fallando"
        ],
        symptoms: [
            "Limitación a 3000 RPM",
            "Motor en modo emergencia",
            "CEL encendido"
        ],
        solutions: [
            "Ajustar posición del sensor OMP",
            "Reemplazar sensor OMP",
            "Si la bomba falla: reemplazo urgente para evitar daño al motor"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    // MARK: - Códigos de Combustible

    public static let p0171 = DTCCode(
        code: "P0171",
        name: "Sistema Demasiado Pobre",
        description: "La mezcla aire/combustible es demasiado pobre (mucho aire, poco combustible)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Fuga de vacío",
            "Sensor MAF sucio o defectuoso",
            "Inyectores obstruidos",
            "Bomba de combustible débil",
            "Filtro de combustible obstruido"
        ],
        symptoms: [
            "Ralentí alto o irregular",
            "Pérdida de potencia",
            "Motor se calienta más de lo normal"
        ],
        solutions: [
            "Buscar fugas de vacío (spray de carburador)",
            "Limpiar o reemplazar MAF",
            "Verificar presión de combustible",
            "Limpiar inyectores"
        ],
        rotarySpecific: false,
        affectsApexSeals: true // Mezcla pobre daña seals
    )

    public static let p0172 = DTCCode(
        code: "P0172",
        name: "Sistema Demasiado Rico",
        description: "La mezcla aire/combustible es demasiado rica (mucho combustible)",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Inyectores con fugas",
            "Regulador de presión defectuoso",
            "Sensor O2 defectuoso",
            "Sensor MAF defectuoso",
            "Filtro de aire muy sucio"
        ],
        symptoms: [
            "Olor a combustible",
            "Humo negro del escape",
            "Consumo excesivo",
            "Bujías negras"
        ],
        solutions: [
            "Verificar inyectores",
            "Reemplazar filtro de aire",
            "Verificar presión de combustible",
            "Verificar sondas O2"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de Encendido

    public static let p0351 = DTCCode(
        code: "P0351",
        name: "Bobina A Circuito Primario",
        description: "Problema en el circuito de la bobina de encendido A (Leading Delantera)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina defectuosa",
            "Conector corroído",
            "Cableado dañado",
            "Problema en PCM"
        ],
        symptoms: [
            "Misfire",
            "Pérdida de potencia",
            "Ralentí irregular"
        ],
        solutions: [
            "Reemplazar bobina Leading Delantera",
            "Verificar conector y cableado"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0352 = DTCCode(
        code: "P0352",
        name: "Bobina B Circuito Primario",
        description: "Problema en el circuito de la bobina de encendido B (Trailing Delantera)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina defectuosa",
            "Conector corroído",
            "Cableado dañado"
        ],
        symptoms: [
            "Misfire (puede ser sutil)",
            "Pérdida de potencia en altas RPM",
            "Daño al catalizador"
        ],
        solutions: [
            "Reemplazar bobina Trailing Delantera",
            "Las bobinas trailing fallan silenciosamente - ¡importante!"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0353 = DTCCode(
        code: "P0353",
        name: "Bobina C Circuito Primario",
        description: "Problema en el circuito de la bobina de encendido C (Leading Trasera)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina defectuosa",
            "Conector corroído",
            "Cableado dañado"
        ],
        symptoms: [
            "Misfire",
            "Pérdida de potencia",
            "Ralentí irregular"
        ],
        solutions: [
            "Reemplazar bobina Leading Trasera"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0354 = DTCCode(
        code: "P0354",
        name: "Bobina D Circuito Primario",
        description: "Problema en el circuito de la bobina de encendido D (Trailing Trasera)",
        category: .powertrain,
        severity: .high,
        causes: [
            "Bobina defectuosa",
            "Conector corroído",
            "Cableado dañado"
        ],
        symptoms: [
            "Misfire (puede ser sutil)",
            "Pérdida de potencia en altas RPM",
            "Daño al catalizador"
        ],
        solutions: [
            "Reemplazar bobina Trailing Trasera",
            "¡Reemplazar siempre las 4 bobinas juntas!"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    // MARK: - Códigos de Refrigeración

    public static let p0117 = DTCCode(
        code: "P0117",
        name: "ECT Señal Baja",
        description: "Sensor de temperatura del refrigerante señal baja",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sensor ECT cortocircuitado",
            "Cableado dañado",
            "Sensor defectuoso"
        ],
        symptoms: [
            "Ventilador siempre encendido",
            "Consumo elevado",
            "Arranque en frío difícil"
        ],
        solutions: [
            "Verificar conexión del sensor",
            "Reemplazar sensor ECT"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0125 = DTCCode(
        code: "P0125",
        name: "Temp. Insuficiente para Control de Combustible",
        description: "El motor no alcanza temperatura operativa",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Termostato atascado abierto",
            "Sensor ECT defectuoso",
            "Fuga de refrigerante"
        ],
        symptoms: [
            "Motor no llega a temperatura",
            "Consumo elevado",
            "Calefacción débil"
        ],
        solutions: [
            "Reemplazar termostato (problema común)",
            "Verificar nivel de refrigerante",
            "Verificar sensor ECT"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos Específicos Mazda (P1xxx)

    public static let p1000 = DTCCode(
        code: "P1000",
        name: "Monitores OBD No Completados",
        description: "Los monitores del sistema OBD2 no han terminado sus ciclos de prueba",
        category: .powertrain,
        severity: .low,
        causes: [
            "Batería desconectada recientemente",
            "Códigos borrados recientemente",
            "No se ha completado ciclo de conducción"
        ],
        symptoms: [
            "No pasa ITV/emisiones",
            "CEL puede estar encendido"
        ],
        solutions: [
            "Completar ciclo de conducción Mazda:",
            "1. Arrancar en frío, dejar calentar a 80°C",
            "2. Conducir 20 min en autopista (60-100 km/h)",
            "3. Varias aceleraciones y deceleraciones",
            "4. Dejar en ralentí 2 minutos",
            "5. Apagar y esperar 8 horas"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p1131 = DTCCode(
        code: "P1131",
        name: "O2 B1S1 Señal Baja (Mezcla Pobre)",
        description: "La sonda O2 primaria indica mezcla pobre constante",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Fuga de aire en admisión",
            "MAF sucio",
            "Fuga en escape antes de sonda",
            "Sonda O2 defectuosa"
        ],
        symptoms: [
            "Rendimiento reducido",
            "Motor se calienta más"
        ],
        solutions: [
            "Buscar fugas de vacío",
            "Limpiar MAF",
            "Verificar escape por fugas"
        ],
        rotarySpecific: false,
        affectsApexSeals: true
    )

    // MARK: - Colección Completa

    public static let allCodes: [DTCCode] = [
        // Misfire
        p0300, p0301, p0302,
        // Sensores
        p0101, p0107, p0113,
        // O2/Catalizador
        p0130, p0420,
        // OMP
        p1520,
        // Combustible
        p0171, p0172,
        // Bobinas
        p0351, p0352, p0353, p0354,
        // Temperatura
        p0117, p0125,
        // Mazda específicos
        p1000, p1131
    ]

    /// Buscar código por string
    public static func find(code: String) -> DTCCode? {
        allCodes.first { $0.code.uppercased() == code.uppercased() }
    }

    /// Códigos que afectan apex seals
    public static var apexSealRelatedCodes: [DTCCode] {
        allCodes.filter { $0.affectsApexSeals }
    }

    /// Códigos específicos del rotativo
    public static var rotarySpecificCodes: [DTCCode] {
        allCodes.filter { $0.rotarySpecific }
    }

    /// Códigos críticos
    public static var criticalCodes: [DTCCode] {
        allCodes.filter { $0.severity == .critical }
    }
}

// MARK: - Parser de Códigos DTC

public struct DTCParser {

    /// Parsea respuesta OBD2 Mode 03 (Read DTCs)
    public static func parseDTCResponse(_ data: Data) -> [String] {
        var codes: [String] = []

        // Cada DTC son 2 bytes
        var index = 0
        while index + 1 < data.count {
            let byte1 = data[index]
            let byte2 = data[index + 1]

            // Ignorar bytes vacíos
            if byte1 == 0 && byte2 == 0 {
                index += 2
                continue
            }

            let code = decodeDTC(byte1: byte1, byte2: byte2)
            codes.append(code)
            index += 2
        }

        return codes
    }

    private static func decodeDTC(byte1: UInt8, byte2: UInt8) -> String {
        // Primer carácter basado en bits 6-7 del byte1
        let prefix: Character
        switch (byte1 >> 6) & 0x03 {
        case 0: prefix = "P"
        case 1: prefix = "C"
        case 2: prefix = "B"
        case 3: prefix = "U"
        default: prefix = "P"
        }

        // Segundo carácter basado en bits 4-5 del byte1
        let secondDigit = (byte1 >> 4) & 0x03

        // Tercer carácter basado en bits 0-3 del byte1
        let thirdDigit = byte1 & 0x0F

        // Cuarto y quinto caracteres del byte2
        let fourthDigit = (byte2 >> 4) & 0x0F
        let fifthDigit = byte2 & 0x0F

        return String(format: "%c%X%X%X%X", prefix, secondDigit, thirdDigit, fourthDigit, fifthDigit)
    }
}

// MARK: - Resultado de Escaneo

public struct DTCScanResult: Codable, Sendable {
    public let timestamp: Date
    public let codes: [String]
    public let pendingCodes: [String]
    public let milStatus: Bool // Check engine light
    public let testsCompleted: Int
    public let testsAvailable: Int

    public var hasCriticalCodes: Bool {
        codes.contains { code in
            RX8DTCDatabase.criticalCodes.contains { $0.code == code }
        }
    }

    public var hasApexSealRelatedCodes: Bool {
        codes.contains { code in
            RX8DTCDatabase.apexSealRelatedCodes.contains { $0.code == code }
        }
    }

    public init(codes: [String], pendingCodes: [String] = [], milStatus: Bool = false,
                testsCompleted: Int = 0, testsAvailable: Int = 0) {
        self.timestamp = Date()
        self.codes = codes
        self.pendingCodes = pendingCodes
        self.milStatus = milStatus
        self.testsCompleted = testsCompleted
        self.testsAvailable = testsAvailable
    }
}
