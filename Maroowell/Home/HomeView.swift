import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @ObservedObject private var quantityStore = QuantityStore.shared
    @ObservedObject private var inspectionStore = InspectionStore.shared
    @StateObject private var homeScheduleStore = HomeScheduleStore()
    @State private var selectedTab: HomeTab = .home

    let session: AppSession

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .home:
                        dashboard
                    case .work, .status, .more:
                        menuPage(selectedTab)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HomeBottomBar(selectedTab: $selectedTab)
            }
            .background(MaroowellTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                settlementHero
                HomeCalendarView(scheduleStore: homeScheduleStore)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(MaroowellTheme.background)
    }

    private func menuPage(_ tab: HomeTab) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tab.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text(tab.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MaroowellTheme.muted)
                }
                .padding(.bottom, 2)

                ForEach(items(for: tab)) { item in
                    destinationLink(for: item)
                }

                if tab == .more {
                    accountCard

                    Button(role: .destructive) {
                        Task { await sessionViewModel.signOut() }
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .background(MaroowellTheme.background)
    }

    @ViewBuilder
    private func destinationLink(for item: HomeMenuItem) -> some View {
        switch item.destination {
        case .quantity:
            NavigationLink { QuantityView() } label: { HomeMenuRow(item: item, badge: nil) }
                .buttonStyle(.plain)
        case .quantityStats:
            NavigationLink { QuantityStatsView(session: session) } label: { HomeMenuRow(item: item, badge: nil) }
                .buttonStyle(.plain)
        case .inspection:
            NavigationLink { DailyInspectionView() } label: { HomeMenuRow(item: item, badge: nil) }
                .buttonStyle(.plain)
        case .schedule:
            NavigationLink { ScheduleView() } label: { HomeMenuRow(item: item, badge: "팀장") }
                .buttonStyle(.plain)
        case .metaRealtime:
            NavigationLink { MetaRealtimeView() } label: { HomeMenuRow(item: item, badge: "팀장") }
                .buttonStyle(.plain)
        case .web(let path):
            NavigationLink {
                MaroowellWebView(title: item.title, path: path)
            } label: {
                HomeMenuRow(item: item, badge: AppAccessPolicy.permissionBadge(for: path, session: session))
            }
            .buttonStyle(.plain)
        case .placeholder(let message):
            NavigationLink {
                FeaturePlaceholderView(title: item.title, subtitle: message, symbol: item.symbol)
            } label: {
                HomeMenuRow(item: item, badge: "준비중")
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("마루웰")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                    Text("iOS v1.0")
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
        let actualDates = quantityStore.settlementRecordDates(anchor: .now)
        let scheduledDates = settlementScheduledDates(start: summary.startDate, end: summary.endDate)
        let projectedDates = actualDates.union(scheduledDates)
        let average = actualDates.isEmpty ? 0 : summary.total / Int64(actualDates.count)
        let projected = average * Int64(projectedDates.count)
        let remaining = scheduledDates.subtracting(actualDates).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(summary.startDate.compactMD) ~ \(summary.endDate.compactMD)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text(roleLabel)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 14) {
                heroMetric(
                    title: "누적 정산액",
                    value: summary.total.krw,
                    detail: "배송 \(counts.delivery) · 반품 \(counts.returns) · 프백 \(counts.freshbag)"
                )
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 1, height: 68)
                heroMetric(
                    title: "예상 정산액",
                    value: projected.krw,
                    detail: "평균 \(average.krw) · 예상근무 \(projectedDates.count)일 · 남은 \(remaining)일"
                )
            }

            HStack {
                Image(systemName: "calendar.badge.clock")
                Text("이번 정산 입차 \(scheduledDates.count)일")
                Spacer()
                if homeScheduleStore.isLoading {
                    ProgressView().tint(.white).controlSize(.mini)
                    Text("동기화 중")
                } else {
                    Text("등록 \(summary.days)일")
                }
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

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(MaroowellTheme.deepYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.headline.weight(.black))
                    Text(session.email)
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Text(roleLabel)
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
            }
            Text("현재 계정 권한에 따라 메뉴가 자동으로 표시됩니다.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
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
                .minimumScaleFactor(0.64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settlementScheduledDates(start: Date, end: Date) -> Set<String> {
        let startISO = ScheduleDatePolicy.iso(start)
        let endISO = ScheduleDatePolicy.iso(end)
        return Set(homeScheduleStore.entriesByDate.compactMap { date, entries in
            guard date >= startISO, date <= endISO, entries.contains(where: { !$0.isOff }) else { return nil }
            return date
        })
    }

    private func items(for tab: HomeTab) -> [HomeMenuItem] {
        allMenuItems.filter { $0.tab == tab }
    }

    private var allMenuItems: [HomeMenuItem] {
        var items: [HomeMenuItem] = [
            .init(tab: .work, title: "배송 수량 등록", subtitle: "라우트별 수량·단가와 일자별 예상소득", symbol: "shippingbox.fill", destination: .quantity),
            .init(tab: .work, title: "배송 통계", subtitle: "월별·정산월 일별 매출과 수량 추이", symbol: "chart.line.uptrend.xyaxis", destination: .quantityStats),
            .init(tab: .work, title: "운수종사자 일상점검", subtitle: inspectionStore.hasDay(Date()) ? "오늘 점검 완료 · 월간 PDF 지원" : "오늘 점검 미완료 · 바로 등록", symbol: inspectionStore.hasDay(Date()) ? "checkmark.shield.fill" : "shield.lefthalf.filled", destination: .inspection),
            .init(tab: .work, title: "차량 점검 / 정비", subtitle: "내 차량 점검·정비 기록 관리", symbol: "wrench.and.screwdriver.fill", destination: .placeholder("차량 정비 기록 화면은 다음 네이티브 포팅 묶음에서 연결합니다."))
        ]

        if session.canView(AppAccessPolicy.schedulePath) {
            items.append(.init(tab: .work, title: "입차 스케줄", subtitle: "전체 라우트 입차 일정 조회 및 관리", symbol: "calendar", destination: .schedule))
        }
        if session.canView(AppAccessPolicy.metaRealtimePath) {
            items.append(.init(tab: .status, title: "실시간 배송 현황", subtitle: "META 라우트 스캔 · 오스캔 자동 확인", symbol: "dot.radiowaves.left.and.right", destination: .metaRealtime))
        }

        let webItems: [(HomeTab, String, String, String, String)] = [
            (.more, "마루웰 정보", "마루웰 기본 정보", "building.2.fill", "/maroowell_info"),
            (.more, "우편번호 검색", "주소·지도 빠른 조회", "mappin.and.ellipse", "/zipcode_search"),
            (.more, "라우트 편집기", "라우트·벤더·입차지 편집", "point.3.connected.trianglepath.dotted", "/coupangRouteMap.html"),
            (.status, "쿠팡 캠프 조회", "캠프 및 주소 조회", "building.fill", "/coupang_camp"),
            (.status, "프백 현황", "프레시백 현황 조회", "shippingbox.and.arrow.backward.fill", "/coupang_freshbag"),
            (.status, "클렌징 히스토리", "클렌징 기록 조회", "clock.arrow.circlepath", "/cleansing_history"),
            (.status, "마루웰 라우트정보", "라우트 상세·지도·배송 포인트", "map.fill", "/maroowell_route_info"),
            (.status, "마루웰 회수율", "프레시백 회수율 조회", "percent", "/maroowell_freshbag_ratio"),
            (.more, "마루웰 라우트 단가", "라우트 단가·주소·원청 관리", "wonsign.circle.fill", "/maroowell_route"),
            (.status, "통계조회", "배송·반품 통계 조회", "chart.bar.xaxis", "/maroowell_account"),
            (.more, "용차", "용차 운영 관리", "truck.box.fill", "/dragon_car_index"),
            (.more, "용차 스케줄", "기사 출근·휴무 일정", "calendar.badge.clock", "/dragon_car_schedule"),
            (.more, "관리자 권한 관리", "사용자·관리자 권한 관리", "person.badge.key.fill", "/admin_access.html"),
            (.more, "PUSH 알림", "긴급 PUSH · 팀 공지 발송", "bell.badge.fill", "/maroowell_push")
        ]

        for (tab, title, subtitle, symbol, path) in webItems where session.canView(path) {
            items.append(.init(tab: tab, title: title, subtitle: subtitle, symbol: symbol, destination: .web(path)))
        }

        return items
    }

    private var roleLabel: String {
        if session.isSuperAdmin { return "최고관리자" }
        if session.isManager { return "관리자" }
        if session.isTeamLeader { return "팀장" }
        if session.isDragonCarAdmin { return "용차관리자" }
        if session.isMaroowell { return "마루웰" }
        return "기사"
    }
}

private enum HomeTab: String, CaseIterable, Identifiable {
    case home
    case work
    case status
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "홈"
        case .work: "업무"
        case .status: "현황"
        case .more: "더보기"
        }
    }

    var subtitle: String {
        switch self {
        case .home: ""
        case .work: "기록과 일정을 빠르게 시작하세요."
        case .status: "캠프·기사·배송 통계를 한곳에서 확인하세요."
        case .more: "설정과 관리 기능을 확인하세요."
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .work: "briefcase.fill"
        case .status: "chart.bar.fill"
        case .more: "ellipsis.circle.fill"
        }
    }
}

private enum HomeMenuDestination {
    case quantity
    case quantityStats
    case inspection
    case schedule
    case metaRealtime
    case web(String)
    case placeholder(String)
}

private struct HomeMenuItem: Identifiable {
    let id = UUID()
    let tab: HomeTab
    let title: String
    let subtitle: String
    let symbol: String
    let destination: HomeMenuDestination
}

private struct HomeMenuRow: View {
    let item: HomeMenuItem
    let badge: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MaroowellTheme.yellow.opacity(0.18))
                Image(systemName: item.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MaroowellTheme.deepYellow)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    if let badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(MaroowellTheme.deepYellow)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MaroowellTheme.yellow.opacity(0.16), in: Capsule())
                    }
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(MaroowellTheme.muted.opacity(0.72))
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct HomeBottomBar: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .bold))
                            .scaleEffect(selectedTab == tab ? 1.06 : 1)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(selectedTab == tab ? Color(red: 0.08, green: 0.60, blue: 0.53) : MaroowellTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(selectedTab == tab ? MaroowellTheme.yellow : Color.clear)
                            .frame(width: 28, height: 3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(MaroowellTheme.border.opacity(0.7)).frame(height: 1)
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
