import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hero
                section("1. 처리하는 개인정보와 이용 목적", items: [
                    ("계정·인증 정보", "이메일 주소, 사용자 식별자, 로그인 및 인증 세션 정보를 로그인, 본인 식별, 권한 확인 및 보안 유지에 사용합니다."),
                    ("프로필·업무 정보", "이름, 연락처, 직책, 소속 캠프, 주·야 구분, 쿠팡 ID, 차량번호, 사업자 및 정산 관련 정보 등 회사 업무 수행을 위해 등록된 정보를 배차·스케줄·라우트·정산·업무 현황 제공에 사용합니다."),
                    ("업무 입력 데이터", "입차 스케줄, 배송·반품 수량, 일상점검, 게시판 및 알림 관련 데이터를 해당 업무 기능 제공과 운영 기록 관리에 사용합니다."),
                    ("위치정보", "사용자가 지도에서 현재 위치 기능을 직접 사용하는 경우 기기의 대략적 또는 정확한 위치정보를 처리할 수 있습니다. 기본적으로 지도 표시 및 주변 기능 제공에 사용하며 별도 저장 기능을 사용하지 않는 한 현재 위치 자체를 지속적으로 저장하지 않습니다."),
                    ("PUSH 정보", "기기 알림 토큰 및 알림 수신 상태를 업무 알림과 긴급 공지 발송에 사용합니다."),
                    ("서비스 이용 정보", "접속 시점, 요청 결과, 오류 및 보안 관련 로그 등 서비스 운영 과정에서 생성되는 정보를 장애 대응, 보안 및 서비스 개선에 사용합니다.")
                ])
                section("2. 개인정보의 보유 및 이용기간", items: [
                    ("보유 원칙", "개인정보는 원칙적으로 처리 목적이 달성되거나 계정이 삭제되면 지체 없이 삭제 또는 비식별 처리합니다. 관련 법령에서 일정 기간 보관을 요구하는 경우에는 해당 기간 동안 보관할 수 있습니다."),
                    ("계정 및 권한 정보", "계정 사용 기간 동안 또는 업무상 권한 유지에 필요한 기간"),
                    ("PUSH 기기 토큰", "로그아웃·기기 해제·토큰 무효화 또는 계정 삭제 시까지"),
                    ("업무 기록", "회사의 정당한 업무 운영 및 법령상 보존 의무가 있는 범위에서 필요한 기간")
                ])
                section("3. 외부 서비스 이용", items: [
                    ("Supabase", "사용자 인증, 데이터베이스 및 서버 기능"),
                    ("Google Firebase Cloud Messaging", "앱 PUSH 알림 발송 및 기기 토큰 처리"),
                    ("Kakao 지도 관련 서비스", "지도·주소·위치 기반 기능 제공")
                ], footer: "외부 서비스의 처리 방식은 해당 서비스 제공자의 개인정보 보호정책 및 보안정책의 적용을 받을 수 있습니다.")
                section("4. 앱 권한", items: [
                    ("인터넷", "로그인, 데이터 조회·저장, 지도 및 알림 기능에 필요합니다."),
                    ("위치", "현재 위치를 지도에 표시하는 기능에서만 사용하며 사용자가 권한을 허용한 경우에만 접근합니다."),
                    ("알림", "긴급 공지 및 업무 PUSH 알림 수신에 사용합니다.")
                ], footer: "선택 권한을 허용하지 않아도 해당 권한이 필요하지 않은 다른 기능은 이용할 수 있습니다.")
                section("5. 개인정보의 안전성 확보", items: [
                    ("보호조치", "인증 기반 접근제어, 역할·소속별 권한 제한, 전송 구간 암호화(HTTPS), 서버 측 권한 검증 등을 통해 개인정보 및 업무 데이터에 대한 비인가 접근을 제한합니다. 서버 비밀키 등 민감한 서버 자격증명은 앱에 포함하지 않습니다.")
                ])
                section("6. 이용자의 권리와 계정 삭제 요청", items: [
                    ("열람·정정·삭제", "이용자는 본인의 개인정보에 대한 열람, 정정 및 삭제를 요청할 수 있습니다. 본인 및 업무 권한 확인 후 관련 법령과 회사의 보존 의무 범위 내에서 처리합니다."),
                    ("개인정보 문의 및 삭제 요청", "운영자: 마루웰\n이메일: brain@maroowell.com")
                ])
                section("7. 개인정보처리방침의 변경", items: [
                    ("변경 안내", "법령, 서비스 기능 또는 개인정보 처리 방식이 변경되는 경우 본 방침을 변경할 수 있으며 중요한 변경사항은 서비스 내 또는 웹사이트를 통해 안내합니다.")
                ])
                Text("© MAROOWELL · 문의 brain@maroowell.com")
                    .font(.caption2)
                    .foregroundStyle(MaroowellTheme.muted)
                    .padding(.vertical, 10)
            }
            .padding(14)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("개인정보처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("마루웰 개인정보처리방침")
                .font(.title2.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text("마루웰은 서비스 제공에 필요한 범위에서 개인정보를 처리하며, 이용자의 개인정보를 안전하게 보호하기 위해 노력합니다.")
                .font(.subheadline)
                .foregroundStyle(MaroowellTheme.muted)
            Text("시행일 2026.08.27 · 마루웰 iOS 앱")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.deepYellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private func section(_ title: String, items: [(String, String)], footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.subheadline.weight(.bold)).foregroundStyle(MaroowellTheme.ink)
                    Text(item.1).font(.subheadline).foregroundStyle(Color.secondary)
                }
            }
            if let footer {
                Text(footer).font(.caption).foregroundStyle(MaroowellTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }
}