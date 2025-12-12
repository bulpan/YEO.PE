import SwiftUI

struct OpenSourceLibrary: Identifiable {
    let id = UUID()
    let name: String
    let licenseType: String
    let url: String
    let description: String
}

struct OpenSourceListView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let libraries = [
        OpenSourceLibrary(
            name: "Socket.IO-Client-Swift",
            licenseType: "MIT License",
            url: "https://github.com/socketio/socket.io-client-swift",
            description: "Socket.IO client for iOS/OS X."
        ),
        OpenSourceLibrary(
            name: "Firebase iOS SDK",
            licenseType: "Apache License 2.0",
            url: "https://github.com/firebase/firebase-ios-sdk",
            description: "Firebase is an app development platform with tools to help you build, improve and grow your app."
        ),
        OpenSourceLibrary(
            name: "Starscream",
            licenseType: "Apache License 2.0",
            url: "https://github.com/daltoniam/Starscream",
            description: "Websockets in swift for iOS and OSX."
        ),
        OpenSourceLibrary(
            name: "SnapKit",
            licenseType: "MIT License",
            url: "https://github.com/SnapKit/SnapKit",
            description: "A Swift Autolayout DSL for iOS & OS X."
        )
    ]
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Custom Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme.accentPrimary)
                    }
                    Spacer()
                    Text("open_source_license".localized)
                        .font(.headline)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    // Dummy spacer for balance
                    Image(systemName: "arrow.left").opacity(0)
                        .font(.system(size: 20))
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(libraries) { lib in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(lib.name)
                                        .font(.headline)
                                        .foregroundColor(Color.theme.textPrimary)
                                    Spacer()
                                    Text(lib.licenseType)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.theme.accentPrimary.opacity(0.1))
                                        .foregroundColor(Color.theme.accentPrimary)
                                        .cornerRadius(4)
                                }
                                
                                Text(lib.description)
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(lib.url)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .underline()
                                    .onTapGesture {
                                        if let url = URL(string: lib.url) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                            }
                            .padding()
                            .background(Color.theme.bgLayer1)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.borderPrimary, lineWidth: 0.5)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
