import SwiftUI

struct ConnectionAlertView: View {
    let matchedUser: String
    var title: String = "SIGNAL MATCHED"
    var message: String = "A new signal has been detected nearby."
    var confirmText: String = "CONNECT"
    let onAccept: () -> Void
    let onIgnore: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.neonGreen)
                }
                .padding(.top, 10)
                
                // Text
                VStack(spacing: 8) {
                    Text(title)
                        .font(.radarHeadline)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.radarBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Matched User Info (Abstract)
                HStack {
                    Circle()
                        .fill(Color.mysteryViolet)
                        .frame(width: 40, height: 40)
                    
                    Text(matchedUser)
                        .font(.radarBody)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Actions
                HStack(spacing: 15) {
                    Button(action: onIgnore) {
                        Text("IGNORE")
                            .font(.radarBody)
                            .fontWeight(.bold)
                            .foregroundColor(.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    NeonButton(title: confirmText, action: onAccept)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .glassmorphism(cornerRadius: 24)
            .padding(30)
        }
    }
}
