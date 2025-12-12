import SwiftUI

// MARK: - Theme Accessor
extension Color {
    static let theme = YeoPeColors()
}

// MARK: - Semantic Color Definitions
struct YeoPeColors {
    // MARK: Backgrounds
    var bgMain: Color {
        ThemeManager.shared.isDarkMode ? Color(radarHex: "050505") : Color(radarHex: "F2F2F7")
    }
    
    var bgLayer1: Color {
        ThemeManager.shared.isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
    }
    
    var bgLayer2: Color {
        ThemeManager.shared.isDarkMode ? Color(radarHex: "1C1C1E") : Color.white
    }
    
    // MARK: Text
    var textPrimary: Color {
        ThemeManager.shared.isDarkMode ? .white : .black
    }
    
    var textSecondary: Color {
        ThemeManager.shared.isDarkMode ? Color(radarHex: "8E8E93") : Color(radarHex: "636366")
    }
    
    // MARK: Accents
    var accentPrimary: Color {
        // Dark: Neon Green, Light: Dark Charcoal
        ThemeManager.shared.isDarkMode ? Color(radarHex: "00FF94") : Color(radarHex: "1C1C1E")
    }
    
    var accentSecondary: Color {
        // Dark: Violet, Light: Deep Purple
        ThemeManager.shared.isDarkMode ? Color(radarHex: "7000FF") : Color(radarHex: "5856D6")
    }
    
    var signalRed: Color {
        Color(radarHex: "FF3B30")
    }
    
    var signalBlue: Color {
        ThemeManager.shared.isDarkMode ? Color(radarHex: "5AC8FA") : Color(radarHex: "007AFF")
    }
    
    // MARK: Borders/Dividers
    var borderPrimary: Color {
        ThemeManager.shared.isDarkMode ? Color(radarHex: "00FF94").opacity(0.3) : Color(radarHex: "1C1C1E").opacity(0.2)
    }
    
    var borderSubtle: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    // MARK: Raw Colors (Legacy/Specific)
    var neonGreenRaw: Color { Color(radarHex: "00FF94") }
    var deepBlackRaw: Color { Color(radarHex: "050505") }
}

// MARK: - Legacy Compatibility (Deprecating slowly)
extension Color {
    static var deepBlack: Color { Color.theme.bgMain }
    static var neonGreen: Color { Color.theme.accentPrimary }
    static var mysteryViolet: Color { Color.theme.accentSecondary }
    static var glassBlack: Color { Color.theme.bgLayer1 }
    static var signalRed: Color { Color.theme.signalRed }
    static var lightBlue: Color { Color.theme.signalBlue }
    static var textPrimary: Color { Color.theme.textPrimary }
    static var textSecondary: Color { Color.theme.textSecondary }
    static var structuralGray: Color { Color.theme.borderPrimary }
}

// MARK: - Typography
extension Font {
    static let radarHeadline = Font.system(size: 28, weight: .black, design: .default)
    static let radarBody = Font.system(size: 16, weight: .regular, design: .default)
    static let radarData = Font.system(size: 14, weight: .medium, design: .monospaced)
    static let radarCaption = Font.system(size: 12, weight: .light, design: .default)
}

// MARK: - Hex Color Helper
extension Color {
    init(radarHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
