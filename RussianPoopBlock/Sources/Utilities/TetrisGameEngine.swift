import UIKit

struct Block {
    let type: Int
    var shape: [[Int]]
    var x: Int
    var y: Int

    init(type: Int, shape: [[Int]], x: Int = 0, y: Int = 0) {
        self.type = type
        self.shape = shape
        self.x = x
        self.y = y
    }
}

class TetrisGameEngine {
    static let gridWidth = 10
    static let gridHeight = 20
    static let gameSpeed: TimeInterval = 1.0

    private(set) var gameGrid: [[Int]]
    private(set) var currentBlock: Block?
    private(set) var nextBlockType: Int = 0
    private(set) var score: Int = 0
    private(set) var gameDuration: Int = 0
    private(set) var isGameRunning: Bool = false

    var gameStartTime: Date?

    let blockIcons: [String] = [
        "BlockImages/egg", "BlockImages/cabbage", "BlockImages/cigarette",
        "BlockImages/poop_block", "BlockImages/poop_block",
        "BlockImages/stone", "BlockImages/stone"
    ]

    let blockSounds: [SoundManager.SoundType] = [
        .jidan, .baicai, .yantou, .baba, .baba, .shitou, .shitou
    ]

    static let blocksShapes: [[[Int]]] = [
        [[0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]],
        [[1, 1], [1, 1]],
        [[0, 1, 0], [1, 1, 1], [0, 0, 0]],
        [[0, 0, 1], [1, 1, 1], [0, 0, 0]],
        [[1, 0, 0], [1, 1, 1], [0, 0, 0]],
        [[0, 1, 1], [1, 1, 0], [0, 0, 0]],
        [[1, 1, 0], [0, 1, 1], [0, 0, 0]]
    ]

    private var gameTimer: Timer?
    private var durationTimer: Timer?
    private var currentPlayingSoundId: Int = -1

    var onScoreChanged: ((Int) -> Void)?
    var onGameGridUpdated: (() -> Void)?
    var onNextBlockUpdated: ((Int) -> Void)?
    var onGameOver: ((Int, Int) -> Void)?

    init() {
        gameGrid = Array(repeating: Array(repeating: 0, count: TetrisGameEngine.gridWidth), count: TetrisGameEngine.gridHeight)
    }

    func startGame() {
        resetGame()
        isGameRunning = true
        gameStartTime = Date()

        SoundManager.shared.initSoundManager(soundEnabled: GameSettings.shared.gameSoundEnabled)

        spawnNewBlock()

        gameTimer = Timer.scheduledTimer(withTimeInterval: TetrisGameEngine.gameSpeed, repeats: true) { [weak self] _ in
            self?.moveDown()
        }

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.gameDuration += 1
        }
    }

    func resetGame() {
        gameTimer?.invalidate()
        durationTimer?.invalidate()
        gameTimer = nil
        durationTimer = nil

        gameGrid = Array(repeating: Array(repeating: 0, count: TetrisGameEngine.gridWidth), count: TetrisGameEngine.gridHeight)
        currentBlock = nil
        score = 0
        gameDuration = 0
        isGameRunning = false
        gameStartTime = nil
    }

    func pauseGame() {
        isGameRunning = false
        gameTimer?.invalidate()
        durationTimer?.invalidate()
    }

    func resumeGame() {
        guard !isGameRunning else { return }
        isGameRunning = true

        gameTimer = Timer.scheduledTimer(withTimeInterval: TetrisGameEngine.gameSpeed, repeats: true) { [weak self] _ in
            self?.moveDown()
        }

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.gameDuration += 1
        }
    }

    func stopGame() {
        isGameRunning = false
        gameTimer?.invalidate()
        durationTimer?.invalidate()
        gameTimer = nil
        durationTimer = nil
    }

    private func spawnNewBlock() {
        let blockType = nextBlockType
        let shape = TetrisGameEngine.blocksShapes[blockType]

        let startX = TetrisGameEngine.gridWidth / 2 - shape[0].count / 2

        currentBlock = Block(type: blockType, shape: shape, x: startX, y: 0)

        nextBlockType = Int.random(in: 0..<TetrisGameEngine.blocksShapes.count)

        onNextBlockUpdated?(nextBlockType)
        onScoreChanged?(score)

        playBlockSpawnSound()

        if checkCollision(x: currentBlock!.x, y: currentBlock!.y, shape: currentBlock!.shape) {
            endGame()
        }
    }

    func moveLeft() {
        guard let block = currentBlock, isGameRunning else { return }
        if !checkCollision(x: block.x - 1, y: block.y, shape: block.shape) {
            currentBlock?.x -= 1
            onGameGridUpdated?()
        }
    }

    func moveRight() {
        guard let block = currentBlock, isGameRunning else { return }
        if !checkCollision(x: block.x + 1, y: block.y, shape: block.shape) {
            currentBlock?.x += 1
            onGameGridUpdated?()
        }
    }

    func moveDown() {
        guard let block = currentBlock, isGameRunning else { return }

        if !checkCollision(x: block.x, y: block.y + 1, shape: block.shape) {
            currentBlock?.y += 1
            onGameGridUpdated?()
        } else {
            fixBlock()
            checkLines()
            spawnNewBlock()
        }
    }

    func fastDrop() {
        guard let block = currentBlock, isGameRunning else { return }

        var dropCount = 0
        while !checkCollision(x: block.x, y: currentBlock!.y + 1, shape: block.shape) {
            currentBlock?.y += 1
            dropCount += 1
            if dropCount > 100 { break }
        }

        fixBlock()
        checkLines()
        onGameGridUpdated?()
        spawnNewBlock()
    }

    func rotateBlock() {
        guard let block = currentBlock, isGameRunning else { return }

        let rotatedShape = rotateMatrix(block.shape)

        if !checkCollision(x: block.x, y: block.y, shape: rotatedShape) {
            currentBlock?.shape = rotatedShape
            onGameGridUpdated?()
        }
    }

    private func rotateMatrix(_ matrix: [[Int]]) -> [[Int]] {
        let rows = matrix.count
        let cols = matrix[0].count
        var rotated = Array(repeating: Array(repeating: 0, count: rows), count: cols)

        for i in 0..<rows {
            for j in 0..<cols {
                rotated[j][rows - 1 - i] = matrix[i][j]
            }
        }

        return rotated
    }

    private func checkCollision(x: Int, y: Int, shape: [[Int]]) -> Bool {
        for row in 0..<shape.count {
            for col in 0..<shape[row].count {
                if shape[row][col] == 1 {
                    let newX = x + col
                    let newY = y + row

                    if newX < 0 || newX >= TetrisGameEngine.gridWidth || newY >= TetrisGameEngine.gridHeight {
                        return true
                    }

                    if newY >= 0 && gameGrid[newY][newX] != 0 {
                        return true
                    }
                }
            }
        }

        return false
    }

    private func fixBlock() {
        guard let block = currentBlock else { return }

        for row in 0..<block.shape.count {
            for col in 0..<block.shape[row].count {
                if block.shape[row][col] == 1 {
                    let gridX = block.x + col
                    let gridY = block.y + row

                    if gridX >= 0 && gridX < TetrisGameEngine.gridWidth && gridY >= 0 && gridY < TetrisGameEngine.gridHeight {
                        gameGrid[gridY][gridX] = block.type + 1
                    }
                }
            }
        }

        score += 5
        onScoreChanged?(score)
    }

    private func checkLines() {
        var linesCleared = 0

        var row = TetrisGameEngine.gridHeight - 1
        while row >= 0 {
            if isLineFull(row) {
                clearLine(row)
                linesCleared += 1
            } else {
                row -= 1
            }
        }

        if linesCleared > 0 {
            switch linesCleared {
            case 1: score += 10
            case 2: score += 30
            case 3: score += 60
            case 4: score += 100
            default: score += linesCleared * 100
            }
            onScoreChanged?(score)
        }
    }

    private func isLineFull(_ row: Int) -> Bool {
        for col in 0..<TetrisGameEngine.gridWidth {
            if gameGrid[row][col] == 0 {
                return false
            }
        }
        return true
    }

    private func clearLine(_ line: Int) {
        for row in stride(from: line, to: 0, by: -1) {
            gameGrid[row] = gameGrid[row - 1]
        }

        gameGrid[0] = Array(repeating: 0, count: TetrisGameEngine.gridWidth)

        onGameGridUpdated?()
    }

    private func playBlockSpawnSound() {
        guard let block = currentBlock, GameSettings.shared.gameSoundEnabled else { return }
        SoundManager.shared.playSound(blockSounds[block.type])
    }

    private func endGame() {
        isGameRunning = false
        gameTimer?.invalidate()
        durationTimer?.invalidate()

        SoundManager.shared.playSound(.jieshu)

        let duration = gameStartTime.map { Int(Date().timeIntervalSince($0)) } ?? gameDuration

        onGameOver?(score, duration)
    }

    func getNextBlockShape() -> [[Int]] {
        return TetrisGameEngine.blocksShapes[nextBlockType]
    }
}
