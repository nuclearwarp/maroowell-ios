import CoreGraphics
import CoreText
import ImageIO
import SwiftUI
import UIKit

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

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.backgroundColor = .clear
        imageView.image = Self.animatedGIF(named: resourceName)
        imageView.startAnimating()
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image == nil {
            uiView.image = Self.animatedGIF(named: resourceName)
        }
        if !uiView.isAnimating {
            uiView.startAnimating()
        }
    }

    private static func animatedGIF(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        frames.reserveCapacity(count)
        var duration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))

            var delay: TimeInterval = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
               let gif = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                let clamped = gif[kCGImagePropertyGIFDelayTime as String] as? Double
                delay = unclamped ?? clamped ?? 0.1
            }
            duration += max(delay, 0.02)
        }

        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0] }
        return UIImage.animatedImage(with: frames, duration: max(duration, 0.1))
    }
}
