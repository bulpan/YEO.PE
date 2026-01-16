import SwiftUI
import WebKit

struct GenericWebView: UIViewRepresentable {
    let url: URL
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.isOpaque = true
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
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.background.edgesIgnoringSafeArea(.all)
                
                if let url = URL(string: urlString) {
                    GenericWebView(
                        url: url,
                        backgroundColor: themeManager.isDarkMode ? .black : .white
                    )
                } else {
                    Text("Invalid URL")
                        .foregroundColor(themeManager.text)
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(themeManager.highlight)
            })
        }
    }
}
