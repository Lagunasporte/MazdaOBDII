import SwiftUI

// MARK: - Vista de Códigos DTC (Responsive: Vertical=Móvil, Horizontal=CarPlay)

struct DTCView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var currentDTCs: [String] = []
    @State private var pendingDTCs: [String] = []
    @State private var isScanning = false
    @State private var showClearConfirmation = false
    @State private var lastScan: Date?

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                // MODO CARPLAY
                CarPlayDTCView(
                    geometry: geometry,
                    currentDTCs: $currentDTCs,
                    pendingDTCs: $pendingDTCs,
                    isScanning: $isScanning,
                    showClearConfirmation: $showClearConfirmation,
                    scanAction: scanDTCs
                )
            } else {
                // MODO MÓVIL
                MobileDTCView(
                    currentDTCs: $currentDTCs,
                    pendingDTCs: $pendingDTCs,
                    isScanning: $isScanning,
                    showClearConfirmation: $showClearConfirmation,
                    lastScan: lastScan,
                    scanAction: scanDTCs,
                    clearAction: clearDTCs
                )
            }
        }
        .background(Color.black)
        .alert("diagnostics.clear_dtcs_title".localized, isPresented: $showClearConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                clearDTCs()
            }
        } message: {
            Text("diagnostics.clear_dtcs_confirm".localized)
        }
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

// MARK: - Vista CarPlay DTC (Horizontal)

struct CarPlayDTCView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    let geometry: GeometryProxy
    @Binding var currentDTCs: [String]
    @Binding var pendingDTCs: [String]
    @Binding var isScanning: Bool
    @Binding var showClearConfirmation: Bool
    let scanAction: () -> Void

    var totalCodes: Int { currentDTCs.count + pendingDTCs.count }

    var body: some View {
        HStack(spacing: 12) {
            // Columna izquierda: Estado y botones
            VStack(spacing: 12) {
                // Indicador principal
                if isScanning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.orange)
                        Text("dtc.scanning".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if totalCodes == 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("dtc.no_errors".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("\(totalCodes)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        Text(totalCodes == 1 ? "dtc.code_singular".localized : "dtc.codes_plural".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Botones
                HStack(spacing: 8) {
                    Button(action: scanAction) {
                        VStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                            Text("diagnostics.scan_dtcs".localized)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(connectionManager.connectionState != .connectedToVehicle || isScanning)

                    Button(action: { showClearConfirmation = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.title3)
                            Text("diagnostics.clear_dtcs".localized)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(currentDTCs.isEmpty ? Color.gray.opacity(0.5) : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(currentDTCs.isEmpty)
                }
            }
            .frame(width: geometry.size.width * 0.3)
            .padding()

            // Columna derecha: Lista de códigos
            VStack(alignment: .leading, spacing: 8) {
                if !currentDTCs.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("dtc.active".localized.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currentDTCs, id: \.self) { code in
                                CarPlayDTCChip(code: code, isActive: true)
                            }
                        }
                    }
                }

                if !pendingDTCs.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("dtc.pending".localized.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pendingDTCs, id: \.self) { code in
                                CarPlayDTCChip(code: code, isActive: false)
                            }
                        }
                    }
                }

                if totalCodes == 0 && !isScanning {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("dtc.engine_ok".localized)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

struct CarPlayDTCChip: View {
    let code: String
    let isActive: Bool

    var dtcInfo: DTCCode? {
        RX8DTCDatabase.find(code: code)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(code)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let info = dtcInfo {
                    if info.rotarySpecific {
                        Image(systemName: "r.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                    if info.affectsApexSeals {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                }
            }

            if let info = dtcInfo {
                Text(info.name)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.red.opacity(0.3) : Color.orange.opacity(0.3))
        .cornerRadius(10)
    }
}

// MARK: - Vista Móvil DTC (Vertical)

struct MobileDTCView: View {
    @EnvironmentObject var connectionManager: OBDConnectionManager
    @Binding var currentDTCs: [String]
    @Binding var pendingDTCs: [String]
    @Binding var isScanning: Bool
    @Binding var showClearConfirmation: Bool
    let lastScan: Date?
    let scanAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Botones de acción
                    HStack(spacing: 12) {
                        Button(action: scanAction) {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                Text("diagnostics.scan_dtcs".localized)
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
                                Text("diagnostics.clear_dtcs".localized)
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

                    // Estado
                    if isScanning {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.orange)
                            Text("dtc.scanning_codes".localized)
                                .foregroundColor(.white)
                            Text("dtc.reading_modules".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)
                    } else if currentDTCs.isEmpty && pendingDTCs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("diagnostics.no_dtcs_found".localized)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("dtc.no_active_or_pending".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            if let lastScan = lastScan {
                                Text("dtc.last_scan".localized + ": \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(16)
                    } else {
                        if !currentDTCs.isEmpty {
                            DTCListCard(title: "diagnostics.current_dtcs".localized, codes: currentDTCs, isActive: true)
                        }
                        if !pendingDTCs.isEmpty {
                            DTCListCard(title: "diagnostics.pending_dtcs".localized, codes: pendingDTCs, isActive: false)
                        }
                    }

                    // Base de datos
                    DTCDatabaseCard()
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("tabs.dtcs".localized)
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
                        Text("dtc.severity".localized + ":")
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
                        Text("dtc.possible_causes".localized + ":")
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
                        Text("dtc.symptoms".localized + ":")
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
                        Text("dtc.solutions".localized + ":")
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
                            Badge(text: "dtc.rotary_specific".localized, color: .orange)
                        }
                        if info.affectsApexSeals {
                            Badge(text: "dtc.affects_apex_seals".localized, color: .red)
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
                Text("dtc.database_rx8".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("dtc.database_description".localized)
                .font(.caption)
                .foregroundColor(.gray)

            Button(action: { showDatabase = true }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("dtc.search_code".localized)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.3))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }

            // Estadísticas
            HStack {
                DTCStatItem(value: "\(RX8DTCDatabase.allCodes.count)", label: "dtc.codes".localized)
                DTCStatItem(value: "\(RX8DTCDatabase.rotarySpecificCodes.count)", label: "dtc.rotary".localized)
                DTCStatItem(value: "\(RX8DTCDatabase.criticalCodes.count)", label: "dtc.critical".localized)
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
        case all
        case rotary
        case critical
        case apexSeals

        var displayName: String {
            switch self {
            case .all: return "dtc.filter_all".localized
            case .rotary: return "dtc.filter_rotary".localized
            case .critical: return "dtc.filter_critical".localized
            case .apexSeals: return "dtc.filter_apex_seals".localized
            }
        }
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
                                title: filter.displayName,
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
            .searchable(text: $searchText, prompt: "dtc.search_code_or_name".localized)
            .navigationTitle("dtc.rx8_codes".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close".localized) { dismiss() }
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
