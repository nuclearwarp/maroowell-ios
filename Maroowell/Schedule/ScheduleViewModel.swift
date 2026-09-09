import Foundation

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedCamp: ScheduleCampOption?
    @Published var weekStart = ScheduleDatePolicy.sunday()
    @Published var selectedDayIndex = ScheduleDatePolicy.dayIndex(for: .now, inWeekStarting: ScheduleDatePolicy.sunday())
    @Published private(set) var routeRows: [ScheduleRouteRow] = []
    @Published private(set) var allRouteRows: [ScheduleRouteRow] = []
    @Published private(set) var driverAccounts: [ScheduleDriverAccount] = []
    @Published private(set) var workingValues: [ScheduleCellKey: String] = [:]
    @Published private(set) var dirtyKeys: Set<ScheduleCellKey> = []
    @Published private(set) var expandedParents: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = ScheduleAPI()
    private var assignmentByKey: [ScheduleCellKey: ScheduleAssignment] = [:]
    private var accountByKey: [String: ScheduleDriverAccount] = [:]

    var weekDates: [Date] { ScheduleDatePolicy.weekDates(sunday: weekStart) }
    var selectedDate: Date { weekDates[min(max(selectedDayIndex, 0), 6)] }
    var dirtyCount: Int { dirtyKeys.count }
    var canSave: Bool { !dirtyKeys.isEmpty && !isLoading && !isSaving }
    var suggestions: [String] { driverAccounts.map(\.displayName) }

    func selectCamp(_ camp: ScheduleCampOption) async {
        guard !isLoading && !isSaving else { return }
        selectedCamp = camp
        await loadWeek()
    }

    func moveWeek(by days: Int) async {
        guard !isLoading && !isSaving else { return }
        weekStart = ScheduleDatePolicy.addingDays(days, to: weekStart)
        selectedDayIndex = ScheduleDatePolicy.dayIndex(for: .now, inWeekStarting: weekStart)
        if selectedCamp != nil { await loadWeek() }
    }

    func currentWeek() async {
        guard !isLoading && !isSaving else { return }
        weekStart = ScheduleDatePolicy.sunday()
        selectedDayIndex = ScheduleDatePolicy.dayIndex(for: .now, inWeekStarting: weekStart)
        if selectedCamp != nil { await loadWeek() }
    }

    func loadWeek() async {
        guard let selectedCamp else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let data = try await api.loadWeek(camp: selectedCamp.name, wave: selectedCamp.wave, weekStart: weekStart)
            apply(data)
        } catch {
            clearLoadedWeek()
            errorMessage = friendly(error)
        }
    }

    func value(for row: ScheduleRouteRow) -> String {
        value(for: ScheduleCellKey(date: ScheduleDatePolicy.iso(selectedDate), routeLabel: row.label))
    }

    func update(row: ScheduleRouteRow, value rawValue: String) {
        let date = ScheduleDatePolicy.iso(selectedDate)
        let key = ScheduleCellKey(date: date, routeLabel: row.label)
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        setWorkingValue(key, value: value)

        if !value.isEmpty && row.isChild {
            let parentKey = ScheduleCellKey(date: date, routeLabel: row.parentKey)
            if !self.value(for: parentKey).isEmpty {
                setWorkingValue(parentKey, value: "")
            }
        } else if !value.isEmpty && row.hasChildren {
            for child in childRows(parentKey: row.label) {
                let childKey = ScheduleCellKey(date: date, routeLabel: child.label)
                if !self.value(for: childKey).isEmpty {
                    setWorkingValue(childKey, value: "")
                }
            }
        }
        syncExpandedParents()
    }

    func isLocked(_ row: ScheduleRouteRow) -> Bool {
        let date = ScheduleDatePolicy.iso(selectedDate)
        if row.hasChildren && value(for: row).isEmpty {
            return childRows(parentKey: row.label).contains { child in
                !value(for: ScheduleCellKey(date: date, routeLabel: child.label)).isEmpty
            }
        }
        if row.isChild {
            return !value(for: ScheduleCellKey(date: date, routeLabel: row.parentKey)).isEmpty
        }
        return false
    }

    func toggle(_ row: ScheduleRouteRow) {
        guard row.hasChildren else { return }
        if expandedParents.contains(row.label) {
            expandedParents.remove(row.label)
        } else {
            expandedParents.insert(row.label)
        }
        refreshVisibleRows()
    }

    func save() async {
        guard canSave, let selectedCamp else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            let rows = dirtyKeys.map { makeSaveRow(key: $0, camp: selectedCamp) }
            let result = try await api.save(rows: rows)
            successMessage = "입차 스케줄 \(result.saved + result.deleted)건 저장 완료"
            await loadWeek()
        } catch {
            errorMessage = friendly(error)
        }
    }

    func discardChanges() {
        workingValues = assignmentByKey.mapValues(\.displayValue)
        dirtyKeys.removeAll()
        syncExpandedParents()
    }

    private func apply(_ data: ScheduleWeekData) {
        guard let selectedCamp else { return }
        assignmentByKey.removeAll()
        workingValues.removeAll()
        dirtyKeys.removeAll()

        allRouteRows = buildRouteRows(data.routes, camp: selectedCamp.name)
        driverAccounts = buildDriverAccounts(data.drivers, assignments: data.schedules, camp: selectedCamp.name)
        indexAccounts()

        let displayAssignments = collapseUniformChildren(data.schedules)
        for assignment in displayAssignments where assignment.isActive {
            let key = ScheduleCellKey(date: assignment.scheduleDate, routeLabel: ScheduleNormalization.route(assignment.routeLabel))
            assignmentByKey[key] = assignment
            workingValues[key] = assignment.displayValue
        }
        selectedDayIndex = min(max(selectedDayIndex, 0), 6)
        syncExpandedParents()
    }

    private func buildRouteRows(_ sources: [ScheduleRouteSource], camp: String) -> [ScheduleRouteRow] {
        struct Parent {
            var label: String
            var description: String
            var rowOrder: Int
            var children: [String: ScheduleRouteSource]
        }

        let sorted = sources
            .filter { $0.isActive && ScheduleNormalization.campMatches($0.camp, camp) }
            .sorted {
                let lp = parentLabel($0), rp = parentLabel($1)
                if lp != rp { return lp < rp }
                let lc = childLabel($0), rc = childLabel($1)
                if lc != rc { return lc < rc }
                return $0.sortOrder < $1.sortOrder
            }

        var parents: [String: Parent] = [:]
        var order: [String] = []
        for source in sorted {
            let parent = parentLabel(source)
            let child = childLabel(source)
            guard !parent.isEmpty || !child.isEmpty else { continue }
            let key = parent.isEmpty ? child : parent
            if parents[key] == nil {
                parents[key] = Parent(label: key, description: source.description.isEmpty ? source.memo : source.description, rowOrder: source.sortOrder, children: [:])
                order.append(key)
            }
            if parents[key]?.description.isEmpty == true {
                parents[key]?.description = source.description.isEmpty ? source.memo : source.description
            }
            if !child.isEmpty && child != key {
                parents[key]?.children[child] = source
            }
        }

        var rows: [ScheduleRouteRow] = [
            ScheduleRouteRow(label: ScheduleNormalization.offRouteLabel, parentKey: ScheduleNormalization.offRouteLabel, isChild: false, hasChildren: false, isOff: true, description: "휴무 인원을 쉼표로 구분해 입력할 수 있습니다.", rowOrder: -1)
        ]
        for key in order {
            guard let parent = parents[key] else { continue }
            let children = parent.children.values.sorted { childLabel($0) < childLabel($1) }
            rows.append(ScheduleRouteRow(label: parent.label, parentKey: parent.label, isChild: false, hasChildren: !children.isEmpty, isOff: false, description: parent.description, rowOrder: parent.rowOrder))
            for child in children {
                rows.append(ScheduleRouteRow(label: childLabel(child), parentKey: parent.label, isChild: true, hasChildren: false, isOff: false, description: child.description.isEmpty ? child.memo : child.description, rowOrder: child.sortOrder))
            }
        }
        return rows
    }

    private func buildDriverAccounts(_ sources: [ScheduleDriverSource], assignments: [ScheduleAssignment], camp: String) -> [ScheduleDriverAccount] {
        var accounts: [String: ScheduleDriverAccount] = [:]
        for source in sources where (source.camp.isEmpty || ScheduleNormalization.campMatches(source.camp, camp)) && !isExcludedPosition(source.position) {
            let parsed = parseAccountToken(source.coupangID, defaultName: source.personName)
            let display = source.personName.isEmpty ? (source.coupangAdminName.isEmpty ? (parsed.name.isEmpty ? parsed.id : parsed.name) : source.coupangAdminName) : source.personName
            guard !display.isEmpty else { continue }
            let account = ScheduleDriverAccount(displayName: display, ownerName: source.personName.isEmpty ? display : source.personName, exportName: source.coupangAdminName.isEmpty ? (parsed.name.isEmpty ? display : parsed.name) : source.coupangAdminName, exportID: parsed.id, accountType: "본계정")
            accounts[ScheduleNormalization.accountKey(display), default: account] = account
        }
        for assignment in assignments {
            let display = assignment.displayValue
            guard !display.isEmpty else { continue }
            let account = ScheduleDriverAccount(displayName: display, ownerName: assignment.driverOwnerName.isEmpty ? display : assignment.driverOwnerName, exportName: assignment.driverExportName.isEmpty ? display : assignment.driverExportName, exportID: assignment.driverCoupangID, accountType: assignment.driverAccountType.isEmpty ? "본계정" : assignment.driverAccountType)
            let key = ScheduleNormalization.accountKey(display)
            if accounts[key] == nil { accounts[key] = account }
        }
        return accounts.values.sorted { $0.displayName < $1.displayName }
    }

    private func indexAccounts() {
        accountByKey.removeAll()
        for account in driverAccounts {
            for value in [account.displayName, account.ownerName, account.exportName, account.exportID] where !value.isEmpty {
                let key = ScheduleNormalization.accountKey(value)
                if accountByKey[key] == nil { accountByKey[key] = account }
            }
        }
    }

    private func makeSaveRow(key: ScheduleCellKey, camp: ScheduleCampOption) -> ScheduleSaveRow {
        let value = self.value(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        let original = assignmentByKey[key]
        let unchanged = original?.displayValue.trimmingCharacters(in: .whitespacesAndNewlines) == value
        let account = accountByKey[ScheduleNormalization.accountKey(value)]
        let row = allRouteRows.first { $0.label == key.routeLabel }
        let week = ScheduleDatePolicy.weekInfo(sunday: weekStart)
        let active = !value.isEmpty

        return ScheduleSaveRow(
            scheduleDate: key.date,
            isoYear: week.year,
            isoWeek: week.week,
            weekLabel: ScheduleDatePolicy.weekLabel(sunday: weekStart),
            camp: camp.name,
            wave: camp.wave,
            routeLabel: ScheduleNormalization.route(key.routeLabel),
            driverName: active ? value : nil,
            driverDisplayName: active ? value : nil,
            driverOwnerName: active ? (unchanged ? original?.driverOwnerName.nilIfBlank ?? value : account?.ownerName ?? value) : nil,
            driverExportName: active ? (unchanged ? original?.driverExportName.nilIfBlank ?? value : account?.exportName ?? value) : nil,
            driverCoupangID: active ? (unchanged ? original?.driverCoupangID.nilIfBlank : account?.exportID.nilIfBlank) : nil,
            driverAccountType: active ? (unchanged ? original?.driverAccountType.nilIfBlank ?? "직접입력" : account?.accountType ?? "직접입력") : nil,
            memo: active && unchanged ? original?.memo.nilIfBlank : nil,
            rowOrder: original?.rowOrder ?? row?.rowOrder ?? 0,
            cellColor: active ? (unchanged ? original?.cellColor.nilIfBlank : nil) : nil,
            isActive: active
        )
    }

    private func setWorkingValue(_ key: ScheduleCellKey, value: String) {
        workingValues[key] = value
        let original = assignmentByKey[key]?.displayValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.trimmingCharacters(in: .whitespacesAndNewlines) == original {
            dirtyKeys.remove(key)
        } else {
            dirtyKeys.insert(key)
        }
    }

    private func value(for key: ScheduleCellKey) -> String {
        workingValues[key] ?? assignmentByKey[key]?.displayValue ?? ""
    }

    private func childRows(parentKey: String) -> [ScheduleRouteRow] {
        allRouteRows.filter { $0.isChild && $0.parentKey == parentKey }
    }

    private func parentLabel(_ source: ScheduleRouteSource) -> String {
        ScheduleNormalization.route(source.parentRouteLabel.isEmpty ? ((source.route + source.sub).isEmpty ? source.routeLabel : source.route + source.sub) : source.parentRouteLabel)
    }

    private func childLabel(_ source: ScheduleRouteSource) -> String {
        let parent = parentLabel(source)
        guard !source.subSub.isEmpty else { return parent }
        let label = ScheduleNormalization.route(source.routeLabel)
        return !label.isEmpty && label != parent ? label : ScheduleNormalization.route(source.route + source.sub + source.subSub)
    }

    private func isExcludedPosition(_ position: String) -> Bool {
        let normalized = position.replacingOccurrences(of: " ", with: "").uppercased(with: Locale(identifier: "ko_KR"))
        return ["퇴사", "퇴직", "RETIRED", "RESIGNED", "INACTIVE", "서브", "SUB"].contains { normalized.contains($0) }
    }

    private func parseAccountToken(_ rawValue: String, defaultName: String) -> (id: String, name: String) {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return ("", defaultName.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let parts = raw.split(whereSeparator: { $0 == "/" || $0 == "／" }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return (raw, defaultName.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let first = parts.first ?? ""
        let last = parts.last ?? ""
        let rest = parts.dropFirst().joined(separator: " / ")
        if looksLikeID(first) && !looksLikeID(rest) { return (first, rest) }
        if !looksLikeID(first) && looksLikeID(last) { return (last, first) }
        if looksLikeID(first) { return (first, rest) }
        if looksLikeID(last) { return (last, first) }
        return (first, rest)
    }

    private func looksLikeID(_ value: String) -> Bool {
        !value.contains(where: { $0.isKorean }) && value.contains(where: { $0.isLetter || $0.isNumber })
    }

    private func collapseUniformChildren(_ assignments: [ScheduleAssignment]) -> [ScheduleAssignment] {
        var map: [ScheduleCellKey: ScheduleAssignment] = [:]
        for assignment in assignments where assignment.isActive {
            map[ScheduleCellKey(date: assignment.scheduleDate, routeLabel: ScheduleNormalization.route(assignment.routeLabel))] = assignment
        }
        for parent in allRouteRows where !parent.isOff && !parent.isChild && parent.hasChildren {
            let children = childRows(parentKey: parent.label)
            guard !children.isEmpty else { continue }
            for date in weekDates.map(ScheduleDatePolicy.iso) {
                let concrete = children.compactMap { map[ScheduleCellKey(date: date, routeLabel: $0.label)] }
                guard concrete.count == children.count, concrete.allSatisfy({ !$0.displayValue.isEmpty }) else { continue }
                let identities = concrete.map(scheduleIdentity)
                guard let identity = identities.first, !identity.isEmpty, identities.allSatisfy({ $0 == identity }) else { continue }
                let parentKey = ScheduleCellKey(date: date, routeLabel: parent.label)
                if let parentAssignment = map[parentKey], scheduleIdentity(parentAssignment) != identity { continue }
                if map[parentKey] == nil, let first = concrete.first {
                    map[parentKey] = first.replacingRouteLabel(parent.label, rowOrder: concrete.map(\.rowOrder).min() ?? first.rowOrder)
                }
                children.forEach { map.removeValue(forKey: ScheduleCellKey(date: date, routeLabel: $0.label)) }
            }
        }
        return Array(map.values)
    }

    private func scheduleIdentity(_ row: ScheduleAssignment) -> String {
        let candidates = [row.displayValue, row.driverOwnerName, row.driverDisplayName, row.driverName, row.driverExportName, row.driverCoupangID].filter { !$0.isEmpty }
        for candidate in candidates {
            if let account = accountByKey[ScheduleNormalization.accountKey(candidate)] {
                return ScheduleNormalization.accountKey(!account.ownerName.isEmpty ? account.ownerName : (!account.exportID.isEmpty ? account.exportID : candidate))
            }
        }
        return ScheduleNormalization.accountKey(candidates.first ?? "")
    }

    private func syncExpandedParents() {
        expandedParents.removeAll()
        for parent in allRouteRows where !parent.isOff && !parent.isChild && parent.hasChildren {
            if hasActualChildAssignment(parentKey: parent.label) { expandedParents.insert(parent.label) }
        }
        refreshVisibleRows()
    }

    private func hasActualChildAssignment(parentKey: String) -> Bool {
        let children = childRows(parentKey: parentKey)
        guard !children.isEmpty else { return false }
        for date in weekDates.map(ScheduleDatePolicy.iso) {
            if !value(for: ScheduleCellKey(date: date, routeLabel: parentKey)).isEmpty { continue }
            if children.contains(where: { !value(for: ScheduleCellKey(date: date, routeLabel: $0.label)).isEmpty }) { return true }
        }
        return false
    }

    private func refreshVisibleRows() {
        routeRows = allRouteRows.filter { !$0.isChild || expandedParents.contains($0.parentKey) }
    }

    private func clearLoadedWeek() {
        assignmentByKey.removeAll()
        workingValues.removeAll()
        dirtyKeys.removeAll()
        accountByKey.removeAll()
        allRouteRows.removeAll()
        routeRows.removeAll()
        expandedParents.removeAll()
        driverAccounts.removeAll()
    }

    private func friendly(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty { return description }
        return "입차 스케줄을 처리하지 못했습니다. 인터넷 연결을 확인해주세요."
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Character {
    var isKorean: Bool {
        unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }
}
