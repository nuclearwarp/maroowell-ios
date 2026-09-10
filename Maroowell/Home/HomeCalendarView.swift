import SwiftUI

struct HomeCalendarView: View {
    @ObservedObject var scheduleStore: HomeScheduleStore
    @ObservedObject private var inspectionStore = InspectionStore.shared
    @ObservedObject private var quantityStore = QuantityStore.shared
    @ObservedObject private var memoStore = HomeCalendarMemoStore.shared
    @StateObject private var holidayStore = HomeHolidayStore()

    @State private var anchorMonth: Date
    @State private var selectedDay: HomeSettlementCalendarDay?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(scheduleStore: HomeScheduleStore) {
        self.scheduleStore = scheduleStore
        _anchorMonth = State(initialValue: HomeSettlementCalendarPolicy.anchorMonth(containing: .now))
    }

    var body: some View {
        VStack(spacing: 12) {
            calendarHeader
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(visibleDays) { day in
                    dayCell(day)
                }
            }

            legend

            if let errorMessage = scheduleStore.errorMessage {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                    Spacer()
                    Button("재조회") {
                        Task { await loadCalendarData(force: true) }
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            } else if let holidayError = holidayStore.errorMessage {
                HStack(spacing: 7) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text(holidayError)
                    Spacer()
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.75), lineWidth: 1)
        }
        .task(id: periodKey) {
            await loadCalendarData()
        }
        .sheet(item: $selectedDay) { day in
            HomeCalendarDaySheet(
                date: day.date,
                entries: scheduleStore.entries(for: day.date),
                holidayName: holidayStore.holiday(for: day.date)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.light)
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 12) {
            Button {
                anchorMonth = HomeSettlementCalendarPolicy.movingMonth(anchorMonth, by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.black))
                    .frame(width: 38, height: 38)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(HomeSettlementCalendarPolicy.title(anchorMonth))
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
            }
            .frame(maxWidth: .infinity)

            Button {
                anchorMonth = HomeSettlementCalendarPolicy.movingMonth(anchorMonth, by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.black))
                    .frame(width: 38, height: 38)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(index == 0 ? Color.red.opacity(0.78) : index == 6 ? Color.blue.opacity(0.72) : MaroowellTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: HomeSettlementCalendarDay) -> some View {
        if day.inPeriod {
            Button {
                selectedDay = day
            } label: {
                activeDayCell(day)
            }
            .buttonStyle(.plain)
        } else {
            Text("\(HomeSettlementCalendarPolicy.dayNumber(day.date))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MaroowellTheme.muted.opacity(0.42))
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                .padding(.top, 6)
                .padding(.leading, 6)
        }
    }

    private func activeDayCell(_ day: HomeSettlementCalendarDay) -> some View {
        let entries = scheduleStore.entries(for: day.date)
        let activeEntries = entries.filter { !$0.isOff }
        let hasDay = activeEntries.contains { $0.wave == "WAVE2" }
        let hasNight = activeEntries.contains { $0.wave == "WAVE1" }
        let inspectionDone = inspectionStore.hasDay(day.date)
        let isFuture = HomeSettlementCalendarPolicy.isFuture(day.date)
        let amount = quantityStore.load(day.date).map(quantityStore.amount(of:))
        let campText = calendarCampText(entries, date: day.date)
        let isToday = HomeSettlementCalendarPolicy.isToday(day.date)
        let holidayName = holidayStore.holiday(for: day.date)
        let memoText = memoStore.memo(for: day.date)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text("\(HomeSettlementCalendarPolicy.dayNumber(day.date))")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(dayNumberColor(day.date, holidayName: holidayName))
                Spacer(minLength: 0)
                if quantityStore.hasRecord(day.date) {
                    Circle()
                        .fill(MaroowellTheme.deepYellow)
                        .frame(width: 4, height: 4)
                }
            }

            if !holidayName.isEmpty {
                Text(holidayName)
                    .font(.system(size: 6.8, weight: .black))
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            Text(campText)
                .font(.system(size: 8.2, weight: .black))
                .foregroundStyle(scheduleColor(hasDay: hasDay, hasNight: hasNight))
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .topLeading)

            if let amount {
                Text(amount.compactKRW)
                    .font(.system(size: 7.6, weight: .bold))
                    .foregroundStyle(amount < 0 ? Color.red : MaroowellTheme.deepYellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text(" ")
                    .font(.system(size: 7.6))
            }

            let inspectionText = isFuture ? "" : inspectionDone ? "일상점검" : activeEntries.isEmpty ? "" : "일상점검!"
            Text(inspectionText)
                .font(.system(size: 7.5, weight: inspectionText.isEmpty ? .regular : .black))
                .foregroundStyle(inspectionDone ? Color.green : Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            if !memoText.isEmpty {
                Text("메모 O")
                    .font(.system(size: 7.2, weight: .black))
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(dayBackground(hasDay: hasDay, hasNight: hasNight, isToday: isToday), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isToday ? MaroowellTheme.deepYellow : Color.black.opacity(0.08), lineWidth: isToday ? 2.2 : 1)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem("주간", color: Color(red: 0.09, green: 0.54, blue: 0.29))
            legendItem("야간", color: Color(red: 0.44, green: 0.28, blue: 0.66))
            legendItem("점검완료", color: .green)
            legendItem("공휴일", color: .red)
            Spacer(minLength: 0)
            if scheduleStore.isLoading || holidayStore.isLoading { ProgressView().controlSize(.small) }
        }
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
        }
    }

    private func dayBackground(hasDay: Bool, hasNight: Bool, isToday: Bool) -> Color {
        if hasDay && hasNight { return Color(red: 0.949, green: 0.969, blue: 0.98) }
        if hasNight { return Color(red: 0.969, green: 0.945, blue: 1.0) }
        if hasDay { return Color(red: 0.941, green: 0.98, blue: 0.957) }
        if isToday { return Color(red: 1.0, green: 0.973, blue: 0.839) }
        return .white
    }

    private func scheduleColor(hasDay: Bool, hasNight: Bool) -> Color {
        if hasDay && hasNight { return Color(red: 0.14, green: 0.42, blue: 0.47) }
        if hasNight { return Color(red: 0.44, green: 0.28, blue: 0.66) }
        if hasDay { return Color(red: 0.09, green: 0.54, blue: 0.29) }
        return MaroowellTheme.muted
    }

    private func dayNumberColor(_ date: Date, holidayName: String) -> Color {
        if !holidayName.isEmpty || HomeSettlementCalendarPolicy.isSunday(date) { return .red }
        if HomeSettlementCalendarPolicy.isSaturday(date) { return .blue }
        return MaroowellTheme.ink
    }

    private func calendarCampText(_ entries: [HomePersonalScheduleEntry], date: Date) -> String {
        let active = entries.filter { !$0.isOff }
        let scheduleCamps = active.map(\.camp).filter { !$0.isEmpty }
        let savedCamps = quantityStore.load(date)?.routes.map(\.campName).filter { !$0.isEmpty } ?? []
        var camps: [String] = []
        for camp in scheduleCamps + savedCamps where !camps.contains(camp) {
            camps.append(camp)
        }

        if !active.isEmpty {
            if camps.isEmpty { return "입차" }
            return camps.count == 1 ? camps[0] : "\(camps[0]) +\(camps.count - 1)"
        }
        if entries.contains(where: \.isOff) { return "휴무" }
        if !camps.isEmpty {
            return camps.count == 1 ? camps[0] : "\(camps[0]) +\(camps.count - 1)"
        }
        return ""
    }

    private var visibleDays: [HomeSettlementCalendarDay] {
        HomeSettlementCalendarPolicy.visibleDays(anchorMonth)
    }

    private var periodKey: String {
        let period = HomeSettlementCalendarPolicy.period(anchorMonth)
        return "\(ScheduleDatePolicy.iso(period.start))|\(ScheduleDatePolicy.iso(period.end))"
    }

    private func loadCalendarData(force: Bool = false) async {
        await scheduleStore.load(dates: visibleDays.map(\.date), force: force)
        await holidayStore.load(dates: visibleDays.map(\.date), force: force)
    }
}

private struct HomeCalendarDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inspectionStore = InspectionStore.shared
    @ObservedObject private var quantityStore = QuantityStore.shared
    @ObservedObject private var memoStore = HomeCalendarMemoStore.shared

    let date: Date
    let entries: [HomePersonalScheduleEntry]
    let holidayName: String

    @State private var showMemoEditor = false
    @State private var memoDraft = ""

    private var activeEntries: [HomePersonalScheduleEntry] { entries.filter { !$0.isOff } }
    private var inspectionDone: Bool { inspectionStore.hasDay(date) }
    private var isFuture: Bool { HomeSettlementCalendarPolicy.isFuture(date) }
    private var quantityRecord: QuantityRecord? { quantityStore.load(date) }
    private var memoText: String { memoStore.memo(for: date) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(HomeSettlementCalendarPolicy.fullDate(date))
                            .font(.title2.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                        if !holidayName.isEmpty {
                            Text(holidayName)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(.red)
                        }
                        Text(statusText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(statusColor)
                    }

                    if let record = quantityRecord {
                        let amount = quantityStore.amount(of: record)
                        HStack {
                            Text("당일 예상 수수료")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MaroowellTheme.muted)
                            Spacer()
                            Text(amount.krw)
                                .font(.headline.weight(.black))
                                .foregroundStyle(amount < 0 ? Color.red : MaroowellTheme.deepYellow)
                        }
                        .padding(14)
                        .background(MaroowellTheme.yellow.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                    }

                    if !entries.isEmpty {
                        Text("입차 스케줄")
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)

                        if activeEntries.isEmpty {
                            scheduleCard(title: "휴무", routes: ["등록된 입차 노선 없음"], night: false, off: true)
                        } else {
                            ForEach(activeEntries) { entry in
                                scheduleCard(
                                    title: [entry.camp, entry.waveLabel].filter { !$0.isEmpty }.joined(separator: " · "),
                                    routes: groupRoutes(entry.routes),
                                    night: entry.wave == "WAVE1",
                                    off: false
                                )
                            }
                        }
                    }

                    if !memoText.isEmpty {
                        Text("메모  \(memoText)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        memoDraft = memoText
                        showMemoEditor = true
                    } label: {
                        Label(memoText.isEmpty ? "메모 등록" : "메모 수정", systemImage: "note.text")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if !isFuture {
                        NavigationLink {
                            DatedDailyInspectionView(date: date)
                        } label: {
                            Label(inspectionDone ? "일상점검 확인" : "일상점검", systemImage: inspectionDone ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(inspectionDone ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        QuantityView(date: date)
                    } label: {
                        Label("배송 수량 등록", systemImage: "shippingbox.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .padding(.bottom, 18)
            }
            .background(Color.white)
            .navigationTitle("일자 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showMemoEditor) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(HomeSettlementCalendarPolicy.fullDate(date))
                            .font(.headline.weight(.black))
                        TextEditor(text: $memoDraft)
                            .padding(10)
                            .frame(minHeight: 180)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay { RoundedRectangle(cornerRadius: 14).stroke(MaroowellTheme.border, lineWidth: 1) }
                        Button {
                            memoStore.save(memoDraft, for: date)
                            showMemoEditor = false
                        } label: {
                            Text("메모 저장")
                                .font(.headline.weight(.black))
                                .foregroundStyle(MaroowellTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Spacer()
                    }
                    .padding(20)
                    .background(MaroowellTheme.background)
                    .navigationTitle("달력 메모")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if !memoText.isEmpty {
                                Button("삭제", role: .destructive) {
                                    memoDraft = ""
                                    memoStore.save("", for: date)
                                    showMemoEditor = false
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { showMemoEditor = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var statusText: String {
        if isFuture {
            return activeEntries.isEmpty ? "이 날짜의 작업을 확인하세요" : "예정 입차 스케줄을 확인하세요"
        }
        if inspectionDone { return "일상점검 완료" }
        if !activeEntries.isEmpty { return "일상점검이 아직 완료되지 않았습니다" }
        return "이 날짜의 작업을 선택해주세요"
    }

    private var statusColor: Color {
        if isFuture { return MaroowellTheme.muted }
        if inspectionDone { return .green }
        if !activeEntries.isEmpty { return .red }
        return MaroowellTheme.muted
    }

    private func scheduleCard(title: String, routes: [String], night: Bool, off: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.isEmpty ? "입차" : title)
                .font(.caption.weight(.black))
                .foregroundStyle(off ? MaroowellTheme.muted : night ? Color(red: 0.44, green: 0.28, blue: 0.66) : Color.green)
            ForEach(routes.isEmpty ? ["노선 미지정"] : routes, id: \.self) { route in
                Text(route)
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            off ? Color.gray.opacity(0.06) : night ? Color.purple.opacity(0.07) : Color.green.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private func groupRoutes(_ routes: [String]) -> [String] {
        var grouped: [String: [String]] = [:]
        var order: [String] = []

        for raw in routes where raw != "휴무" {
            let route = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !route.isEmpty else { continue }

            if let split = splitSubSub(route) {
                if grouped[split.parent] == nil { order.append(split.parent) }
                grouped[split.parent, default: []].append(split.suffix)
            } else {
                if grouped[route] == nil { order.append(route) }
                grouped[route, default: []].append("")
            }
        }

        return order.map { parent in
            let suffixes = Array(Set(grouped[parent] ?? [])).sorted { left, right in
                if left.isEmpty != right.isEmpty { return left.isEmpty }
                return left < right
            }
            if suffixes.count == 1 && suffixes[0].isEmpty { return parent }
            let labels = suffixes.map { $0.isEmpty ? "전체" : $0 }
            return "\(parent) · \(labels.joined(separator: " / "))"
        }
    }

    private func splitSubSub(_ route: String) -> (parent: String, suffix: String)? {
        guard route.count >= 3 else { return nil }
        let suffix = String(route.suffix(2))
        guard suffix.allSatisfy(\.isNumber) else { return nil }
        let parent = String(route.dropLast(2))
        guard let last = parent.last, last.isLetter else { return nil }
        return (parent, suffix)
    }
}

private struct HomeSettlementCalendarDay: Identifiable {
    let date: Date
    let inPeriod: Bool
    var id: String { ScheduleDatePolicy.iso(date) }
}

private enum HomeSettlementCalendarPolicy {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    static func anchorMonth(containing date: Date) -> Date {
        var anchor = date
        if calendar.component(.day, from: date) >= 26 {
            anchor = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
        return monthStart(anchor)
    }

    static func movingMonth(_ date: Date, by delta: Int) -> Date {
        monthStart(calendar.date(byAdding: .month, value: delta, to: date) ?? date)
    }

    static func period(_ anchor: Date) -> (start: Date, end: Date) {
        let endComponents = calendar.dateComponents([.year, .month], from: anchor)
        let end = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: endComponents.year,
            month: endComponents.month,
            day: 25,
            hour: 12
        )) ?? anchor
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: anchor) ?? anchor
        let startComponents = calendar.dateComponents([.year, .month], from: previousMonth)
        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: startComponents.year,
            month: startComponents.month,
            day: 26,
            hour: 12
        )) ?? previousMonth
        return (start, end)
    }

    static func visibleDays(_ anchor: Date) -> [HomeSettlementCalendarDay] {
        let range = period(anchor)
        let startWeekday = calendar.component(.weekday, from: range.start)
        let visibleStart = calendar.date(byAdding: .day, value: -(startWeekday - 1), to: range.start) ?? range.start
        let endWeekday = calendar.component(.weekday, from: range.end)
        let visibleEnd = calendar.date(byAdding: .day, value: 7 - endWeekday, to: range.end) ?? range.end

        var days: [HomeSettlementCalendarDay] = []
        var cursor = visibleStart
        while cursor <= visibleEnd {
            let iso = ScheduleDatePolicy.iso(cursor)
            let inPeriod = iso >= ScheduleDatePolicy.iso(range.start) && iso <= ScheduleDatePolicy.iso(range.end)
            days.append(HomeSettlementCalendarDay(date: cursor, inPeriod: inPeriod))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? visibleEnd.addingTimeInterval(86_400)
        }
        return days
    }

    static func title(_ anchor: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: anchor)
        return String(format: "%04d년 %02d월", components.year ?? 0, components.month ?? 0)
    }

    static func rangeLabel(_ anchor: Date) -> String {
        let range = period(anchor)
        return "\(shortDate(range.start)) ~ \(shortDate(range.end))"
    }

    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    static func dayNumber(_ date: Date) -> Int { calendar.component(.day, from: date) }
    static func isSunday(_ date: Date) -> Bool { calendar.component(.weekday, from: date) == 1 }
    static func isSaturday(_ date: Date) -> Bool { calendar.component(.weekday, from: date) == 7 }
    static func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }
    static func isFuture(_ date: Date) -> Bool { calendar.startOfDay(for: date) > calendar.startOfDay(for: .now) }

    private static func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: 1,
            hour: 12
        )) ?? date
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private extension Int64 {
    var compactKRW: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let absolute = formatter.string(from: NSNumber(value: Swift.abs(self))) ?? "0"
        return self < 0 ? "−\(absolute)" : "\(absolute)원"
    }
}