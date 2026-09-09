import SwiftUI

struct NativeMenuRouterView: View {
    let title: String
    let path: String
    let session: AppSession

    var body: some View {
        switch AppAccessPolicy.basePath(path) {
        case "/zipcode_search":
            ZipcodeSearchView()
        case "/coupangRouteMap.html":
            RouteEditorView(session: session)
        case "/coupang_freshbag":
            FreshbagStatusView(session: session)
        case "/cleansing_history":
            CleansingHistoryView(session: session)
        case "/maroowell_route_info":
            RouteInfoView(session: session)
        case "/maroowell_route":
            RoutePriceView(session: session)
        case "/dragon_car_index":
            DragonCarView(session: session)
        case "/dragon_car_schedule":
            DragonScheduleView(session: session)
        case "/admin_access.html":
            AdminApprovalView(session: session)
        case "/maroowell_push":
            PushConsoleView(session: session)
        default:
            MaroowellWebView(title: title, path: path)
        }
    }
}
