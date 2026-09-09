import Foundation
import SwiftUI

struct DragonScheduleView: View {
    let session: AppSession
    @StateObject private var store = DragonScheduleStore()

    var body: some View {
        Group {
            if session.canView("/dragon_car_schedule") { content }
            else { denied }
        }
        .navigationTitle("용차 스케줄")
        .navigationBarTitleDisplayMode(.inline)
        .task { if store.drivers.isEmpty { await store.load() } }
        .alert("용차 스케줄", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if store.loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 5) }
            HStack(spacing: 7) {
                Button("이전주") { Task { store.changeWeek(-7); await store.load() } }.buttonStyle(.bordered)
                Button("이번주") { Task { store.resetWeek(); await store.load() } }.buttonStyle(.bordered)
                Button("다음주") { Task { store.changeWeek(7); await store.load() } }.buttonStyle(.bordered)
                Spacer()
                Button("저장") { Task { await store.save() } }.buttonStyle(.borderedProminent).disabled(store.staged.isEmpty || store.loading)
            }.padding(12).background(Color.white)
            Text("\(DragonScheduleDate.range(store.weekStart)) · 기사 \(store.drivers.count)명 · 미저장 \(store.staged.count)")
                .font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 8).background(Color.white)

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        header("용차 기사", width: 150)
                        ForEach(store.dates, id: \.self) { header(DragonScheduleDate.dayLabel($0), width: 112) }
                    }
                    ForEach(store.drivers) { driver in
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(driver.displayName).font(.subheadline.weight(.black))
                                if !driver.coupangID.isEmpty { Text(driver.coupangID).font(.caption2).foregroundStyle(MaroowellTheme.muted) }
                                if !driver.vehicle.isEmpty { Text(driver.vehicle).font(.caption2).foregroundStyle(MaroowellTheme.muted) }
                            }.frame(width: 150, height: 72, alignment: .leading).padding(.horizontal, 8)
                                .background(Color.white).overlay { Rectangle().stroke(MaroowellTheme.border) }
                            ForEach(store.dates, id: \.self) { date in
                                let status = store.status(driver: driver, date: date)
                                Button { if !status.protected { store.cycle(driver: driver, date: date) } } label: {
                                    VStack(spacing: 3) {
                                        Text(status.label).font(.caption.weight(.black))
                                        if !status.sub.isEmpty { Text(status.sub).font(.system(size: 9)).lineLimit(2).minimumScaleFactor(0.7) }
                                    }.frame(width: 112, height: 72)
                                        .foregroundStyle(status.foreground).background(status.background)
                                        .overlay { Rectangle().stroke(MaroowellTheme.border) }
                                }.buttonStyle(.plain).disabled(status.protected)
                            }
                        }
                    }
                    if store.drivers.isEmpty && !store.loading { Text("표시할 용차 기사가 없습니다.").foregroundStyle(MaroowellTheme.muted).padding(40) }
                }.padding(12)
            }.background(MaroowellTheme.background)
        }
    }

    private func header(_ text: String, width: CGFloat) -> some View {
        Text(text).font(.caption.weight(.black)).frame(width: width, height: 48)
            .background(Color(red: 0.93, green: 0.96, blue: 0.97)).overlay { Rectangle().stroke(MaroowellTheme.border) }
    }
    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("용차 스케줄 권한이 필요합니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

@MainActor private final class DragonScheduleStore: ObservableObject {
    @Published var weekStart = DragonScheduleDate.sunday(Date())
    @Published var drivers: [DragonScheduleDriver] = []
    @Published var manual: [DragonScheduleAssignment] = []
    @Published var normal: [DragonScheduleAssignment] = []
    @Published var records: [DragonScheduleRecord] = []
    @Published var staged: [String: DragonScheduleStage] = [:]
    @Published var loading = false
    @Published var message: String?
    private let api = DragonScheduleAPI()
    var dates: [String] { (0...6).compactMap { DragonScheduleDate.add(weekStart, $0) }.map(DragonScheduleDate.iso) }

    func load() async {
        loading = true; staged = [:]; defer { loading = false }
        do { let loaded = try await api.load(start: DragonScheduleDate.iso(weekStart), end: DragonScheduleDate.iso(DragonScheduleDate.add(weekStart, 6) ?? weekStart)); drivers=loaded.drivers; manual=loaded.manual; normal=loaded.normal; records=loaded.records }
        catch { drivers=[]; manual=[]; normal=[]; records=[]; message=error.localizedDescription }
    }
    func changeWeek(_ days: Int) { weekStart = DragonScheduleDate.add(weekStart, days) ?? weekStart }
    func resetWeek() { weekStart = DragonScheduleDate.sunday(Date()) }
    func status(driver: DragonScheduleDriver, date: String) -> DragonScheduleStatus {
        if let s=staged[key(driver,date)] { return s.deleted ? .free : (s.status == "휴무" ? .off : .work) }
        let m=manual.first { $0.date==date && $0.routeLabel==driver.key }
        let assignments=normal.filter { $0.date==date && $0.matches(driver) }
        let recs=records.filter { $0.date==date && $0.matches(driver) }
        if m?.status.contains("휴무") == true { if !assignments.isEmpty || !recs.isEmpty { return .warn }; return .off }
        if let r=recs.first { return .protected(label:r.camp.isEmpty ? "배정":r.camp, sub:r.route) }
        if let a=assignments.first { return .protected(label:a.camp.isEmpty ? "배정":a.camp, sub:a.routeLabel) }
        if m != nil { return .work }; return .free
    }
    func cycle(driver: DragonScheduleDriver, date: String) {
        let current=status(driver:driver,date:date)
        let next: DragonScheduleStage
        if current.label == "여유" { next = .init(driver:driver,date:date,status:"출근",deleted:false) }
        else if current.label == "출근" { next = .init(driver:driver,date:date,status:"휴무",deleted:false) }
        else { next = .init(driver:driver,date:date,status:"",deleted:true) }
        staged[key(driver,date)] = next
    }
    func save() async {
        guard !staged.isEmpty else { message="저장할 변경사항이 없습니다."; return }
        loading=true; defer { loading=false }
        do { try await api.save(Array(staged.values), weekStart:weekStart); message="용차 스케줄 저장 완료"; await load() }
        catch { message=error.localizedDescription }
    }
    private func key(_ d:DragonScheduleDriver,_ date:String)->String { "\(date)|\(d.key)" }
}

private struct DragonScheduleDriver: Identifiable, Hashable {
    let pk:Int64; let name, phone, position, camp, wave, coupangID, vehicle:String
    var id:String { pk > 0 ? String(pk):name }
    var displayName:String { name == "이우람" ? "이대표" : (name == "장세인" ? "장이사":name) }
    var key:String { pk > 0 ? "DRIVER:\(pk)" : "DRIVER:\(name)" }
}
private struct DragonScheduleAssignment: Hashable { let date,camp,wave,routeLabel,driverName,driverDisplay,driverOwner,driverExport,driverID,status:String; func matches(_ d:DragonScheduleDriver)->Bool { let vals=[driverName,driverDisplay,driverOwner,driverExport,driverID].map(DragonScheduleNorm.key); return vals.contains(DragonScheduleNorm.key(d.name)) || (!d.coupangID.isEmpty && vals.contains(DragonScheduleNorm.key(d.coupangID))) } }
private struct DragonScheduleRecord: Hashable { let date,camp,route,driver,orderName:String; func matches(_ d:DragonScheduleDriver)->Bool { [driver,orderName].map(DragonScheduleNorm.key).contains(DragonScheduleNorm.key(d.name)) || [driver,orderName].map(DragonScheduleNorm.key).contains(DragonScheduleNorm.key(d.displayName)) } }
private struct DragonScheduleData { let drivers:[DragonScheduleDriver]; let manual,normal:[DragonScheduleAssignment]; let records:[DragonScheduleRecord] }
private struct DragonScheduleStage: Hashable { let driver:DragonScheduleDriver; let date,status:String; let deleted:Bool }
private struct DragonScheduleStatus { let label,sub:String; let protected:Bool; let background,foreground:Color
    static let free=Self(label:"여유",sub:"",protected:false,background:Color(red:0.97,green:0.98,blue:0.98),foreground:.secondary)
    static let work=Self(label:"출근",sub:"",protected:false,background:Color(red:0.93,green:0.98,blue:0.94),foreground:Color(red:0.18,green:0.48,blue:0.28))
    static let off=Self(label:"휴무",sub:"",protected:false,background:Color(red:1,green:0.94,blue:0.94),foreground:Color(red:0.70,green:0.32,blue:0.32))
    static let warn=Self(label:"휴무 충돌",sub:"배정 있음",protected:false,background:Color(red:1,green:0.96,blue:0.87),foreground:Color(red:0.60,green:0.43,blue:0))
    static func protected(label:String,sub:String)->Self{.init(label:label,sub:sub,protected:true,background:Color(red:0.91,green:0.95,blue:0.98),foreground:Color(red:0.21,green:0.42,blue:0.63))}
}

private struct DragonScheduleAPI {
    private let client=SupabaseService.shared.client
    func load(start:String,end:String) async throws -> DragonScheduleData {
        let drivers=try await table("maroowell_info",query:"select=pk_id,person_name,contact_phone,position_title,camp_code,wave,coupang_id,vehicle_plate_number&order=person_name.asc")
        let schedules=try await table("maroowell_schedule",query:"select=schedule_date,camp,wave,route_label,driver_name,driver_display_name,driver_owner_name,driver_export_name,driver_coupang_id,driver_account_type,is_active&schedule_date=gte.\(start)&schedule_date=lte.\(end)&is_active=eq.true&order=schedule_date.asc,row_order.asc")
        let records=try await table("dragon_car",query:"select=order_date,order_name,camp,route,delivery_driver&order_date=gte.\(start)&order_date=lte.\(end)&order=order_date.asc,id.asc")
        let ds=drivers.map { o in DragonScheduleDriver(pk:i(o["pk_id"]),name:t(o["person_name"]),phone:t(o["contact_phone"]),position:t(o["position_title"]),camp:t(o["camp_code"]),wave:t(o["wave"]),coupangID:t(o["coupang_id"]),vehicle:t(o["vehicle_plate_number"])) }.filter { !$0.name.isEmpty && (DragonScheduleNorm.key($0.camp)==DragonScheduleNorm.key("용차") || ["이우람","장세인","김용준"].contains($0.name)) && !DragonScheduleNorm.excluded($0.position) }
        let ss=schedules.map { o in DragonScheduleAssignment(date:t(o["schedule_date"]),camp:t(o["camp"]),wave:t(o["wave"]),routeLabel:t(o["route_label"]),driverName:t(o["driver_name"]),driverDisplay:t(o["driver_display_name"]),driverOwner:t(o["driver_owner_name"]),driverExport:t(o["driver_export_name"]),driverID:t(o["driver_coupang_id"]),status:t(o["driver_account_type"])) }
        let manual=ss.filter{DragonScheduleNorm.key($0.camp)==DragonScheduleNorm.key("용차") && DragonScheduleNorm.wave($0.wave)=="WAVE2"}; let normal=ss.filter{DragonScheduleNorm.key($0.camp) != DragonScheduleNorm.key("용차")}
        let rs=records.map { o in DragonScheduleRecord(date:t(o["order_date"]),camp:t(o["camp"]),route:t(o["route"]),driver:t(o["delivery_driver"]),orderName:t(o["order_name"])) }
        return .init(drivers:ds,manual:manual,normal:normal,records:rs)
    }
    func save(_ stages:[DragonScheduleStage],weekStart:Date) async throws {
        let auth=try await client.auth.session; let rows:[[String:Any]]=stages.map { s in ["schedule_date":s.date,"camp":"용차","wave":"WAVE2","route_label":s.driver.key,"driver_name":s.deleted ? NSNull():s.driver.name,"driver_display_name":s.deleted ? NSNull():s.driver.name,"driver_owner_name":s.deleted ? NSNull():s.driver.name,"driver_export_name":s.deleted ? NSNull():s.driver.name,"driver_coupang_id":s.deleted || s.driver.coupangID.isEmpty ? NSNull():s.driver.coupangID,"driver_account_type":s.deleted ? NSNull():s.status,"memo":NSNull(),"row_order":Int(s.driver.pk),"cell_color":NSNull(),"is_active":!s.deleted,"deleted":s.deleted] }
        var r=URLRequest(url:URL(string:"https://schedule.maroowell.com/schedule/save")!);r.httpMethod="POST";r.timeoutInterval=30;r.setValue("application/json",forHTTPHeaderField:"Content-Type");r.setValue("Bearer \(auth.accessToken)",forHTTPHeaderField:"Authorization");r.httpBody=try JSONSerialization.data(withJSONObject:["rows":rows]);let (_,res)=try await URLSession.shared.data(for:r);guard let h=res as? HTTPURLResponse,(200..<300).contains(h.statusCode) else{throw NSError(domain:"DragonSchedule",code:1,userInfo:[NSLocalizedDescriptionKey:"스케줄 저장 실패"])}
    }
    private func table(_ name:String,query:String) async throws -> [[String:Any]] { var c=URLComponents(url:AppConfig.supabaseURL.appendingPathComponent("rest/v1/\(name)"),resolvingAgainstBaseURL:false)!;c.query=query;let auth=try await client.auth.session;var r=URLRequest(url:c.url!);r.setValue("application/json",forHTTPHeaderField:"Accept");r.setValue(AppConfig.supabasePublishableKey,forHTTPHeaderField:"apikey");r.setValue("Bearer \(auth.accessToken)",forHTTPHeaderField:"Authorization");let(d,res)=try await URLSession.shared.data(for:r);guard let h=res as? HTTPURLResponse,(200..<300).contains(h.statusCode) else{throw NSError(domain:"DragonSchedule",code:1,userInfo:[NSLocalizedDescriptionKey:"용차 스케줄 조회 실패"])};return try JSONSerialization.jsonObject(with:d) as? [[String:Any]] ?? [] }
    private func t(_ v:Any?)->String{if let s=v as? String{return s};if let n=v as? NSNumber{return n.stringValue};return ""};private func i(_ v:Any?)->Int64{if let n=v as? NSNumber{return n.int64Value};return Int64(t(v)) ?? 0}
}

private enum DragonScheduleNorm { static func key(_ v:String)->String{v.replacingOccurrences(of:"\\s+",with:"",options:.regularExpression).uppercased()};static func wave(_ v:String)->String{["야간","NIGHT","N","W1","WAVE1"].contains(key(v)) ? "WAVE1":"WAVE2"};static func excluded(_ v:String)->Bool{let k=key(v);return ["퇴사","퇴직","RETIRED","RESIGNED","INACTIVE","서브","SUB"].contains{ k.contains($0) }} }
private enum DragonScheduleDate {
    static var cal:Calendar{var c=Calendar(identifier:.gregorian);c.locale=Locale(identifier:"ko_KR");c.timeZone=TimeZone(identifier:"Asia/Seoul") ?? .current;return c}
    static func sunday(_ d:Date)->Date{let w=cal.component(.weekday,from:d);return cal.date(byAdding:.day,value:-(w-1),to:d) ?? d}
    static func add(_ d:Date,_ n:Int)->Date?{cal.date(byAdding:.day,value:n,to:d)}
    static func iso(_ d:Date)->String{let p=cal.dateComponents([.year,.month,.day],from:d);return String(format:"%04d-%02d-%02d",p.year ?? 0,p.month ?? 0,p.day ?? 0)}
    static func dayLabel(_ iso:String)->String{let p=iso.split(separator:"-").compactMap{Int($0)};guard p.count==3,let d=cal.date(from:DateComponents(year:p[0],month:p[1],day:p[2])) else{return iso};let w=["일","월","화","수","목","금","토"][cal.component(.weekday,from:d)-1];return "\(p[1])/\(p[2]) \(w)"}
    static func range(_ start:Date)->String{let end=add(start,6) ?? start;return "\(iso(start)) ~ \(iso(end))"}
}