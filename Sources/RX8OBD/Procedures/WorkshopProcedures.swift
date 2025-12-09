import Foundation

// MARK: - Workshop Procedures for Mazda RX-8
// Procedimientos de taller basados en el manual oficial Mazda y experiencia de mecánicos

/// Procedure category
public enum ProcedureCategory: String, CaseIterable, Codable {
    case diagnostic = "Diagnóstico"
    case maintenance = "Mantenimiento"
    case repair = "Reparación"
    case emergency = "Emergencia"
    case performance = "Rendimiento"
    case electrical = "Eléctrico"
}

/// Difficulty level for the procedure
public enum ProcedureDifficulty: String, Codable {
    case basic = "Básico"
    case intermediate = "Intermedio"
    case advanced = "Avanzado"
    case professional = "Profesional"

    public var color: String {
        switch self {
        case .basic: return "green"
        case .intermediate: return "yellow"
        case .advanced: return "orange"
        case .professional: return "red"
        }
    }
}

/// Tool required for a procedure
public struct RequiredTool: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let partNumber: String?
    public let alternative: String?

    public init(name: String, partNumber: String? = nil, alternative: String? = nil) {
        self.id = UUID()
        self.name = name
        self.partNumber = partNumber
        self.alternative = alternative
    }
}

/// Step in a procedure
public struct ProcedureStep: Identifiable, Codable {
    public let id: UUID
    public let number: Int
    public let instruction: String
    public let warning: String?
    public let tip: String?
    public let imageRef: String?
    public let pidToMonitor: String?
    public let expectedValue: String?

    public init(number: Int, instruction: String, warning: String? = nil, tip: String? = nil,
                imageRef: String? = nil, pidToMonitor: String? = nil, expectedValue: String? = nil) {
        self.id = UUID()
        self.number = number
        self.instruction = instruction
        self.warning = warning
        self.tip = tip
        self.imageRef = imageRef
        self.pidToMonitor = pidToMonitor
        self.expectedValue = expectedValue
    }
}

/// Workshop procedure
public struct WorkshopProcedure: Identifiable, Codable {
    public let id: String
    public let title: String
    public let category: ProcedureCategory
    public let difficulty: ProcedureDifficulty
    public let estimatedTime: String
    public let description: String
    public let symptoms: [String]
    public let tools: [RequiredTool]
    public let parts: [String]
    public let steps: [ProcedureStep]
    public let warnings: [String]
    public let tips: [String]
    public let relatedDTCs: [String]
    public let videoURL: String?

    public init(id: String, title: String, category: ProcedureCategory, difficulty: ProcedureDifficulty,
                estimatedTime: String, description: String, symptoms: [String] = [], tools: [RequiredTool] = [],
                parts: [String] = [], steps: [ProcedureStep], warnings: [String] = [], tips: [String] = [],
                relatedDTCs: [String] = [], videoURL: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.estimatedTime = estimatedTime
        self.description = description
        self.symptoms = symptoms
        self.tools = tools
        self.parts = parts
        self.steps = steps
        self.warnings = warnings
        self.tips = tips
        self.relatedDTCs = relatedDTCs
        self.videoURL = videoURL
    }
}

// MARK: - RX-8 Procedures Database

public struct RX8Procedures {

    // MARK: - Emergency Procedures

    public static let floodRecovery = WorkshopProcedure(
        id: "flood_recovery",
        title: "Recuperación de Motor Ahogado (Flooded)",
        category: .emergency,
        difficulty: .basic,
        estimatedTime: "5-15 minutos",
        description: """
            El motor rotativo se puede ahogar fácilmente si se apaga antes de alcanzar temperatura
            o si se arranca repetidamente sin llegar a encender. Este procedimiento limpia el exceso
            de combustible de las cámaras.
            """,
        symptoms: [
            "Motor no arranca tras varios intentos",
            "Olor fuerte a gasolina",
            "Motor giró pero no encendió",
            "Se apagó en frío sin dejarlo calentar"
        ],
        tools: [],
        parts: [],
        steps: [
            ProcedureStep(number: 1, instruction: "Asegurar que el motor está frío o templado (no caliente)",
                         warning: "No realizar si el motor está muy caliente"),
            ProcedureStep(number: 2, instruction: "Pisar el acelerador a fondo y mantenerlo pisado",
                         tip: "Esto activa el modo de limpieza de flood en la ECU"),
            ProcedureStep(number: 3, instruction: "Con el acelerador a fondo, girar el motor de arranque durante 8-10 segundos",
                         warning: "No exceder 10 segundos para no sobrecalentar el motor de arranque"),
            ProcedureStep(number: 4, instruction: "Esperar 30 segundos con el acelerador suelto"),
            ProcedureStep(number: 5, instruction: "Intentar arrancar normalmente SIN pisar el acelerador"),
            ProcedureStep(number: 6, instruction: "Si arranca, dejar el motor en ralentí 5-10 minutos para alcanzar temperatura",
                         tip: "Nunca apagar un RX-8 hasta que el refrigerante llegue a 70°C mínimo"),
            ProcedureStep(number: 7, instruction: "Si no arranca, repetir pasos 2-5 hasta 3 veces más"),
            ProcedureStep(number: 8, instruction: "Si sigue sin arrancar, puede ser necesario retirar las bujías para drenar combustible",
                         warning: "Este paso requiere herramientas y conocimiento adicional")
        ],
        warnings: [
            "NUNCA apagar el RX-8 sin dejarlo calentar completamente",
            "Evitar trayectos cortos donde el motor no llegue a temperatura",
            "El modo flood solo funciona con el acelerador 100% pisado"
        ],
        tips: [
            "Si el motor se ahoga frecuentemente, verificar bujías y bobinas",
            "Considerar cambiar a bujías de iridio para mejor arranque en frío",
            "En climas fríos, dejar calentar el motor más tiempo antes de apagar"
        ],
        relatedDTCs: ["P0300", "P0301", "P0302"]
    )

    // MARK: - Diagnostic Procedures

    public static let compressionTest = WorkshopProcedure(
        id: "compression_test",
        title: "Test de Compresión Motor Rotativo",
        category: .diagnostic,
        difficulty: .professional,
        estimatedTime: "45-60 minutos",
        description: """
            El test de compresión es el diagnóstico más importante del motor rotativo.
            Indica el estado de los apex seals, side seals y corner seals.
            Se requiere herramienta especial Mazda o adaptador para motores rotativos.
            """,
        symptoms: [
            "Pérdida de potencia",
            "Arranque difícil en caliente",
            "Consumo excesivo de aceite",
            "Humo azulado en el escape",
            "Ralentí irregular"
        ],
        tools: [
            RequiredTool(name: "Compresímetro Rotativo Mazda", partNumber: "49-F043-001", alternative: "Compresímetro genérico con adaptador rotativo"),
            RequiredTool(name: "Llave de bujías 16mm con extensión"),
            RequiredTool(name: "Batería completamente cargada o cargador")
        ],
        parts: [
            "Bujías nuevas (recomendado si las actuales tienen más de 30,000 km)"
        ],
        steps: [
            ProcedureStep(number: 1, instruction: "Calentar el motor hasta temperatura de operación (refrigerante >80°C)",
                         pidToMonitor: "ect", expectedValue: ">80°C"),
            ProcedureStep(number: 2, instruction: "Apagar el motor y desconectar las 4 bobinas de encendido"),
            ProcedureStep(number: 3, instruction: "Retirar las 4 bujías (2 leading + 2 trailing)",
                         warning: "Las bujías pueden estar muy calientes"),
            ProcedureStep(number: 4, instruction: "Instalar el compresímetro en el orificio de bujía leading del rotor frontal"),
            ProcedureStep(number: 5, instruction: "Pisar el acelerador a fondo y mantener"),
            ProcedureStep(number: 6, instruction: "Girar el motor de arranque 7-10 revoluciones del rotor (observar el compresímetro)",
                         tip: "El rotor gira 3 veces por cada vuelta del cigüeñal"),
            ProcedureStep(number: 7, instruction: "Anotar el valor máximo de compresión para cada cara del rotor (3 caras)",
                         expectedValue: "Mínimo 6.0 kg/cm² por cara"),
            ProcedureStep(number: 8, instruction: "Repetir para el rotor trasero"),
            ProcedureStep(number: 9, instruction: "Comparar valores entre caras y entre rotores",
                         expectedValue: "Diferencia máxima 1.0 kg/cm² entre caras"),
            ProcedureStep(number: 10, instruction: "Reinstalar bujías y bobinas"),
            ProcedureStep(number: 11, instruction: "Arrancar y verificar funcionamiento")
        ],
        warnings: [
            "Batería debe estar completamente cargada",
            "Motor debe estar a temperatura de operación",
            "No exceder 10 segundos de arranque continuo"
        ],
        tips: [
            "Valores nuevos: 7.5-8.5 kg/cm²",
            "Valores límite: 6.0 kg/cm² mínimo",
            "Si una cara tiene compresión muy baja, los apex seals de esa cara están desgastados",
            "El motor puede funcionar con compresión baja pero con pérdida de potencia"
        ],
        relatedDTCs: ["P0300", "P0301", "P0302"]
    )

    public static let sparkPlugInspection = WorkshopProcedure(
        id: "spark_plug_inspection",
        title: "Inspección y Cambio de Bujías",
        category: .maintenance,
        difficulty: .intermediate,
        estimatedTime: "30-45 minutos",
        description: """
            Las bujías del RX-8 son críticas para el funcionamiento del motor rotativo.
            El motor usa 4 bujías: 2 leading (encendido principal) y 2 trailing (encendido secundario).
            Deben cambiarse cada 20,000-30,000 km.
            """,
        symptoms: [
            "Arranque difícil",
            "Pérdida de potencia",
            "Ralentí irregular",
            "Mayor consumo de combustible",
            "Fallos de encendido"
        ],
        tools: [
            RequiredTool(name: "Llave de bujías 16mm magnética"),
            RequiredTool(name: "Extensión 150mm"),
            RequiredTool(name: "Torquímetro")
        ],
        parts: [
            "2x Bujías Leading: NGK RE7C-L o DENSO W24ESR-U",
            "2x Bujías Trailing: NGK RE9B-T o DENSO W22ESR-U"
        ],
        steps: [
            ProcedureStep(number: 1, instruction: "Desconectar la batería (terminal negativo)"),
            ProcedureStep(number: 2, instruction: "Retirar la cubierta del motor (4 clips)"),
            ProcedureStep(number: 3, instruction: "Desconectar los conectores de las bobinas de encendido"),
            ProcedureStep(number: 4, instruction: "Retirar los tornillos de fijación de las bobinas (2 por bobina)"),
            ProcedureStep(number: 5, instruction: "Extraer las bobinas tirando hacia arriba",
                         tip: "Marcar la posición de cada bobina"),
            ProcedureStep(number: 6, instruction: "Retirar las bujías con la llave de 16mm",
                         warning: "No dejar caer nada en los orificios"),
            ProcedureStep(number: 7, instruction: "Inspeccionar las bujías usadas:",
                         tip: "Leading deben ser más oscuras (queman aceite OMP). Trailing más limpias."),
            ProcedureStep(number: 8, instruction: "Verificar gap de bujías nuevas: Leading 1.1mm, Trailing 1.1mm"),
            ProcedureStep(number: 9, instruction: "Aplicar anti-seize a las roscas de las bujías nuevas"),
            ProcedureStep(number: 10, instruction: "Instalar bujías a mano primero, luego torque: 15-22 Nm",
                         warning: "No exceder el torque para evitar dañar las roscas de aluminio"),
            ProcedureStep(number: 11, instruction: "Reinstalar bobinas y conectores"),
            ProcedureStep(number: 12, instruction: "Reconectar batería y arrancar")
        ],
        warnings: [
            "Las bujías Leading y Trailing son DIFERENTES - no intercambiar",
            "Leading tienen electrodo más largo",
            "Usar siempre bujías específicas para motor rotativo"
        ],
        tips: [
            "Bujías de iridio duran más y mejoran arranque en frío",
            "Si las bujías leading están aceitosas en exceso, verificar OMP",
            "Revisar las bobinas al mismo tiempo por signos de daño"
        ],
        relatedDTCs: ["P0351", "P0352", "P0353", "P0354", "P0300"]
    )

    public static let ignitionCoilTest = WorkshopProcedure(
        id: "ignition_coil_test",
        title: "Diagnóstico de Bobinas de Encendido",
        category: .diagnostic,
        difficulty: .intermediate,
        estimatedTime: "30 minutos",
        description: """
            El RX-8 tiene 4 bobinas de encendido individuales: 2 para bujías leading y 2 para trailing.
            Las bobinas leading son más propensas a fallar debido a la mayor carga de trabajo.
            """,
        symptoms: [
            "Fallos de encendido intermitentes",
            "Luz Check Engine encendida",
            "Pérdida de potencia a altas RPM",
            "Ralentí irregular"
        ],
        tools: [
            RequiredTool(name: "Multímetro digital"),
            RequiredTool(name: "OBD Scanner")
        ],
        parts: [],
        steps: [
            ProcedureStep(number: 1, instruction: "Leer DTCs con el scanner - buscar P0351-P0354",
                         pidToMonitor: "dtc"),
            ProcedureStep(number: 2, instruction: "Con motor en marcha, observar datos de fallos de encendido por cilindro"),
            ProcedureStep(number: 3, instruction: "Apagar motor y desconectar conector de la bobina sospechosa"),
            ProcedureStep(number: 4, instruction: "Medir resistencia del primario de la bobina: 0.3-1.0 Ω",
                         expectedValue: "0.3-1.0 Ω"),
            ProcedureStep(number: 5, instruction: "Medir resistencia del secundario: 6-15 kΩ",
                         expectedValue: "6-15 kΩ"),
            ProcedureStep(number: 6, instruction: "Intercambiar bobina sospechosa con una buena conocida"),
            ProcedureStep(number: 7, instruction: "Borrar DTCs y probar el vehículo"),
            ProcedureStep(number: 8, instruction: "Si el fallo sigue a la bobina, reemplazarla")
        ],
        warnings: [
            "Las bobinas originales Mazda son más fiables que las genéricas",
            "No tocar los conectores con el motor en marcha (alto voltaje)"
        ],
        tips: [
            "Es recomendable cambiar las 4 bobinas juntas si una falla",
            "Las bobinas leading (L1, L2) fallan más frecuentemente",
            "Bobinas originales: N3H1-18-100B (Leading), N3H1-18-100C (Trailing)"
        ],
        relatedDTCs: ["P0351", "P0352", "P0353", "P0354"]
    )

    // MARK: - Maintenance Procedures

    public static let oilChange = WorkshopProcedure(
        id: "oil_change",
        title: "Cambio de Aceite Motor Rotativo",
        category: .maintenance,
        difficulty: .basic,
        estimatedTime: "30 minutos",
        description: """
            El motor rotativo requiere aceite de calidad y cambios frecuentes.
            El aceite no solo lubrica, sino que también sella los apex seals mediante el sistema OMP.
            Intervalo recomendado: 5,000 km o 6 meses.
            """,
        symptoms: [],
        tools: [
            RequiredTool(name: "Llave de drenaje 17mm"),
            RequiredTool(name: "Llave para filtro de aceite"),
            RequiredTool(name: "Recipiente de drenaje 5L"),
            RequiredTool(name: "Embudo")
        ],
        parts: [
            "Aceite 5W-30 o 5W-40 (4.5L) - API SN o superior",
            "Filtro de aceite Mazda N3R1-14-302 o equivalente",
            "Arandela de drenaje (si es necesario)"
        ],
        steps: [
            ProcedureStep(number: 1, instruction: "Calentar el motor hasta temperatura de operación",
                         pidToMonitor: "ect", expectedValue: ">80°C"),
            ProcedureStep(number: 2, instruction: "Apagar motor y elevar el vehículo"),
            ProcedureStep(number: 3, instruction: "Colocar recipiente de drenaje bajo el cárter"),
            ProcedureStep(number: 4, instruction: "Retirar tapón de drenaje (17mm) y drenar aceite",
                         warning: "El aceite estará caliente"),
            ProcedureStep(number: 5, instruction: "Retirar filtro de aceite viejo"),
            ProcedureStep(number: 6, instruction: "Aplicar aceite limpio a la junta del filtro nuevo"),
            ProcedureStep(number: 7, instruction: "Instalar filtro nuevo - apretar a mano + 3/4 de vuelta"),
            ProcedureStep(number: 8, instruction: "Instalar tapón de drenaje con arandela nueva - Torque: 30-40 Nm"),
            ProcedureStep(number: 9, instruction: "Bajar vehículo y añadir 4.3L de aceite"),
            ProcedureStep(number: 10, instruction: "Arrancar motor y verificar que no hay fugas"),
            ProcedureStep(number: 11, instruction: "Apagar, esperar 5 minutos, verificar nivel",
                         tip: "El nivel debe estar entre las marcas de la varilla")
        ],
        warnings: [
            "NUNCA usar aceite de motocicleta con aditivos anti-desgaste (ZDDP alto)",
            "No llenar en exceso - puede causar humo y daño a catalizador",
            "Usar aceite de calidad - el motor rotativo es sensible"
        ],
        tips: [
            "Aceites recomendados: Idemitsu Rotary, Mazda Original, Castrol Edge",
            "Es normal que el RX-8 consuma 0.5-1L de aceite cada 3000-5000 km",
            "Verificar nivel de aceite frecuentemente (cada 1000 km)",
            "Considerar cambio cada 3000 km si se usa para circuito"
        ],
        relatedDTCs: []
    )

    public static let coolantFlush = WorkshopProcedure(
        id: "coolant_flush",
        title: "Cambio de Refrigerante y Purgado",
        category: .maintenance,
        difficulty: .intermediate,
        estimatedTime: "60 minutos",
        description: """
            El sistema de refrigeración del RX-8 es crítico - el motor rotativo es
            muy sensible al sobrecalentamiento. El sistema tiene bolsas de aire
            que deben purgarse correctamente.
            """,
        symptoms: [
            "Temperatura alta intermitente",
            "Calefacción que no calienta bien",
            "Refrigerante viejo/sucio"
        ],
        tools: [
            RequiredTool(name: "Recipiente de drenaje 10L"),
            RequiredTool(name: "Alicates para abrazaderas"),
            RequiredTool(name: "Embudo con extensión")
        ],
        parts: [
            "Refrigerante Mazda FL22 o equivalente (7.3L dilución 50/50)",
            "Agua destilada (si se usa concentrado)"
        ],
        steps: [
            ProcedureStep(number: 1, instruction: "Asegurar que el motor está frío",
                         warning: "NUNCA abrir sistema de refrigeración caliente"),
            ProcedureStep(number: 2, instruction: "Abrir tapón del radiador"),
            ProcedureStep(number: 3, instruction: "Localizar el tapón de drenaje del radiador (parte inferior izquierda)"),
            ProcedureStep(number: 4, instruction: "Drenar refrigerante en recipiente"),
            ProcedureStep(number: 5, instruction: "Opcional: desconectar manguera inferior del radiador para drenar más"),
            ProcedureStep(number: 6, instruction: "Cerrar drenajes y reconectar mangueras"),
            ProcedureStep(number: 7, instruction: "Localizar tornillo de purga en la carcasa del termostato"),
            ProcedureStep(number: 8, instruction: "Aflojar tornillo de purga"),
            ProcedureStep(number: 9, instruction: "Llenar refrigerante lentamente por el radiador"),
            ProcedureStep(number: 10, instruction: "Cuando salga refrigerante por el purgador, apretar tornillo"),
            ProcedureStep(number: 11, instruction: "Continuar llenando hasta que esté lleno"),
            ProcedureStep(number: 12, instruction: "Instalar tapón del radiador sin apretar del todo"),
            ProcedureStep(number: 13, instruction: "Arrancar motor con calefacción al máximo"),
            ProcedureStep(number: 14, instruction: "Dejar que el motor llegue a temperatura y el termostato abra",
                         pidToMonitor: "ect", expectedValue: "82-95°C"),
            ProcedureStep(number: 15, instruction: "Añadir más refrigerante según baje el nivel"),
            ProcedureStep(number: 16, instruction: "Cuando no baje más, apretar tapón y verificar depósito de expansión")
        ],
        warnings: [
            "El sistema contiene bolsas de aire difíciles de purgar",
            "Verificar temperatura durante los primeros días de uso",
            "Si la temperatura sube anormalmente, hay aire en el sistema"
        ],
        tips: [
            "Usar solo refrigerante compatible con aluminio",
            "El refrigerante FL22 de Mazda es de larga vida (cambio cada 4 años)",
            "Elevar la parte delantera del coche ayuda a purgar aire"
        ],
        relatedDTCs: ["P0117", "P0118", "P0125"]
    )

    public static let ssvCleaning = WorkshopProcedure(
        id: "ssv_cleaning",
        title: "Limpieza de Válvula Secundaria (SSV)",
        category: .maintenance,
        difficulty: .advanced,
        estimatedTime: "90 minutos",
        description: """
            La Secondary Shutter Valve (SSV) controla el flujo de aire secundario.
            Con el tiempo se acumula carbonilla y puede atascarse, causando pérdida
            de potencia a altas RPM.
            """,
        symptoms: [
            "Pérdida de potencia sobre 5000 RPM",
            "Motor se siente ahogado a altas vueltas",
            "DTC P1520 (SSV stuck)"
        ],
        tools: [
            RequiredTool(name: "Limpiador de carburador/inyectores"),
            RequiredTool(name: "Cepillo de nylon"),
            RequiredTool(name: "Llaves Torx"),
            RequiredTool(name: "Trapos limpios")
        ],
        parts: [],
        steps: [
            ProcedureStep(number: 1, instruction: "Desconectar la batería"),
            ProcedureStep(number: 2, instruction: "Retirar la cubierta del motor y conducto de admisión"),
            ProcedureStep(number: 3, instruction: "Localizar la SSV en el colector de admisión (lado izquierdo)"),
            ProcedureStep(number: 4, instruction: "Desconectar el actuador de vacío de la SSV"),
            ProcedureStep(number: 5, instruction: "Mover la válvula manualmente para verificar que gira libremente"),
            ProcedureStep(number: 6, instruction: "Aplicar limpiador en las zonas con carbonilla"),
            ProcedureStep(number: 7, instruction: "Cepillar suavemente para remover depósitos",
                         warning: "No forzar la válvula"),
            ProcedureStep(number: 8, instruction: "Dejar actuar el limpiador 5 minutos"),
            ProcedureStep(number: 9, instruction: "Limpiar con trapo y repetir si es necesario"),
            ProcedureStep(number: 10, instruction: "Verificar que la válvula abre y cierra suavemente"),
            ProcedureStep(number: 11, instruction: "Reconectar actuador y conductos"),
            ProcedureStep(number: 12, instruction: "Reconectar batería y borrar DTCs")
        ],
        warnings: [
            "No usar limpiadores agresivos que puedan dañar sellos de goma",
            "No permitir que caigan residuos dentro del colector"
        ],
        tips: [
            "Limpiar cada 50,000 km o si hay síntomas",
            "Verificar también el actuador de vacío",
            "El SSV solenoid puede fallar - verificar con multímetro"
        ],
        relatedDTCs: ["P1520", "P1521"]
    )

    public static let catalystCheck = WorkshopProcedure(
        id: "catalyst_check",
        title: "Verificación del Catalizador",
        category: .diagnostic,
        difficulty: .intermediate,
        estimatedTime: "30 minutos",
        description: """
            El catalizador del RX-8 es propenso a fallar debido a las características
            del motor rotativo (más combustible sin quemar). Un catalizador obstruido
            causa pérdida severa de potencia.
            """,
        symptoms: [
            "Pérdida de potencia significativa",
            "Olor a huevo podrido del escape",
            "DTC P0420 (eficiencia del catalizador)",
            "Escape restringido (se siente ahogado)"
        ],
        tools: [
            RequiredTool(name: "OBD Scanner"),
            RequiredTool(name: "Pirómetro infrarrojo", alternative: "Termómetro láser"),
            RequiredTool(name: "Manómetro de contrapresión", alternative: nil)
        ],
        parts: [],
        steps: [
            ProcedureStep(number: 1, instruction: "Leer DTCs - buscar P0420 y relacionados"),
            ProcedureStep(number: 2, instruction: "Calentar motor a temperatura de operación"),
            ProcedureStep(number: 3, instruction: "Comparar voltajes de sensor O2 pre y post catalizador",
                         pidToMonitor: "o2_pre_cat",
                         expectedValue: "Pre-cat: oscilando 0.1-0.9V, Post-cat: estable ~0.6V"),
            ProcedureStep(number: 4, instruction: "Si post-cat oscila igual que pre-cat, el catalizador está agotado"),
            ProcedureStep(number: 5, instruction: "Medir temperatura antes y después del catalizador con pirómetro",
                         expectedValue: "Post-cat debe ser 20-50°C más caliente que pre-cat"),
            ProcedureStep(number: 6, instruction: "Si post-cat está igual o más frío, no está funcionando"),
            ProcedureStep(number: 7, instruction: "Verificar contrapresión del escape (opcional)",
                         expectedValue: "Máximo 1.5 psi en ralentí, 2.5 psi a 2500 RPM")
        ],
        warnings: [
            "El catalizador puede alcanzar más de 800°C - riesgo de quemaduras",
            "Un catalizador obstruido puede destruirse y dañar el motor"
        ],
        tips: [
            "Los catalizadores de alto flujo ayudan al rendimiento del rotativo",
            "Verificar estado de bujías y bobinas antes de culpar al catalizador",
            "Un motor que quema aceite en exceso daña el catalizador rápidamente"
        ],
        relatedDTCs: ["P0420", "P0421", "P0430"]
    )

    public static let premixProcedure = WorkshopProcedure(
        id: "premix",
        title: "Procedimiento de Premix (Aceite en Combustible)",
        category: .performance,
        difficulty: .basic,
        estimatedTime: "5 minutos",
        description: """
            Añadir aceite 2T al combustible (premix) proporciona lubricación adicional
            a los apex seals. Recomendado para uso en circuito o conducción agresiva.
            """,
        symptoms: [],
        tools: [
            RequiredTool(name: "Aceite 2T de calidad (Idemitsu, Motul, etc.)")
        ],
        parts: [
            "Aceite 2 tiempos de calidad"
        ],
        steps: [
            ProcedureStep(number: 1, instruction: "Elegir aceite 2T de calidad (sintético o semi-sintético)",
                         tip: "Idemitsu Premix, Motul 800, Lucas 2T"),
            ProcedureStep(number: 2, instruction: "Calcular cantidad: ratio recomendado 1:200 (uso calle) o 1:100 (circuito)"),
            ProcedureStep(number: 3, instruction: "Para depósito de 60L a 1:200 = 300ml de aceite 2T"),
            ProcedureStep(number: 4, instruction: "Añadir aceite ANTES de llenar combustible"),
            ProcedureStep(number: 5, instruction: "Llenar combustible - esto mezclará el aceite automáticamente")
        ],
        warnings: [
            "No exceder ratio 1:100 para evitar problemas con bujías",
            "Puede aumentar ligeramente las emisiones",
            "No usar aceites 2T con aditivos para motores náuticos"
        ],
        tips: [
            "Muchos propietarios de RX-8 hacen premix siempre",
            "Ayuda especialmente a motores con alto kilometraje",
            "Usar bujías de punta fría si se hace premix constantemente"
        ],
        relatedDTCs: []
    )

    // MARK: - All Procedures Collection

    public static let allProcedures: [WorkshopProcedure] = [
        floodRecovery,
        compressionTest,
        sparkPlugInspection,
        ignitionCoilTest,
        oilChange,
        coolantFlush,
        ssvCleaning,
        catalystCheck,
        premixProcedure
    ]

    public static func procedures(for category: ProcedureCategory) -> [WorkshopProcedure] {
        return allProcedures.filter { $0.category == category }
    }

    public static func procedures(forDTC code: String) -> [WorkshopProcedure] {
        return allProcedures.filter { $0.relatedDTCs.contains(code) }
    }

    public static func procedure(byId id: String) -> WorkshopProcedure? {
        return allProcedures.first { $0.id == id }
    }

    public static func search(_ query: String) -> [WorkshopProcedure] {
        let lowercased = query.lowercased()
        return allProcedures.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased) ||
            $0.symptoms.contains { $0.lowercased().contains(lowercased) }
        }
    }
}
