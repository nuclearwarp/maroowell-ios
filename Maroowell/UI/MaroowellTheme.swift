import SwiftUI

enum MaroowellTheme {
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.08)
    static let deepYellow = Color(red: 0.93, green: 0.64, blue: 0.0)
    static let background = Color(red: 1.0, green: 0.995, blue: 0.975)
    static let card = Color.white
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let muted = Color(red: 0.48, green: 0.51, blue: 0.56)
    static let border = Color(red: 0.92, green: 0.87, blue: 0.70)
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
