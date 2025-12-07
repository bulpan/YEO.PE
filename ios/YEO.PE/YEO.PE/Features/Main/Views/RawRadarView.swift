import SwiftUI

struct RawRadarView: View {
    let peripherals: [UUID: BLEManager.RawPeripheral]
    let filter: BLEManager.DeviceType? // nil = All
    
    var body: some View {
        ZStack {
            // Radar Circles (Static Background)
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .scaleEffect(CGFloat(i + 1) / 3.0)
            }
            
            // Device Points
            ForEach(Array(peripherals.values)) { peripheral in
                if filter == nil || peripheral.deviceType == filter {
                    let distance = calculateDistance(rssi: peripheral.rssi)
                    let angle = Double(peripheral.id.hashValue) // Random but consistent angle
                    
                    // Convert polar to cartesian
                    // Max distance ~20m mapped to radius 150
                    let radius = min(CGFloat(distance) * 10, 150)
                    let x = radius * cos(angle)
                    let y = radius * sin(angle)
                    
                    VStack(spacing: 2) {
                        Circle()
                            .fill(colorForDeviceType(peripheral.deviceType))
                            .frame(width: 6, height: 6)
                            .shadow(color: colorForDeviceType(peripheral.deviceType).opacity(0.5), radius: 3)
                        
                        Text(peripheral.name.prefix(10))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .offset(x: x, y: y)
                    .animation(.spring(), value: peripheral.rssi)
                }
            }
            
            // Device Counter (Bottom Left)
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RAW DEVICES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(peripherals.filter { filter == nil || $0.value.deviceType == filter }.count)")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func colorForDeviceType(_ type: BLEManager.DeviceType) -> Color {
        switch type {
        case .ios: return .gray
        case .android: return .green
        case .other: return .blue.opacity(0.7)
        }
    }
    
    // Rough approximation of distance from RSSI
    private func calculateDistance(rssi: Int) -> Double {
        // Simple path loss model: RSSI = TxPower - 10 * n * log10(d)
        // Assuming TxPower = -59, n = 2.0
        let txPower = -59.0
        if rssi == 0 {
            return -1.0 // Unknown
        }
        
        let ratio = Double(rssi) * 1.0 / txPower
        if ratio < 1.0 {
            return pow(ratio, 10)
        } else {
            return (0.89976) * pow(ratio, 7.7095) + 0.111
        }
    }
}
