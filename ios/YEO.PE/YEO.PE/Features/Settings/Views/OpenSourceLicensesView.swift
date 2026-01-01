import SwiftUI

struct OpenSourceLicensesView: View {
    @Environment(\.presentationMode) var presentationMode
    
    struct License: Identifiable {
        let id = UUID()
        let name: String
        let url: String
        let copyright: String
    }
    
    let licenses: [License] = [
        License(name: "KakaoSDK", url: "https://developers.kakao.com", copyright: "Copyright © Kakao Corp. All rights reserved."),
        License(name: "Socket.IO-Client-Swift", url: "https://github.com/socketio/socket.io-client-swift", copyright: "Copyright (c) 2014-2015 Erik Little"),
        License(name: "Alamofire", url: "https://github.com/Alamofire/Alamofire", copyright: "Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)"),
        License(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit", copyright: "Copyright (c) 2011-Present SnapKit Team - https://snapkit.io"),
        License(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher", copyright: "Copyright (c) 2019 Wei Wang")
    ]
    
    var body: some View {
        ZStack {
            Color.theme.bgMain.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme.textPrimary)
                    }
                    Spacer()
                    Text("open_source_licenses".localized)
                        .font(.headline)
                        .foregroundColor(Color.theme.textPrimary)
                    Spacer()
                    Spacer().frame(width: 20)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(licenses) { license in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(license.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.theme.textPrimary)
                                
                                Text(license.copyright)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    if let url = URL(string: license.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text(license.url)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.theme.bgLayer1)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
