import Foundation
import SwiftUI
import Combine

enum Language: String, CaseIterable {
    case english = "en"
    case korean = "ko"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
        }
    }
    
    private var bundle: Bundle?
    
    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Default to system language if supported, else English
            let systemLanguage = Locale.current.languageCode
            if systemLanguage == "ko" {
                self.currentLanguage = .korean
            } else {
                self.currentLanguage = .english
            }
        }
        updateBundle()
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        updateBundle()
    }
    
    private func updateBundle() {
        let lang = currentLanguage.rawValue
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj") {
            bundle = Bundle(path: path)
        } else if let path = Bundle.main.path(forResource: lang, ofType: "lproj", inDirectory: "Resources") {
            bundle = Bundle(path: path)
        } else {
            // Fallback: Try to force load main bundle, but this follows system locale
            bundle = Bundle.main
            print("LanguageManager: Failed to load bundle for \(lang). Falling back to system.")
        }
    }
    
    func localizedString(_ key: String) -> String {
        return bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }
}

// String extension for easier usage
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }
}
