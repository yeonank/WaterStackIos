import SwiftUI
import WebKit

// 1. WKWebView를 SwiftUI에서 사용하기 위한 Wrapper
struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true // 자바스크립트 허용
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        // 로컬 파일에서 다른 로컬 파일(JS 모듈 등)을 읽어오는 보안 정책을 완화
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        // 이 코드가 있어야 사파리 개발자 도구에 나타납니다.
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 'browser'라는 이름의 파란색 폴더 내의 index.html 경로 찾기
        guard let folderPath = Bundle.main.resourcePath?.appending("/browser") else {
            print("Error: browser 폴더를 찾을 수 없습니다.")
            return
        }
        
        let folderURL = URL(fileURLWithPath: folderPath)
        let fileURL = folderURL.appendingPathComponent("index.html")
        
        // 앵귤러는 index.html 외에 같은 폴더 내의 JS/CSS를 읽어야 하므로
        // allowingReadAccessTo에 폴더 전체 경로를 줍니다.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            uiView.loadFileURL(fileURL, allowingReadAccessTo: folderURL)
        } else {
            print("Error: index.html 파일이 폴더 안에 없습니다.")
        }
    }
}

struct ContentView: View {
    var body: some View {
        // 기존 VStack 대신 WebView를 화면 전체에 꽉 차게 배치합니다.
        WebView()
            .edgesIgnoringSafeArea(.all) // 상태바까지 꽉 채우고 싶을 때 사용
    }
}

#Preview {
    ContentView()
}
