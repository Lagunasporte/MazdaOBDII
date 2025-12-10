import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    @State private var showRestartAlert = false

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    LanguageRow(
                        language: language,
                        isSelected: localizationManager.currentLanguage == language
                    ) {
                        if localizationManager.currentLanguage != language {
                            localizationManager.currentLanguage = language
                            showRestartAlert = true
                        }
                    }
                }
            } header: {
                Text("settings.language".localized)
            } footer: {
                Text("language.restart_note".localized)
                    .font(.caption)
            }
        }
        .navigationTitle("settings.language".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("language.restart_title".localized, isPresented: $showRestartAlert) {
            Button("common.ok".localized) {
                dismiss()
            }
        } message: {
            Text("language.restart_message".localized)
        }
    }
}

struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .foregroundColor(.primary)

                    if language != .system {
                        Text(nativeLanguageName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nativeLanguageName: String {
        switch language {
        case .system: return ""
        case .english: return "English"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .chinese: return "简体中文"
        }
    }
}

// MARK: - Compact Language Picker for Settings

struct LanguagePicker: View {
    @EnvironmentObject var localizationManager: LocalizationManager

    var body: some View {
        NavigationLink {
            LanguageSelectionView()
        } label: {
            HStack {
                Label("settings.language".localized, systemImage: "globe")

                Spacer()

                Text(localizationManager.currentLanguage.flag)
                Text(localizationManager.currentLanguage.displayName)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
    .environmentObject(LocalizationManager.shared)
}
