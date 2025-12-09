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

    // MARK: - Códigos de Mariposa (Throttle)

    public static let p0120 = DTCCode(
        code: "P0120",
        name: "TPS A Mal Funcionamiento",
        description: "Sensor de posición del acelerador A reporta valores incorrectos",
        category: .powertrain,
        severity: .high,
        causes: [
            "Sensor TPS defectuoso",
            "Cableado dañado o conectores sucios",
            "Cuerpo de aceleración sucio",
            "Problema en PCM"
        ],
        symptoms: [
            "Aceleración errática",
            "Ralentí irregular",
            "Motor se ahoga",
            "Respuesta lenta del acelerador"
        ],
        solutions: [
            "Limpiar cuerpo de aceleración con limpiador específico",
            "Verificar conexiones del TPS",
            "Calibrar TPS con escáner",
            "Reemplazar TPS si defectuoso"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0121 = DTCCode(
        code: "P0121",
        name: "TPS A Rango/Rendimiento",
        description: "El sensor TPS A está fuera del rango esperado",
        category: .powertrain,
        severity: .medium,
        causes: [
            "TPS desajustado",
            "Cuerpo de aceleración sucio",
            "TPS desgastado",
            "Fuga de vacío"
        ],
        symptoms: [
            "Aceleración inconsistente",
            "Consumo elevado",
            "Ralentí variable"
        ],
        solutions: [
            "Limpiar cuerpo de aceleración",
            "Recalibrar TPS",
            "Verificar fugas de vacío"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0122 = DTCCode(
        code: "P0122",
        name: "TPS A Señal Baja",
        description: "Voltaje del sensor TPS A por debajo del mínimo",
        category: .powertrain,
        severity: .high,
        causes: [
            "Cortocircuito en cableado",
            "TPS defectuoso",
            "Conector dañado",
            "Problema de tierra"
        ],
        symptoms: [
            "Motor no acelera correctamente",
            "Modo de emergencia activado",
            "Limitación de potencia"
        ],
        solutions: [
            "Verificar cableado y conectores",
            "Medir voltaje del TPS (0.5-4.5V)",
            "Reemplazar TPS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0123 = DTCCode(
        code: "P0123",
        name: "TPS A Señal Alta",
        description: "Voltaje del sensor TPS A por encima del máximo",
        category: .powertrain,
        severity: .high,
        causes: [
            "Circuito abierto en señal de tierra",
            "TPS defectuoso",
            "Cortocircuito a voltaje"
        ],
        symptoms: [
            "Ralentí muy alto",
            "Motor acelera solo",
            "Modo de emergencia"
        ],
        solutions: [
            "Verificar conexión a tierra del TPS",
            "Inspeccionar cableado",
            "Reemplazar TPS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p2101 = DTCCode(
        code: "P2101",
        name: "Motor Mariposa Rango/Rendimiento",
        description: "El motor del cuerpo de aceleración electrónico no responde correctamente",
        category: .powertrain,
        severity: .high,
        causes: [
            "Cuerpo de aceleración sucio o atascado",
            "Motor de mariposa defectuoso",
            "Cableado dañado",
            "Problema en PCM"
        ],
        symptoms: [
            "Modo de emergencia (limp mode)",
            "Ralentí fijo alto",
            "No responde al acelerador"
        ],
        solutions: [
            "Limpiar cuerpo de aceleración exhaustivamente",
            "Verificar funcionamiento del motor de mariposa",
            "Recalibrar con escáner Mazda",
            "Reemplazar cuerpo de aceleración si necesario"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p2102 = DTCCode(
        code: "P2102",
        name: "Motor Mariposa Circuito Bajo",
        description: "Señal baja en el circuito del motor del acelerador electrónico",
        category: .powertrain,
        severity: .high,
        causes: [
            "Cortocircuito en cableado",
            "Motor de mariposa defectuoso",
            "Fusible quemado"
        ],
        symptoms: [
            "Mariposa no se mueve",
            "Modo de emergencia",
            "CEL encendido"
        ],
        solutions: [
            "Verificar fusibles relacionados",
            "Inspeccionar cableado",
            "Probar motor de mariposa"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p2103 = DTCCode(
        code: "P2103",
        name: "Motor Mariposa Circuito Alto",
        description: "Señal alta en el circuito del motor del acelerador electrónico",
        category: .powertrain,
        severity: .high,
        causes: [
            "Circuito abierto",
            "Motor de mariposa defectuoso",
            "Problema de conexión"
        ],
        symptoms: [
            "Mariposa completamente abierta",
            "Ralentí muy alto",
            "Modo de emergencia"
        ],
        solutions: [
            "Verificar conexiones",
            "Probar resistencia del motor",
            "Reemplazar cuerpo de aceleración"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos SSV (Secondary Shutter Valve) - Específico RX-8

    public static let p2006 = DTCCode(
        code: "P2006",
        name: "SSV Atascada Cerrada",
        description: "La válvula secundaria de admisión (SSV) está atascada en posición cerrada",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Depósitos de carbón en la SSV",
            "Actuador de vacío defectuoso",
            "Manguera de vacío rota o desconectada",
            "Válvula solenoide SSV defectuosa"
        ],
        symptoms: [
            "Pérdida de potencia a altas RPM (>5000)",
            "Motor no respira bien arriba",
            "Sensación de tope a altas vueltas"
        ],
        solutions: [
            "Limpiar SSV con limpiador de admisión",
            "Verificar actuador de vacío",
            "Inspeccionar mangueras de vacío",
            "Reemplazar solenoide SSV si defectuoso"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    public static let p2007 = DTCCode(
        code: "P2007",
        name: "SSV Atascada Abierta",
        description: "La válvula secundaria de admisión (SSV) está atascada en posición abierta",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Actuador de vacío roto",
            "Varilla de conexión rota",
            "Depósitos impiden cierre"
        ],
        symptoms: [
            "Ralentí irregular",
            "Pérdida de torque a bajas RPM",
            "Respuesta pobre en parcial"
        ],
        solutions: [
            "Verificar mecanismo de la SSV",
            "Limpiar válvula",
            "Reemplazar actuador de vacío"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    public static let p2008 = DTCCode(
        code: "P2008",
        name: "SSV Circuito Abierto Banco 1",
        description: "Circuito abierto en el solenoide de control de la SSV",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Solenoide SSV defectuoso",
            "Cableado roto",
            "Conector desconectado"
        ],
        symptoms: [
            "CEL encendido",
            "SSV no opera",
            "Pérdida de rendimiento"
        ],
        solutions: [
            "Verificar conexión del solenoide",
            "Medir resistencia del solenoide",
            "Reemplazar solenoide SSV"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    // MARK: - Códigos VDI (Variable Dynamic Intake) - Específico RX-8

    public static let p1530 = DTCCode(
        code: "P1530",
        name: "VDI Solenoide Circuito",
        description: "Problema en el solenoide del sistema de admisión variable (VDI)",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Solenoide VDI defectuoso",
            "Cableado dañado",
            "Problema en PCM"
        ],
        symptoms: [
            "Pérdida de potencia en rango medio",
            "Respuesta plana entre 4000-6000 RPM",
            "CEL encendido"
        ],
        solutions: [
            "Verificar solenoide VDI",
            "Inspeccionar cableado",
            "Limpiar conductos de vacío"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    public static let p1531 = DTCCode(
        code: "P1531",
        name: "VDI Válvula Atascada",
        description: "La válvula de admisión dinámica variable no se mueve correctamente",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Depósitos de carbón",
            "Actuador defectuoso",
            "Articulación atascada"
        ],
        symptoms: [
            "Curva de potencia plana",
            "Motor no tira arriba",
            "Consumo elevado"
        ],
        solutions: [
            "Limpiar sistema VDI",
            "Verificar actuador",
            "Lubricar articulaciones"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    // MARK: - Códigos EGR

    public static let p0400 = DTCCode(
        code: "P0400",
        name: "EGR Flujo Insuficiente",
        description: "El sistema de recirculación de gases de escape no fluye correctamente",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Válvula EGR obstruida por carbón",
            "Conductos EGR bloqueados",
            "Solenoide EGR defectuoso",
            "Sensor de posición EGR malo"
        ],
        symptoms: [
            "Emisiones altas de NOx",
            "Pistoneo/detonación",
            "Temperatura de combustión alta"
        ],
        solutions: [
            "Limpiar válvula EGR",
            "Limpiar conductos de EGR",
            "Reemplazar válvula EGR si necesario"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0401 = DTCCode(
        code: "P0401",
        name: "EGR Flujo Insuficiente Detectado",
        description: "El flujo de EGR es menor al esperado",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Válvula EGR carbonizada",
            "Pasajes de EGR obstruidos",
            "Problema de vacío"
        ],
        symptoms: [
            "Detonación bajo carga",
            "Temperaturas altas",
            "CEL encendido"
        ],
        solutions: [
            "Desmontar y limpiar válvula EGR",
            "Limpiar pasajes con limpiador de carburador",
            "Verificar líneas de vacío"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0402 = DTCCode(
        code: "P0402",
        name: "EGR Flujo Excesivo",
        description: "El sistema EGR permite demasiado flujo de gases",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Válvula EGR atascada abierta",
            "Fuga en diafragma de EGR",
            "Solenoide EGR atascado abierto"
        ],
        symptoms: [
            "Ralentí muy irregular",
            "Motor se ahoga",
            "Pérdida de potencia",
            "Humo en escape"
        ],
        solutions: [
            "Reemplazar válvula EGR",
            "Verificar solenoide de control",
            "Bloquear EGR temporalmente para diagnóstico"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0403 = DTCCode(
        code: "P0403",
        name: "EGR Circuito de Control",
        description: "Problema en el circuito eléctrico del sistema EGR",
        category: .powertrain,
        severity: .low,
        causes: [
            "Solenoide EGR defectuoso",
            "Cableado dañado",
            "Mala conexión"
        ],
        symptoms: [
            "CEL encendido",
            "EGR no opera"
        ],
        solutions: [
            "Verificar conexiones eléctricas",
            "Medir resistencia del solenoide",
            "Reemplazar solenoide EGR"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos Sistema de Ralentí (IAC)

    public static let p0505 = DTCCode(
        code: "P0505",
        name: "IAC Mal Funcionamiento",
        description: "El sistema de control de ralentí no funciona correctamente",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Válvula IAC sucia o defectuosa",
            "Fuga de vacío",
            "Cuerpo de aceleración sucio",
            "Problema en PCM"
        ],
        symptoms: [
            "Ralentí inestable",
            "Ralentí muy alto o muy bajo",
            "Motor se apaga en ralentí"
        ],
        solutions: [
            "Limpiar válvula IAC",
            "Limpiar cuerpo de aceleración",
            "Verificar fugas de vacío",
            "Recalibrar ralentí con escáner"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0506 = DTCCode(
        code: "P0506",
        name: "IAC RPM Menor a Esperado",
        description: "El ralentí es más bajo de lo que debería ser",
        category: .powertrain,
        severity: .medium,
        causes: [
            "IAC restringido",
            "Fuga de vacío grande",
            "Cuerpo de aceleración muy sucio"
        ],
        symptoms: [
            "Ralentí bajo (<600 RPM)",
            "Motor se apaga",
            "Vibración excesiva"
        ],
        solutions: [
            "Limpiar IAC y cuerpo de aceleración",
            "Buscar fugas de vacío",
            "Verificar sensor TPS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0507 = DTCCode(
        code: "P0507",
        name: "IAC RPM Mayor a Esperado",
        description: "El ralentí es más alto de lo que debería ser",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Fuga de vacío",
            "IAC atascado abierto",
            "TPS desajustado",
            "Fuga en junta de admisión"
        ],
        symptoms: [
            "Ralentí alto (>1000 RPM)",
            "Consumo elevado en ralentí"
        ],
        solutions: [
            "Buscar fugas de vacío exhaustivamente",
            "Limpiar o reemplazar IAC",
            "Verificar ajuste del TPS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos OMP Adicionales (Oil Metering Pump)

    public static let p0661 = DTCCode(
        code: "P0661",
        name: "OMP Solenoide Circuito Bajo",
        description: "Señal baja en el circuito del solenoide de la bomba de aceite",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Solenoide OMP en cortocircuito",
            "Cableado dañado",
            "Problema en PCM"
        ],
        symptoms: [
            "CEL encendido",
            "Posible lubricación insuficiente",
            "Limitación de RPM"
        ],
        solutions: [
            "Verificar cableado del OMP",
            "Medir resistencia del solenoide",
            "Reemplazar solenoide OMP urgentemente"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    public static let p0662 = DTCCode(
        code: "P0662",
        name: "OMP Solenoide Circuito Alto",
        description: "Señal alta en el circuito del solenoide de la bomba de aceite",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Circuito abierto en solenoide",
            "Conector desconectado",
            "Solenoide defectuoso"
        ],
        symptoms: [
            "CEL encendido",
            "OMP puede no dosificar correctamente",
            "Riesgo de daño al motor"
        ],
        solutions: [
            "Verificar conexión del solenoide OMP",
            "Inspeccionar cableado",
            "Reemplazar solenoide si defectuoso"
        ],
        rotarySpecific: true,
        affectsApexSeals: true
    )

    // MARK: - Códigos de Sensores de Posición

    public static let p0335 = DTCCode(
        code: "P0335",
        name: "Sensor CKP Sin Señal",
        description: "El sensor de posición del cigüeñal (CKP) no envía señal a la ECU",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Sensor CKP defectuoso",
            "Cableado del sensor dañado o desconectado",
            "Conector corroído",
            "Anillo reluctor dañado o desalineado",
            "Espacio de aire incorrecto entre sensor y reluctor",
            "Problema en PCM (raro)"
        ],
        symptoms: [
            "Motor no arranca",
            "Motor se para inesperadamente",
            "Tirones o funcionamiento irregular",
            "Tacómetro no funciona",
            "Luz Check Engine encendida/parpadeando"
        ],
        solutions: [
            "Verificar conexión del sensor CKP (ubicado cerca del volante motor)",
            "Inspeccionar cableado por daños",
            "Medir resistencia del sensor (típicamente 1000-2000 ohms)",
            "Verificar señal con osciloscopio",
            "Limpiar área del sensor de suciedad metálica",
            "Reemplazar sensor CKP si defectuoso"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    public static let p0336 = DTCCode(
        code: "P0336",
        name: "Sensor CKP Rango/Rendimiento",
        description: "El sensor de posición del cigüeñal reporta señal fuera de rango",
        category: .powertrain,
        severity: .high,
        causes: [
            "Sensor CKP deteriorándose",
            "Espacio de aire incorrecto",
            "Anillo reluctor dañado o con dientes faltantes",
            "Interferencia electromagnética",
            "Cableado con resistencia alta"
        ],
        symptoms: [
            "Arranque difícil",
            "Tirones ocasionales",
            "RPM erráticas",
            "Posible calado del motor"
        ],
        solutions: [
            "Verificar espacio de aire del sensor (consultar especificaciones)",
            "Inspeccionar anillo reluctor por daños",
            "Verificar cableado por resistencia alta",
            "Reemplazar sensor CKP"
        ],
        rotarySpecific: true,
        affectsApexSeals: false
    )

    public static let p0340 = DTCCode(
        code: "P0340",
        name: "Sensor CMP Sin Señal",
        description: "El sensor de posición del árbol de levas (CMP) no envía señal",
        category: .powertrain,
        severity: .high,
        causes: [
            "Sensor CMP defectuoso",
            "Cableado dañado",
            "Conector con corrosión",
            "Problema de sincronización"
        ],
        symptoms: [
            "Arranque difícil o motor no arranca",
            "Pérdida de potencia",
            "Consumo elevado",
            "CEL encendido"
        ],
        solutions: [
            "Verificar conexión del sensor CMP",
            "Medir resistencia del sensor",
            "Verificar señal con osciloscopio",
            "Reemplazar sensor CMP"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0341 = DTCCode(
        code: "P0341",
        name: "Sensor CMP Rango/Rendimiento",
        description: "Señal del sensor CMP fuera de los parámetros esperados",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sensor CMP deteriorado",
            "Rueda fónica dañada",
            "Problema de alineación",
            "Cableado con alta resistencia"
        ],
        symptoms: [
            "Rendimiento reducido",
            "Consumo irregular",
            "Posibles tirones"
        ],
        solutions: [
            "Inspeccionar sensor y rueda fónica",
            "Verificar cableado",
            "Reemplazar sensor si necesario"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de MAP/BARO

    public static let p0105 = DTCCode(
        code: "P0105",
        name: "MAP/BARO Circuito",
        description: "Problema en el circuito del sensor de presión del colector de admisión",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sensor MAP defectuoso",
            "Manguera de vacío rota o desconectada",
            "Cableado dañado",
            "Conector con corrosión"
        ],
        symptoms: [
            "Ralentí irregular",
            "Pérdida de potencia",
            "Consumo elevado",
            "Motor se ahoga"
        ],
        solutions: [
            "Verificar manguera de vacío al sensor MAP",
            "Inspeccionar conexiones eléctricas",
            "Medir voltaje del sensor (típicamente 1-4.5V)",
            "Reemplazar sensor MAP"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0106 = DTCCode(
        code: "P0106",
        name: "MAP Rango/Rendimiento",
        description: "El sensor MAP reporta valores fuera del rango esperado para las condiciones actuales",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Fuga de vacío",
            "Sensor MAP defectuoso",
            "Manguera MAP obstruida",
            "Filtro de aire muy sucio",
            "Problema de EGR"
        ],
        symptoms: [
            "Aceleración pobre",
            "Ralentí inestable",
            "Mayor consumo"
        ],
        solutions: [
            "Buscar fugas de vacío",
            "Verificar manguera del MAP",
            "Limpiar o reemplazar filtro de aire",
            "Verificar funcionamiento del sensor"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de Presión de Aceite

    public static let p0520 = DTCCode(
        code: "P0520",
        name: "Sensor Presión Aceite Circuito",
        description: "Problema en el circuito del sensor de presión de aceite",
        category: .powertrain,
        severity: .high,
        causes: [
            "Sensor de presión defectuoso",
            "Cableado dañado",
            "Baja presión de aceite real"
        ],
        symptoms: [
            "Luz de aceite encendida",
            "CEL encendido"
        ],
        solutions: [
            "Verificar nivel de aceite",
            "Medir presión de aceite mecánicamente",
            "Reemplazar sensor si presión es correcta"
        ],
        rotarySpecific: false,
        affectsApexSeals: true
    )

    public static let p0524 = DTCCode(
        code: "P0524",
        name: "Presión Aceite Demasiado Baja",
        description: "La presión de aceite del motor está por debajo del mínimo seguro",
        category: .powertrain,
        severity: .critical,
        causes: [
            "Nivel de aceite bajo",
            "Bomba de aceite desgastada",
            "Filtro de aceite obstruido",
            "Cojinetes desgastados",
            "Aceite incorrecto"
        ],
        symptoms: [
            "Luz de presión de aceite",
            "Ruidos metálicos",
            "Motor caliente"
        ],
        solutions: [
            "¡DETENER EL MOTOR INMEDIATAMENTE!",
            "Verificar nivel de aceite",
            "No arrancar hasta diagnosticar causa",
            "Verificar bomba de aceite",
            "En rotativo: verificar OMP y premix"
        ],
        rotarySpecific: false,
        affectsApexSeals: true
    )

    // MARK: - Códigos de Chasis (ABS/DSC/TCS)

    public static let c0300 = DTCCode(
        code: "C0300",
        name: "ABS/DSC - Error de Sistema",
        description: "Error general en el sistema ABS/DSC. El módulo ha detectado un fallo que afecta al funcionamiento del sistema de frenos antibloqueo o control de estabilidad.",
        category: .chassis,
        severity: .high,
        causes: [
            "Sensor de velocidad de rueda defectuoso",
            "Cableado de sensor ABS dañado",
            "Módulo ABS/DSC defectuoso",
            "Bajo voltaje de batería",
            "Conexión a tierra defectuosa",
            "Anillo reluctor dañado o sucio"
        ],
        symptoms: [
            "Luz ABS encendida en el tablero",
            "Luz DSC/TCS encendida",
            "Sistema ABS desactivado",
            "Control de tracción desactivado",
            "Frenado puede sentirse diferente"
        ],
        solutions: [
            "Escanear módulo ABS específicamente",
            "Verificar voltaje de batería (>12V)",
            "Inspeccionar sensores de velocidad de ruedas",
            "Verificar conexiones y cableado",
            "Limpiar anillos reluctores",
            "Revisar fusibles del sistema ABS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c0700 = DTCCode(
        code: "C0700",
        name: "ABS - Fallo de Comunicación",
        description: "Error de comunicación entre el módulo ABS y otros módulos del vehículo a través del bus CAN.",
        category: .chassis,
        severity: .medium,
        causes: [
            "Problema en el bus de comunicación CAN",
            "Módulo ABS con fallo interno",
            "Conexión defectuosa en módulo ABS",
            "Fusible del bus CAN quemado",
            "Interferencia eléctrica",
            "Bajo voltaje de sistema"
        ],
        symptoms: [
            "Múltiples luces de advertencia encendidas",
            "ABS puede no funcionar",
            "Velocímetro errático (algunos casos)",
            "Otros sistemas pueden fallar"
        ],
        solutions: [
            "Verificar voltaje de batería y alternador",
            "Inspeccionar conexiones del módulo ABS",
            "Verificar fusibles relacionados",
            "Escanear todos los módulos por errores",
            "Verificar integridad del bus CAN",
            "Revisar tierra del módulo ABS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1095 = DTCCode(
        code: "C1095",
        name: "Sensor ABS Delantero Izquierdo",
        description: "El sensor de velocidad de rueda delantero izquierdo reporta señal incorrecta o ausente",
        category: .chassis,
        severity: .medium,
        causes: [
            "Sensor de velocidad defectuoso",
            "Cableado dañado o desconectado",
            "Anillo reluctor dañado",
            "Suciedad o limaduras metálicas en sensor",
            "Entrehierro incorrecto"
        ],
        symptoms: [
            "Luz ABS encendida",
            "ABS no funciona o funciona mal",
            "Posible activación prematura del ABS"
        ],
        solutions: [
            "Limpiar sensor y anillo reluctor",
            "Verificar entrehierro del sensor",
            "Inspeccionar cableado del sensor",
            "Reemplazar sensor si defectuoso"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1096 = DTCCode(
        code: "C1096",
        name: "Sensor ABS Delantero Derecho",
        description: "El sensor de velocidad de rueda delantero derecho reporta señal incorrecta o ausente",
        category: .chassis,
        severity: .medium,
        causes: [
            "Sensor de velocidad defectuoso",
            "Cableado dañado o desconectado",
            "Anillo reluctor dañado",
            "Suciedad o limaduras metálicas en sensor"
        ],
        symptoms: [
            "Luz ABS encendida",
            "ABS no funciona correctamente"
        ],
        solutions: [
            "Limpiar sensor y anillo reluctor",
            "Verificar conexiones",
            "Reemplazar sensor si necesario"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1097 = DTCCode(
        code: "C1097",
        name: "Sensor ABS Trasero Izquierdo",
        description: "El sensor de velocidad de rueda trasero izquierdo reporta señal incorrecta o ausente",
        category: .chassis,
        severity: .medium,
        causes: [
            "Sensor de velocidad defectuoso",
            "Cableado dañado",
            "Anillo reluctor dañado o desalineado",
            "Acumulación de suciedad"
        ],
        symptoms: [
            "Luz ABS encendida",
            "Sistema ABS desactivado"
        ],
        solutions: [
            "Inspeccionar sensor trasero izquierdo",
            "Limpiar área del sensor",
            "Verificar cableado",
            "Reemplazar sensor"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1098 = DTCCode(
        code: "C1098",
        name: "Sensor ABS Trasero Derecho",
        description: "El sensor de velocidad de rueda trasero derecho reporta señal incorrecta o ausente",
        category: .chassis,
        severity: .medium,
        causes: [
            "Sensor de velocidad defectuoso",
            "Cableado dañado",
            "Anillo reluctor dañado"
        ],
        symptoms: [
            "Luz ABS encendida",
            "Sistema ABS no operativo"
        ],
        solutions: [
            "Inspeccionar sensor trasero derecho",
            "Verificar cableado y conexiones",
            "Reemplazar sensor si defectuoso"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1145 = DTCCode(
        code: "C1145",
        name: "DSC - Sensor de Ángulo de Dirección",
        description: "El sensor de ángulo del volante no proporciona señal correcta al sistema DSC",
        category: .chassis,
        severity: .medium,
        causes: [
            "Sensor de ángulo de dirección defectuoso",
            "Sensor requiere calibración",
            "Cableado dañado",
            "Problema después de alineación"
        ],
        symptoms: [
            "Luz DSC encendida",
            "Control de estabilidad desactivado",
            "DSC puede activarse incorrectamente"
        ],
        solutions: [
            "Calibrar sensor de ángulo de dirección",
            "Girar volante de tope a tope y centrar",
            "Realizar alineación si es necesario",
            "Reemplazar sensor si defectuoso"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let c1288 = DTCCode(
        code: "C1288",
        name: "DSC - Sensor de Presión de Freno",
        description: "El sensor de presión del sistema de frenos reporta valores fuera de rango",
        category: .chassis,
        severity: .high,
        causes: [
            "Sensor de presión defectuoso",
            "Fuga en el sistema hidráulico",
            "Problema con bomba de frenos",
            "Aire en el sistema de frenos"
        ],
        symptoms: [
            "Luz de frenos encendida",
            "Luz DSC encendida",
            "Frenado puede sentirse esponjoso",
            "ABS/DSC desactivado"
        ],
        solutions: [
            "Verificar nivel de líquido de frenos",
            "Inspeccionar sistema por fugas",
            "Purgar sistema de frenos",
            "Verificar sensor de presión"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de Carrocería (Airbag/SRS)

    public static let b1342 = DTCCode(
        code: "B1342",
        name: "SRS - Fallo de Módulo ECU",
        description: "El módulo del sistema de airbags ha detectado un error interno",
        category: .body,
        severity: .critical,
        causes: [
            "Módulo SRS defectuoso",
            "Voltaje de batería bajo",
            "Problema de conexión del módulo",
            "Daño por agua o corrosión"
        ],
        symptoms: [
            "Luz de airbag encendida",
            "Sistema de airbags desactivado",
            "Airbags pueden no desplegarse en accidente"
        ],
        solutions: [
            "Escanear módulo SRS específicamente",
            "Verificar voltaje de batería",
            "Inspeccionar conexiones del módulo",
            "Puede requerir reemplazo del módulo SRS"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let b1884 = DTCCode(
        code: "B1884",
        name: "Airbag Conductor - Circuito",
        description: "Problema en el circuito del airbag del conductor",
        category: .body,
        severity: .critical,
        causes: [
            "Muelle de reloj (clockspring) defectuoso",
            "Conector del volante dañado",
            "Airbag defectuoso",
            "Cableado dañado"
        ],
        symptoms: [
            "Luz de airbag encendida",
            "Airbag del conductor puede no funcionar"
        ],
        solutions: [
            "Verificar muelle de reloj",
            "Inspeccionar conectores del volante",
            "NO manipular sin desconectar batería 10+ minutos",
            "Llevar a servicio profesional"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Códigos de Red (Comunicación)

    public static let u0100 = DTCCode(
        code: "U0100",
        name: "Sin Comunicación con ECM/PCM",
        description: "Pérdida de comunicación con el módulo de control del motor",
        category: .network,
        severity: .critical,
        causes: [
            "Problema en el bus CAN",
            "PCM defectuoso",
            "Fusible quemado",
            "Cableado del bus CAN dañado",
            "Batería muy baja"
        ],
        symptoms: [
            "Múltiples luces de advertencia",
            "Motor puede no arrancar",
            "Velocímetro/tacómetro no funcionan"
        ],
        solutions: [
            "Verificar fusibles del PCM",
            "Verificar voltaje de batería",
            "Inspeccionar cableado del bus CAN",
            "Verificar conexiones del PCM"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let u0121 = DTCCode(
        code: "U0121",
        name: "Sin Comunicación con ABS",
        description: "Pérdida de comunicación con el módulo de frenos antibloqueo",
        category: .network,
        severity: .high,
        causes: [
            "Módulo ABS sin alimentación",
            "Fusible del ABS quemado",
            "Problema en bus CAN",
            "Módulo ABS defectuoso"
        ],
        symptoms: [
            "Luz ABS encendida",
            "ABS no operativo",
            "Posibles otros errores de comunicación"
        ],
        solutions: [
            "Verificar fusibles del ABS",
            "Inspeccionar conexiones del módulo ABS",
            "Verificar integridad del bus CAN"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let u0140 = DTCCode(
        code: "U0140",
        name: "Sin Comunicación con BCM",
        description: "Pérdida de comunicación con el módulo de control de carrocería",
        category: .network,
        severity: .medium,
        causes: [
            "BCM sin alimentación",
            "Fusible quemado",
            "Problema de cableado",
            "BCM defectuoso"
        ],
        symptoms: [
            "Luces interiores no funcionan",
            "Problemas con cierre centralizado",
            "Otros accesorios fallan"
        ],
        solutions: [
            "Verificar fusibles del BCM",
            "Inspeccionar conexiones",
            "Verificar bus CAN"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Más códigos genéricos comunes

    public static let p0133 = DTCCode(
        code: "P0133",
        name: "Sonda O2 B1S1 Respuesta Lenta",
        description: "La sonda de oxígeno primaria tarda demasiado en cambiar entre rico y pobre",
        category: .powertrain,
        severity: .medium,
        causes: [
            "Sonda O2 envejecida",
            "Contaminación de la sonda",
            "Fuga de escape",
            "Problema de mezcla aire/combustible"
        ],
        symptoms: [
            "Mayor consumo de combustible",
            "Emisiones elevadas",
            "Posible fallo de catalizador"
        ],
        solutions: [
            "Reemplazar sonda O2 (B1S1)",
            "Verificar no hay fugas de escape",
            "Verificar estado del motor"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0134 = DTCCode(
        code: "P0134",
        name: "Sonda O2 B1S1 Sin Actividad",
        description: "La sonda de oxígeno primaria no muestra cambios de señal",
        category: .powertrain,
        severity: .high,
        causes: [
            "Sonda O2 defectuosa",
            "Calentador de sonda fallando",
            "Circuito abierto en cableado",
            "Fusible quemado"
        ],
        symptoms: [
            "Alto consumo de combustible",
            "Humo del escape",
            "Motor funciona en modo abierto"
        ],
        solutions: [
            "Verificar conexiones de la sonda",
            "Medir resistencia del calentador",
            "Reemplazar sonda O2"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0141 = DTCCode(
        code: "P0141",
        name: "Calentador Sonda O2 B1S2",
        description: "El calentador de la sonda O2 posterior no funciona correctamente",
        category: .powertrain,
        severity: .low,
        causes: [
            "Elemento calentador quemado",
            "Fusible del calentador quemado",
            "Cableado dañado"
        ],
        symptoms: [
            "CEL encendido",
            "La sonda tarda en calentar",
            "Emisiones ligeramente elevadas al arrancar"
        ],
        solutions: [
            "Verificar fusibles relacionados",
            "Medir resistencia del calentador",
            "Reemplazar sonda O2 (B1S2)"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0455 = DTCCode(
        code: "P0455",
        name: "EVAP Fuga Grande Detectada",
        description: "El sistema de control de emisiones evaporativas detecta una fuga grande",
        category: .powertrain,
        severity: .low,
        causes: [
            "Tapón de gasolina suelto o defectuoso",
            "Manguera EVAP desconectada",
            "Válvula de purga atascada",
            "Bote de carbón dañado"
        ],
        symptoms: [
            "Olor a gasolina",
            "CEL encendido",
            "Posible dificultad para repostar"
        ],
        solutions: [
            "Verificar tapón de gasolina (apretar bien)",
            "Inspeccionar mangueras del sistema EVAP",
            "Verificar válvula de purga",
            "Revisar bote de carbón"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    public static let p0456 = DTCCode(
        code: "P0456",
        name: "EVAP Fuga Pequeña Detectada",
        description: "El sistema EVAP detecta una fuga pequeña en el sistema de vapores",
        category: .powertrain,
        severity: .low,
        causes: [
            "Tapón de gasolina no sella bien",
            "Junta del tapón deteriorada",
            "Pequeña grieta en manguera EVAP",
            "Válvula de venteo con fuga"
        ],
        symptoms: [
            "CEL encendido",
            "Generalmente sin síntomas notables"
        ],
        solutions: [
            "Reemplazar tapón de gasolina",
            "Realizar prueba de humo del sistema EVAP",
            "Inspeccionar todas las conexiones"
        ],
        rotarySpecific: false,
        affectsApexSeals: false
    )

    // MARK: - Colección Completa

    public static let allCodes: [DTCCode] = [
        // Misfire
        p0300, p0301, p0302,
        // MAP/BARO
        p0105, p0106,
        // Sensores
        p0101, p0107, p0113,
        // O2/Catalizador
        p0130, p0133, p0134, p0141, p0420,
        // OMP
        p1520, p0661, p0662,
        // Combustible
        p0171, p0172,
        // Sensores de Posición (CKP/CMP)
        p0335, p0336, p0340, p0341,
        // Bobinas
        p0351, p0352, p0353, p0354,
        // Temperatura
        p0117, p0125,
        // Mazda específicos
        p1000, p1131,
        // Mariposa/Throttle
        p0120, p0121, p0122, p0123, p2101, p2102, p2103,
        // SSV (Secondary Shutter Valve)
        p2006, p2007, p2008,
        // VDI (Variable Dynamic Intake)
        p1530, p1531,
        // EGR
        p0400, p0401, p0402, p0403,
        // IAC (Idle Air Control)
        p0505, p0506, p0507,
        // Presión de aceite
        p0520, p0524,
        // EVAP
        p0455, p0456,
        // Chasis (ABS/DSC)
        c0300, c0700, c1095, c1096, c1097, c1098, c1145, c1288,
        // Carrocería (Airbag/SRS)
        b1342, b1884,
        // Red (Comunicación)
        u0100, u0121, u0140
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

        return "\(prefix)\(String(format: "%X%X%X%X", secondDigit, thirdDigit, fourthDigit, fifthDigit))"
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
