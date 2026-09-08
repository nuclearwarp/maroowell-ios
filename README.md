# 마루웰 iOS

SwiftUI 기반 마루웰 iPhone 앱입니다.

- Bundle ID: `com.maroowell.app`
- Supabase project: `maroowell`
- iOS deployment target: 17.0
- Build project generated with XcodeGen

## Local build (macOS)

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Maroowell.xcodeproj -scheme Maroowell -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions에서도 동일한 방식으로 iOS Simulator 빌드를 검증합니다.
