import UIKit
import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // Convenience methods
    func success() { notification(type: .success) }
    func warning() { notification(type: .warning) }
    func error() { notification(type: .error) }
    
    func light() { impact(style: .light) }
    func medium() { impact(style: .medium) }
    func heavy() { impact(style: .heavy) }
    func soft() { impact(style: .soft) }
    func rigid() { impact(style: .rigid) }
}
