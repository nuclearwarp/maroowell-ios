import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    let session: AppSession

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    quickSummary

                    Text("업무 메뉴")
                        .font(.title3.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)

                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink {
                            FeaturePlaceholderView(
                                title: "배송 수량 등록",
                                subtitle: "Android의 수량 등록 기능을 iPhone 네이티브 화면으로 이식합니다.",
                                symbol: "shippingbox.fill"
                            )
                        } label: {
                            HomeMenuCard(title: "배송 수량 등록", subtitle: "라우트별 수량과 예상소득", symbol: "shippingbox.fill")
                        }

                        NavigationLink {
                            FeaturePlaceholderView(
                                title: "배송 통계",
                                subtitle: "월별·정산월별 매출과 수량 통계를 이식합니다.",
                                symbol: "chart.line.uptrend.xyaxis"
                            )
                        } label: {
                            HomeMenuCard(title: "배송 통계", subtitle: "월별·정산월별 추이", symbol: "chart.line.uptrend.xyaxis")
                        }

                        NavigationLink {
                            FeaturePlaceholderView(
                                title: "일상점검",
                                subtitle: "운수종사자 일상점검 화면을 iPhone에 맞게 구현합니다.",
                                symbol: "checkmark.shield.fill"
                            )
                        } label: {
                            HomeMenuCard(title: "일상점검", subtitle: "오늘 점검을 빠르게 등록", symbol: "checkmark.shield.fill")
                        }

                        if session.isTeamLeader {
                            NavigationLink {
                                FeaturePlaceholderView(
                                    title: "마루웰 일정",
                                    subtitle: "팀장 권한 일정과 달력 기능을 연결합니다.",
                                    symbol: "calendar"
                                )
                            } label: {
                                HomeMenuCard(title: "마루웰 일정", subtitle: "스케줄과 달력 확인", symbol: "calendar")
                            }
                        }

                        if session.isTeamLeader {
                            NavigationLink {
                                FeaturePlaceholderView(
                                    title: "PUSH",
                                    subtitle: "APNs 등록 후 현재 마루웰 PUSH 콘솔과 연결합니다.",
                                    symbol: "bell.badge.fill"
                                )
                            } label: {
                                HomeMenuCard(title: "PUSH", subtitle: "알림 발송과 수신 관리", symbol: "bell.badge.fill")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        Task { await sessionViewModel.signOut() }
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .background(MaroowellTheme.background)
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("안녕하세요, \(session.displayName)님")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)
                Text("오늘도 안전하고 좋은 하루 보내세요 💛")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MaroowellTheme.muted)
            }

            Spacer(minLength: 8)
            MaroowellMark(size: 58)
        }
    }

    private var quickSummary: some View {
        HStack(spacing: 0) {
            summaryItem(title: "권한", value: roleLabel)
            Divider().frame(height: 42)
            summaryItem(title: "소속", value: session.isMaroowell ? "마루웰" : "협력")
            Divider().frame(height: 42)
            summaryItem(title: "상태", value: "승인")
        }
        .padding(.vertical, 18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.75), lineWidth: 1)
        }
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var roleLabel: String {
        if session.isSuperAdmin { return "관리자" }
        if session.isManager { return "운영" }
        if session.isTeamLeader { return "팀장" }
        return "기사"
    }
}

private struct HomeMenuCard: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(MaroowellTheme.yellow.opacity(0.22))
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(MaroowellTheme.deepYellow)
            }
            .frame(width: 48, height: 48)

            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .multilineTextAlignment(.leading)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.75), lineWidth: 1)
        }
    }
}
