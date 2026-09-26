import SwiftUI
import Foundation

struct NumberingView: View {
    let session: AppSession

    @State private var mode: NumberingMode = .menu
    @State private var contexts: [NumberingContext] = []
    @State private var forms: [String: GoogleFormDefinition] = [:]
    @State private var history: [NumberingHistoryRow] = []
    @State private var selectedContext = 0
    @State private var driverID = ""
    @State private var waybill = ""
    @State private var quantity = ""
    @State private var mobileCamp = ""
    @State private var selectedMonth = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirm = false
    @State private var showSuccess = false

    private let client = SupabaseService.shared.client

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                switch mode {
                case .menu:
                    menu
                case .numbering:
                    requestForm(returnLabel: false)
                case .returnLabel:
                    requestForm(returnLabel: true)
                case .history:
                    historyView
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("채번")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if contexts.isEmpty {
                await loadContexts()
            }
        }
        .alert("오류", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(mode == .returnLabel ? "반품 송장 출력 요청" : "채번 요청", isPresented: $showConfirm) {
            Button("취소", role: .cancel) {}
            Button("제출") {
                Task { await submitCurrentRequest() }
            }
        } message: {
            Text(confirmMessage)
        }
        .alert("요청 완료", isPresented: $showSuccess) {
            Button("확인") { mode = .menu }
        } message: {
            Text("요청을 제출하고 채번 이력에 저장했습니다.")
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘 스케줄과 입차지 정보를 이용해 자동 입력합니다.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MaroowellTheme.muted)
                .padding(.horizontal, 3)
                .padding(.bottom, 2)

            menuCard(
                asset: "numbering_request",
                title: "채번 요청",
                subtitle: "운송장번호 · 기사 ID · 수량 · 모바일캠프 입력"
            ) {
                Task { await openRequest(returnLabel: false) }
            }

            menuCard(
                asset: "return_label",
                title: "반품 송장 출력 요청",
                subtitle: "기사 ID와 요청 모바일캠프 자동 선택"
            ) {
                Task { await openRequest(returnLabel: true) }
            }

            menuCard(
                asset: "numbering_history",
                title: "채번 데이터 확인",
                subtitle: "정산월별 나의 채번/반품 송장 요청 이력"
            ) {
                Task { await loadHistory() }
            }
        }
    }

    private func menuCard(
        asset: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MaroowellTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func requestForm(returnLabel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(returnLabel ? "반품 송장 출력 요청" : "채번 요청")

            fieldCard("오늘 입차 라우트") {
                Picker("오늘 입차 라우트", selection: $selectedContext) {
                    ForEach(Array(contexts.enumerated()), id: .offset) { index, item in
                        Text("\(item.camp) · \(item.route) · \(waveName(item.wave))")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedContext) { _, _ in
                    syncSelectedContext(returnLabel: returnLabel)
                }
            }

            fieldCard("기사님 아이디") {
                TextField("기사 ID", text: $driverID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !returnLabel {
                fieldCard("운송장번호") {
                    TextField("운송장번호 994667647503 주문번호 29100092477318", text: $waybill)
                        .keyboardType(.numbersAndPunctuation)
                }

                fieldCard("채번 수량") {
                    TextField("수량", text: $quantity)
                        .keyboardType(.numberPad)
                }
            }

            fieldCard("요청 모바일 캠프") {
                Picker("요청 모바일 캠프", selection: $mobileCamp) {
                    ForEach(currentMobileOptions(returnLabel: returnLabel), id: .self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.menu)
            }

            if let ctx = currentContext {
                Text(autoContextText(ctx))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.blue)
                    .padding(.horizontal, 3)
            }

            Button("제출") {
                guard validate(returnLabel: returnLabel) else { return }
                showConfirm = true
            }
            .font(.headline.weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 0.145, green: 0.388, blue: 0.922), in: RoundedRectangle(cornerRadius: 14))
            .padding(.top, 4)
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("채번 데이터 확인")

            fieldCard("정산월") {
                Picker("정산월", selection: $selectedMonth) {
                    ForEach(historyMonths, id: .self) { month in
                        Text(month).tag(month)
                    }
                }
                .pickerStyle(.menu)
            }

            let rows = filteredHistory
            if rows.isEmpty {
                Text("해당 정산월의 채번 데이터가 없습니다.")
                    .foregroundStyle(MaroowellTheme.muted)
                    .padding(.vertical, 18)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.isReturnLabel ? "반품 송장 출력 요청" : "채번 요청")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                        Text("\(row.camp) · \(row.mobileCamp)")
                        Text("\(row.driverName) · \(row.coupangID)")
                        if !row.isReturnLabel {
                            Text("운송장 \(row.waybillNo ?? "") · \(row.quantity ?? 0)장")
                        }
                        Text(shortTime(row.requestedAt))
                            .foregroundStyle(MaroowellTheme.muted)
                    }
                    .font(.caption)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MaroowellTheme.border, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(MaroowellTheme.ink)
            Spacer()
            Button("목록") {
                mode = .menu
            }
            .font(.subheadline.weight(.bold))
        }
    }

    private func fieldCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.2, green: 0.25, blue: 0.33))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private var currentContext: NumberingContext? {
        guard contexts.indices.contains(selectedContext) else { return nil }
        return contexts[selectedContext]
    }

    private var confirmMessage: String {
        var lines = ["기사 ID  \(driverID)", "요청 캠프  \(mobileCamp)"]
        if mode == .numbering {
            lines.append("운송장  \(extractWaybill(waybill))")
            lines.append("수량  \(quantity)")
        }
        return lines.joined(separator: "\n")
    }

    private var historyMonths: [String] {
        let values = Array(Set(history.compactMap { $0.settlementMonth?.isEmpty == false ? $0.settlementMonth : nil }))
            .sorted(by: >)
        return values.isEmpty ? [settlementMonth()] : values
    }

    private var filteredHistory: [NumberingHistoryRow] {
        history.filter { ($0.settlementMonth ?? "") == selectedMonth }
    }

    private func openRequest(returnLabel: Bool) async {
        guard !contexts.isEmpty else {
            errorMessage = "오늘 등록된 입차 스케줄이 없습니다."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var loaded: [String: GoogleFormDefinition] = [:]
            for group in Dictionary(grouping: contexts, by: .camp) {
                guard let rawURL = group.value.first(where: { !$0.numberingURL.isEmpty })?.numberingURL else {
                    throw NumberingError.message("\(group.key) 캠프의 채번 URL이 없습니다.")
                }
                loaded[group.key] = try await loadGoogleForm(rawURL)
            }
            forms = loaded
            mode = returnLabel ? .returnLabel : .numbering
            selectedContext = 0
            syncSelectedContext(returnLabel: returnLabel)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadContexts() async {
        guard session.isMaroowell else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client
                .rpc("mw_my_numbering_context_v2", params: ["p_date": koreaToday()])
                .execute()
            let rows = try JSONDecoder().decode([NumberingContext].self, from: response.data)
            contexts = rows.filter { !$0.route.isEmpty && $0.route != "휴무자" }
        } catch {
            errorMessage = "오늘 입차 스케줄 조회 실패: \(error.localizedDescription)"
        }
    }

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client
                .from("numbering_requests")
                .select()
                .order("requested_at", ascending: false)
                .limit(500)
                .execute()
            history = try JSONDecoder().decode([NumberingHistoryRow].self, from: response.data)
            selectedMonth = historyMonths.first ?? settlementMonth()
            mode = .history
        } catch {
            errorMessage = "채번 이력 조회 실패: \(error.localizedDescription)"
        }
    }

    private func syncSelectedContext(returnLabel: Bool) {
        guard let ctx = currentContext, let form = forms[ctx.camp] else { return }
        driverID = ctx.coupangID
        let options = returnLabel ? form.returnMobileOptions : form.mobileOptions
        if let match = fuzzyMatch(ctx.deliveryLocation, options: options) {
            mobileCamp = options[match]
        } else {
            mobileCamp = options.first ?? ""
        }
    }

    private func currentMobileOptions(returnLabel: Bool) -> [String] {
        guard let ctx = currentContext, let form = forms[ctx.camp] else { return [] }
        return returnLabel ? form.returnMobileOptions : form.mobileOptions
    }

    private func autoContextText(_ ctx: NumberingContext) -> String {
        var value = "캠프 \(ctx.camp) · 라우트 \(ctx.route)"
        if !ctx.deliveryLocation.isEmpty {
            value += " · 입차지 \(ctx.deliveryLocation)"
        }
        return value
    }

    private func validate(returnLabel: Bool) -> Bool {
        guard !driverID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "기사 아이디를 입력하세요."
            return false
        }
        guard !mobileCamp.isEmpty else {
            errorMessage = "요청 모바일 캠프를 선택하세요."
            return false
        }
        if !returnLabel {
            guard !extractWaybill(waybill).isEmpty else {
                errorMessage = "운송장번호를 확인하세요."
                return false
            }
            guard let count = Int(quantity), count > 0 else {
                errorMessage = "채번 수량을 입력하세요."
                return false
            }
        }
        return true
    }

    private func submitCurrentRequest() async {
        guard let ctx = currentContext, let form = forms[ctx.camp] else { return }
        let returnLabel = mode == .returnLabel
        isLoading = true
        defer { isLoading = false }

        do {
            var values: [String: String] = [:]
            if let entry = form.branchEntry {
                values[entry] = returnLabel ? "반품 송장 출력 요청" : "채번 요청"
            }
            if returnLabel {
                if let entry = form.returnIDEntry { values[entry] = driverID }
                if let entry = form.returnMobileEntry { values[entry] = mobileCamp }
            } else {
                if let entry = form.waybillEntry { values[entry] = extractWaybill(waybill) }
                if let entry = form.driverIDEntry { values[entry] = driverID }
                if let entry = form.quantityEntry { values[entry] = quantity }
                if let entry = form.mobileEntry { values[entry] = mobileCamp }
            }
            guard !values.isEmpty else {
                throw NumberingError.message("Google Form 질문 항목을 확인하지 못했습니다.")
            }

            try await postGoogleForm(responseURL: form.responseURL, values: values)

            let payload = NumberingInsertRow(
                maroowellInfoID: ctx.infoID,
                driverName: ctx.driverName,
                coupangID: driverID,
                requestType: returnLabel ? "return_label" : "numbering",
                waybillNo: returnLabel ? nil : extractWaybill(waybill),
                quantity: returnLabel ? nil : Int(quantity),
                camp: ctx.camp,
                mobileCamp: mobileCamp
            )
            try await client.from("numbering_requests").insert(payload).execute()
            showSuccess = true
        } catch {
            errorMessage = "제출 실패: \(error.localizedDescription)"
        }
    }

    private func loadGoogleForm(_ rawURL: String) async throws -> GoogleFormDefinition {
        let normalized = normalizeFormURL(rawURL)
        guard let url = URL(string: normalized) else {
            throw NumberingError.message("채번 URL이 올바르지 않습니다.")
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 MaroowellIOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode,
              let html = String(data: data, encoding: .utf8)
        else {
            throw NumberingError.message("채번 양식 조회 실패")
        }

        return try parseGoogleForm(viewURL: response.url?.absoluteString ?? normalized, html: html)
    }

    private func parseGoogleForm(viewURL: String, html: String) throws -> GoogleFormDefinition {
        let pattern = #"FB_PUBLIC_LOAD_DATA_\s*=\s*(.*?);\s*</script>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let jsonRange = Range(match.range(at: 1), in: html)
        else {
            throw NumberingError.message("Google Form 구조를 읽지 못했습니다.")
        }

        let jsonText = String(html[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonText.data(using: .utf8) else {
            throw NumberingError.message("Google Form 데이터를 읽지 못했습니다.")
        }
        let root = try JSONSerialization.jsonObject(with: data)
        var questions: [FormQuestion] = []
        collectQuestions(root, into: &questions)

        func key(_ value: String) -> String {
            value.uppercased().replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        }

        let waybill = questions.first {
            let value = key($0.title)
            return value.contains("운송장번호") || value.contains("송장번호")
        }
        let quantityQuestion = questions.first {
            let value = key($0.title)
            return value.contains("수량") && (value.contains("채번") || value.contains("송장"))
        }
        let ids = questions.filter {
            let value = key($0.title)
            return value.contains("아이디") || value.contains("기사ID") || value.contains("COUPANGID")
        }
        let mobiles = questions.filter {
            let value = key($0.title)
            return (value.contains("모바일") && value.contains("캠프")) ||
                value.contains("요청캠프") || value.contains("입차캠프")
        }
        let branch = questions.first { question in
            question.options.contains { key($0).contains("채번요청") } &&
                question.options.contains {
                    let value = key($0)
                    return value.contains("반품송장") || value.contains("반품출력")
                }
        }

        return GoogleFormDefinition(
            responseURL: formResponseURL(viewURL),
            branchEntry: branch?.entryID,
            waybillEntry: waybill?.entryID,
            driverIDEntry: ids.first?.entryID,
            quantityEntry: quantityQuestion?.entryID,
            mobileEntry: mobiles.first?.entryID,
            mobileOptions: mobiles.first?.options ?? [],
            returnIDEntry: ids.dropFirst().first?.entryID ?? ids.first?.entryID,
            returnMobileEntry: mobiles.dropFirst().first?.entryID ?? mobiles.first?.entryID,
            returnMobileOptions: mobiles.dropFirst().first?.options ?? mobiles.first?.options ?? []
        )
    }

    private func collectQuestions(_ value: Any, into output: inout [FormQuestion]) {
        if let array = value as? [Any] {
            if array.count > 4,
               let title = array[1] as? String,
               let answers = array[4] as? [Any],
               let answer = answers.first as? [Any],
               let rawID = answer.first {
                let entryID: String?
                if let number = rawID as? NSNumber {
                    entryID = number.stringValue
                } else {
                    entryID = rawID as? String
                }

                if let entryID, !title.isEmpty, entryID.allSatisfy(\.isNumber) {
                    var options: [String] = []
                    if answer.count > 1, let optionRows = answer[1] as? [Any] {
                        for row in optionRows {
                            if let row = row as? [Any], let option = row.first as? String, !option.isEmpty {
                                options.append(option)
                            }
                        }
                    }
                    output.append(FormQuestion(title: title, entryID: entryID, options: options))
                }
            }
            array.forEach { collectQuestions($0, into: &output) }
        } else if let dictionary = value as? [String: Any] {
            dictionary.values.forEach { collectQuestions($0, into: &output) }
        }
    }

    private func postGoogleForm(responseURL: String, values: [String: String]) async throws {
        guard let url = URL(string: responseURL) else {
            throw NumberingError.message("Google Form 제출 주소가 올바르지 않습니다.")
        }

        var fields = ["fvv": "1", "pageHistory": "0,1"]
        values.forEach { fields["entry.\($0.key)"] = $0.value }

        let payload = fields
            .map { "\(urlEncode($0.key))=\(urlEncode($0.value))" }
            .joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode else {
            throw NumberingError.message("Google Form 제출 실패")
        }
    }

    private func normalizeFormURL(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/formResponse", with: "/viewform")
        if let hash = result.firstIndex(of: "#") {
            result = String(result[..<hash])
        }
        if result.contains("docs.google.com/forms/"), let question = result.firstIndex(of: "?") {
            result = String(result[..<question])
        }
        return result
    }

    private func formResponseURL(_ value: String) -> String {
        var result = value
        if let question = result.firstIndex(of: "?") { result = String(result[..<question]) }
        if let hash = result.firstIndex(of: "#") { result = String(result[..<hash]) }
        if result.hasSuffix("/viewform") {
            return String(result.dropLast("/viewform".count)) + "/formResponse"
        }
        return result
    }

    private func fuzzyMatch(_ source: String, options: [String]) -> Int? {
        guard !source.isEmpty, !options.isEmpty else { return nil }
        let key = fuzzyKey(source)
        let core = fuzzyCore(source)
        var best: (index: Int, score: Int)?

        for (index, option) in options.enumerated() {
            let optionKey = fuzzyKey(option)
            let optionCore = fuzzyCore(option)
            let prefix = commonPrefix(core, optionCore)
            let score: Int
            if !optionKey.isEmpty && optionKey == key {
                score = 1000
            } else if !optionCore.isEmpty && optionCore == core {
                score = 900
            } else if !optionKey.isEmpty && (key.contains(optionKey) || optionKey.contains(key)) {

                score = 700 + min(key.count, optionKey.count)
            } else if optionCore.count >= 2 && core.count >= 2 &&
                        (core.contains(optionCore) || optionCore.contains(core)) {
                score = 600 + min(core.count, optionCore.count)
            } else if prefix >= 2 {
                score = 400 + prefix
            } else {
                score = 0
            }
            if best == nil || score > best!.score {
                best = (index, score)
            }
        }
        guard let best, best.score >= 400 else { return nil }
        return best.index
    }

    private func fuzzyKey(_ value: String) -> String {
        value.uppercased()
            .replacingOccurrences(of: #"[^0-9A-Z가-힣]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "MOBILE", with: "")
            .replacingOccurrences(of: "CAMP", with: "")
            .replacingOccurrences(of: "CENTER", with: "")
            .replacingOccurrences(of: "MB", with: "")
    }

    private func fuzzyCore(_ value: String) -> String {

        fuzzyKey(value)
            .replacingOccurrences(of: "본캠프", with: "본")
            .replacingOccurrences(of: "본센터", with: "본")
            .replacingOccurrences(of: "센터", with: "")
            .replacingOccurrences(of: "동", with: "")
            .replacingOccurrences(of: "가", with: "")
    }

    private func commonPrefix(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        for (a, b) in zip(lhs, rhs) {
            guard a == b else { break }
            count += 1
        }
        return count
    }

    private func extractWaybill(_ value: String) -> String {
        if let range = value.range(of: #"운송장번호\s*[:：]?\s*(\d{8,})"#, options: .regularExpression) {
            let matched = String(value[range])
            if let numberRange = matched.range(of: #"\d{8,}"#, options: .regularExpression) {
                return String(matched[numberRange])
            }
        }
        if let range = value.range(of: #"\d{8,}"#, options: .regularExpression) {
            return String(value[range])
        }

        return ""
    }

    private func koreaToday() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func settlementMonth() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = Date()
        let day = calendar.component(.day, from: now)
        let target = day >= 26 ? calendar.date(byAdding: .month, value: 1, to: now) ?? now : now
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: target)
    }

    private func shortTime(_ value: String) -> String {
        value.replacingOccurrences(of: "T", with: " ").prefix(16).description

    }

    private func waveName(_ value: String) -> String {
        value.uppercased() == "WAVE1" ? "야간" : "주간"
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

private enum NumberingMode: Equatable {
    case menu
    case numbering
    case returnLabel
    case history
}

private struct NumberingContext: Decodable, Identifiable {
    let camp: String
    let wave: String
    let routeLabel: String
    let driverName: String
    let coupangID: String
    let infoID: Int64?
    let deliveryLocation: String
    let numberingURL: String

    var id: String { "\(camp)|\(wave)|\(routeLabel)|\(coupangID)" }

    var route: String {
        routeLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^0-9A-Za-z가-힣]"#, with: "", options: .regularExpression)
            .uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case camp, wave
        case routeLabel = "route_label"
        case driverName = "driver_name"
        case coupangID = "driver_coupang_id"
        case infoID = "maroowell_info_id"
        case deliveryLocation = "delivery_location_name"
        case numberingURL = "numbering_url"
    }
}

private struct NumberingHistoryRow: Decodable, Identifiable {
    let id: Int64
    let requestType: String
    let settlementMonth: String?
    let requestedAt: String
    let camp: String
    let mobileCamp: String
    let driverName: String
    let coupangID: String
    let waybillNo: String?

    let quantity: Int?

    var isReturnLabel: Bool { requestType == "return_label" }

    enum CodingKeys: String, CodingKey {
        case id
        case requestType = "request_type"
        case settlementMonth = "settlement_month"
        case requestedAt = "requested_at"
        case camp
        case mobileCamp = "mobile_camp"
        case driverName = "driver_name"
        case coupangID = "coupang_id"
        case waybillNo = "waybill_no"
        case quantity
    }
}

private struct NumberingInsertRow: Encodable {
    let maroowellInfoID: Int64?
    let driverName: String
    let coupangID: String
    let requestType: String
    let waybillNo: String?
    let quantity: Int?
    let camp: String

    let mobileCamp: String

    enum CodingKeys: String, CodingKey {
        case maroowellInfoID = "maroowell_info_id"
        case driverName = "driver_name"
        case coupangID = "coupang_id"
        case requestType = "request_type"
        case waybillNo = "waybill_no"
        case quantity, camp
        case mobileCamp = "mobile_camp"
    }
}

private struct FormQuestion {
    let title: String
    let entryID: String
    let options: [String]
}

private struct GoogleFormDefinition {
    let responseURL: String
    let branchEntry: String?
    let waybillEntry: String?
    let driverIDEntry: String?
    let quantityEntry: String?
    let mobileEntry: String?
    let mobileOptions: [String]

    let returnIDEntry: String?
    let returnMobileEntry: String?
    let returnMobileOptions: [String]
}

private enum NumberingError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value): value
        }
    }
}

