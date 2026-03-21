import SwiftUI
import WebKit
import UniformTypeIdentifiers

// 1. 커스텀 스킴 핸들러: 'app://' 요청을 가로채서 로컬 파일을 전달
class LocalAssetHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        
        // 경로 파악 (기본값 index.app.html)
        var path = url.path
        if path.isEmpty || path == "/" {
            path = "/index.app.html"
        }
        
        // browser 폴더 내 실제 파일 경로 찾기
        let fileName = String(path.dropFirst()) // 앞의 "/" 제거
        guard let fileURL = Bundle.main.url(forResource: "browser/\(fileName)", withExtension: nil) else {
            return
        }
        
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

// 2. SwiftUI WebView Wrapper
struct WebView: UIViewRepresentable {
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logger" {
                print("🌐 JS Log: \(message.body)")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // ✅ 커스텀 핸들러 등록
        config.setURLSchemeHandler(LocalAssetHandler(), forURLScheme: "app")
        
        // JS 로그 브릿지 등록
        config.userContentController.add(context.coordinator, name: "logger")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // ✅ 이제 file:// 이 아닌 커스텀 주소로 접속합니다.
        if let url = URL(string: "app://localhost/index.app.html") {
            uiView.load(URLRequest(url: url))
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
    ContentView()
}
