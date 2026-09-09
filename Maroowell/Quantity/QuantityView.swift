import SwiftUI

struct QuantityView: View {
    @StateObject private var viewModel: QuantityViewModel
    @State private var showMessage = false

    @MainActor
    init(date: Date = .now) {
        _viewModel = StateObject(wrappedValue: QuantityViewModel(date: date))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dateCard
                summaryCard
                routesCard
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("배송 수량 등록")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.saveMessage) { _, newValue in
            showMessage = newValue != nil
        }
        .alert("마루웰", isPresented: $showMessage) {
            Button("확인") { viewModel.saveMessage = nil }
        } message: {
            Text(viewModel.saveMessage ?? "")
        }
    }

    private var dateCard: some View {
        VStack(spacing: 10) {
            HStack {
                circleButton(systemName: "chevron.left") { viewModel.moveDay(-1) }
                Spacer()
                Text(viewModel.selectedDateTitle)
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                circleButton(systemName: "chevron.right") { viewModel.moveDay(1) }
            }

            Button("오늘") { viewModel.moveToToday() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MaroowellTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MaroowellTheme.border, lineWidth: 1)
                }
        }
        .padding(16)
        .cardStyle()
    }

    private var summaryCard: some View {
        let settlement = viewModel.settlementSummary
        return VStack(alignment: .leading, spacing: 8) {
            Text("선택일 예상 수수료")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)

            Text(viewModel.selectedTotal.krw)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.40, blue: 0.44))

            Text("\(settlement.settlementYear)년 \(settlement.settlementMonth)월 정산 예상 \(settlement.total.krw) · \(settlement.startDate.shortMD)~\(settlement.endDate.shortMD) · 등록 \(settlement.days)일")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private var routesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("라우트별 수량 / 단가")
                .font(.title3.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            Text("캠프와 라우트를 함께 저장합니다. 같은 캠프·라우트의 최근 단가는 다음 입력 때 불러올 수 있어요.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            ForEach($viewModel.routes) { $route in
                routeEditor(route: $route)
            }

            Button {
                viewModel.addRoute()
            } label: {
                Label("라우트 추가", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MaroowellTheme.border, lineWidth: 1)
            }

            TextField("메모", text: $viewModel.memo, axis: .vertical)
                .lineLimit(2...4)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MaroowellTheme.border, lineWidth: 1)
                }

            Button {
                viewModel.save()
            } label: {
                Text("저장")
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func routeEditor(route: Binding<QuantityRouteRecord>) -> some View {
        let routeID = route.wrappedValue.id
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                labeledTextField("캠프", placeholder: "일산2", text: route.campName)
                labeledTextField("라우트", placeholder: "126A", text: route.routeName, uppercase: true)
            }

            HStack(spacing: 10) {
                Button("최근 단가") { viewModel.applyRecentPrices(to: routeID) }
                    .buttonStyle(OutlineMiniButtonStyle())

                Button(role: .destructive) {
                    viewModel.deleteRoute(id: routeID)
                } label: {
                    Text("삭제")
                }
                .buttonStyle(OutlineMiniButtonStyle())
                .disabled(viewModel.routes.count <= 1)
            }

            ForEach(QuantityLineKey.allCases) { key in
                quantityLine(routeID: routeID, route: route, key: key)
            }
        }
        .padding(14)
        .background(Color(red: 0.985, green: 0.988, blue: 0.992), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private func quantityLine(
        routeID: UUID,
        route: Binding<QuantityRouteRecord>,
        key: QuantityLineKey
    ) -> some View {
        let value = route.wrappedValue.values[key.rawValue] ?? QuantityValue()
        let amount = viewModel.amount(routeID: routeID, key: key)

        return VStack(spacing: 8) {
            HStack {
                Text(key.isNegative ? "− \(key.label)" : key.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(key.isNegative ? Color.red : MaroowellTheme.ink)
                if key == .returns {
                    Text("(반품)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                }
                Spacer()
                Text(amount.krw)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(key.isNegative ? Color.red : MaroowellTheme.ink)
            }

            HStack(spacing: 10) {
                numberField(
                    title: "건수",
                    value: value.count,
                    enabled: true,
                    onChange: { viewModel.updateCount(routeID: routeID, key: key, value: $0) }
                )

                numberField(
                    title: "단가",
                    value: value.unitPrice,
                    enabled: !key.followsDeliveryPrice,
                    onChange: { viewModel.updatePrice(routeID: routeID, key: key, value: $0) }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func labeledTextField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        uppercase: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            TextField(placeholder, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = uppercase ? $0.uppercased() : $0 }
            ))
            .font(.subheadline.weight(.semibold))
            .textInputAutocapitalization(uppercase ? .characters : .sentences)
            .autocorrectionDisabled(uppercase)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        }
    }

    private func numberField(
        title: String,
        value: Int,
        enabled: Bool,
        onChange: @escaping (String) -> Void
    ) -> some View {
        TextField(title, text: Binding(
            get: { value == 0 ? "" : String(value) },
            set: onChange
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .font(.subheadline.weight(.semibold))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.62)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
                .padding(.leading, 10)
                .offset(y: -5)
                .background(MaroowellTheme.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        }
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .frame(width: 44, height: 44)
                .background(MaroowellTheme.yellow.opacity(0.22), in: Circle())
        }
    }
}

private struct OutlineMiniButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(MaroowellTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.white.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            }
    }
}

private extension View {
    func cardStyle() -> some View {
        self.background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MaroowellTheme.border.opacity(0.85), lineWidth: 1)
            }
    }
}

extension Int64 {
    var krw: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let absolute = formatter.string(from: NSNumber(value: Swift.abs(self))) ?? "0"
        return self < 0 ? "− \(absolute)원" : "\(absolute)원"
    }
}

private extension Date {
    var shortMD: String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ko_KR")))
            .replacingOccurrences(of: ". ", with: ".")
            .replacingOccurrences(of: ".", with: ".")
    }
}