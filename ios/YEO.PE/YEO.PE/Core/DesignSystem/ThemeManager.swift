import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    
    private init() {}
    
    var background: Color {
        isDarkMode ? Color.deepBlack : Color(hex: "F2F2F7") // Light Gray
    }
    
    var highlight: Color {
        isDarkMode ? Color.neonGreen : Color(hex: "1C1C1E") // Dark Gray
    }
    
    var text: Color {
        isDarkMode ? .white : .black
    }
}
