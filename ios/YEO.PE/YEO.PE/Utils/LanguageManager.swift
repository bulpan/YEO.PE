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
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj") {
            bundle = Bundle(path: path)
        } else {
            bundle = Bundle.main
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
