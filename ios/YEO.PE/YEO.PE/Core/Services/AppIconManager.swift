import SwiftUI
import UIKit
import Combine
import Foundation

enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "Primary"
    case dark = "AppIconDark"
    case neon = "AppIconNeon"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .primary: return "Default"
        case .dark: return "Deep Dark"
        case .neon: return "Neon Green"
        }
    }
    
    // Preview Image Name (Assumes assets with these names exist in Assets.xcassets for preview)
    // Note: The actual alternate icon files must be added to the project root/group and Info.plist, NOT just Assets.xcassets.
    var previewImageName: String {
        switch self {
        case .primary: return "AppIconPreview" // Placeholder name
        case .dark: return "AppIconDarkPreview"
        case .neon: return "AppIconNeonPreview"
        }
    }
}

class AppIconManager: ObservableObject {
    static let shared = AppIconManager()
    
    @Published var currentIcon: AppIcon = .primary
    
    init() {
        if let name = UIApplication.shared.alternateIconName {
            currentIcon = AppIcon(rawValue: name) ?? .primary
        } else {
            currentIcon = .primary
        }
    }
    
    func changeIcon(to icon: AppIcon) {
        let iconName: String? = (icon == .primary) ? nil : icon.rawValue
        
        // Avoid redundant calls
        guard icon != currentIcon else { return }
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("❌ Failed to change app icon: \(error.localizedDescription)")
            } else {
                print("✅ App icon changed to \(icon.rawValue)")
                DispatchQueue.main.async {
                    self.currentIcon = icon
                }
            }
        }
    }
}
