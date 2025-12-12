import SwiftUI
import CoreBluetooth

struct BluetoothPermissionView: View {
    var onRequest: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 20)
                
                // Title
                Text("enable_radar".localized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Description
                Text("enable_radar_description".localized)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                
                Spacer()
                
                // Button
                Button(action: onRequest) {
                    Text("allow_access".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
}

// Fallback localization strings in case they are missing

