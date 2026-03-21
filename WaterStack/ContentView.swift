import SwiftUI
import WebKit

// MARK: - 1. 커스텀 스킴 핸들러 (기존 동일)
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

// MARK: - 2. WebView Wrapper
struct WebView: UIViewRepresentable {
    @Binding var isSplashScreenActive: Bool

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "hideSplash" {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.6)) {
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
        config.userContentController.add(context.coordinator, name: "hideSplash")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        if let url = URL(string: "app://localhost/index.app.html") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 3. "Droplet Slam" 스플래시 뷰 (네모 로고 최적화)
struct DropletMergeSplashView: View {
    @State private var startAnimation = false
    @State private var logoSlammed = false
    @State private var showText = false
    
    let logoSize = CGSize(width: 240, height: 128)
    let dropletCount = 8
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 로고 및 물방울 컨테이너
                ZStack {
                    // 1. 떨어지는 물방울들
                    if !logoSlammed {
                        ForEach(0..<dropletCount, id: \.self) { i in
                            Circle()
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: CGFloat.random(in: 10...20), height: CGFloat.random(in: 20...35))
                                .offset(x: CGFloat.random(in: -100...100),
                                        y: startAnimation ? 0 : -600) // 위에서 아래로 낙하
                                .animation(
                                    .interpolatingSpring(stiffness: 50, damping: 15)
                                    .delay(Double(i) * 0.1),
                                    value: startAnimation
                                )
                        }
                    }
                    
                    // 2. 최종 네모 로고 아이콘
                    Image("LaunchImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize.width, height: logoSize.height)
                        .scaleEffect(logoSlammed ? 1.0 : 0.5)
                        .opacity(logoSlammed ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: logoSlammed)
                }
                .frame(height: 150)
                
                // 3. 텍스트 라벨
                VStack(spacing: 8) {
                    Text("WaterStack")
                        .font(.custom("Optima-Bold", size: 32))
                        .kerning(2)
                    Text("Smart Hydration")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray)
                }
                .offset(y: showText ? 0 : 20)
                .opacity(showText ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: showText)
            }
            .offset(y: -40)
        }
        .onAppear {
            runSequence()
        }
    }
    
    private func runSequence() {
        // 단계별 실행
        startAnimation = true // 물방울 낙하 시작
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            logoSlammed = true // 로고 쾅!
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            showText = true // 텍스트 등장
        }
    }
}

// MARK: - 4. 메인 진입점
struct MainEntryView: View {
    @State private var isSplashScreenActive = true
    
    var body: some View {
        ZStack {
            WebView(isSplashScreenActive: $isSplashScreenActive)
                .ignoresSafeArea(.container, edges: [.bottom])
            
            if isSplashScreenActive {
                DropletMergeSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}
