import SwiftUI

// MARK: - Color Palette
extension Color {
    /// The Void: Deep Charcoal/Black background
    static let deepBlack = Color(hex: "050505")
    
    /// Primary Signal: Neon Green for active signals and connections
    static let neonGreen = Color(hex: "00FF94")
    
    /// Secondary Mystery: Violet for anonymous/unknown elements
    static let mysteryViolet = Color(hex: "7000FF")
    
    /// Error/Expire: Red for warnings and expiration
    static let signalRed = Color(hex: "FF3B30")
    
    /// Chatting: Light Blue for existing connection
    static let lightBlue = Color(hex: "5AC8FA")
    
    /// Glassmorphism Background (Dark)
    static let glassBlack = Color.black.opacity(0.6)
    
    /// Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
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
    init(hex: String) {
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
