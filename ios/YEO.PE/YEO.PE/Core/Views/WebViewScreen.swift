import SwiftUI
import WebKit

struct GenericWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct WebViewScreen: View {
    let urlString: String
    let title: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.deepBlack.edgesIgnoringSafeArea(.all)
                
                if let url = URL(string: urlString) {
                    GenericWebView(url: url)
                } else {
                    Text("Invalid URL")
                        .foregroundColor(.white)
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.neonGreen)
            })
        }
    }
}
