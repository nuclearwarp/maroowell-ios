import SwiftUI
import WebKit
import Supabase

struct MaroowellWebView: View {
    let title: String
    let path: String

    @State private var bridgePayload: String?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let bridgePayload {
                MaroowellWKWebView(path: path, bridgePayload: bridgePayload)
            } else if let loadError {
                ContentUnavailableView(
                    "페이지를 준비하지 못했습니다",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(loadError)
                )
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("마루웰 페이지를 준비하는 중…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MaroowellTheme.muted)
                }
            }
        }
        .background(MaroowellTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: path) {
            await prepareBridgePayload()
        }
    }

    @MainActor
    private func prepareBridgePayload() async {
        loadError = nil
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let user: [String: Any] = [
                "id": session.user.id.uuidString,
                "email": session.user.email ?? "",
                "aud": session.user.aud
            ]
            let payload: [String: Any] = [
                "access_token": session.accessToken,
                "refresh_token": session.refreshToken,
                "expires_at": session.expiresAt,
                "expires_in": session.expiresIn,
                "token_type": session.tokenType,
                "user": user
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            bridgePayload = String(decoding: data, as: UTF8.self)
        } catch {
            loadError = "로그인 세션을 확인한 뒤 다시 시도해주세요."
        }
    }
}

private struct MaroowellWKWebView: UIViewRepresentable {
    let path: String
    let bridgePayload: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let storageKey = "sb-rgqerimdxkthkcewqbbe-auth-token"
        let quotedPayload = Self.jsQuoted(bridgePayload)
        let quotedKey = Self.jsQuoted(storageKey)
        let bridgeScript = """
        (function() {
          try {
            const raw = \(quotedPayload);
            const key = \(quotedKey);
            localStorage.setItem(key, raw);
            sessionStorage.setItem(key, raw);
          } catch (_) {}
        })();
        """
        configuration.userContentController.addUserScript(
            WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        let chromeScript = """
        (function() {
          function tune() {
            try {
              const path = location.pathname.replace(/\/$/, '') || '/';
              let css = '';
              if (path === '/zipcode_search') css += 'header .brand,header .titleGroup{display:none!important}header{min-height:44px!important;height:auto!important;padding:6px 10px!important}';
              if (path === '/coupangRouteMap.html') css += '.title>a,.titleText{display:none!important}';
              if (path === '/coupang_camp') css += '.topbar .logo,.topbar .titleText,#btnMap{display:none!important}.topbar{min-height:48px!important}';
              if (path === '/coupang_camp_map') css += '.top .logo,.top .title{display:none!important}.app{grid-template-rows:48px 1fr!important}';
              if (path === '/coupang_freshbag') css += '.top .brand{display:none!important}';
              if (path === '/cleansing_history') css += '.top .logo,.top .title{display:none!important}';
              let style = document.getElementById('mw-ios-embed-style');
              if (!style) { style = document.createElement('style'); style.id = 'mw-ios-embed-style'; document.head.appendChild(style); }
              style.textContent = css;
            } catch (_) {}
          }
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', tune); else tune();
        })();
        """
        configuration.userContentController.addUserScript(
            WKUserScript(source: chromeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        context.coordinator.load(path: path, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedPath != path else { return }
        context.coordinator.load(path: path, in: webView)
    }

    private static func jsQuoted(_ raw: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [raw], options: []),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedPath: String?

        func load(path: String, in webView: WKWebView) {
            guard let url = trustedURL(path: path) else { return }
            loadedPath = path
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["tel", "mailto"].contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            guard scheme == "https" else {
                decisionHandler(.cancel)
                return
            }
            guard Self.isTrusted(host: url.host) else {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        private func trustedURL(path raw: String) -> URL? {
            guard var components = URLComponents(string: "https://maroowell.com") else { return nil }
            let pieces = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            let path = pieces.first.map(String.init) ?? "/"
            guard path.hasPrefix("/") else { return nil }
            components.path = path
            if pieces.count == 2 { components.percentEncodedQuery = String(pieces[1]) }
            return components.url
        }

        private static func isTrusted(host: String?) -> Bool {
            guard let normalized = host?.lowercased() else { return false }
            return normalized == "maroowell.com" || normalized.hasSuffix(".maroowell.com")
        }
    }
}
