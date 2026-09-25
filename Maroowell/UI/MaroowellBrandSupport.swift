import CoreGraphics
import CoreText
import SwiftUI
import UIKit
import WebKit

enum MaroowellBrandFont {
    private static let postScriptName: String? = {
        guard let url = Bundle.main.url(forResource: "mungyeong_gamhong", withExtension: "ttf") else {
            return nil
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider),
              let name = font.postScriptName else {
            return nil
        }
        return name as String
    }()

    static func font(size: CGFloat) -> Font {
        guard let postScriptName else {
            return .system(size: size, weight: .black, design: .rounded)
        }
        return .custom(postScriptName, size: size)
    }
}

struct MaroowellLoadingGIFView: UIViewRepresentable {
    let resourceName: String

    init(resourceName: String = "maroowell_login_loading4") {
        self.resourceName = resourceName
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false

        loadGIF(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            loadGIF(into: webView)
        }
    }

    private func loadGIF(into webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "gif"),
              let data = try? Data(contentsOf: url) else {
            return
        }

        let base64 = data.base64EncodedString()
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: #FFFFFF;
            }
            body {
              display: flex;
              align-items: center;
              justify-content: center;
            }
            img {
              display: block;
              width: 100vw;
              height: 100vh;
              object-fit: contain;
              object-position: center center;
            }
          </style>
        </head>
        <body>
          <img src="data:image/gif;base64,\(base64)" alt="">
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
