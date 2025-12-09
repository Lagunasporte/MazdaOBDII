import SwiftUI

// MARK: - Vista de Códigos DTC

struct DTCView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @State private var currentDTCs: [String] = []
    @State private var pendingDTCs: [String] = []
    @State private var isScanning = false
    @State private var showClearConfirmation = false
    @State private var lastScan: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Botones de acción
                    ActionButtonsCard()

                    // Estado actual
                    if isScanning {
                        ScanningCard()
                    } else if currentDTCs.isEmpty && pendingDTCs.isEmpty {
                        NoDTCsCard()
                    } else {
                        // DTCs actuales
                        if !currentDTCs.isEmpty {
                            DTCListCard(title: "Códigos Activos", codes: currentDTCs, isActive: true)
                        }

                        // DTCs pendientes
                        if !pendingDTCs.isEmpty {
                            DTCListCard(title: "Códigos Pendientes", codes: pendingDTCs, isActive: false)
                        }
                    }

                    // Base de datos de códigos
                    DTCDatabaseCard()
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Códigos DTC")
            .alert("Borrar Códigos", isPresented: $showClearConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar", role: .destructive) {
                    clearDTCs()
                }
            } message: {
                Text("¿Estás seguro de que quieres borrar todos los códigos de error? Esto también apagará la luz de Check Engine.")
            }
        }
    }

    // MARK: - Botones de Acción

    func ActionButtonsCard() -> some View {
        HStack(spacing: 12) {
            Button(action: scanDTCs) {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                    Text("Escanear")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(connectionManager.connectionState != .connectedToVehicle || isScanning)

            Button(action: { showClearConfirmation = true }) {
                VStack {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Borrar")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(currentDTCs.isEmpty ? Color.gray : Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(currentDTCs.isEmpty || connectionManager.connectionState != .connectedToVehicle)
        }
    }

    func ScanningCard() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)

            Text("Escaneando códigos de error...")
                .foregroundColor(.white)

            Text("Leyendo PCM, ABS, Airbag...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }

    func NoDTCsCard() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Sin códigos de error")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("No se encontraron códigos de error activos ni pendientes")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            if let lastScan = lastScan {
                Text("Último escaneo: \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Acciones

    func scanDTCs() {
        isScanning = true
        Task {
            do {
                currentDTCs = try await connectionManager.readDTCs()
                pendingDTCs = try await connectionManager.readPendingDTCs()
                lastScan = Date()
            } catch {
                // Manejar error
            }
            isScanning = false
        }
    }

    func clearDTCs() {
        Task {
            do {
                try await connectionManager.clearDTCs()
                currentDTCs = []
                pendingDTCs = []
            } catch {
                // Manejar error
            }
        }
    }
}

// MARK: - Lista de DTCs

struct DTCListCard: View {
    let title: String
    let codes: [String]
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isActive ? "exclamationmark.triangle.fill" : "clock")
                    .foregroundColor(isActive ? .red : .orange)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(codes.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isActive ? Color.red : Color.orange)
                    .cornerRadius(8)
            }

            ForEach(codes, id: \.self) { code in
                DTCRow(code: code)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

struct DTCRow: View {
    let code: String
    @State private var isExpanded = false

    var dtcInfo: DTCCode? {
        RX8DTCDatabase.find(code: code)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    // Código
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Nombre
                    if let info = dtcInfo {
                        Text("- \(info.name)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Indicadores
                    if let info = dtcInfo {
                        if info.rotarySpecific {
                            Image(systemName: "r.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        if info.affectsApexSeals {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if isExpanded, let info = dtcInfo {
                VStack(alignment: .leading, spacing: 12) {
                    // Severidad
                    HStack {
                        Text("Severidad:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(info.severity.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(severityColor(info.severity))
                    }

                    // Descripción
                    Text(info.description)
                        .font(.caption)
                        .foregroundColor(.white)

                    // Causas
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Posibles causas:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)

                        ForEach(info.causes, id: \.self) { cause in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(cause)
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }

                    // Síntomas
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Síntomas:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)

                        ForEach(info.symptoms, id: \.self) { symptom in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(symptom)
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }

                    // Soluciones
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Soluciones:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)

                        ForEach(info.solutions, id: \.self) { solution in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(solution)
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                        }
                    }

                    // Badges
                    HStack {
                        if info.rotarySpecific {
                            Badge(text: "Específico Rotativo", color: .orange)
                        }
                        if info.affectsApexSeals {
                            Badge(text: "Afecta Apex Seals", color: .red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray5).opacity(0.3))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
    }

    func severityColor(_ severity: DTCSeverity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.3))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Base de Datos de DTCs

struct DTCDatabaseCard: View {
    @State private var searchText = ""
    @State private var showDatabase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.blue)
                Text("Base de Datos RX-8")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Consulta códigos específicos del motor rotativo y sus soluciones")
                .font(.caption)
                .foregroundColor(.gray)

            Button(action: { showDatabase = true }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Buscar Código")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.3))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }

            // Estadísticas
            HStack {
                DTCStatItem(value: "\(RX8DTCDatabase.allCodes.count)", label: "Códigos")
                DTCStatItem(value: "\(RX8DTCDatabase.rotarySpecificCodes.count)", label: "Rotativo")
                DTCStatItem(value: "\(RX8DTCDatabase.criticalCodes.count)", label: "Críticos")
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .sheet(isPresented: $showDatabase) {
            DTCDatabaseView()
        }
    }
}

struct DTCStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vista de Base de Datos

struct DTCDatabaseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: DTCFilter = .all

    enum DTCFilter: String, CaseIterable {
        case all = "Todos"
        case rotary = "Rotativo"
        case critical = "Críticos"
        case apexSeals = "Apex Seals"
    }

    var filteredCodes: [DTCCode] {
        var codes = RX8DTCDatabase.allCodes

        switch selectedFilter {
        case .all: break
        case .rotary: codes = codes.filter { $0.rotarySpecific }
        case .critical: codes = codes.filter { $0.severity == .critical }
        case .apexSeals: codes = codes.filter { $0.affectsApexSeals }
        }

        if !searchText.isEmpty {
            codes = codes.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return codes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtros
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(DTCFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding()
                }

                // Lista
                List(filteredCodes) { code in
                    DTCDatabaseRow(code: code)
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Buscar código o nombre")
            .navigationTitle("Códigos RX-8")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .gray)
                .cornerRadius(20)
        }
    }
}

struct DTCDatabaseRow: View {
    let code: DTCCode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(code.code)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)

                if code.rotarySpecific {
                    Image(systemName: "r.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            Text(code.name)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}
