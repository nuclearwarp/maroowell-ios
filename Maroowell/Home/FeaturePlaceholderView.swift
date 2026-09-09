import SwiftUI

struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MaroowellTheme.yellow.opacity(0.2))
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(MaroowellTheme.deepYellow)
            }
            .frame(width: 112, height: 112)

            Text(title)
                .font(.title2.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            Text("iOS 네이티브 이식 진행 중")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.deepYellow)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MaroowellTheme.yellow.opacity(0.14), in: Capsule())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
