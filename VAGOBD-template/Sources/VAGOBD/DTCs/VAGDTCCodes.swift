import Foundation

// MARK: - DTC Severity
public enum DTCSeverity: String, CaseIterable {
    case critical = "Crítico"
    case high = "Alto"
    case medium = "Medio"
    case low = "Bajo"
    case info = "Informativo"

    public var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        case .info: return "gray"
        }
    }
}

// MARK: - DTC Status
public enum DTCStatus: String {
    case active = "Activo"
    case pending = "Pendiente"
    case stored = "Almacenado"
    case permanent = "Permanente"
}

// MARK: - DTC Category
public enum DTCCategory: String, CaseIterable {
    case engine = "Motor"
    case transmission = "Transmisión"
    case emissions = "Emisiones"
    case fuel = "Combustible"
    case ignition = "Encendido"
    case sensors = "Sensores"
    case electrical = "Eléctrico"
    case body = "Carrocería"
    case chassis = "Chasis"
    case network = "Red CAN"
    case hybrid = "Híbrido"
    case unknown = "Desconocido"
}

// MARK: - DTC Code Structure
public struct VAGDTCCode: Identifiable, Hashable {
    public let id = UUID()
    public let code: String
    public let description: String
    public let severity: DTCSeverity
    public let category: DTCCategory
    public let possibleCauses: [String]
    public let solutions: [String]
    public var status: DTCStatus

    public init(
        code: String,
        description: String,
        severity: DTCSeverity,
        category: DTCCategory,
        possibleCauses: [String] = [],
        solutions: [String] = [],
        status: DTCStatus = .active
    ) {
        self.code = code
        self.description = description
        self.severity = severity
        self.category = category
        self.possibleCauses = possibleCauses
        self.solutions = solutions
        self.status = status
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    public static func == (lhs: VAGDTCCode, rhs: VAGDTCCode) -> Bool {
        lhs.code == rhs.code
    }
}

// MARK: - VAG DTC Database
public struct VAGDTCDatabase {

    // MARK: - Common VAG DTCs
    public static let codes: [String: VAGDTCCode] = [

        // ============================================
        // MOTOR - Combustible y Aire
        // ============================================
        "P0087": VAGDTCCode(
            code: "P0087",
            description: "Presión raíl combustible demasiado baja",
            severity: .high,
            category: .fuel,
            possibleCauses: [
                "Bomba de alta presión defectuosa",
                "Filtro de combustible obstruido",
                "Fuga en el sistema de combustible",
                "Regulador de presión defectuoso",
                "Inyectores con fugas"
            ],
            solutions: [
                "Verificar presión de combustible con manómetro",
                "Reemplazar filtro de combustible",
                "Inspeccionar líneas de combustible",
                "Comprobar bomba de alta presión"
            ]
        ),

        "P0088": VAGDTCCode(
            code: "P0088",
            description: "Presión raíl combustible demasiado alta",
            severity: .high,
            category: .fuel,
            possibleCauses: [
                "Regulador de presión atascado",
                "Sensor de presión defectuoso",
                "Válvula de alivio bloqueada"
            ],
            solutions: [
                "Verificar regulador de presión",
                "Comprobar sensor de presión raíl",
                "Inspeccionar válvula de alivio"
            ]
        ),

        "P0171": VAGDTCCode(
            code: "P0171",
            description: "Sistema demasiado pobre (Banco 1)",
            severity: .medium,
            category: .fuel,
            possibleCauses: [
                "Fuga de aire en admisión",
                "Sensor MAF sucio o defectuoso",
                "Inyectores obstruidos",
                "Bomba de combustible débil",
                "Sensor O2 defectuoso"
            ],
            solutions: [
                "Verificar fugas de vacío",
                "Limpiar o reemplazar sensor MAF",
                "Limpiar inyectores",
                "Verificar presión de combustible"
            ]
        ),

        "P0172": VAGDTCCode(
            code: "P0172",
            description: "Sistema demasiado rico (Banco 1)",
            severity: .medium,
            category: .fuel,
            possibleCauses: [
                "Inyectores con fugas",
                "Regulador de presión defectuoso",
                "Sensor MAF contaminado",
                "Filtro de aire obstruido",
                "Sensor de temperatura defectuoso"
            ],
            solutions: [
                "Verificar inyectores",
                "Comprobar presión de combustible",
                "Reemplazar filtro de aire",
                "Verificar sensor MAF"
            ]
        ),

        // ============================================
        // MOTOR - Encendido
        // ============================================
        "P0300": VAGDTCCode(
            code: "P0300",
            description: "Fallo de encendido aleatorio detectado",
            severity: .high,
            category: .ignition,
            possibleCauses: [
                "Bujías desgastadas",
                "Bobinas de encendido defectuosas",
                "Cables de bujía dañados",
                "Problema de compresión",
                "Inyectores defectuosos"
            ],
            solutions: [
                "Reemplazar bujías",
                "Verificar bobinas de encendido",
                "Realizar prueba de compresión",
                "Verificar inyectores"
            ]
        ),

        "P0301": VAGDTCCode(
            code: "P0301",
            description: "Fallo de encendido cilindro 1",
            severity: .high,
            category: .ignition,
            possibleCauses: [
                "Bujía cilindro 1 defectuosa",
                "Bobina cilindro 1 defectuosa",
                "Inyector cilindro 1 obstruido",
                "Baja compresión cilindro 1"
            ],
            solutions: [
                "Reemplazar bujía cilindro 1",
                "Verificar bobina cilindro 1",
                "Limpiar/reemplazar inyector",
                "Prueba de compresión"
            ]
        ),

        "P0302": VAGDTCCode(
            code: "P0302",
            description: "Fallo de encendido cilindro 2",
            severity: .high,
            category: .ignition,
            possibleCauses: ["Bujía cilindro 2 defectuosa", "Bobina cilindro 2 defectuosa"],
            solutions: ["Reemplazar bujía cilindro 2", "Verificar bobina cilindro 2"]
        ),

        "P0303": VAGDTCCode(
            code: "P0303",
            description: "Fallo de encendido cilindro 3",
            severity: .high,
            category: .ignition,
            possibleCauses: ["Bujía cilindro 3 defectuosa", "Bobina cilindro 3 defectuosa"],
            solutions: ["Reemplazar bujía cilindro 3", "Verificar bobina cilindro 3"]
        ),

        "P0304": VAGDTCCode(
            code: "P0304",
            description: "Fallo de encendido cilindro 4",
            severity: .high,
            category: .ignition,
            possibleCauses: ["Bujía cilindro 4 defectuosa", "Bobina cilindro 4 defectuosa"],
            solutions: ["Reemplazar bujía cilindro 4", "Verificar bobina cilindro 4"]
        ),

        // ============================================
        // TURBO
        // ============================================
        "P0234": VAGDTCCode(
            code: "P0234",
            description: "Sobrealimentación turbo excesiva",
            severity: .critical,
            category: .engine,
            possibleCauses: [
                "Válvula wastegate atascada",
                "Actuador de turbo defectuoso",
                "Sensor MAP defectuoso",
                "Fuga en sistema de vacío"
            ],
            solutions: [
                "Verificar válvula wastegate",
                "Comprobar actuador del turbo",
                "Verificar sensor MAP",
                "Inspeccionar líneas de vacío"
            ]
        ),

        "P0299": VAGDTCCode(
            code: "P0299",
            description: "Turbo/Supercargador baja presión",
            severity: .high,
            category: .engine,
            possibleCauses: [
                "Fuga en intercooler",
                "Turbo desgastado",
                "Mangueras de presión dañadas",
                "Válvula de derivación abierta",
                "Sensor de presión defectuoso"
            ],
            solutions: [
                "Verificar mangueras del turbo",
                "Inspeccionar intercooler",
                "Comprobar estado del turbo",
                "Verificar válvula de derivación"
            ]
        ),

        // ============================================
        // EMISIONES - EGR
        // ============================================
        "P0401": VAGDTCCode(
            code: "P0401",
            description: "Flujo EGR insuficiente",
            severity: .medium,
            category: .emissions,
            possibleCauses: [
                "Válvula EGR carbonizada",
                "Conductos EGR obstruidos",
                "Sensor de posición EGR defectuoso",
                "Fuga de vacío"
            ],
            solutions: [
                "Limpiar válvula EGR",
                "Limpiar conductos EGR",
                "Verificar sensor de posición",
                "Comprobar líneas de vacío"
            ]
        ),

        "P0402": VAGDTCCode(
            code: "P0402",
            description: "Flujo EGR excesivo",
            severity: .medium,
            category: .emissions,
            possibleCauses: [
                "Válvula EGR atascada abierta",
                "Sensor DPFE defectuoso",
                "Fuga en el sistema EGR"
            ],
            solutions: [
                "Reemplazar válvula EGR",
                "Verificar sensor DPFE",
                "Inspeccionar sistema EGR"
            ]
        ),

        // ============================================
        // EMISIONES - DPF (Filtro partículas diésel)
        // ============================================
        "P2002": VAGDTCCode(
            code: "P2002",
            description: "Eficiencia filtro partículas por debajo del umbral",
            severity: .high,
            category: .emissions,
            possibleCauses: [
                "DPF saturado de hollín",
                "Regeneraciones fallidas",
                "Sensor diferencial de presión defectuoso",
                "Uso de aceite incorrecto"
            ],
            solutions: [
                "Forzar regeneración DPF",
                "Verificar sensores de presión",
                "Comprobar nivel de hollín",
                "Considerar limpieza profesional DPF"
            ]
        ),

        "P2463": VAGDTCCode(
            code: "P2463",
            description: "DPF - Acumulación de hollín",
            severity: .high,
            category: .emissions,
            possibleCauses: [
                "Conducción urbana excesiva",
                "Regeneraciones interrumpidas",
                "Inyectores defectuosos",
                "Turbo con fugas de aceite"
            ],
            solutions: [
                "Realizar conducción en autopista",
                "Forzar regeneración",
                "Verificar inyectores",
                "Inspeccionar turbo"
            ]
        ),

        // ============================================
        // SENSORES
        // ============================================
        "P0101": VAGDTCCode(
            code: "P0101",
            description: "Sensor MAF - Rango/Rendimiento",
            severity: .medium,
            category: .sensors,
            possibleCauses: [
                "Sensor MAF sucio",
                "Fuga de aire después del MAF",
                "Sensor MAF defectuoso",
                "Cableado dañado"
            ],
            solutions: [
                "Limpiar sensor MAF con limpiador específico",
                "Verificar fugas de aire",
                "Comprobar cableado",
                "Reemplazar sensor MAF"
            ]
        ),

        "P0102": VAGDTCCode(
            code: "P0102",
            description: "Sensor MAF - Entrada baja",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Cortocircuito a masa", "Sensor MAF defectuoso", "Filtro de aire muy restrictivo"],
            solutions: ["Verificar cableado", "Reemplazar sensor MAF", "Cambiar filtro de aire"]
        ),

        "P0103": VAGDTCCode(
            code: "P0103",
            description: "Sensor MAF - Entrada alta",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Cortocircuito a positivo", "Sensor MAF defectuoso"],
            solutions: ["Verificar cableado", "Reemplazar sensor MAF"]
        ),

        "P0110": VAGDTCCode(
            code: "P0110",
            description: "Sensor temperatura admisión - Mal funcionamiento",
            severity: .low,
            category: .sensors,
            possibleCauses: ["Sensor IAT defectuoso", "Cableado dañado", "Conector corroído"],
            solutions: ["Verificar conector", "Comprobar cableado", "Reemplazar sensor IAT"]
        ),

        "P0115": VAGDTCCode(
            code: "P0115",
            description: "Sensor temperatura refrigerante - Mal funcionamiento",
            severity: .medium,
            category: .sensors,
            possibleCauses: [
                "Sensor ECT defectuoso",
                "Termostato atascado",
                "Nivel refrigerante bajo",
                "Cableado dañado"
            ],
            solutions: [
                "Verificar nivel refrigerante",
                "Comprobar termostato",
                "Reemplazar sensor ECT"
            ]
        ),

        "P0116": VAGDTCCode(
            code: "P0116",
            description: "Sensor temperatura refrigerante - Rango/Rendimiento",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Termostato defectuoso", "Sensor ECT fuera de especificación"],
            solutions: ["Verificar termostato", "Reemplazar sensor ECT"]
        ),

        "P0117": VAGDTCCode(
            code: "P0117",
            description: "Sensor temperatura refrigerante - Entrada baja",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Cortocircuito a masa", "Sensor ECT defectuoso"],
            solutions: ["Verificar cableado", "Reemplazar sensor ECT"]
        ),

        "P0118": VAGDTCCode(
            code: "P0118",
            description: "Sensor temperatura refrigerante - Entrada alta",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Circuito abierto", "Cortocircuito a positivo", "Sensor ECT defectuoso"],
            solutions: ["Verificar cableado", "Reemplazar sensor ECT"]
        ),

        "P0130": VAGDTCCode(
            code: "P0130",
            description: "Sensor O2 Banco 1 Sensor 1 - Mal funcionamiento",
            severity: .medium,
            category: .sensors,
            possibleCauses: [
                "Sensor O2 envejecido",
                "Cableado dañado",
                "Fuga de escape",
                "ECU defectuosa"
            ],
            solutions: [
                "Reemplazar sensor O2",
                "Verificar cableado",
                "Inspeccionar escape por fugas"
            ]
        ),

        "P0133": VAGDTCCode(
            code: "P0133",
            description: "Sensor O2 B1S1 - Respuesta lenta",
            severity: .medium,
            category: .sensors,
            possibleCauses: ["Sensor O2 envejecido", "Fuga de escape", "Problema de mezcla"],
            solutions: ["Reemplazar sensor O2", "Verificar escape", "Comprobar sistema combustible"]
        ),

        // ============================================
        // TRANSMISIÓN DSG
        // ============================================
        "P0730": VAGDTCCode(
            code: "P0730",
            description: "Relación de marcha incorrecta",
            severity: .high,
            category: .transmission,
            possibleCauses: [
                "Nivel de aceite transmisión bajo",
                "Embragues desgastados",
                "Mecatrónica defectuosa",
                "Sensor de velocidad defectuoso"
            ],
            solutions: [
                "Verificar nivel aceite DSG",
                "Realizar adaptación de transmisión",
                "Verificar mecatrónica",
                "Comprobar sensores de velocidad"
            ]
        ),

        "P0741": VAGDTCCode(
            code: "P0741",
            description: "Embrague convertidor de par - Rendimiento/Atascado desactivado",
            severity: .high,
            category: .transmission,
            possibleCauses: [
                "Solenoide TCC defectuoso",
                "Aceite transmisión contaminado",
                "Problema mecánico convertidor"
            ],
            solutions: [
                "Cambiar aceite y filtro transmisión",
                "Verificar solenoide TCC",
                "Inspeccionar convertidor de par"
            ]
        ),

        "P17BF": VAGDTCCode(
            code: "P17BF",
            description: "DSG - Presión hidráulica demasiado baja",
            severity: .critical,
            category: .transmission,
            possibleCauses: [
                "Nivel aceite DSG bajo",
                "Bomba hidráulica defectuosa",
                "Fuga en el sistema hidráulico",
                "Mecatrónica defectuosa"
            ],
            solutions: [
                "Verificar nivel aceite DSG",
                "Inspeccionar por fugas",
                "Comprobar bomba hidráulica",
                "Revisar mecatrónica"
            ]
        ),

        // ============================================
        // SISTEMA ELÉCTRICO
        // ============================================
        "P0562": VAGDTCCode(
            code: "P0562",
            description: "Voltaje sistema bajo",
            severity: .medium,
            category: .electrical,
            possibleCauses: [
                "Batería débil",
                "Alternador defectuoso",
                "Conexiones corroídas",
                "Consumo parásito excesivo"
            ],
            solutions: [
                "Verificar batería",
                "Comprobar alternador",
                "Limpiar conexiones",
                "Buscar consumos parásitos"
            ]
        ),

        "P0563": VAGDTCCode(
            code: "P0563",
            description: "Voltaje sistema alto",
            severity: .medium,
            category: .electrical,
            possibleCauses: ["Regulador de voltaje defectuoso", "Alternador sobrecargando"],
            solutions: ["Verificar regulador de voltaje", "Comprobar alternador"]
        ),

        // ============================================
        // VAG ESPECÍFICOS (Serie P1xxx y P2xxx)
        // ============================================
        "P1545": VAGDTCCode(
            code: "P1545",
            description: "Cuerpo de aceleración - Mal funcionamiento",
            severity: .high,
            category: .engine,
            possibleCauses: [
                "Cuerpo de aceleración sucio",
                "Motor del acelerador defectuoso",
                "Sensor de posición defectuoso",
                "Cableado dañado"
            ],
            solutions: [
                "Limpiar cuerpo de aceleración",
                "Realizar adaptación del acelerador",
                "Verificar cableado",
                "Reemplazar cuerpo de aceleración"
            ]
        ),

        "P2015": VAGDTCCode(
            code: "P2015",
            description: "Sensor posición colector admisión - Rango/Rendimiento B1",
            severity: .medium,
            category: .engine,
            possibleCauses: [
                "Motor de aletas de admisión defectuoso",
                "Sensor de posición defectuoso",
                "Aletas de admisión atascadas",
                "Colector de admisión carbonizado"
            ],
            solutions: [
                "Verificar motor de aletas",
                "Limpiar colector de admisión",
                "Comprobar sensor de posición",
                "Reemplazar colector si es necesario"
            ]
        ),

        "P2187": VAGDTCCode(
            code: "P2187",
            description: "Sistema demasiado pobre en ralentí B1",
            severity: .medium,
            category: .fuel,
            possibleCauses: [
                "Fuga de vacío",
                "Válvula PCV defectuosa",
                "Inyectores sucios",
                "Sensor O2 defectuoso"
            ],
            solutions: [
                "Verificar fugas de vacío",
                "Comprobar válvula PCV",
                "Limpiar inyectores",
                "Verificar sensores O2"
            ]
        ),

        "P2188": VAGDTCCode(
            code: "P2188",
            description: "Sistema demasiado rico en ralentí B1",
            severity: .medium,
            category: .fuel,
            possibleCauses: ["Inyectores con fugas", "Presión combustible alta", "Sensor MAF defectuoso"],
            solutions: ["Verificar inyectores", "Comprobar regulador de presión", "Limpiar sensor MAF"]
        ),

        // ============================================
        // RED CAN
        // ============================================
        "U0100": VAGDTCCode(
            code: "U0100",
            description: "Pérdida comunicación con ECM/PCM",
            severity: .critical,
            category: .network,
            possibleCauses: [
                "Fallo en bus CAN",
                "ECU defectuosa",
                "Cableado CAN dañado",
                "Resistencia terminadora faltante"
            ],
            solutions: [
                "Verificar cableado CAN",
                "Comprobar resistencias terminadoras",
                "Escanear red CAN completa",
                "Verificar ECU"
            ]
        ),

        "U0101": VAGDTCCode(
            code: "U0101",
            description: "Pérdida comunicación con TCM",
            severity: .high,
            category: .network,
            possibleCauses: ["Módulo transmisión defectuoso", "Cableado CAN dañado", "Fusible fundido"],
            solutions: ["Verificar fusibles", "Comprobar cableado", "Verificar módulo TCM"]
        ),

        "U0121": VAGDTCCode(
            code: "U0121",
            description: "Pérdida comunicación con ABS",
            severity: .high,
            category: .network,
            possibleCauses: ["Módulo ABS defectuoso", "Cableado CAN dañado"],
            solutions: ["Verificar módulo ABS", "Comprobar cableado CAN"]
        ),
    ]

    // MARK: - Lookup Methods
    public static func lookup(code: String) -> VAGDTCCode? {
        return codes[code.uppercased()]
    }

    public static func decode(rawCode: UInt16) -> String {
        let firstChar: Character
        let prefix = (rawCode >> 14) & 0x03

        switch prefix {
        case 0: firstChar = "P"
        case 1: firstChar = "C"
        case 2: firstChar = "B"
        case 3: firstChar = "U"
        default: firstChar = "P"
        }

        let numericPart = rawCode & 0x3FFF
        return String(format: "%C%04X", firstChar.asciiValue!, numericPart)
    }

    public static func getCodesByCategory(_ category: DTCCategory) -> [VAGDTCCode] {
        return codes.values.filter { $0.category == category }
    }

    public static func getCodesBySeverity(_ severity: DTCSeverity) -> [VAGDTCCode] {
        return codes.values.filter { $0.severity == severity }
    }

    public static func searchCodes(query: String) -> [VAGDTCCode] {
        let lowercaseQuery = query.lowercased()
        return codes.values.filter {
            $0.code.lowercased().contains(lowercaseQuery) ||
            $0.description.lowercased().contains(lowercaseQuery)
        }
    }
}

// MARK: - DTC Parser
public struct DTCParser {

    public static func parseDTCResponse(_ response: String) -> [VAGDTCCode] {
        var dtcs: [VAGDTCCode] = []

        // Remove spaces and clean response
        let cleaned = response
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")

        // Mode 03 response starts with 43
        guard cleaned.hasPrefix("43") else { return dtcs }

        let dataStart = cleaned.index(cleaned.startIndex, offsetBy: 2)
        let data = String(cleaned[dataStart...])

        // Each DTC is 4 hex characters (2 bytes)
        var index = data.startIndex
        while index < data.endIndex {
            guard let endIndex = data.index(index, offsetBy: 4, limitedBy: data.endIndex) else { break }

            let dtcHex = String(data[index..<endIndex])

            // Skip "0000" (no more DTCs)
            if dtcHex == "0000" { break }

            if let rawCode = UInt16(dtcHex, radix: 16) {
                let codeString = VAGDTCDatabase.decode(rawCode: rawCode)

                if let knownDTC = VAGDTCDatabase.lookup(code: codeString) {
                    dtcs.append(knownDTC)
                } else {
                    // Unknown DTC
                    dtcs.append(VAGDTCCode(
                        code: codeString,
                        description: "Código desconocido",
                        severity: .info,
                        category: .unknown,
                        possibleCauses: ["Consultar manual de servicio VAG"],
                        solutions: ["Usar VCDS/ODIS para más información"]
                    ))
                }
            }

            index = endIndex
        }

        return dtcs
    }
}
