import Foundation
import MapKit
import SwiftUI

struct ZipcodeSearchView: View {
    let session: AppSession
    @StateObject private var store = ZipcodeSearchStore()
    @State private var zipInput = ""
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if session.canView("/zipcode_search") { content }
            else { denied }
        }
        .navigationTitle("우편번호 검색")
        .navigationBarTitleDisplayMode(.inline)
        .alert("우편번호 검색", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                ForEach(store.places) { place in
                    Marker(place.name, coordinate: place.coordinate)
                }
            }
            .frame(minHeight: 260)
            .overlay(alignment: .topTrailing) {
                Text("지도 · 위치검색")
                    .font(.caption2.weight(.black)).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule()).padding(8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    locationCard
                    zipcodeCard
                    HStack(spacing: 8) {
                        if store.loading { ProgressView().controlSize(.small) }
                        Text(store.status).font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
                        Spacer()
                    }
                    ForEach(store.results) { result in resultCard(result) }
                }.padding(12)
            }.background(MaroowellTheme.background)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📍 위치 검색").font(.caption.weight(.black)).foregroundStyle(Color(red: 0.12, green: 0.30, blue: 0.27))
            HStack {
                TextField("주소 · 장소 · 상호 검색", text: $store.locationQuery).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit { Task { await searchLocation() } }
                Button("검색") { Task { await searchLocation() } }.buttonStyle(.borderedProminent)
            }
            if !store.places.isEmpty {
                ForEach(store.places.prefix(6)) { p in
                    Button {
                        camera = .region(MKCoordinateRegion(center: p.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) { Text(p.name).font(.caption.weight(.bold)); if !p.address.isEmpty { Text(p.address).font(.caption2).foregroundStyle(MaroowellTheme.muted) } }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8).background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(13).background(Color.white, in: RoundedRectangle(cornerRadius: 17)).overlay { RoundedRectangle(cornerRadius: 17).stroke(MaroowellTheme.border) }
    }

    private var zipcodeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("우편번호 여러 개 동시 조회").font(.caption.weight(.black))
            Text("쉼표 / 공백 / 줄바꿈 모두 가능").font(.caption2).foregroundStyle(MaroowellTheme.muted)
            TextField("예: 07420, 07421 07422", text: $zipInput, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
            HStack(spacing: 7) {
                Button("추가") { add(load: false) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("지도표시") { add(load: true) }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                Button("초기화") { zipInput=""; store.clear() }.buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
            if !store.selected.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.selected, id: \.self) { zip in
                            Button { store.remove(zip) } label: { HStack(spacing: 4) { Text(zip); Image(systemName: "xmark.circle.fill") }.font(.caption.weight(.bold)) }.buttonStyle(.bordered)
                        }
                    }
                }
            }
        }.padding(13).background(Color.white, in: RoundedRectangle(cornerRadius: 17)).overlay { RoundedRectangle(cornerRadius: 17).stroke(MaroowellTheme.border) }
    }

    private func resultCard(_ result: ZipcodeBoundaryResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(result.zip).font(.headline.weight(.black)); Spacer(); Text("경계 \(result.polygonCount)개").font(.caption.weight(.bold)).foregroundStyle(.blue) }
            Text("우편번호 경계 원본 좌표(EPSG:5179) 조회 완료").font(.caption).foregroundStyle(MaroowellTheme.muted)
            if let center = result.approximateCenter {
                Text("원본 중심 X \(String(format: "%.0f", center.x)) · Y \(String(format: "%.0f", center.y))")
                    .font(.caption2).foregroundStyle(MaroowellTheme.muted)
            }
        }.padding(13).background(Color.white, in: RoundedRectangle(cornerRadius: 15)).overlay { RoundedRectangle(cornerRadius: 15).stroke(MaroowellTheme.border) }
    }

    private func add(load: Bool) {
        let parsed = ZipcodeSearchFormat.parse(zipInput)
        if parsed.isEmpty && store.selected.isEmpty { store.message = "5자리 우편번호를 입력하세요."; return }
        store.add(parsed); zipInput=""; if load { Task { await store.loadSelected() } }
    }
    private func searchLocation() async {
        await store.searchPlaces()
        if let first = store.places.first { camera = .region(MKCoordinateRegion(center: first.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))) }
    }
    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("마루웰 팀장 권한 이상만 이용할 수 있습니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

@MainActor private final class ZipcodeSearchStore: ObservableObject {
    @Published var locationQuery=""
    @Published var places:[ZipcodePlace]=[]
    @Published var selected:[String]=[]
    @Published var results:[ZipcodeBoundaryResult]=[]
    @Published var loading=false
    @Published var status="지도표시 후 우편번호별 분석정보가 표시됩니다."
    @Published var message:String?

    func add(_ zips:[String]) { for z in zips where !selected.contains(z) { selected.append(z) }; selected.sort() }
    func remove(_ zip:String) { selected.removeAll{$0==zip}; results.removeAll{$0.zip==zip} }
    func clear() { selected=[];results=[];places=[];status="지도표시 후 우편번호별 분석정보가 표시됩니다." }
    func searchPlaces() async {
        let q=locationQuery.trimmingCharacters(in:.whitespacesAndNewlines); guard !q.isEmpty else { message="검색할 주소나 장소를 입력하세요."; return }
        do { let req=MKLocalSearch.Request(); req.naturalLanguageQuery=q; let res=try await MKLocalSearch(request:req).start(); places=res.mapItems.prefix(8).map { item in ZipcodePlace(name:item.name ?? item.placemark.title ?? "검색 결과",address:item.placemark.title ?? "",coordinate:item.placemark.coordinate) }; status=places.isEmpty ? "검색 결과가 없습니다.":"위치 검색 \(places.count)개 결과" } catch { message="위치 검색에 실패했습니다." }
    }
    func loadSelected() async {
        guard !selected.isEmpty else{return};loading=true;status="우편번호 경계 조회 중…";defer{loading=false}
        var loaded:[ZipcodeBoundaryResult]=[],failed=0
        for zip in selected { do{loaded.append(try await ZipcodeBoundaryAPI.fetch(zip))}catch{failed += 1} }
        results=loaded.sorted{$0.zip<$1.zip};status=failed==0 ? "\(loaded.count)개 우편번호 경계 조회 완료":"\(loaded.count)개 조회 · \(failed)개 실패"; if failed>0{message="일부 우편번호 경계를 불러오지 못했습니다."}
    }
}

private struct ZipcodePlace:Identifiable{let id=UUID();let name,address:String;let coordinate:CLLocationCoordinate2D}
private struct ZipcodePoint:Hashable{let x,y:Double}
private struct ZipcodeBoundaryResult:Identifiable{let zip:String;let polygons:[[[ZipcodePoint]]];var id:String{zip};var polygonCount:Int{polygons.count};var approximateCenter:ZipcodePoint?{let pts=polygons.flatMap{$0}.flatMap{$0};guard !pts.isEmpty else{return nil};return .init(x:pts.reduce(0){$0+$1.x}/Double(pts.count),y:pts.reduce(0){$0+$1.y}/Double(pts.count))}}

private enum ZipcodeBoundaryAPI {
    static func fetch(_ zip:String) async throws -> ZipcodeBoundaryResult {
        var c=URLComponents(string:"https://zip.maroowell.com/")!;c.queryItems=[URLQueryItem(name:"zipcode",value:zip)];let(d,res)=try await URLSession.shared.data(from:c.url!);guard let h=res as? HTTPURLResponse,(200..<300).contains(h.statusCode) else{throw NSError(domain:"Zipcode",code:1)};guard let root=try JSONSerialization.jsonObject(with:d) as? [String:Any] else{throw NSError(domain:"Zipcode",code:2)};let raw=(root["polygon5179"] ?? root["polygon_5179"] ?? root["polygon"]) as Any;let polygons=parse(raw);guard !polygons.isEmpty else{throw NSError(domain:"Zipcode",code:3)};return .init(zip:zip,polygons:polygons)
    }
    private static func parse(_ value:Any)->[[[ZipcodePoint]]]{guard let a=value as? [Any],!a.isEmpty else{return[]};func point(_ v:Any)->ZipcodePoint?{guard let p=v as? [Any],p.count>=2,let x=num(p[0]),let y=num(p[1]) else{return nil};return .init(x:x,y:y)};func ring(_ v:Any)->[ZipcodePoint]?{guard let p=v as? [Any] else{return nil};let pts=p.compactMap(point);return pts.count>=3 ? pts:nil};if let r=ring(a){return [[r]]};if let first=a.first as? [Any],ring(first) != nil{return [a.compactMap(ring)]};var out:[[[ZipcodePoint]]]=[];for p in a{if let rings=p as? [Any]{let parsed=rings.compactMap(ring);if !parsed.isEmpty{out.append(parsed)}}};return out}
    private static func num(_ v:Any)->Double?{if let n=v as? NSNumber{return n.doubleValue};if let s=v as? String{return Double(s)};return nil}
}
private enum ZipcodeSearchFormat { static func parse(_ v:String)->[String]{var out:[String]=[];let regex=try? NSRegularExpression(pattern:"\\d{5}");let range=NSRange(v.startIndex...,in:v);regex?.enumerateMatches(in:v,range:range){m,_,_ in guard let m,let r=Range(m.range,in:v) else{return};let z=String(v[r]);if !out.contains(z){out.append(z)}};return out} }
