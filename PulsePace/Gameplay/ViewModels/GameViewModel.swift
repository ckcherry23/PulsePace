//
//  GameViewModel.swift
//  PulsePace
//
//  Created by Charisma Kausar on 16/3/23.
//

import Foundation
import QuartzCore
import AVKit

protocol RenderSystem {
    var sceneAdaptor: ([Entity: any GameHO]) -> Void { get }
}

class GameViewModel: ObservableObject, RenderSystem {
    private var displayLink: CADisplayLink?
    // FIXME: make private
    var gameEngine: GameEngine?
    private var audioPlayer: AVAudioPlayer?
    @Published var slideGameHOs: [SlideGameHOVM] = []
    @Published var holdGameHOs: [HoldGameHOVM] = []
    @Published var tapGameHOs: [TapGameHOVM] = []
    @Published var songPosition: Double = 0
    @Published var matchFeedMessages: [MatchFeedMessage] = []

    var score: String {
        guard let scoreManager = gameEngine?.scoreSystem?.scoreManager else {
            return String(0)
        }
        return String(format: "%06d", scoreManager.score)
    }

    var accuracy: String {
        String(Double(round(100 * 82.3883) / 100)) + "%"
    }

    var combo: String {
        guard let scoreManager = gameEngine?.scoreSystem?.scoreManager else {
            return String(0)
        }
        return String(scoreManager.comboCount) + "x"
    }

    var health: Double {
        50
    }

    var disruptors = Disruptor.allCases.map({ $0.rawValue })

    var selectedGameMode: ModeAttachment = ModeFactory.defaultMode
    var match: Match?

    typealias DictAsArray = [(key: String, value: String)]
    var otherPlayers: DictAsArray = []
    var leaderboard: DictAsArray = []

    lazy var sceneAdaptor: ([Entity: any GameHO]) -> Void = { [weak self] gameHOTable in
        self?.clear()
        guard let gameEngine = self?.gameEngine else {
            return
        }
        gameHOTable.forEach { gameHOEntity in
            if let slideGameHO = gameHOEntity.value as? SlideGameHO {
                self?.slideGameHOs.append(SlideGameHOVM(gameHO: slideGameHO, id: gameHOEntity.key.id,
                                                        eventManager: gameEngine.eventManager))
            } else if let holdGameHO = gameHOEntity.value as? HoldGameHO {
                self?.holdGameHOs.append(HoldGameHOVM(gameHO: holdGameHO, id: gameHOEntity.key.id,
                                                      eventManager: gameEngine.eventManager))
            } else if let tapGameHO = gameHOEntity.value as? TapGameHO {
                self?.tapGameHOs.append(TapGameHOVM(gameHO: tapGameHO, id: gameHOEntity.key.id,
                                                    eventManager: gameEngine.eventManager))
            } else {
                print("Unidentified game HO type")
            }
        }
    }

    private func clear() {
        slideGameHOs = []
        holdGameHOs = []
        tapGameHOs = []
    }

    var gameBackground: String {
        "game-background"
    }

    @objc func step() {
        guard let displayLink = displayLink else {
            print("No active display link")
            return
        }

        guard let gameEngine = gameEngine else {
            print("No game engine running")
            return
        }

        let deltaTime = displayLink.targetTimestamp - displayLink.timestamp

        gameEngine.step(deltaTime)
        sceneAdaptor(gameEngine.gameHOTable)

        guard let audioPlayer = audioPlayer else {
            print("No song player")
            return
        }

        songPosition = audioPlayer.currentTime
        updateMatchFeed()
        updateLeaderboard()
    }

    func assignMatch(_ match: Match) {
        self.match = match
        self.otherPlayers = []
        match.players.forEach({
            if $0.key != UserConfig().userId {
                self.otherPlayers.append((key: $0.key, value: $0.value))
            }
        })
    }

    func initEngine(with beatmap: Beatmap) {
        gameEngine = GameEngine(selectedGameMode, match: match)
        gameEngine?.load(beatmap)
    }

    func startGameplay() {
        createDisplayLink()
    }

    func toggleGameplay() {
        guard let isPaused = displayLink?.isPaused else {
            print("No active display link")
            return
        }

        displayLink?.isPaused = !isPaused
    }

    func stopGameplay() {
        displayLink?.invalidate()
        gameEngine = nil
        match = nil
        clear()
    }

    func initialisePlayer(audioPlayer: AVAudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    func setTarget(_ targetId: String) {
        gameEngine?.setTarget(targetId: targetId)
    }

    func setDisruptor(_ disruptor: Disruptor) {
        gameEngine?.setDisruptor(disruptor: disruptor)
    }

    private func createDisplayLink() {
        self.displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 75, maximum: 150, __preferred: 90)
        displayLink?.add(to: .current, forMode: .default)
    }

    private func updateMatchFeed() {
        matchFeedMessages = gameEngine?.matchFeedSystem?.matchFeedMessages.toArray() ?? []
        matchFeedMessages.sort(by: { x, y in x.timestamp < y.timestamp })
    }

    private func updateLeaderboard() {
        leaderboard = []
        (gameEngine?.scoreSystem as? DisruptorSystem)?.allScores.forEach({
            leaderboard.append((key: match?.players[$0.key] ?? "Anonymous",
                                value: String(format: "%06d", $0.value)))
            leaderboard.sort(by: { x, y in Int(x.value) ?? 0 > Int(y.value) ?? 0 })
        })
    }
}
