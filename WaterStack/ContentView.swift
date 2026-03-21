import SwiftUI
import WebKit
import UniformTypeIdentifiers

// 1. 커스텀 스킴 핸들러 (기존 코드 유지)
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
        case "svg":  return "image/svg+xml"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "woff", "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}

// 2. WebView Wrapper (기존 코드 유지)
struct WebView: UIViewRepresentable {
    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logger" { print("🌐 JS Log: \(message.body)") }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalAssetHandler(), forURLScheme: "app")
        config.userContentController.add(context.coordinator, name: "logger")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        webView.allowsBackForwardNavigationGestures = true
        
        // 초기 로드 시점 조절을 위해 여기서 로드할 수도 있습니다.
        if let url = URL(string: "app://localhost/index.app.html") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// 3. 통합된 메인 뷰 (스플래시 로직 추가)
struct MainEntryView: View {
    @State private var isSplashScreenActive = true
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.7

    var body: some View {
        ZStack {
            if isSplashScreenActive {
                // --- 스플래시 화면 ---
                Color.white // 배경색 설정
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "safari.fill") // 앱 로고 이미지로 교체하세요
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                    
                    Text("My Web App")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    // 등장 애니메이션
                    withAnimation(.easeOut(duration: 1.0)) {
                        self.logoOpacity = 1.0
                        self.logoScale = 1.0
                    }
                    
                    // 2.5초 후 메인 WebView로 전환
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.isSplashScreenActive = false
                        }
                    }
                }
            } else {
                // --- 실제 웹뷰 화면 ---
                ContentView()
                    .transition(.opacity) // 부드러운 화면 교체 효과
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebView()
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    MainEntryView()
}
