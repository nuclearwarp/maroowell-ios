import Foundation

struct WebSessionBridgePolicy {
    static let supabaseStorageKey = "sb-rgqerimdxkthkcewqbbe-auth-token"

    static func trustedURL(path raw: String) -> URL? {
        guard var components = URLComponents(string: "https://maroowell.com") else { return nil }
        let pieces = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = pieces.first.map(String.init) ?? "/"
        guard path.hasPrefix("/"), !path.contains("..") else { return nil }
        components.path = path
        if pieces.count == 2 { components.percentEncodedQuery = String(pieces[1]) }
        return components.url
    }

    static func isTrusted(host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "maroowell.com" || host.hasSuffix(".maroowell.com")
    }

    static func bridgeJavaScript(payload: String) -> String {
        let quotedPayload = jsQuoted(payload)
        let quotedKey = jsQuoted(supabaseStorageKey)
        return """
        (function() {
          try {
            const raw = \(quotedPayload);
            const key = \(quotedKey);
            localStorage.setItem(key, raw);
            sessionStorage.setItem(key, raw);
            window.dispatchEvent(new StorageEvent('storage', { key: key, newValue: raw }));
            document.dispatchEvent(new CustomEvent('maroowell-auth-ready'));
          } catch (_) {}
        })();
        """
    }

    static func chromeJavaScript() -> String {
        """
        (function() {
          function tune() {
            try {
              const path = (location.pathname.endsWith('/') ? location.pathname.slice(0, -1) : location.pathname) || '/';
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
    }

    static func jsQuoted(_ raw: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [raw], options: []),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }
}
