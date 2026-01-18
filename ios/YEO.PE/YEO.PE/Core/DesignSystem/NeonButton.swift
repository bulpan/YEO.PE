import SwiftUI

struct NeonButton: View {
    let title: String
    let action: () -> Void
    var color: Color = .neonGreen
    var textColor: Color = .black
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.radarBody)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(12)
                .shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        }
    }
}
