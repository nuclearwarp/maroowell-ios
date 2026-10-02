import SpriteKit
import SwiftUI
import UIKit

extension Notification.Name {
    static let upUpScoreUpdated = Notification.Name("upup_score_updated")
    static let upUpScoreSubmitFailed = Notification.Name("upup_score_submit_failed")
    static let upUpExitRequested = Notification.Name("upup_exit_requested")
}

struct MiniGameHubView: View {
    @StateObject private var model = MiniGameHubModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("미니게임")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)

                Text("시즌별 활성 게임만 표시됩니다. 최고 점수에 도전해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(MaroowellTheme.muted)

                if let game = model.activeGame {
                    gameCard(game)
                    rankingCard(game)
                } else if model.isLoading {
                    ProgressView("활성 게임을 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    Text(model.errorMessage ?? "현재 활성화된 미니게임이 없습니다.")
                        .font(.subheadline)
                        .foregroundStyle(MaroowellTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
            .padding(18)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("미니게임")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .upUpScoreUpdated)) { _ in
            Task { await model.refresh() }
        }
    }

    @ViewBuilder
    private func gameCard(_ game: MiniGameConfig) -> some View {
        NavigationLink { UpUpGameView(initialBestScore: model.leaderboard.myScore ?? 0) } label: {
            VStack(spacing: 10) {
                upUpCover
                    .frame(width: 112, height: 112)

                Text(game.displayName)
                    .font(.title2.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)

                Text("람콩이와 뒤집힌 토트박스를 밟고 끝없이 올라가세요.")
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.muted)
                    .multilineTextAlignment(.center)

                Text("시즌 \(game.seasonNo) · 내 계정 최고 기록  \(model.leaderboard.myScore ?? 0)점")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(MaroowellTheme.deepYellow)

                Text("게임 시작")
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(MaroowellTheme.border) }
        }
        .buttonStyle(.plain)
    }

    private var upUpCover: some View {
        Image("game_upup_cover")
            .resizable()
            .scaledToFit()
    }

    @ViewBuilder
    private func rankingCard(_ game: MiniGameConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("올라올라 랭킹")
                .font(.title3.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            if let rank = model.leaderboard.myRank, let score = model.leaderboard.myScore {
                Text("내 순위  \(rank)위 · \(score)점")
                    .font(.headline.weight(.black))
            } else {
                Text("아직 등록된 내 기록이 없습니다.")
                    .font(.headline.weight(.black))
            }

            Text("\(game.seasonKey) 시즌 · 전체 1~10위 · 계정별 최고점 1개")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            if model.leaderboard.rows.isEmpty {
                Text("첫 번째 기록에 도전해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(MaroowellTheme.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.leaderboard.rows) { row in
                    rankRow(row)
                }
            }

            Button("랭킹 새로고침") {
                Task { await model.refresh() }
            }
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 12))
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(MaroowellTheme.border) }
    }

    private func rankRow(_ row: MiniGameRankRow) -> some View {
        let isMe = row.userID == model.leaderboard.currentUserID
        return HStack(spacing: 10) {
            Text(rankSymbol(row.rank))
                .font(row.rank <= 3 ? .title3 : .caption.weight(.bold))
                .frame(width: 34)

            Text("\(row.organizationLabel) / \(row.displayName) / \(row.groupLabel)" + (isMe ? " · 나" : ""))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MaroowellTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)
            Text("\(row.score)점")
                .font(.subheadline.weight(.black))
                .foregroundStyle(MaroowellTheme.deepYellow)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(isMe ? MaroowellTheme.yellow.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private func rankSymbol(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)위"
        }
    }
}

struct UpUpGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scene: UpUpScene
    @State private var scoreError: String?

    init(initialBestScore: Int) {
        _scene = State(initialValue: UpUpScene(initialBestScore: initialBestScore))
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("올라올라")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { scene.scaleMode = .resizeFill }
            .onReceive(NotificationCenter.default.publisher(for: .upUpExitRequested)) { _ in
                dismiss()
            }
            .onReceive(NotificationCenter.default.publisher(for: .upUpScoreSubmitFailed)) { note in
                scoreError = note.object as? String ?? "점수 등록에 실패했습니다."
            }
            .alert("점수 등록 실패", isPresented: Binding(
                get: { scoreError != nil },
                set: { if !$0 { scoreError = nil } }
            )) {
                Button("확인", role: .cancel) { scoreError = nil }
            } message: {
                Text(scoreError ?? "")
            }
    }
}

private final class TotePlatform {
    let node: SKNode
    let width: CGFloat
    let height: CGFloat

    init(node: SKNode, width: CGFloat, height: CGFloat) {
        self.node = node
        self.width = width
        self.height = height
    }
}

private final class UpUpScene: SKScene {
    private let player = SKSpriteNode(texture: SKTexture(imageNamed: "game_upup_player"))
    private var platforms: [TotePlatform] = []
    private var horizontalDirection: CGFloat = 0
    private var velocity = CGVector.zero
    private var lastUpdateTime: TimeInterval = 0
    private var climbed: CGFloat = 0
    private var score = 0
    private var bestScore: Int
    private var started = false
    private var gameOver = false
    private var gamePaused = false

    private let playerSize = CGSize(width: 68, height: 68)
    private let gravity: CGFloat = -1680
    private let jumpSpeed: CGFloat = 700
    private let moveSpeed: CGFloat = 270

    override init(size: CGSize) {
        bestScore = 0
        super.init(size: size)
        backgroundColor = SKColor(red: 0.85, green: 0.95, blue: 0.98, alpha: 1)
        anchorPoint = .zero
    }

    convenience init(initialBestScore: Int) {
        self.init(size: CGSize(width: 390, height: 844))
        bestScore = max(0, initialBestScore)
    }

    override convenience init() {
        self.init(initialBestScore: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        reset(autoStart: false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        reset(autoStart: false)
    }

    private func reset(autoStart: Bool) {
        removeAllChildren()
        platforms.removeAll()
        climbed = 0
        score = 0
        horizontalDirection = autoStart ? 1 : 0
        velocity = .zero
        lastUpdateTime = 0
        started = autoStart
        gameOver = false
        gamePaused = false

        addChild(player)
        player.size = playerSize
        player.zPosition = 20

        let baseWidth = min(118, size.width * 0.33)
        let baseY: CGFloat = 135
        let base = makeTote(width: baseWidth, height: 60, color: nextToteColor())
        base.node.position = CGPoint(x: size.width / 2, y: baseY)
        addChild(base.node)
        platforms.append(base)

        player.position = CGPoint(
            x: size.width / 2,
            y: baseY + base.height / 2 + playerSize.height / 2
        )

        var y = baseY + 122
        while y < size.height + 220 {
            addPlatform(y: y)
            y += CGFloat(Int.random(in: 100...138))
        }

        addBackgroundDecoration()
        if autoStart {
            velocity.dy = jumpSpeed
        }
    }

    private func addBackgroundDecoration() {
        for index in 0..<5 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 54, height: 24))
            cloud.fillColor = SKColor.white.withAlphaComponent(0.48)
            cloud.strokeColor = .clear
            cloud.position = CGPoint(
                x: index.isMultiple(of: 2) ? size.width * 0.22 : size.width * 0.74,
                y: CGFloat(index) * max(1, size.height / 4) + 40
            )
            cloud.zPosition = -10
            addChild(cloud)
        }
    }

    private func addPlatform(y: CGFloat) {
        let width = CGFloat(Int.random(in: 96...132))
        let x = CGFloat.random(in: width / 2 ... max(width / 2, size.width - width / 2))
        let platform = makeTote(width: width, height: 60, color: nextToteColor())
        platform.node.position = CGPoint(x: x, y: y)
        addChild(platform.node)
        platforms.append(platform)
    }

    private func nextToteColor() -> SKColor {
        let value = Int.random(in: 0..<100)
        switch value {
        case 0..<48:
            return SKColor(red: 45/255, green: 161/255, blue: 224/255, alpha: 1)
        case 48..<67:
            return SKColor(red: 157/255, green: 103/255, blue: 66/255, alpha: 1)
        case 67..<82:
            return SKColor(red: 44/255, green: 168/255, blue: 86/255, alpha: 1)
        case 82..<94:
            return SKColor(red: 224/255, green: 61/255, blue: 62/255, alpha: 1)
        default:
            return SKColor(red: 205/255, green: 211/255, blue: 216/255, alpha: 1)
        }
    }

    private func makeTote(width: CGFloat, height: CGFloat, color: SKColor) -> TotePlatform {
        let root = SKNode()
        let dark = shade(color, factor: 0.50)
        let mid = shade(color, factor: 0.78)

        let body = SKShapeNode(rectOf: CGSize(width: width, height: height - 8), cornerRadius: 5)
        body.fillColor = color
        body.strokeColor = dark
        body.lineWidth = 1.4
        body.position.y = -1
        root.addChild(body)

        let topLip = SKShapeNode(rectOf: CGSize(width: width + 5, height: 10), cornerRadius: 4)
        topLip.fillColor = mid
        topLip.strokeColor = .clear
        topLip.position.y = height / 2 - 5
        root.addChild(topLip)

        let highlight = SKShapeNode(rectOf: CGSize(width: width - 16, height: 4), cornerRadius: 2)
        highlight.fillColor = SKColor.white.withAlphaComponent(0.28)
        highlight.strokeColor = .clear
        highlight.position.y = height / 2 - 6
        root.addChild(highlight)

        let panel = SKShapeNode(rectOf: CGSize(width: width * 0.46, height: height * 0.38), cornerRadius: 3)
        panel.fillColor = shade(color, factor: 0.66)
        panel.strokeColor = dark
        panel.lineWidth = 1.2
        panel.position.y = -2
        root.addChild(panel)

        for side: CGFloat in [-1, 1] {
            let post = SKShapeNode(rectOf: CGSize(width: 7, height: height - 19), cornerRadius: 2)
            post.fillColor = dark
            post.strokeColor = .clear
            post.position = CGPoint(x: side * (width / 2 - 9), y: -2)
            root.addChild(post)

            let bracePath = CGMutablePath()
            bracePath.move(to: CGPoint(x: side * (width / 2 - 11), y: -height / 2 + 10))
            bracePath.addLine(to: CGPoint(x: side * (width * 0.23), y: height * 0.12))
            let brace = SKShapeNode(path: bracePath)
            brace.strokeColor = dark
            brace.lineWidth = 1.6
            root.addChild(brace)
        }

        let bottomLip = SKShapeNode(rectOf: CGSize(width: width + 6, height: 9), cornerRadius: 4)
        bottomLip.fillColor = dark
        bottomLip.strokeColor = .clear
        bottomLip.position.y = -height / 2 + 4.5
        root.addChild(bottomLip)

        return TotePlatform(node: root, width: width, height: height)
    }

    private func shade(_ color: SKColor, factor: CGFloat) -> SKColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SKColor(
            red: min(1, red * factor),
            green: min(1, green * factor),
            blue: min(1, blue * factor),
            alpha: alpha
        )
    }

    override func update(_ currentTime: TimeInterval) {
        guard started, !gameOver, !gamePaused else { return }

        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1 / 60
        } else {
            dt = min(0.032, CGFloat(currentTime - lastUpdateTime))
        }
        lastUpdateTime = currentTime

        let previousBottom = player.position.y - playerSize.height / 2
        let wantedVX = horizontalDirection * moveSpeed
        velocity.dx += (wantedVX - velocity.dx) * min(1, dt * 11)
        velocity.dy += gravity * dt

        player.position.x += velocity.dx * dt
        player.position.y += velocity.dy * dt
        player.position.x = min(
            max(playerSize.width / 2, player.position.x),
            size.width - playerSize.width / 2
        )

        if velocity.dy < 0 {
            let newBottom = player.position.y - playerSize.height / 2
            for platform in platforms {
                let top = platform.node.position.y + platform.height / 2
                let left = platform.node.position.x - platform.width / 2
                let right = platform.node.position.x + platform.width / 2
                let playerLeft = player.position.x - playerSize.width * 0.30
                let playerRight = player.position.x + playerSize.width * 0.30

                if playerRight > left,
                   playerLeft < right,
                   previousBottom >= top - 5,
                   newBottom <= top {
                    player.position.y = top + playerSize.height / 2
                    velocity.dy = jumpSpeed

                    if score >= 500 {
                        let cameraKick: CGFloat
                        switch score {
                        case 2500...: cameraKick = 7
                        case 1800...: cameraKick = 6
                        case 1200...: cameraKick = 5
                        case 800...: cameraKick = 4
                        default: cameraKick = 3
                        }
                        player.position.y -= cameraKick
                        platforms.forEach { $0.node.position.y -= cameraKick }
                        climbed += cameraKick
                        score = max(score, Int(climbed / 10))
                    }
                    break
                }
            }
        }

        let anchor = size.height * 0.58
        if player.position.y > anchor {
            let shift = player.position.y - anchor
            player.position.y -= shift
            platforms.forEach { $0.node.position.y -= shift }
            climbed += shift
            score = max(score, Int(climbed / 10))
        }

        platforms.removeAll { platform in
            if platform.node.position.y < -80 {
                platform.node.removeFromParent()
                return true
            }
            return false
        }

        var top = platforms.map(\.node.position.y).max() ?? 0
        while top < size.height + 180 {
            top += CGFloat(Int.random(in: 100...138))
            addPlatform(y: top)
        }

        if player.position.y < -90 {
            finishGame()
        }
    }

    private func finishGame() {
        gameOver = true
        horizontalDirection = 0
        bestScore = max(bestScore, score)

        let finalScore = score
        Task {
            do {
                let serverBest = try await MiniGameRankingService.submitScore(
                    gameKey: "upup",
                    score: finalScore,
                    countAttempt: true
                )
                await MainActor.run {
                    self.bestScore = max(self.bestScore, serverBest)
                    NotificationCenter.default.post(name: .upUpScoreUpdated, object: nil)
                }
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .upUpScoreSubmitFailed,
                        object: error.localizedDescription
                    )
                }
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let hitNames = Set(nodes(at: point).compactMap(\.name))

        if gamePaused {
            if hitNames.contains("pause_resume") {
                gamePaused = false
                lastUpdateTime = 0
            } else if hitNames.contains("pause_restart") {
                reset(autoStart: true)
            } else if hitNames.contains("pause_exit") {
                NotificationCenter.default.post(name: .upUpExitRequested, object: nil)
            }
            return
        }

        if gameOver {
            if hitNames.contains("gameover_retry") {
                reset(autoStart: true)
            } else if hitNames.contains("gameover_exit") {
                NotificationCenter.default.post(name: .upUpExitRequested, object: nil)
            }
            return
        }

        if hitNames.contains("pause_button"), started {
            gamePaused = true
            return
        }

        if !started {
            started = true
            horizontalDirection = 1
            velocity.dy = jumpSpeed
            lastUpdateTime = 0
            return
        }

        horizontalDirection = horizontalDirection >= 0 ? -1 : 1
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func didFinishUpdate() {
        childNode(withName: "hud")?.removeFromParent()

        let hud = SKNode()
        hud.name = "hud"
        hud.zPosition = 100

        addHudLabels(to: hud)

        if started && !gameOver {
            addPauseButton(to: hud)
        }
        if !started && !gameOver {
            addStartPanel(to: hud)
        }
        if gamePaused {
            addPausePanel(to: hud)
        }
        if gameOver {
            addGameOverPanel(to: hud)
        }

        addChild(hud)
    }

    private func addHudLabels(to hud: SKNode) {
        let scoreLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        scoreLabel.text = "\(score)점"
        scoreLabel.fontSize = 21
        scoreLabel.fontColor = SKColor(red: 23/255, green: 37/255, blue: 46/255, alpha: 1)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 18, y: size.height - 42)
        hud.addChild(scoreLabel)

        let bestLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        bestLabel.text = "BEST \(bestScore)"
        bestLabel.fontSize = 12
        bestLabel.fontColor = SKColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1)
        bestLabel.horizontalAlignmentMode = .left
        bestLabel.position = CGPoint(x: 18, y: size.height - 62)
        hud.addChild(bestLabel)
    }

    private func addPauseButton(to hud: SKNode) {
        let button = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 17)
        button.name = "pause_button"
        button.fillColor = SKColor.white.withAlphaComponent(0.94)
        button.strokeColor = SKColor(red: 0.55, green: 0.62, blue: 0.66, alpha: 1)
        button.lineWidth = 1.5
        button.position = CGPoint(x: size.width - 45, y: size.height - 44)
        hud.addChild(button)

        for offset: CGFloat in [-7, 7] {
            let bar = SKShapeNode(rectOf: CGSize(width: 5, height: 24), cornerRadius: 2)
            bar.name = "pause_button"
            bar.fillColor = SKColor(red: 23/255, green: 37/255, blue: 46/255, alpha: 1)
            bar.strokeColor = .clear
            bar.position = CGPoint(x: offset, y: 0)
            button.addChild(bar)
        }
    }

    private func addStartPanel(to hud: SKNode) {
        let panel = panelNode(height: 245)
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        hud.addChild(panel)

        addLabel("올라올라", size: 30, y: 52, to: panel)
        addLabel("화면을 누를 때마다 좌우 방향이 바뀌어요.", size: 14, y: 5, to: panel,
                 color: SKColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1))
        addLabel("화면을 눌러 시작", size: 16, y: -54, to: panel,
                 color: SKColor(red: 122/255, green: 90/255, blue: 0, alpha: 1))
    }

    private func addPausePanel(to hud: SKNode) {
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = SKColor.black.withAlphaComponent(0.52)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        hud.addChild(dim)

        let panel = panelNode(height: 360)
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        hud.addChild(panel)
        addLabel("일시정지", size: 30, y: 128, to: panel)

        addMenuButton("▶  계속하기", name: "pause_resume", y: 55, yellow: true, to: panel)
        addMenuButton("↻  처음부터 다시하기", name: "pause_restart", y: -12, to: panel)
        addMenuButton("⌂  미니게임으로 나가기", name: "pause_exit", y: -79, danger: true, to: panel)
    }

    private func addGameOverPanel(to hud: SKNode) {
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = SKColor.black.withAlphaComponent(0.52)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        hud.addChild(dim)

        let panel = panelNode(height: 330)
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        hud.addChild(panel)
        addLabel("게임 오버", size: 30, y: 112, to: panel)
        addLabel("\(score)점", size: 26, y: 70, to: panel)
        addLabel("최고 기록 \(bestScore)점", size: 14, y: 38, to: panel,
                 color: SKColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1))

        addMenuButton("↻  다시하기", name: "gameover_retry", y: -28, yellow: true, to: panel)
        addMenuButton("⌂  미니게임으로 나가기", name: "gameover_exit", y: -95, danger: true, to: panel)
    }

    private func panelNode(height: CGFloat) -> SKShapeNode {
        let panel = SKShapeNode(
            rectOf: CGSize(width: min(330, size.width - 56), height: height),
            cornerRadius: 24
        )
        panel.fillColor = SKColor(red: 1, green: 0.99, blue: 0.965, alpha: 0.98)
        panel.strokeColor = .clear
        return panel
    }

    private func addMenuButton(
        _ text: String,
        name: String,
        y: CGFloat,
        yellow: Bool = false,
        danger: Bool = false,
        to panel: SKNode
    ) {
        let button = SKShapeNode(rectOf: CGSize(width: min(278, size.width - 100), height: 50), cornerRadius: 15)
        button.name = name
        button.fillColor = yellow
            ? SKColor(red: 1, green: 0.77, blue: 0, alpha: 1)
            : (danger ? SKColor(red: 1, green: 0.96, blue: 0.96, alpha: 1) : .white)
        button.strokeColor = SKColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
        button.lineWidth = 1
        button.position = CGPoint(x: 0, y: y)
        panel.addChild(button)

        let label = SKLabelNode(fontNamed: "Arial-BoldMT")
        label.name = name
        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor(red: 23/255, green: 37/255, blue: 46/255, alpha: 1)
        label.verticalAlignmentMode = .center
        button.addChild(label)
    }

    private func addLabel(
        _ text: String,
        size: CGFloat,
        y: CGFloat,
        to panel: SKNode,
        color: SKColor = SKColor(red: 23/255, green: 37/255, blue: 46/255, alpha: 1)
    ) {
        let label = SKLabelNode(fontNamed: "Arial-BoldMT")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        panel.addChild(label)
    }
}
