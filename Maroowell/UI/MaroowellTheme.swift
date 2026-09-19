import SwiftUI

enum MaroowellTheme {
    static let primary = Color(red: 0.145, green: 0.388, blue: 0.922)       // #2563EB
    static let primaryDark = Color(red: 0.114, green: 0.306, blue: 0.847)   // #1D4ED8
    static let primarySoft = Color(red: 0.937, green: 0.965, blue: 1.0)     // #EFF6FF
    static let primaryBorder = Color(red: 0.576, green: 0.773, blue: 0.992) // #93C5FD
    static let logoGold = Color(red: 1.0, green: 0.773, blue: 0.043)        // #FFC50B

    // Backward-compatible aliases for existing views.
    static let yellow = primary
    static let deepYellow = primaryDark
    static let background = Color(red: 0.961, green: 0.969, blue: 0.976)
    static let card = Color.white
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let muted = Color(red: 0.48, green: 0.51, blue: 0.56)
    static let border = Color(red: 0.867, green: 0.890, blue: 0.918)
}

struct MaroowellMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(MaroowellTheme.yellow)
            Text("MW")
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(-2)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .accessibilityLabel("마루웰")
    }
}
