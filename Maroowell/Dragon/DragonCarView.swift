import Foundation
import SwiftUI

struct DragonCarView: View {
    let session: AppSession
    @StateObject private var store = DragonCarStore()
    @State private var editing: DragonCarRow?
    @State private var adding = false

    var body: some View {
        Group {
            if session.canView("/dragon_car_index") { content }
            else { denied }
        }
        .navigationTitle("용차")
        .navigationBarTitleDisplayMode(.inline)
        .task { if store.rows.isEmpty { await store.load() } }
        .sheet(item: $editing) { row in DragonCarEditor(store: store, row: row, isNew: false) }
        .sheet(isPresented: $adding) { DragonCarEditor(store: store, row: .new(for: store.cycle), isNew: true) }
        .alert("용차", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if store.loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 5) }
            VStack(spacing: 8) {
                HStack {
                    Text(store.cycle.monthLabel).font(.title3.weight(.black)).foregroundStyle(MaroowellTheme.ink)
                    Spacer()
                    Button("이전") { Task { store.move(-1); await store.load() } }.buttonStyle(.bordered)
                    Button("이번달") { Task { store.resetCycle(); await store.load() } }.buttonStyle(.bordered)
                    Button("다음") { Task { store.move(1); await store.load() } }.buttonStyle(.bordered)
                }
                Text(store.cycle.periodLabel).font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                Text("\(store.rows.count)건 · 배송 \(store.parcel.formatted()) · 반품 \(store.returns.formatted()) · 금액 \(DragonCarFormat.won(store.amount))")
                    .font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                Button { adding = true } label: { Label("용차 등록", systemImage: "plus").frame(maxWidth: .infinity).frame(height: 42) }.buttonStyle(.borderedProminent)
            }.padding(14).background(Color.white)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.rows.isEmpty && !store.loading {
                        Text("\(store.cycle.monthLabel) 용차 데이터가 없습니다.").foregroundStyle(MaroowellTheme.muted).padding(.vertical, 40)
                    }
                    ForEach(store.rows) { row in
                        Button { editing = row } label: { card(row) }.buttonStyle(.plain)
                    }
                }.padding(12)
            }.background(MaroowellTheme.background)
        }
    }

    private func card(_ row: DragonCarRow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(row.orderDate.replacingOccurrences(of: "-", with: "."))  ·  \(row.deliveryDriver.isEmpty ? (row.orderName.isEmpty ? "기사 미입력" : row.orderName) : row.deliveryDriver)")
                .font(.headline.weight(.black)).foregroundStyle(MaroowellTheme.ink)
            Text([row.orderVendor, row.camp, row.wave, row.route].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(MaroowellTheme.muted)
            Text("배송 \(row.parcel.formatted()) · 반품 \(row.returnCount.formatted()) · 단가 \(DragonCarFormat.won(row.price)) · \(DragonCarFormat.won(row.calculatedAmount))")
                .font(.caption.weight(.black)).foregroundStyle(Color(red: 0.25, green: 0.40, blue: 0.44))
            Text("세금계산서 \(row.taxInvoice ? "발행" : "미발행") · 입금 \(row.paymentConfirm ? "확인" : "대기")\(row.note.isEmpty ? "" : " · \(row.note)")")
                .font(.caption2).foregroundStyle(MaroowellTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
    }

    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("용차 관리 권한이 필요합니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

@MainActor private final class DragonCarStore: ObservableObject {
    @Published var cycle = DragonSettlementCycle.current()
    @Published var rows: [DragonCarRow] = []
    @Published var loading = false
    @Published var message: String?
    private let api = DragonCarAPI()
    var parcel: Int { rows.reduce(0) { $0 + $1.parcel } }
    var returns: Int { rows.reduce(0) { $0 + $1.returnCount } }
    var amount: Double { rows.reduce(0) { $0 + $1.calculatedAmount } }

    func load() async {
        loading = true; defer { loading = false }
        do { rows = try await api.load(start: cycle.start, end: cycle.end).sorted { ($0.orderDate, $0.id) > ($1.orderDate, $1.id) } }
        catch { rows = []; message = error.localizedDescription }
    }
    func move(_ delta: Int) { cycle = cycle.moved(delta) }
    func resetCycle() { cycle = .current() }
    func save(_ row: DragonCarRow, isNew: Bool) async -> Bool {
        loading = true; defer { loading = false }
        do { try await api.save(row, isNew: isNew); await load(); return true } catch { message = error.localizedDescription; return false }
    }
    func delete(_ row: DragonCarRow) async -> Bool {
        loading = true; defer { loading = false }
        do { try await api.delete(row.id); await load(); return true } catch { message = error.localizedDescription; return false }
    }
}

private struct DragonCarEditor: View {
    @ObservedObject var store: DragonCarStore
    let row: DragonCarRow; let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DragonCarDraft
    @State private var confirmDelete = false
    init(store: DragonCarStore, row: DragonCarRow, isNew: Bool) { self.store=store; self.row=row; self.isNew=isNew; _draft=State(initialValue: .init(row)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("배차") {
                    DatePicker("날짜", selection: $draft.date, displayedComponents: .date)
                    TextField("벤더", text: $draft.vendor); TextField("캠프", text: $draft.camp); TextField("주/야", text: $draft.wave)
                    TextField("라우트", text: $draft.route, axis: .vertical); TextField("기사", text: $draft.driver)
                }
                Section("수량·단가") {
                    TextField("배송", text: $draft.parcel).keyboardType(.numberPad)
                    TextField("반품", text: $draft.returns).keyboardType(.numberPad)
                    TextField("단가", text: $draft.price).keyboardType(.decimalPad)
                    TextField("비고", text: $draft.note, axis: .vertical)
                }
                if !isNew { Section { Button("삭제", role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(isNew ? "용차 등록" : "용차 수정").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { Task { if await store.save(draft.row(id: row.id, cycle: store.cycle, flags: row), isNew: isNew) { dismiss() } } }.disabled(store.loading) }
            }
            .confirmationDialog("이 용차 데이터를 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { if await store.delete(row) { dismiss() } } }
            }
        }
    }
}

private struct DragonCarDraft {
    var date: Date; var vendor, camp, wave, route, driver, parcel, returns, price, note: String
    init(_ row: DragonCarRow) {
        date = DragonCarFormat.date(row.orderDate) ?? Date(); vendor=row.orderVendor; camp=row.camp; wave=row.wave; route=row.route; driver=row.deliveryDriver
        parcel=String(row.parcel); returns=String(row.returnCount); price=String(Int64(row.price)); note=row.note
    }
    func row(id: Int64, cycle: DragonSettlementCycle, flags: DragonCarRow) -> DragonCarRow {
        let p=Int(parcel.replacingOccurrences(of: ",", with: "")) ?? 0, r=Int(returns.replacingOccurrences(of: ",", with: "")) ?? 0, pr=Double(price.replacingOccurrences(of: ",", with: "")) ?? 0
        return .init(id:id, orderDate:DragonCarFormat.iso(date), orderName:flags.orderName, orderVendor:vendor, camp:camp, wave:wave, route:route, price:pr, deliveryDriver:driver, parcel:p, returnCount:r, amount:Double(p+r)*pr, settlementMonth:cycle.monthKey, taxInvoice:flags.taxInvoice, paymentConfirm:flags.paymentConfirm, note:note)
    }
}

private struct DragonCarRow: Identifiable, Hashable {
    let id: Int64; let orderDate, orderName, orderVendor, camp, wave, route: String; let price: Double; let deliveryDriver: String
    let parcel, returnCount: Int; let amount: Double; let settlementMonth: String; let taxInvoice, paymentConfirm: Bool; let note: String
    var calculatedAmount: Double { amount != 0 ? amount : Double(parcel + returnCount) * price }
    static func new(for cycle: DragonSettlementCycle) -> Self { .init(id:0, orderDate:DragonCarFormat.iso(Date()), orderName:"", orderVendor:"", camp:"", wave:"", route:"", price:0, deliveryDriver:"", parcel:0, returnCount:0, amount:0, settlementMonth:cycle.monthKey, taxInvoice:false, paymentConfirm:false, note:"") }
}

private struct DragonSettlementCycle: Hashable {
    let year, month: Int; let start, end, monthKey, monthLabel, periodLabel: String
    static func make(_ year: Int, _ month: Int) -> Self {
        let prevY = month == 1 ? year-1 : year, prevM = month == 1 ? 12 : month-1
        let start=String(format:"%04d-%02d-26",prevY,prevM), end=String(format:"%04d-%02d-25",year,month)
        return .init(year:year, month:month, start:start, end:end, monthKey:String(format:"%04d-%02d",year,month), monthLabel:"\(year)년 \(month)월", periodLabel:"\(start) ~ \(end)")
    }
    static func current() -> Self {
        var cal=Calendar(identifier:.gregorian); cal.timeZone=TimeZone(identifier:"Asia/Seoul") ?? .current
        let now=Date(), d=cal.component(.day,from:now); var y=cal.component(.year,from:now), m=cal.component(.month,from:now)
        if d >= 26 { m += 1; if m == 13 { m=1; y += 1 } }; return make(y,m)
    }
    func moved(_ delta: Int) -> Self { var total=year*12+(month-1)+delta; let y=total/12, m=total%12+1; return .make(y,m) }
}

private struct DragonCarAPI {
    private let client = SupabaseService.shared.client
    private var base: URL { AppConfig.supabaseURL.appendingPathComponent("rest/v1/dragon_car") }
    func load(start: String, end: String) async throws -> [DragonCarRow] {
        var c=URLComponents(url:base,resolvingAgainstBaseURL:false)!; c.query="select=id,order_date,order_name,order_vendor,camp,wave,route,price,delivery_driver,parcel,return_count,amount,settlement_month,tax_invoice,payment_confirm,dragon_car_note&order_date=gte.\(start)&order_date=lte.\(end)&order=order_date.desc,id.desc"
        let d=try await request(c.url!,method:"GET"); let a=try JSONSerialization.jsonObject(with:d) as? [[String:Any]] ?? []
        return a.map { o in .init(id:i64(o["id"]),orderDate:t(o["order_date"]),orderName:t(o["order_name"]),orderVendor:t(o["order_vendor"]),camp:t(o["camp"]),wave:t(o["wave"]),route:t(o["route"]),price:dbl(o["price"]),deliveryDriver:t(o["delivery_driver"]),parcel:Int(i64(o["parcel"])),returnCount:Int(i64(o["return_count"])),amount:dbl(o["amount"]),settlementMonth:t(o["settlement_month"]),taxInvoice:bool(o["tax_invoice"]),paymentConfirm:bool(o["payment_confirm"]),note:t(o["dragon_car_note"])) }
    }
    func save(_ row: DragonCarRow, isNew: Bool) async throws {
        var url=base; if !isNew { var c=URLComponents(url:base,resolvingAgainstBaseURL:false)!; c.query="id=eq.\(row.id)"; url=c.url! }
        let body:[String:Any]=["order_date":row.orderDate,"order_vendor":null(row.orderVendor),"camp":null(row.camp),"wave":null(row.wave),"route":null(row.route),"delivery_driver":null(row.deliveryDriver),"parcel":row.parcel,"return_count":row.returnCount,"price":row.price,"amount":row.calculatedAmount,"settlement_month":row.settlementMonth,"dragon_car_note":null(row.note),"tax_invoice":row.taxInvoice,"payment_confirm":row.paymentConfirm]
        _=try await request(url,method:isNew ? "POST":"PATCH",body:body,prefer:"return=minimal")
    }
    func delete(_ id:Int64) async throws { var c=URLComponents(url:base,resolvingAgainstBaseURL:false)!; c.query="id=eq.\(id)"; _=try await request(c.url!,method:"DELETE") }
    private func request(_ url:URL,method:String,body:[String:Any]?=nil,prefer:String?=nil) async throws -> Data {
        let auth=try await client.auth.session; var r=URLRequest(url:url); r.httpMethod=method; r.timeoutInterval=30; r.setValue("application/json",forHTTPHeaderField:"Accept"); r.setValue(AppConfig.supabasePublishableKey,forHTTPHeaderField:"apikey"); r.setValue("Bearer \(auth.accessToken)",forHTTPHeaderField:"Authorization"); if let prefer{r.setValue(prefer,forHTTPHeaderField:"Prefer")}; if let body{r.setValue("application/json",forHTTPHeaderField:"Content-Type");r.httpBody=try JSONSerialization.data(withJSONObject:body)}; let (d,res)=try await URLSession.shared.data(for:r); guard let h=res as? HTTPURLResponse,(200..<300).contains(h.statusCode) else{throw NSError(domain:"DragonCar",code:1,userInfo:[NSLocalizedDescriptionKey:"용차 요청에 실패했습니다."])}; return d
    }
    private func t(_ v:Any?)->String{if let s=v as? String{return s};if let n=v as? NSNumber{return n.stringValue};return ""}; private func i64(_ v:Any?)->Int64{if let n=v as? NSNumber{return n.int64Value};return Int64(t(v)) ?? 0}; private func dbl(_ v:Any?)->Double{if let n=v as? NSNumber{return n.doubleValue};return Double(t(v)) ?? 0}; private func bool(_ v:Any?)->Bool{if let b=v as? Bool{return b};if let n=v as? NSNumber{return n.boolValue};return false}; private func null(_ v:String)->Any{v.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? NSNull():v.trimmingCharacters(in:.whitespacesAndNewlines)}
}

private enum DragonCarFormat {
    static func iso(_ date:Date)->String{let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(identifier:"Asia/Seoul");f.dateFormat="yyyy-MM-dd";return f.string(from:date)}
    static func date(_ s:String)->Date?{let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(identifier:"Asia/Seoul");f.dateFormat="yyyy-MM-dd";return f.date(from:s)}
    static func won(_ v:Double)->String{let f=NumberFormatter();f.numberStyle = .decimal; return "\(f.string(from:NSNumber(value:Int64(v))) ?? String(Int64(v)))원"}
}
