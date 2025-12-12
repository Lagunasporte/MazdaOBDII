import SwiftUI

struct DTCView: View {
    @EnvironmentObject var diagnosticService: DiagnosticService
    @EnvironmentObject var connectionManager: ConnectionManager

    @State private var selectedDTC: VAGDTCCode?
    @State private var showClearConfirmation = false
    @State private var searchText = ""

    var filteredActiveDTCs: [VAGDTCCode] {
        if searchText.isEmpty {
            return diagnosticService.activeDTCs
        }
        return diagnosticService.activeDTCs.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredPendingDTCs: [VAGDTCCode] {
        if searchText.isEmpty {
            return diagnosticService.pendingDTCs
        }
        return diagnosticService.pendingDTCs.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredStoredDTCs: [VAGDTCCode] {
        if searchText.isEmpty {
            return diagnosticService.storedDTCs
        }
        return diagnosticService.storedDTCs.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if !connectionManager.isConnected {
                    NotConnectedView()
                } else {
                    List {
                        // Scan Button Section
                        Section {
                            Button(action: {
                                Task {
                                    try? await diagnosticService.readAllDTCs()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Escanear códigos")
                                    Spacer()
                                    if diagnosticService.isScanning {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(diagnosticService.isScanning)
                        }

                        // Active DTCs
                        if !filteredActiveDTCs.isEmpty {
                            Section(header: DTCSectionHeader(title: "Códigos Activos", count: filteredActiveDTCs.count, color: .red)) {
                                ForEach(filteredActiveDTCs) { dtc in
                                    DTCRow(dtc: dtc)
                                        .onTapGesture {
                                            selectedDTC = dtc
                                        }
                                }
                            }
                        }

                        // Pending DTCs
                        if !filteredPendingDTCs.isEmpty {
                            Section(header: DTCSectionHeader(title: "Códigos Pendientes", count: filteredPendingDTCs.count, color: .orange)) {
                                ForEach(filteredPendingDTCs) { dtc in
                                    DTCRow(dtc: dtc)
                                        .onTapGesture {
                                            selectedDTC = dtc
                                        }
                                }
                            }
                        }

                        // Stored DTCs
                        if !filteredStoredDTCs.isEmpty {
                            Section(header: DTCSectionHeader(title: "Códigos Almacenados", count: filteredStoredDTCs.count, color: .gray)) {
                                ForEach(filteredStoredDTCs) { dtc in
                                    DTCRow(dtc: dtc)
                                        .onTapGesture {
                                            selectedDTC = dtc
                                        }
                                }
                            }
                        }

                        // No DTCs
                        if diagnosticService.activeDTCs.isEmpty &&
                           diagnosticService.pendingDTCs.isEmpty &&
                           diagnosticService.storedDTCs.isEmpty &&
                           diagnosticService.lastScanDate != nil {
                            Section {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title)
                                    VStack(alignment: .leading) {
                                        Text("Sin códigos de error")
                                            .font(.headline)
                                        if let lastScan = diagnosticService.lastScanDate {
                                            Text("Último escaneo: \(lastScan.formatted())")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }

                        // Clear DTCs Button
                        if !diagnosticService.activeDTCs.isEmpty || !diagnosticService.pendingDTCs.isEmpty {
                            Section {
                                Button(action: {
                                    showClearConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Borrar códigos")
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar código")
                }
            }
            .navigationTitle("Códigos DTC")
            .sheet(item: $selectedDTC) { dtc in
                DTCDetailView(dtc: dtc)
            }
            .alert("Borrar códigos", isPresented: $showClearConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar", role: .destructive) {
                    Task {
                        try? await diagnosticService.clearDTCs()
                    }
                }
            } message: {
                Text("¿Estás seguro de que quieres borrar todos los códigos de error? Esta acción no se puede deshacer.")
            }
        }
    }
}

// MARK: - Not Connected View
struct NotConnectedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plug.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No conectado")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Conecta el adaptador OBD2 para escanear códigos de error")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - DTC Section Header
struct DTCSectionHeader: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(8)
        }
    }
}

// MARK: - DTC Row
struct DTCRow: View {
    let dtc: VAGDTCCode

    var severityColor: Color {
        switch dtc.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(severityColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(dtc.code)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(dtc.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(dtc.category.rawValue, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(dtc.severity.rawValue, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(severityColor)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DTC Detail View
struct DTCDetailView: View {
    let dtc: VAGDTCCode
    @Environment(\.dismiss) var dismiss

    var severityColor: Color {
        switch dtc.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(dtc.code)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(dtc.description)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Label(dtc.category.rawValue, systemImage: "folder")
                            Label(dtc.severity.rawValue, systemImage: "exclamationmark.triangle")
                                .foregroundColor(severityColor)
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Possible Causes
                    if !dtc.possibleCauses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Posibles causas", systemImage: "questionmark.circle")
                                .font(.headline)

                            ForEach(dtc.possibleCauses, id: \.self) { cause in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .padding(.top, 6)
                                    Text(cause)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Solutions
                    if !dtc.solutions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Soluciones sugeridas", systemImage: "wrench.and.screwdriver")
                                .font(.headline)

                            ForEach(Array(dtc.solutions.enumerated()), id: \.offset) { index, solution in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.bold)
                                        .frame(width: 24)
                                    Text(solution)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Search Online
                    Link(destination: URL(string: "https://www.google.com/search?q=\(dtc.code)+VAG+\(dtc.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Buscar más información online")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Detalle del código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DTCView()
        .environmentObject(DiagnosticService.shared)
        .environmentObject(ConnectionManager())
}
