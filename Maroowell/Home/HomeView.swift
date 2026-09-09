import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @ObservedObject private var quantityStore = QuantityStore.shared
    @ObservedObject private var inspectionStore = InspectionStore.shared
    @StateObject private var homeScheduleStore = HomeScheduleStore()
    let session: AppSession

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    settlementHero
                    HomeCalendarView(scheduleStore: homeScheduleStore)

                    Text("업무 메뉴")
                        .font(.title3.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)

                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink {
                            QuantityView()
                        } label: {
                            HomeMenuCard(
                                title: "배송 수량 등록",
                                subtitle: "라우트별 수량·단가와 일자별 예상소득",
                                symbol: "shippingbox.fill"
                            )
                        }

                        NavigationLink {
                            QuantityStatsView(session: session)
                        } label: {
                            HomeMenuCard(
                                title: "배송 통계",
                                subtitle: "월별·정산월 일별 매출과 수량 추이",
                                symbol: "chart.line.uptrend.xyaxis"
                            )
                        }

                        NavigationLink {
                            DailyInspectionView()
                        } label: {
                            HomeMenuCard(
                                title: "일상점검",
                                subtitle: inspectionStore.hasDay(Date()) ? "오늘 점검 완료 · 월간 PDF 지원" : "오늘 점검 미완료 · 바로 등록",
                                symbol: inspectionStore.hasDay(Date()) ? "checkmark.shield.fill" : "shield.lefthalf.filled"
                            )
                        }

                        if session.isTeamLeader {
                            NavigationLink {
                                ScheduleView()
                            } label: {
                                HomeMenuCard(title: "입차 스케줄", subtitle: "전체 라우트 입차 일정 조회 및 관리", symbol: "calendar")
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
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(MaroowellTheme.background)
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("마루웰")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                    Text("v1.0")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MaroowellTheme.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white, in: Capsule())
                }

                Text("안녕하세요, \(session.displayName)님")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)
                Text("오늘도 안전하고 좋은 하루 보내세요 💛")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MaroowellTheme.muted)
            }

            Spacer(minLength: 8)
            MaroowellMark(size: 58)
        }
    }

    private var settlementHero: some View {
        let summary = quantityStore.settlementSummary(anchor: .now)
        let counts = quantityStore.settlementCounts(anchor: .now)
        let average = summary.days > 0 ? summary.total / Int64(summary.days) : 0
        let projectedDays = max(summary.days, 20)
        let projected = summary.days > 0 ? average * Int64(projectedDays) : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(summary.startDate.compactMD) ~ \(summary.endDate.compactMD)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
            }

            HStack(spacing: 14) {
                heroMetric(title: "누적 정산액", value: summary.total.krw, detail: "배송 \(counts.delivery) · 반품 \(counts.returns) · 프백 \(counts.freshbag)")
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 1, height: 68)
                heroMetric(title: "예상 정산액", value: projected.krw, detail: "평균 \(average.krw) · 예상근무 \(projectedDays)일")
            }

            HStack {
                Image(systemName: "calendar.badge.clock")
                Text("이번 정산 등록 \(summary.days)일")
                Spacer()
                Text(roleLabel)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.19, green: 0.35, blue: 0.39), Color(red: 0.26, green: 0.47, blue: 0.50)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func heroMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.76))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(detail)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private extension Date {
    var compactMD: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: self)
    }
}
