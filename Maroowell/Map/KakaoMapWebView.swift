import CoreLocation
import SwiftUI
import WebKit

struct KakaoMapPolygon: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let label: String
    let selected: Bool
    let draft: Bool
    let fillColor: String?
    let strokeColor: String?

    init(id: String, coordinates: [CLLocationCoordinate2D], label: String = "", selected: Bool = false, draft: Bool = false,
         fillColor: String? = nil, strokeColor: String? = nil) {
        self.id = id
        self.coordinates = coordinates
        self.label = label
        self.selected = selected
        self.draft = draft
        self.fillColor = fillColor
        self.strokeColor = strokeColor
    }
}

struct KakaoMapMarker: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let label: String
    let address: String
    let kind: String

    init(id: String, coordinate: CLLocationCoordinate2D, label: String, address: String = "", kind: String = "") {
        self.id = id
        self.coordinate = coordinate
        self.label = label
        self.address = address
        self.kind = kind
    }
}

struct KakaoMapAddress: Identifiable {
    let id: String
    let label: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let kind: String

    init(id: String, label: String, address: String, latitude: Double? = nil, longitude: Double? = nil, kind: String = "") {
        self.id = id
        self.label = label
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
    }
}

struct KakaoResolvedAddress: Identifiable {
    let id: String
    let label: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let kind: String
}

struct KakaoMapWebView: UIViewRepresentable {
    let polygons: [KakaoMapPolygon]
    let markers: [KakaoMapMarker]
    let addresses: [KakaoMapAddress]
    let drawingEnabled: Bool
    let satelliteEnabled: Bool
    let roadviewEnabled: Bool
    let fitContent: Bool
    let focusMarkerID: String?
    let onMapTap: ((CLLocationCoordinate2D) -> Void)?
    let onResolvedAddresses: (([KakaoResolvedAddress]) -> Void)?

    init(
        polygons: [KakaoMapPolygon] = [],
        markers: [KakaoMapMarker] = [],
        addresses: [KakaoMapAddress] = [],
        drawingEnabled: Bool = false,
        satelliteEnabled: Bool = false,
        roadviewEnabled: Bool = false,
        fitContent: Bool = true,
        focusMarkerID: String? = nil,
        onMapTap: ((CLLocationCoordinate2D) -> Void)? = nil,
        onResolvedAddresses: (([KakaoResolvedAddress]) -> Void)? = nil
    ) {
        self.polygons = polygons
        self.markers = markers
        self.addresses = addresses
        self.drawingEnabled = drawingEnabled
        self.satelliteEnabled = satelliteEnabled
        self.roadviewEnabled = roadviewEnabled
        self.fitContent = fitContent
        self.focusMarkerID = focusMarkerID
        self.onMapTap = onMapTap
        self.onResolvedAddresses = onResolvedAddresses
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "mapBridge")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.933, green: 0.953, blue: 0.973, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        context.coordinator.webView = webView

        let baseURL = URL(string: "https://maroowell.com/")!
        webView.loadHTMLString(Self.html, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.renderIfReady()
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "mapBridge")
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: KakaoMapWebView
        weak var webView: WKWebView?
        private var ready = false
        private var renderSerial = 0

        init(parent: KakaoMapWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mapBridge", let body = message.body as? [String: Any], let type = body["type"] as? String else { return }

            if type == "ready" {
                ready = true
                renderIfReady()
                return
            }

            if type == "tap",
               let lat = Self.number(body["lat"]),
               let lng = Self.number(body["lng"]) {
                parent.onMapTap?(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                return
            }

            if type == "resolved", let raw = body["items"] as? [[String: Any]] {
                let items = raw.compactMap(Self.resolvedAddress)
                parent.onResolvedAddresses?(items)
            }
        }

        func renderIfReady() {
            guard ready, let webView else { return }
            renderSerial += 1

            let payload: [String: Any] = [
                "polygons": parent.polygons.map { polygon in
                    [
                        "id": polygon.id,
                        "label": polygon.label,
                        "selected": polygon.selected,
                        "draft": polygon.draft,
                        "fillColor": polygon.fillColor ?? NSNull(),
                        "strokeColor": polygon.strokeColor ?? NSNull(),
                        "points": polygon.coordinates.map { [$0.latitude, $0.longitude] }
                    ]
                },
                "markers": parent.markers.map { marker in
                    [
                        "id": marker.id,
                        "lat": marker.coordinate.latitude,
                        "lng": marker.coordinate.longitude,
                        "label": marker.label,
                        "address": marker.address,
                        "kind": marker.kind
                    ]
                },
                "addresses": parent.addresses.map { item in
                    var value: [String: Any] = [
                        "id": item.id,
                        "label": item.label,
                        "address": item.address,
                        "kind": item.kind
                    ]
                    if let lat = item.latitude, lat.isFinite { value["lat"] = lat }
                    if let lng = item.longitude, lng.isFinite { value["lng"] = lng }
                    return value
                }
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            let focus = parent.focusMarkerID.map(Self.jsQuoted) ?? "null"
            let script = "window.mwRender(\(json), \(parent.drawingEnabled ? "true" : "false"), \(parent.fitContent ? "true" : "false"), \(focus), \(renderSerial)); window.mwSetSatellite(\(parent.satelliteEnabled ? "true" : "false")); window.mwSetRoadview(\(parent.roadviewEnabled ? "true" : "false"));"
            webView.evaluateJavaScript(script)
        }

        private static func resolvedAddress(_ value: [String: Any]) -> KakaoResolvedAddress? {
            guard
                let id = value["id"] as? String,
                let lat = number(value["lat"]),
                let lng = number(value["lng"])
            else { return nil }
            return KakaoResolvedAddress(
                id: id,
                label: value["label"] as? String ?? "",
                address: value["address"] as? String ?? "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                kind: value["kind"] as? String ?? ""
            )
        }

        private static func number(_ value: Any?) -> Double? {
            if let number = value as? NSNumber { return number.doubleValue }
            if let string = value as? String { return Double(string) }
            return nil
        }

        private static func jsQuoted(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let text = String(data: data, encoding: .utf8),
                  text.count >= 2 else { return "null" }
            return String(text.dropFirst().dropLast())
        }
    }

    private static var html: String {
        let key = AppConfig.kakaoJavascriptKey
        return """
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{width:100%;height:100%;margin:0;padding:0;overflow:hidden;background:#eef3f8}
#map{position:absolute;top:0;left:0;width:100%;height:100%}
#roadview{position:absolute;bottom:0;left:0;width:100%;height:50%;display:none;background:#e2e8f0}
body.mw-roadview-open #map{height:50%}
body.mw-roadview-open #roadview{display:block}
#mwRoadviewHint{display:none;position:absolute;z-index:8;left:7px;top:7px;background:#ffffffed;color:#315171;
border:1px solid #bcd0db;border-radius:7px;padding:5px 9px;font:700 11px -apple-system,sans-serif;pointer-events:none}
body.mw-roadview-open #mwRoadviewHint{display:block}
.mw-label{padding:4px 7px;border-radius:7px;background:rgba(255,255,255,.96);color:#1e3a8a;
border:1px solid #93c5fd;font:800 10.5px -apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo",sans-serif;
white-space:nowrap;box-shadow:0 1px 5px rgba(15,23,42,.18);transform:translateY(-3px)}
.mw-marker{position:relative;min-width:36px;max-width:190px;padding:5px 8px;border-radius:8px;background:#fff;
border:1.2px solid #dbeafe;color:#0f172a;font:800 11px -apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo",sans-serif;
white-space:nowrap;overflow:hidden;text-overflow:ellipsis;box-shadow:0 2px 8px rgba(15,23,42,.22);transform:translateY(-36px)}
.mw-marker.sub{background:#fff7ed;border-color:#fdba74;color:#9a3412}
</style>
<script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=\(key)&autoload=false&libraries=services"></script>
</head>
<body>
<div id="map"></div>
<div id="roadview"></div>
<div id="mwRoadviewHint">지도에서 도로를 눌러 로드뷰 위치를 선택하세요</div>
<script>
let map=null, geocoder=null, drawing=false, objects=[], markerIndex={};
function bridge(message){try{window.webkit.messageHandlers.mapBridge.postMessage(message)}catch(e){}}
function clearObjects(){objects.forEach(o=>{try{o.setMap(null)}catch(e){}});objects=[];markerIndex={};}
function addObject(o){objects.push(o);return o;}
function centroid(points){
  if(!points.length)return null;
  let lat=0,lng=0;points.forEach(p=>{lat+=p.getLat();lng+=p.getLng()});
  return new kakao.maps.LatLng(lat/points.length,lng/points.length);
}
function markerElement(label,kind){
  const el=document.createElement('div');el.className='mw-marker'+(String(kind).toUpperCase()==='SUB_HUB'?' sub':'');
  el.textContent=label||'위치';return el;
}
function labelElement(label){const el=document.createElement('div');el.className='mw-label';el.textContent=label;return el;}
function addMarker(item,bounds,resolved){
  const pos=new kakao.maps.LatLng(Number(item.lat),Number(item.lng));
  const marker=addObject(new kakao.maps.Marker({position:pos,map:map}));
  const overlay=addObject(new kakao.maps.CustomOverlay({position:pos,content:markerElement(item.label,item.kind),yAnchor:1,map:map}));
  markerIndex[String(item.id)]=pos;bounds.extend(pos);
  if(resolved)resolved.push({id:String(item.id),label:item.label||'',address:item.address||'',kind:item.kind||'',lat:pos.getLat(),lng:pos.getLng()});
}
function finishRender(bounds,count,fit,focus){
  if(fit && count>0){
    map.setBounds(bounds,44,36,52,36);
    if(count===1)map.setLevel(4);
  }
  if(focus && markerIndex[String(focus)]){
    map.panTo(markerIndex[String(focus)]);
    map.setLevel(4);
  }
}
window.mwRender=function(payload,enableDrawing,fit,focus,serial){
  if(!map)return;
  drawing=!!enableDrawing;clearObjects();
  const bounds=new kakao.maps.LatLngBounds();let count=0;
  const resolved=[];const addresses=Array.isArray(payload.addresses)?payload.addresses:[];
  (payload.polygons||[]).forEach((item,index)=>{
    const path=(item.points||[]).map(p=>new kakao.maps.LatLng(Number(p[0]),Number(p[1])));
    if(path.length<2)return;
    // Road colors are derived from the name, not a feature index.
    const defaultColor=item.draft?'#f59e0b':(item.selected?'#7c3aed':'#2563eb');
    const stroke=/^#[0-9a-f]{6}$/i.test(item.strokeColor||'')?item.strokeColor:defaultColor;
    const fill=/^#[0-9a-f]{6}$/i.test(item.fillColor||'')?item.fillColor:defaultColor;
    const opacity=item.fillColor ? .75 : (item.draft ? .22 : .13);
    const polygon=addObject(new kakao.maps.Polygon({map:map,path:path,strokeWeight:item.draft?3:2,strokeColor:stroke,strokeOpacity:.94,fillColor:fill,fillOpacity:opacity}));
    path.forEach(p=>{bounds.extend(p);count++});
    if(item.label){
      const center=centroid(path);
      if(center)addObject(new kakao.maps.CustomOverlay({map:map,position:center,content:labelElement(item.label),yAnchor:.5}));
    }
  });
  (payload.markers||[]).forEach(item=>{addMarker(item,bounds,null);count++});
  if(!addresses.length){finishRender(bounds,count,fit,focus);bridge({type:'resolved',items:resolved});return;}
  let pending=addresses.length;
  function done(){pending--;if(pending<=0){finishRender(bounds,count,fit,focus);bridge({type:'resolved',items:resolved})}}
  addresses.forEach(item=>{
    const lat=Number(item.lat),lng=Number(item.lng);
    if(Number.isFinite(lat)&&Number.isFinite(lng)){addMarker({...item,lat:lat,lng:lng},bounds,resolved);count++;done();return;}
    if(!item.address){done();return;}
    geocoder.addressSearch(item.address,(result,status)=>{
      if(status===kakao.maps.services.Status.OK&&result&&result.length){
        addMarker({...item,lat:Number(result[0].y),lng:Number(result[0].x)},bounds,resolved);count++;
      }
      done();
    });
  });
};
// Same Kakao Roadview/map orientation walker used by coupangRouteMap.
let roadview=null,roadClient=null,roadWalker=null,roadClick=null,roadviewOn=false;
function ensureRoadview(){
  if(roadview)return;
  roadview=new kakao.maps.Roadview(document.getElementById('roadview'));
  roadClient=new kakao.maps.RoadviewClient();
  const root=document.createElement('div');
  root.style.cssText='position:relative;width:46px;height:46px;pointer-events:none;filter:drop-shadow(0 2px 3px #0f172a55)';
  const cone=document.createElement('div');
  cone.style.cssText='position:absolute;left:50%;top:-21px;width:25px;height:32px;transform:translateX(-50%);transform-origin:50% 37px;background:#2563eb7a;clip-path:polygon(50% 0,100% 100%,50% 77%,0 100%)';
  const halo=document.createElement('div');
  halo.style.cssText='position:absolute;left:50%;top:50%;width:30px;height:30px;transform:translate(-50%,-50%);border-radius:50%;background:#2563eb29;border:2px solid #2563ebb8';
  const dot=document.createElement('div');
  dot.style.cssText='position:absolute;left:50%;top:50%;width:12px;height:12px;transform:translate(-50%,-50%);border-radius:50%;background:#2563eb;border:3px solid white';
  root.append(cone,halo,dot);
  roadWalker=new kakao.maps.CustomOverlay({content:root,position:map.getCenter(),xAnchor:.5,yAnchor:.5,zIndex:99});
  function sync(){
    const pos=roadview.getPosition&&roadview.getPosition();
    if(pos)roadWalker.setPosition(pos);
    const point=roadview.getViewpoint&&roadview.getViewpoint();
    if(point)cone.style.transform='translateX(-50%) rotate('+Number(point.pan||0)+'deg)';
    if(roadviewOn)roadWalker.setMap(map);
  }
  kakao.maps.event.addListener(roadview,'init',sync);
  kakao.maps.event.addListener(roadview,'viewpoint_changed',sync);
  kakao.maps.event.addListener(roadview,'position_changed',sync);
}
function openRoadview(position){
  ensureRoadview();
  roadClient.getNearestPanoId(position,200,function(id){
    if(!roadviewOn)return;
    if(!id){document.getElementById('mwRoadviewHint').textContent='근처에 로드뷰가 없습니다. 다른 도로를 눌러주세요.';return;}
    roadview.setPanoId(id,position);
    document.getElementById('mwRoadviewHint').textContent='상단 방향 표시와 하단 로드뷰가 연동됩니다';
  });
}
window.mwSetSatellite=function(on){
  if(!map)return;
  map.setMapTypeId(on?kakao.maps.MapTypeId.HYBRID:kakao.maps.MapTypeId.ROADMAP);
};
window.mwSetRoadview=function(on){
  if(!map)return;
  const next=!!on;
  if(roadviewOn===next)return;
  roadviewOn=next;
  document.body.classList.toggle('mw-roadview-open',next);
  if(next){
    ensureRoadview();
    try{map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW)}catch(e){}
    roadWalker.setMap(map);
    if(!roadClick){
      roadClick=function(e){if(e&&e.latLng)openRoadview(e.latLng);};
      kakao.maps.event.addListener(map,'click',roadClick);
    }
    requestAnimationFrame(function(){
      map.relayout();
      if(roadview.relayout)roadview.relayout();
      openRoadview(map.getCenter());
    });
  }else{
    try{map.removeOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW)}catch(e){}
    if(roadClick){kakao.maps.event.removeListener(map,'click',roadClick);roadClick=null;}
    if(roadWalker)roadWalker.setMap(null);
    requestAnimationFrame(function(){map.relayout();});
  }
};

kakao.maps.load(function(){
  const container=document.getElementById('map');
  map=new kakao.maps.Map(container,{center:new kakao.maps.LatLng(37.5665,126.9780),level:7});
  geocoder=new kakao.maps.services.Geocoder();
  map.addControl(new kakao.maps.MapTypeControl(),kakao.maps.ControlPosition.TOPRIGHT);
  map.addControl(new kakao.maps.ZoomControl(),kakao.maps.ControlPosition.RIGHT);
  kakao.maps.event.addListener(map,'click',function(mouseEvent){
    if(!drawing)return;
    const p=mouseEvent.latLng;bridge({type:'tap',lat:p.getLat(),lng:p.getLng()});
  });
  bridge({type:'ready'});
});
</script>
</body>
</html>
"""
    }
}
