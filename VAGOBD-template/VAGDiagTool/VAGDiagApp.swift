import SwiftUI

@main
struct VAGDiagApp: App {

    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var engineData = EngineData.shared
    @StateObject private var diagnosticService = DiagnosticService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .environmentObject(engineData)
                .environmentObject(diagnosticService)
        }
    }
}

// MARK: - Connection Manager
@MainActor
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var useSimulator = false

    private let connection = OBDConnection.shared
    private let virtualAdapter = VirtualOBDAdapter.shared

    func connect() async {
        isConnecting = true
        connectionError = nil

        do {
            if useSimulator {
                await virtualAdapter.connect()
                isConnected = true
            } else {
                try await DiagnosticService.shared.connect()
                isConnected = true
            }
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }

        isConnecting = false
    }

    func disconnect() {
        if useSimulator {
            virtualAdapter.disconnect()
        } else {
            connection.disconnect()
        }
        isConnected = false
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DiagnosticView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)

            DTCView()
                .tabItem {
                    Label("Códigos", systemImage: "exclamationmark.triangle")
                }
                .tag(1)

            FuelConsumptionView()
                .tabItem {
                    Label("Consumo", systemImage: "fuelpump")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(ConnectionManager())
        .environmentObject(EngineData.shared)
        .environmentObject(DiagnosticService.shared)
}
