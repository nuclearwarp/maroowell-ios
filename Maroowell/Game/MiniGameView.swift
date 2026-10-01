import SpriteKit
import SwiftUI

struct MiniGameHubView: View {
    @AppStorage("upup_best_score") private var bestScore = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("미니게임")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)

                Text("짧고 간단하게, 최고 기록에 도전하세요.")
                    .font(.subheadline)
                    .foregroundStyle(MaroowellTheme.muted)

                NavigationLink {
                    UpUpGameView()
                } label: {
                    VStack(spacing: 12) {
                        Image("menu_numbering_rangkong")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)

                        Text("올라올라")
                            .font(.title2.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)

                        Text("람콩이와 뒤집힌 토트박스를 밟고 계속 올라가세요.")
                            .font(.caption)
                            .foregroundStyle(MaroowellTheme.muted)
                            .multilineTextAlignment(.center)

                        Text("최고 기록 \(bestScore)점")
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(MaroowellTheme.border)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("미니게임")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UpUpGameView: View {
    @State private var scene = UpUpScene()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("올라올라")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                scene.scaleMode = .resizeFill
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
    private let player = SKSpriteNode(imageNamed: "menu_numbering_rangkong")
    private var platforms: [TotePlatform] = []
    private var horizontalDirection: CGFloat = 0
    private var velocity = CGVector.zero
    private var lastUpdateTime: TimeInterval = 0
    private var climbed: CGFloat = 0
    private var score = 0
    private var bestScore = UserDefaults.standard.integer(forKey: "upup_best_score")
    private var started = false
    private var gameOver = false

    private let playerSize = CGSize(width: 56, height: 56)
    private let gravity: CGFloat = -1680
    private let jumpSpeed: CGFloat = 700
    private let moveSpeed: CGFloat = 270

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = SKColor(red: 0.85, green: 0.95, blue: 0.98, alpha: 1)
        anchorPoint = .zero
    }

    override convenience init() {
        self.init(size: CGSize(width: 390, height: 844))
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
        horizontalDirection = 0
        velocity = .zero
        lastUpdateTime = 0
        started = autoStart
        gameOver = false

        addChild(player)
        player.size = playerSize
        player.zPosition = 20

        let baseWidth = min(118, size.width * 0.33)
        let baseY: CGFloat = 120
        let base = makeTote(width: baseWidth, height: 36, color: nextToteColor())
        base.node.position = CGPoint(x: size.width / 2, y: baseY)
        addChild(base.node)
        platforms.append(base)

        player.position = CGPoint(
            x: size.width / 2,
            y: baseY + base.height / 2 + playerSize.height / 2
        )

        var y = baseY + 112
        while y < size.height + 220 {
            addPlatform(y: y)
            y += CGFloat(Int.random(in: 88...126))
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
        let width = CGFloat(Int.random(in: 92...126))
        let x = CGFloat.random(in: width / 2 ... max(width / 2, size.width - width / 2))
        let platform = makeTote(width: width, height: 36, color: nextToteColor())
        platform.node.position = CGPoint(x: x, y: y)
        addChild(platform.node)
        platforms.append(platform)
    }

    private func nextToteColor() -> SKColor {
        let value = Int.random(in: 0..<100)
        switch value {
        case 0..<56:
            return SKColor(red: 119/255, green: 204/255, blue: 232/255, alpha: 1)
        case 56..<78:
            return SKColor(red: 153/255, green: 108/255, blue: 72/255, alpha: 1)
        case 78..<92:
            return SKColor(red: 67/255, green: 163/255, blue: 96/255, alpha: 1)
        default:
            return SKColor(red: 211/255, green: 70/255, blue: 68/255, alpha: 1)
        }
    }

    private func makeTote(width: CGFloat, height: CGFloat, color: SKColor) -> TotePlatform {
        let root = SKNode()

        let body = SKShapeNode(rectOf: CGSize(width: width, height: height - 7), cornerRadius: 6)
        body.fillColor = color
        body.strokeColor = color.withAlphaComponent(0.78)
        body.position.y = -3.5
        root.addChild(body)

        let lip = SKShapeNode(rectOf: CGSize(width: width + 8, height: 9), cornerRadius: 4)
        lip.fillColor = color.withAlphaComponent(0.78)
        lip.strokeColor = .clear
        lip.position.y = height / 2 - 4.5
        root.addChild(lip)

        let highlight = SKShapeNode(rectOf: CGSize(width: width - 14, height: 5), cornerRadius: 2)
        highlight.fillColor = SKColor.white.withAlphaComponent(0.18)
        highlight.strokeColor = .clear
        highlight.position.y = height / 2 - 10
        root.addChild(highlight)

        for index in 1...4 {
            let path = CGMutablePath()
            let x = -width / 2 + width * CGFloat(index) / 5
            path.move(to: CGPoint(x: x, y: -height / 2 + 5))
            path.addLine(to: CGPoint(x: x, y: height / 2 - 14))
            let rib = SKShapeNode(path: path)
            rib.strokeColor = color.withAlphaComponent(0.68)
            rib.lineWidth = 1.2
            root.addChild(rib)
        }

        return TotePlatform(node: root, width: width, height: height)
    }

    override func update(_ currentTime: TimeInterval) {
        guard started, !gameOver else { return }

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
            top += CGFloat(Int.random(in: 88...126))
            addPlatform(y: top)
        }

        if player.position.y < -90 {
            finishGame()
        }
    }

    private func finishGame() {
        gameOver = true
        horizontalDirection = 0
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(score, forKey: "upup_best_score")
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if gameOver {
            reset(autoStart: true)
        } else if !started {
            started = true
            velocity.dy = jumpSpeed
            lastUpdateTime = 0
        }

        let point = touch.location(in: self)
        horizontalDirection = point.x < size.width / 2 ? -1 : 1
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        horizontalDirection = point.x < size.width / 2 ? -1 : 1
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        horizontalDirection = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        horizontalDirection = 0
    }

    override func didFinishUpdate() {
        childNode(withName: "hud")?.removeFromParent()

        let hud = SKNode()
        hud.name = "hud"
        hud.zPosition = 100

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

        if !started || gameOver {
            let panel = SKShapeNode(
                rectOf: CGSize(width: min(330, size.width - 56), height: gameOver ? 260 : 245),
                cornerRadius: 24
            )
            panel.fillColor = SKColor.white.withAlphaComponent(0.92)
            panel.strokeColor = .clear
            panel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
            hud.addChild(panel)

            let title = SKLabelNode(fontNamed: "Arial-BoldMT")
            title.text = gameOver ? "게임 오버" : "올라올라"
            title.fontSize = 30
            title.fontColor = SKColor(red: 23/255, green: 37/255, blue: 46/255, alpha: 1)
            title.position = CGPoint(x: size.width / 2, y: size.height * 0.60)
            hud.addChild(title)

            let detail = SKLabelNode(fontNamed: "Arial-BoldMT")
            detail.text = gameOver ? "\(score)점 · 최고 \(bestScore)점" : "왼쪽/오른쪽을 눌러 이동"
            detail.fontSize = 15
            detail.fontColor = SKColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1)
            detail.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
            hud.addChild(detail)

            let action = SKLabelNode(fontNamed: "Arial-BoldMT")
            action.text = gameOver ? "화면을 눌러 다시 시작" : "화면을 눌러 시작"
            action.fontSize = 16
            action.fontColor = SKColor(red: 122/255, green: 90/255, blue: 0, alpha: 1)
            action.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
            hud.addChild(action)
        }

        addChild(hud)
    }
}
