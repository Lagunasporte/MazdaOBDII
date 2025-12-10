import Foundation

// MARK: - String Extension for Localization

extension String {
    /// Returns the localized string using the current bundle settings
    /// Works with the app's LocalizationManager language preferences
    var localized: String {
        // Use a simple approach that works from any context
        // This uses the standard NSLocalizedString which respects the app's bundle settings
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        let languageCode: String

        if savedLanguage == "system" {
            languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            languageCode = savedLanguage
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        }

        return NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
