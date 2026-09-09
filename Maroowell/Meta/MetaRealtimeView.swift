import Foundation
import SwiftUI
import WebKit
import UIKit

struct MetaRealtimeView: View {
    @StateObject private var viewModel = MetaRealtimeViewModel()

    var body: some View {
        ZStack {
            MaroowellTheme.background.ignoresSafeArea()

            MetaBrowserView(webView: viewModel.webView)
                .opacity(viewModel.showBrowser ? 1 : 0)
                .allowsHitTesting(viewModel.showBrowser)

            if !viewModel.showBrowser {
                nativeContent
            }
        }
        .navigationTitle("실시간 배송 현황")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.openMetaBrowser()
                } label: {
                    Label("META", systemImage: "globe")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showBrowser && !viewModel.camps.isEmpty {
                Button {
                    viewModel.closeMetaBrowser()
                } label: {
                    Label("배송 현황으로 돌아가기", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Color(red: 0.08, green: 0.60, blue: 0.53), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
        }
    }

    private var nativeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                controlsCard

                if let model = viewModel.model {
                    Text("캠프 전체")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    MetaOverallSummaryCard(model: model)

                    if !model.rows.isEmpty {
                        HStack {
                            Text("기사별 현황")
                                .font(.headline.weight(.black))
                            Spacer()
                            Text("\(model.rows.count)명")
                                .font(.caption.weight(.black))
                                .foregroundStyle(MaroowellTheme.muted)
                        }
                        .foregroundStyle(MaroowellTheme.ink)

                        ForEach(model.rows) { row in
                            MetaDriverCard(row: row, wave: model.wave)
                        }
                    }
                } else {
                    statusCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .refreshable {
            await viewModel.refreshAsync()
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(viewModel.camps) { camp in
                        Button(camp.label) {
                            viewModel.selectCamp(camp.code)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                        Text(viewModel.selectedCamp?.label ?? "캠프 선택")
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.camps.isEmpty)

                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .black))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading || viewModel.selectedWave.isEmpty || viewModel.selectedCamp == nil)
            }

            HStack(spacing: 8) {
                MetaWaveButton(
                    title: "주간",
                    symbol: "sun.max.fill",
                    selected: viewModel.selectedWave == "WAVE2",
                    accent: Color(red: 0.85, green: 0.42, blue: 0.00)
                ) {
                    viewModel.selectWave("WAVE2")
                }
                MetaWaveButton(
                    title: "야간",
                    symbol: "moon.stars.fill",
                    selected: viewModel.selectedWave == "WAVE1",
                    accent: Color(red: 0.31, green: 0.27, blue: 0.90)
                ) {
                    viewModel.selectWave("WAVE1")
                }
            }

            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
                Text(viewModel.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MaroowellTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.camps.isEmpty ? "person.badge.key.fill" : "dot.radiowaves.left.and.right")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(MaroowellTheme.deepYellow)
            Text(viewModel.camps.isEmpty ? "META 로그인을 확인해주세요" : "주간 또는 야간을 선택해주세요")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text(viewModel.statusText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(MaroowellTheme.muted)
            if viewModel.camps.isEmpty {
                Button("META 로그인 화면 열기") {
                    viewModel.openMetaBrowser()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }
}

private struct MetaBrowserView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct MetaWaveButton: View {
    let title: String
    let symbol: String
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.black))
                .foregroundStyle(selected ? Color.white : accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? accent : Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(selected ? 1 : 0.42), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct MetaOverallSummaryCard: View {
    let model: MetaRealtimeModel

    var body: some View {
        VStack(spacing: 12) {
            MetaSummarySection(title: "배송", metric: model.delivery, accent: Color(red: 0.09, green: 0.50, blue: 0.46), extra: "미스캔 \(model.delivery.misscan)")
            if model.wave != "WAVE1" {
                Divider()
                MetaSummarySection(title: "반품", metric: model.returns, accent: Color(red: 0.49, green: 0.23, blue: 0.89), extra: nil)
            }
            Divider()
            MetaSummarySection(title: "프백", metric: model.freshbag, accent: Color(red: 0.44, green: 0.51, blue: 0.25), extra: nil)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }
}

private struct MetaSummarySection: View {
    let title: String
    let metric: MetaMetric
    let accent: Color
    let extra: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent, in: Capsule())
                Spacer()
                Text("완료율 \(MetaFormat.percent(metric.ratio))")
                    .font(.caption.weight(.black))
                    .foregroundStyle(accent)
            }
            HStack(spacing: 6) {
                MetaMetricBox(label: "총 수량", value: metric.total)
                MetaMetricBox(label: "완료", value: metric.completed)
                MetaMetricBox(label: "남음", value: metric.remaining)
            }
            if let extra {
                Text(extra)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.70, green: 0.14, blue: 0.10))
            }
        }
    }
}

private struct MetaMetricBox: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text(MetaFormat.count(value))
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MetaDriverCard: View {
    let row: MetaDriverRow
    let wave: String
    @State private var expanded = false

    private var accent: Color {
        switch row.status {
        case .external: Color(red: 0.78, green: 0.13, blue: 0.12)
        case .mismatch: Color(red: 0.71, green: 0.37, blue: 0.02)
        case .ok: Color(red: 0.20, green: 0.30, blue: 0.34)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.scheduleRoute.isEmpty ? row.driver : "\(row.driver) - \(row.scheduleRoute)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.leading)
                        if row.status != .ok {
                            Text(row.status == .external ? "외부 라우트 포함" : "담당 서서브 확인")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(accent)
                        }
                    }
                    Spacer()
                    if !row.routes.isEmpty {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(accent)
                    }
                }
            }
            .buttonStyle(.plain)

            Text("배송 · 완료율 \(MetaFormat.percent(row.delivery.ratio))")
                .font(.caption.weight(.black))
                .foregroundStyle(Color(red: 0.09, green: 0.50, blue: 0.46))

            HStack(spacing: 5) {
                MetaMiniMetric(label: "총", value: row.delivery.total)
                MetaMiniMetric(label: "미스캔", value: row.delivery.misscan)
                MetaMiniMetric(label: "배송중", value: row.delivery.remaining)
                MetaMiniMetric(label: "완료", value: row.delivery.completed)
            }

            if wave != "WAVE1" {
                MetaCollectionLine(title: "반품", metric: row.returns, accent: Color(red: 0.49, green: 0.23, blue: 0.89))
            }
            MetaCollectionLine(title: "프백", metric: row.freshbag, accent: Color(red: 0.44, green: 0.51, blue: 0.25))

            if expanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(row.routes) { route in
                        HStack(alignment: .top, spacing: 6) {
                            Text("• \(route.route)")
                                .font(.caption.weight(.black))
                            if route.status != .ok {
                                Text(route.status == .external ? "마루웰 관리 라우트 아님" : "등록 \(route.owner.isEmpty ? "다른 담당" : route.owner)")
                                    .font(.caption)
                                    .foregroundStyle(accent)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(row.status == .ok ? 0.18 : 0.86), lineWidth: row.status == .ok ? 1 : 2)
        }
    }
}

private struct MetaMiniMetric: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(MaroowellTheme.muted)
            Text(MetaFormat.count(value)).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MetaCollectionLine: View {
    let title: String
    let metric: MetaMetric
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(accent)
                .frame(width: 34)
            Text("총 \(MetaFormat.count(metric.total)) · 남음 \(MetaFormat.count(metric.remaining)) · 회수 \(MetaFormat.count(metric.completed))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.ink)
            Spacer(minLength: 4)
            Text(MetaFormat.percent(metric.ratio))
                .font(.caption2.weight(.black))
                .foregroundStyle(accent)
        }
    }
}

private enum MetaFormat {
    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

private struct MetaCampOption: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let label: String
}

private enum MetaRouteState: String {
    case ok
    case mismatch
    case external
}

private struct MetaRouteRow: Identifiable {
    var id: String { route }
    let route: String
    let owner: String
    let status: MetaRouteState
}

private struct MetaMetric {
    var total = 0
    var completed = 0
    var remaining = 0
    var misscan = 0
    var impossible = 0
    var pddMiss = 0

    var ratio: Double {
        total > 0 ? Double(completed) * 100.0 / Double(total) : 0
    }
}

private struct MetaDriverRow: Identifiable {
    let id = UUID()
    let driver: String
    let scheduleRoute: String
    let status: MetaRouteState
    let routes: [MetaRouteRow]
    let delivery: MetaMetric
    let returns: MetaMetric
    let freshbag: MetaMetric
}

private struct MetaRealtimeModel {
    let camp: String
    let campCode: String
    let wave: String
    let scheduleDate: String
    let fetchedAt: String
    let delivery: MetaMetric
    let returns: MetaMetric
    let freshbag: MetaMetric
    let rows: [MetaDriverRow]
}

private enum MetaScheduleDatePolicy {
    private static let nightAliases: Set<String> = ["NIGHT", "WAVE1", "W1", "N", "야간"]
    private static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    static func scheduleDate(wave: String, now: Date = Date()) -> String {
        format(scheduleBaseDate(wave: wave, now: now))
    }

    static func metaWorkDate(wave: String, now: Date = Date()) -> String {
        var date = scheduleBaseDate(wave: wave, now: now)
        if isNight(wave) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return format(date)
    }

    private static func scheduleBaseDate(wave: String, now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var date = now
        if isNight(wave), calendar.component(.hour, from: now) < 8 {
            date = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }
        return date
    }

    private static func isNight(_ wave: String) -> Bool {
        nightAliases.contains(wave.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    private static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private enum MetaRouteDisplayPolicy {
    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber }
            .uppercased()
    }

    static func toSubRoute(_ value: String) -> String {
        let normalized = normalize(value)
        guard let regex = try? NSRegularExpression(pattern: "^(.+?[A-Z])\\d{2}$") else { return normalized }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, range: range),
              let swiftRange = Range(match.range(at: 1), in: normalized) else { return normalized }
        return String(normalized[swiftRange])
    }
}

@MainActor
private final class MetaRealtimeViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Published var camps: [MetaCampOption] = []
    @Published var selectedCampCode = ""
    @Published var selectedWave = ""
    @Published var statusText = "META 로그인과 캠프 권한 정보를 확인하는 중입니다."
    @Published var isLoading = false
    @Published var showBrowser = true
    @Published var model: MetaRealtimeModel?

    private(set) var webView: WKWebView!
    private var scriptProxy: MetaWeakScriptHandler?
    private var vendorCampCodes = Set<String>()
    private var campCatalog: [String: String] = [:]
    private var lastSearchFingerprint = ""

    var selectedCamp: MetaCampOption? {
        camps.first(where: { $0.code == selectedCampCode })
    }

    override init() {
        super.init()
        configureWebView()
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.bridgeName)
        webView?.navigationDelegate = nil
    }

    func selectCamp(_ code: String) {
        guard camps.contains(where: { $0.code == code }) else { return }
        selectedCampCode = code
        model = nil
        if !selectedWave.isEmpty { refresh() }
    }

    func selectWave(_ wave: String) {
        selectedWave = wave
        model = nil
        refresh()
    }

    func refresh() {
        guard let camp = selectedCamp else {
            statusText = "META 캠프 권한 정보를 불러오는 중입니다."
            return
        }
        guard !selectedWave.isEmpty else {
            statusText = "주간 또는 야간을 선택해 주세요."
            return
        }
        guard !showBrowser else {
            statusText = "META 로그인 화면을 확인한 뒤 다시 조회해 주세요."
            return
        }

        isLoading = true
        let scheduleDate = MetaScheduleDatePolicy.scheduleDate(wave: selectedWave)
        let workDate = MetaScheduleDatePolicy.metaWorkDate(wave: selectedWave)
        statusText = "스케줄 \(scheduleDate) · META \(workDate) 조회 중입니다."

        let payload: [String: Any] = [
            "campCodes": [camp.code],
            "waveCode": selectedWave,
            "sortType": "DELIVERY_COMPLETED_RATIO",
            "sortDirection": "ASC",
            "workDate": workDate,
            "page": 0,
            "size": 50
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            isLoading = false
            statusText = "META 조회 요청을 만들지 못했습니다."
            return
        }
        webView.evaluateJavaScript("window.__mwMetaSearch && window.__mwMetaSearch(\(json));") { [weak self] _, error in
            guard let self else { return }
            if let error {
                self.isLoading = false
                self.statusText = "META 조회 요청 실패: \(error.localizedDescription)"
            }
        }
    }

    func refreshAsync() async {
        refresh()
    }

    func openMetaBrowser() {
        showBrowser = true
        statusText = "META 로그인 상태를 확인해 주세요."
    }

    func closeMetaBrowser() {
        guard !camps.isEmpty else { return }
        showBrowser = false
        statusText = selectedWave.isEmpty ? "캠프를 확인했습니다. 주간 또는 야간을 선택해 주세요." : statusText
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(Self.metaBridgeScript, completionHandler: nil)
        let url = webView.url?.absoluteString ?? ""
        if url.contains("/ui/dashboard/realtime") {
            statusText = camps.isEmpty ? "META 로그인과 캠프 권한 정보를 확인하는 중입니다." : statusText
            showBrowser = camps.isEmpty
        } else {
            showBrowser = true
            webView.evaluateJavaScript(Self.loginStateScript, completionHandler: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "https" else {
            decisionHandler(.cancel)
            return
        }
        guard Self.isAllowedCoupangHost(url.host) else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode == 401 || response.statusCode == 403 {
            handleAuthExpired(status: response.statusCode)
        }
        decisionHandler(.allow)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.bridgeName,
              let envelope = message.body as? [String: Any],
              let name = envelope["name"] as? String else { return }
        let payload = envelope["payload"]

        switch name {
        case "onAuthenticated":
            statusText = "META 로그인 확인 · 실시간 화면을 불러오는 중입니다."
            if webView.url?.absoluteString.contains("/ui/dashboard/realtime") != true {
                webView.load(URLRequest(url: Self.realtimeURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
            }
        case "onAuthExpired":
            let raw = payload as? String ?? "403"
            handleAuthExpired(status: Int(raw) ?? 403)
        case "onVendorResponse":
            if let object = payload as? [String: Any] { consumeVendor(object) }
        case "onCampsResponse":
            if let object = payload as? [String: Any] { consumeCamps(object) }
        case "onSearchResponse":
            if let object = payload as? [String: Any] { consumeSearch(object) }
        case "onSearchError":
            isLoading = false
            statusText = "META 조회 실패: \((payload as? String ?? "알 수 없는 오류").prefix(100))"
        default:
            break
        }
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let proxy = MetaWeakScriptHandler(delegate: self)
        scriptProxy = proxy
        configuration.userContentController.add(proxy, name: Self.bridgeName)
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.metaBridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.keyboardDismissMode = .interactive
        view.customUserAgent = Self.desktopUserAgent
        webView = view
        view.load(URLRequest(url: Self.realtimeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    private func handleAuthExpired(status: Int) {
        vendorCampCodes.removeAll()
        campCatalog.removeAll()
        camps = []
        selectedCampCode = ""
        selectedWave = ""
        model = nil
        isLoading = false
        showBrowser = true
        statusText = "META 로그인 세션이 만료되었습니다. 다시 로그인해 주세요. (\(status))"
        webView.load(URLRequest(url: Self.flyBaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
    }

    private func consumeVendor(_ object: [String: Any]) {
        let data = object["data"] as? [String: Any] ?? object
        let raw = data["contractedCampCodes"] as? [Any] ?? data["campCodes"] as? [Any] ?? []
        vendorCampCodes = Set(raw.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        rebuildCampSelector()
    }

    private func consumeCamps(_ object: [String: Any]) {
        let dataAny = object["data"]
        var rows: [[String: Any]] = []
        if let array = dataAny as? [[String: Any]] {
            rows = array
        } else if let data = dataAny as? [String: Any] {
            for key in ["content", "camps", "items", "results"] {
                if let array = data[key] as? [[String: Any]] { rows = array; break }
            }
        }
        if rows.isEmpty {
            for key in ["content", "camps"] {
                if let array = object[key] as? [[String: Any]] { rows = array; break }
            }
        }

        var next: [String: String] = [:]
        for row in rows {
            let code = ["code", "campCode", "workplaceCode"].compactMap { row[$0] as? String }.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !code.isEmpty else { continue }
            let name = ["name", "campName", "workplaceName", "displayName"].compactMap { row[$0] as? String }.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines) ?? code
            next[code] = name
        }
        campCatalog = next
        rebuildCampSelector()
    }

    private func rebuildCampSelector() {
        guard !vendorCampCodes.isEmpty, !campCatalog.isEmpty else { return }
        let next = vendorCampCodes.compactMap { code -> MetaCampOption? in
            guard let name = campCatalog[code] else { return nil }
            return MetaCampOption(code: code, label: name)
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }

        guard !next.isEmpty else {
            statusText = "계약 캠프와 META 캠프 목록의 코드가 매칭되지 않습니다."
            return
        }
        camps = next
        if !next.contains(where: { $0.code == selectedCampCode }) {
            selectedCampCode = next[0].code
        }
        showBrowser = false
        statusText = "META 캠프 \(next.count)개 확인 · 주간 또는 야간을 선택해 주세요."
    }

    private func consumeSearch(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              let rawData = try? JSONSerialization.data(withJSONObject: object),
              let fingerprint = String(data: rawData, encoding: .utf8),
              fingerprint != lastSearchFingerprint else { return }
        lastSearchFingerprint = fingerprint

        guard let data = object["data"] as? [String: Any],
              let content = data["content"] as? [[String: Any]],
              let camp = selectedCamp else {
            isLoading = false
            statusText = "META 응답 형식을 확인하지 못했습니다."
            return
        }

        let wave = selectedWave
        let scheduleDate = MetaScheduleDatePolicy.scheduleDate(wave: wave)
        if content.isEmpty {
            model = MetaRealtimeModel(
                camp: camp.label,
                campCode: camp.code,
                wave: wave,
                scheduleDate: scheduleDate,
                fetchedAt: Self.fetchedAtNow(),
                delivery: MetaMetric(),
                returns: MetaMetric(),
                freshbag: MetaMetric(),
                rows: []
            )
            isLoading = false
            statusText = "\(scheduleDate) 조회 결과가 없습니다."
            return
        }

        Task {
            do {
                let schedule = try await loadSchedule(campCode: camp.code, wave: wave, scheduleDate: scheduleDate)
                let built = buildModel(content: content, schedule: schedule, camp: camp, wave: wave, scheduleDate: scheduleDate)
                model = built
                isLoading = false
                statusText = "\(scheduleDate) 기준 · 미스캔=위탁 · 배송중=스캔 · 주황=담당 서서브 확인 · 빨강=외부 라우트"
            } catch {
                isLoading = false
                statusText = "스케줄 비교 데이터를 불러오지 못했습니다: \(error.localizedDescription)"
            }
        }
    }

    private func loadSchedule(campCode: String, wave: String, scheduleDate: String) async throws -> [String: Any] {
        let session = try await SupabaseService.shared.client.auth.session
        let url = AppConfig.supabaseURL.appendingPathComponent("rest/v1/rpc/mw_meta_realtime_schedule")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "p_camp_code": campCode,
            "p_wave": wave,
            "p_schedule_date": scheduleDate
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MetaRealtimeError.invalidScheduleResponse }
        guard (200...299).contains(http.statusCode) else {
            throw MetaRealtimeError.scheduleServer(http.statusCode)
        }
        let object = try JSONSerialization.jsonObject(with: data)
        if let dictionary = object as? [String: Any] { return dictionary }
        if let array = object as? [[String: Any]], let first = array.first { return first }
        throw MetaRealtimeError.invalidScheduleResponse
    }

    private func buildModel(
        content: [[String: Any]],
        schedule: [String: Any],
        camp: MetaCampOption,
        wave: String,
        scheduleDate: String
    ) -> MetaRealtimeModel {
        let assignments = schedule["assignments"] as? [[String: Any]] ?? []
        let ownRoutesRaw = schedule["routes"] as? [Any] ?? []
        var exactOwners: [String: String] = [:]
        var scheduledRoutesByDriver: [String: [String]] = [:]

        for assignment in assignments {
            let route = MetaRouteDisplayPolicy.normalize(Self.string(assignment["route"]))
            let driver = Self.string(assignment["driver"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !route.isEmpty, !driver.isEmpty else { continue }
            exactOwners[route] = driver
            let displayRoute = MetaRouteDisplayPolicy.toSubRoute(route)
            if !displayRoute.isEmpty, scheduledRoutesByDriver[driver, default: []].contains(displayRoute) == false {
                scheduledRoutesByDriver[driver, default: []].append(displayRoute)
            }
        }

        let ownRoutes = Set(ownRoutesRaw.map { MetaRouteDisplayPolicy.normalize(Self.string($0)) }.filter { !$0.isEmpty })

        func ownerOf(_ route: String) -> String {
            if let exact = exactOwners[route] { return exact }
            return exactOwners
                .filter { route.hasPrefix($0.key) }
                .max { $0.key.count < $1.key.count }?
                .value ?? ""
        }

        func isOwnRoute(_ route: String) -> Bool {
            if ownRoutes.contains(route) { return true }
            return exactOwners.keys.contains { $0.count == 4 && route.hasPrefix($0) }
        }

        var totalDelivery = MetaMetric()
        var totalReturns = MetaMetric()
        var totalFreshbag = MetaMetric()
        var output: [MetaDriverRow] = []

        for source in content {
            let worker = source["workerInfo"] as? [String: Any] ?? [:]
            let delivery = Self.deliveryMetric(source["deliverySummary"] as? [String: Any])
            let returns = Self.collectionMetric(source["returnSummary"] as? [String: Any], includeAbsent: true)
            let freshbag = Self.collectionMetric(source["freshbagSummary"] as? [String: Any], includeAbsent: false)
            totalDelivery.add(delivery)
            totalReturns.add(returns)
            totalFreshbag.add(freshbag)

            let routeValues = worker["workSubRoutes"] as? [Any] ?? []
            let routes = routeValues.map { MetaRouteDisplayPolicy.normalize(Self.string($0)) }.filter { !$0.isEmpty }
            let owners = Dictionary(uniqueKeysWithValues: routes.map { ($0, ownerOf($0)) })
            let ownerCounts = Dictionary(grouping: owners.values.filter { !$0.isEmpty }, by: { $0 }).mapValues(\.count)
            let majorityDriver = ownerCounts.sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }.first?.key ?? ""
            let apiDriver = ["workerName", "name", "workerDisplayName"]
                .map { Self.string(worker[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? ""

            var routeRows: [MetaRouteRow] = []
            var hasExternal = false
            var hasMismatch = false
            for route in routes {
                let owner = owners[route] ?? ""
                let state: MetaRouteState
                if !isOwnRoute(route) {
                    state = .external
                    hasExternal = true
                } else if !majorityDriver.isEmpty, !owner.isEmpty, owner != majorityDriver {
                    state = .mismatch
                    hasMismatch = true
                } else {
                    state = .ok
                }
                routeRows.append(MetaRouteRow(route: route, owner: owner, status: state))
            }

            let resolvedDriver = !majorityDriver.isEmpty ? majorityDriver : (!apiDriver.isEmpty ? apiDriver : "담당 확인")
            let scheduleRoute = scheduledRoutesByDriver[resolvedDriver, default: []].joined(separator: ", ")
            let rowState: MetaRouteState = hasExternal ? .external : (hasMismatch ? .mismatch : .ok)
            output.append(MetaDriverRow(
                driver: resolvedDriver,
                scheduleRoute: scheduleRoute,
                status: rowState,
                routes: routeRows,
                delivery: delivery,
                returns: returns,
                freshbag: freshbag
            ))
        }

        output.sort {
            if $0.delivery.ratio != $1.delivery.ratio { return $0.delivery.ratio < $1.delivery.ratio }
            return $0.driver.localizedStandardCompare($1.driver) == .orderedAscending
        }

        return MetaRealtimeModel(
            camp: camp.label,
            campCode: camp.code,
            wave: wave,
            scheduleDate: scheduleDate,
            fetchedAt: Self.fetchedAtNow(),
            delivery: totalDelivery,
            returns: totalReturns,
            freshbag: totalFreshbag,
            rows: output
        )
    }

    private static func deliveryMetric(_ summary: [String: Any]?) -> MetaMetric {
        let assigned = int(summary?["assignedCount"])
        let scanned = int(summary?["scannedCount"])
        let completed = int(summary?["completedCount"])
        let impossible = int(summary?["impossibleCount"])
        let pddMiss = int(summary?["pddMissCount"])
        return MetaMetric(
            total: assigned + scanned + completed + impossible + pddMiss,
            completed: completed,
            remaining: scanned,
            misscan: assigned,
            impossible: impossible,
            pddMiss: pddMiss
        )
    }

    private static func collectionMetric(_ summary: [String: Any]?, includeAbsent: Bool) -> MetaMetric {
        let assigned = int(summary?["assignedCount"])
        let collected = int(summary?["collectedCount"])
        let uncollected = int(summary?["uncollectedCount"])
        let absent = includeAbsent ? int(summary?["absentCount"]) : 0
        let total = assigned + collected + uncollected + absent
        return MetaMetric(total: total, completed: collected, remaining: max(total - collected, 0))
    }

    private static func int(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) ?? 0 }
        return 0
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private static func fetchedAtNow() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    private static func isAllowedCoupangHost(_ host: String?) -> Bool {
        guard let value = host?.lowercased() else { return false }
        return value == "coupang.com" || value.hasSuffix(".coupang.com") || value == "coupang.net" || value.hasSuffix(".coupang.net")
    }

    private static let bridgeName = "maroowellMeta"
    private static let flyBaseURL = URL(string: "https://fly.coupang.com")!
    private static let realtimeURL = URL(string: "https://fly.coupang.com/ui/dashboard/realtime")!
    private static let desktopUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36"

    private static let loginStateScript = #"""
    (function(){
      try {
        var hasPassword = !!document.querySelector('input[type=password]');
        var text = (document.body && document.body.innerText || '').slice(0,3000);
        var looksLogin = hasPassword || (/로그인|sign\s*in/i.test(text) && document.querySelectorAll('input').length > 0);
        if (!looksLogin && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.maroowellMeta) {
          window.webkit.messageHandlers.maroowellMeta.postMessage({name:'onAuthenticated', payload:{}});
        }
      } catch(e) {}
    })();
    """#

    private static let metaBridgeScript = #"""
    (function(){
      const SEARCH_URL = '/realtime-dashboard/workers/work-status/search';
      function post(name, payload){
        try {
          const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.maroowellMeta;
          if (handler) handler.postMessage({name:name, payload:payload});
        } catch(_) {}
      }
      function contextKind(url){
        const value = String(url || '');
        if (/my-vendor(?:\?|$)/.test(value)) return 'vendor';
        if (/\/camps(?:\?|$)/.test(value)) return 'camps';
        return '';
      }
      function deliverContext(url, payload){
        const kind = contextKind(url);
        if (!kind) return;
        try {
          const obj = typeof payload === 'string' ? JSON.parse(payload) : payload;
          post(kind === 'vendor' ? 'onVendorResponse' : 'onCampsResponse', obj);
        } catch(_) {}
      }
      function headersObject(source){
        const out = {};
        try {
          const headers = new Headers(source || {});
          headers.forEach(function(value, key){ out[key] = value; });
        } catch(_) {}
        return out;
      }
      function rememberSessionHeaders(source){
        const next = headersObject(source);
        const keys = Object.keys(next);
        if (!keys.length) return;
        const current = window.__mwMetaSessionHeaders || {};
        keys.forEach(function(key){
          const lower = String(key).toLowerCase();
          if (!['content-length','cookie','host','origin','referer'].includes(lower) && lower.indexOf('sec-') !== 0) current[key] = next[key];
        });
        window.__mwMetaSessionHeaders = current;
      }
      function notifyAuthExpired(status){ post('onAuthExpired', String(status || '403')); }
      function rememberTemplate(url, method, headers, body){
        if (String(url || '').indexOf(SEARCH_URL) < 0 || !body) return;
        try {
          const parsed = typeof body === 'string' ? JSON.parse(body) : body;
          if (!parsed || typeof parsed !== 'object') return;
          window.__mwMetaSearchTemplate = {url:String(url || SEARCH_URL), method:String(method || 'POST'), headers:headersObject(headers), body:parsed};
        } catch(_) {}
      }
      async function rememberFetchTemplate(input, init, url){
        try {
          const method = (init && init.method) || (input && input.method) || 'POST';
          const headers = (init && init.headers) || (input && input.headers) || {};
          let body = init && init.body;
          if (!body && input && typeof input.clone === 'function') body = await input.clone().text();
          rememberTemplate(url, method, headers, body);
        } catch(_) {}
      }
      if (!window.__mwMetaFetchHookInstalled) {
        window.__mwMetaFetchHookInstalled = true;
        const originalFetch = window.fetch;
        if (originalFetch) {
          window.__mwMetaOriginalFetch = originalFetch;
          window.fetch = async function(){
            const args = arguments;
            const input = args[0];
            const init = args[1] || {};
            const url = typeof input === 'string' ? input : ((input && input.url) || '');
            const requestHeaders = (init && init.headers) || (input && input.headers) || {};
            if (contextKind(url) || String(url).indexOf(SEARCH_URL) >= 0) rememberSessionHeaders(requestHeaders);
            if (String(url).indexOf(SEARCH_URL) >= 0) rememberFetchTemplate(input, init, url).catch(function(){});
            const response = await originalFetch.apply(this, args);
            if (response.status === 401 || response.status === 403) { notifyAuthExpired(response.status); return response; }
            if (contextKind(url)) {
              try { response.clone().text().then(function(body){ deliverContext(url, body); }).catch(function(){}); } catch(_) {}
            }
            return response;
          };
        }
        const XHR = window.XMLHttpRequest;
        if (XHR && XHR.prototype) {
          const originalOpen = XHR.prototype.open;
          const originalSend = XHR.prototype.send;
          const originalSetRequestHeader = XHR.prototype.setRequestHeader;
          XHR.prototype.open = function(method, url){
            this.__mwUrl = String(url || '');
            this.__mwMethod = String(method || 'POST');
            this.__mwHeaders = {};
            return originalOpen.apply(this, arguments);
          };
          XHR.prototype.setRequestHeader = function(name, value){
            try { this.__mwHeaders[String(name)] = String(value); } catch(_) {}
            return originalSetRequestHeader.apply(this, arguments);
          };
          XHR.prototype.send = function(body){
            if (contextKind(this.__mwUrl) || String(this.__mwUrl || '').indexOf(SEARCH_URL) >= 0) rememberSessionHeaders(this.__mwHeaders);
            if (String(this.__mwUrl || '').indexOf(SEARCH_URL) >= 0) rememberTemplate(this.__mwUrl, this.__mwMethod, this.__mwHeaders, body);
            this.addEventListener('load', function(){
              try {
                if (this.status === 401 || this.status === 403) { notifyAuthExpired(this.status); return; }
                if (contextKind(this.__mwUrl) && typeof this.responseText === 'string') deliverContext(this.__mwUrl, this.responseText);
              } catch(_) {}
            });
            return originalSend.apply(this, arguments);
          };
        }
      }
      function requestBody(templateBody, payload, page){
        const base = JSON.parse(JSON.stringify(templateBody || {}));
        const wanted = JSON.parse(JSON.stringify(payload || {}));
        Object.keys(wanted).forEach(function(key){ base[key] = wanted[key]; });
        base.page = page;
        return base;
      }
      window.__mwMetaSearch = async function(payload){
        const captured = window.__mwMetaSearchTemplate;
        const originalFetch = window.__mwMetaOriginalFetch || window.fetch;
        if (!originalFetch) { post('onSearchError', 'META 조회 기능을 초기화하지 못했습니다. META 화면을 다시 열어 주세요.'); return false; }
        const fallbackHeaders = Object.assign({}, window.__mwMetaSessionHeaders || {}, {
          'Accept':'application/json',
          'Content-Type':'application/json;charset=UTF-8',
          'X-Coupang-Accept-Language':'ko-KR',
          'X-Requested-With':'XMLHttpRequest'
        });
        const template = captured || {url:SEARCH_URL, method:'POST', headers:fallbackHeaders, body:{}};
        try {
          async function postPage(page){
            const body = requestBody(template.body, payload, page);
            const response = await originalFetch(template.url || SEARCH_URL, {
              method:template.method || 'POST', credentials:'include',
              headers:template.headers && Object.keys(template.headers).length ? template.headers : fallbackHeaders,
              body:JSON.stringify(body)
            });
            const bodyText = await response.text();
            if (response.status === 401 || response.status === 403) { notifyAuthExpired(response.status); throw new Error('AUTH_EXPIRED'); }
            if (!response.ok) throw new Error('HTTP ' + response.status + ' ' + bodyText.slice(0,120));
            return JSON.parse(bodyText);
          }
          const first = await postPage(0);
          const data = first && first.data ? first.data : {};
          const merged = Array.isArray(data.content) ? data.content.slice() : [];
          const pages = Math.min(Math.max(Number(data.totalPages || 1), 1), 50);
          for (let page = 1; page < pages; page++) {
            const next = await postPage(page);
            const rows = next && next.data && Array.isArray(next.data.content) ? next.data.content : [];
            merged.push.apply(merged, rows);
          }
          if (!first.data) first.data = {};
          first.data.content = merged;
          first.data.number = 0;
          first.data.size = merged.length;
          first.data.totalElements = merged.length;
          first.data.totalPages = 1;
          post('onSearchResponse', first);
          return true;
        } catch(e) {
          if (String(e && e.message || e) === 'AUTH_EXPIRED') return false;
          post('onSearchError', String(e && e.message || e));
          return false;
        }
      };
    })();
    """#
}

private final class MetaWeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

private enum MetaRealtimeError: LocalizedError {
    case invalidScheduleResponse
    case scheduleServer(Int)

    var errorDescription: String? {
        switch self {
        case .invalidScheduleResponse:
            return "스케줄 비교 응답 형식을 확인하지 못했습니다."
        case .scheduleServer(let code):
            return "스케줄 비교 데이터 조회 실패 (\(code))"
        }
    }
}

private extension MetaMetric {
    mutating func add(_ other: MetaMetric) {
        total += other.total
        completed += other.completed
        remaining += other.remaining
        misscan += other.misscan
        impossible += other.impossible
        pddMiss += other.pddMiss
    }
}
