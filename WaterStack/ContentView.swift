import SwiftUI
import WebKit

// 1. 커스텀 스킴 핸들러 (기존 동일)
class LocalAssetHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.app.html" }
        
        let fileName = String(path.dropFirst())
        guard let fileURL = Bundle.main.url(forResource: "browser/\(fileName)", withExtension: nil) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = getMimeType(for: fileURL)
            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: "utf-8")
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            print("❌ 파일 로드 실패: \(fileName)")
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
    
    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "html": return "text/html"
        case "js":   return "application/javascript"
        case "css":  return "text/css"
        default: return "application/octet-stream"
        }
    }
}

// 2. WebView Wrapper (수정됨)
struct WebView: UIViewRepresentable {
    // 🔥 추가: 스플래시 화면을 끌 수 있도록 바인딩 변수 추가
    @Binding var isSplashScreenActive: Bool

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logger" {
                print("🌐 JS Log: \(message.body)")
            }
            // 🔥 추가: 'hideSplash' 메시지를 받으면 스플래시를 끔
            if message.name == "hideSplash" {
                print("hide splash!!")
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.parent.isSplashScreenActive = false
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalAssetHandler(), forURLScheme: "app")
        
        // 🔥 추가: 'hideSplash'라는 이름의 핸들러 등록
        config.userContentController.add(context.coordinator, name: "logger")
        config.userContentController.add(context.coordinator, name: "hideSplash")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        
        if let url = URL(string: "app://localhost/index.app.html") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// 3. 메인 뷰 (수정됨)
struct MainEntryView: View {
    @State private var isSplashScreenActive = true
    
    var body: some View {
        ZStack {
            // 실제 웹뷰를 먼저 밑에 깔아둡니다 (미리 로딩 시작)
            // 🔥 변경: ContentView에 바인딩 전달
            ContentView(isSplashScreenActive: $isSplashScreenActive)
            
            if isSplashScreenActive {
                // --- 스플래시 화면 (위에 덮음) ---
                Color.white.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "safari.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                    Text("Loading Angular...")
                }
                .transition(.opacity) // 사라질 때 효과
            }
        }
    }
}

struct ContentView: View {
    @Binding var isSplashScreenActive: Bool
    
    var body: some View {
        // 🔥 변경: WebView에 바인딩 전달
        WebView(isSplashScreenActive: $isSplashScreenActive)
            .edgesIgnoringSafeArea(.all)
    }
}
