//
//  GameMode.swift
//  PulsePace
//
//  Created by James Chiu on 1/4/23.
//

import Foundation

final class ModeAttachment {
    let modeName: String
    var hOManager: HitObjectManager
    var evaluator: Evaluator
    var scoreSystem: ScoreSystem
    var listeningMatchEvents: [any MatchEvent.Type]
    var matchEventRelay: MatchEventRelay?
    var roomSetting: RoomSetting
    var gameViewElements: [GameViewElement]

    init(modeName: String, hOManager: HitObjectManager, scoreSystem: ScoreSystem,
         evaluator: Evaluator, roomSetting: RoomSetting,
         listeningMatchEvents: [any MatchEvent.Type], matchEventRelay: MatchEventRelay?,
         gameViewElements: [GameViewElement]) {
        self.modeName = modeName
        self.hOManager = hOManager
        self.evaluator = evaluator
        self.scoreSystem = scoreSystem
        self.roomSetting = roomSetting
        self.listeningMatchEvents = listeningMatchEvents
        self.matchEventRelay = matchEventRelay
        self.gameViewElements = gameViewElements
    }

    // ModeFactory reuses the same reference to each mode's ModeAttachment
    func clean() {
        hOManager.reset()
        scoreSystem.reset()
        evaluator.reset()
        matchEventRelay?.reset()
    }

    func requires(gameViewElement: GameViewElement) -> Bool {
        self.gameViewElements.contains(gameViewElement)
    }

    func configEngine(_ gameEngine: GameEngine) {
        gameEngine.hitObjectManager = hOManager
        gameEngine.evaluator = evaluator
        gameEngine.scoreSystem = scoreSystem

        if let matchEventRelay = matchEventRelay,
           let match = gameEngine.match {
            matchEventRelay.assignProperties(publisher: gameEngine.publishMatchEvent, match: match)
            gameEngine.systems.append(matchEventRelay)

            scoreSystem.attachToMatch(match)
        } else {
            print("No active match")
        }
    }
}

protocol Factory {
    associatedtype ProductType
    static var isPopulated: Bool { get }
    static var assemblies: [String: ProductType] { get }
    static func populate()
}

final class ModeFactory: Factory {
    static var isPopulated = false
    private static var gameModes: [GameMode] = []
    static var assemblies: [String: ModeAttachment] = [:]
    static var defaultMode = ModeAttachment(
        modeName: "Classic",
        hOManager: HitObjectManager(),
        scoreSystem: ScoreSystem(ScoreManager()),
        evaluator: DefaultEvaluator(),
        roomSetting: RoomSettingFactory.defaultSetting,
        listeningMatchEvents: [],
        matchEventRelay: nil,
        gameViewElements: [.gameplayArea, .playbackControls, .scoreBoard]
    )

    static func populate() {
        if isPopulated {
            return
        }
        isPopulated = true

        let coopMode = ModeAttachment(
            modeName: "Basic Coop",
            hOManager: CoopHOManager(),
            scoreSystem: CoopScoreSystem(ScoreManager()),
            evaluator: CoopEvaluator(),
            roomSetting: RoomSettingFactory.baseCoopSetting,
            listeningMatchEvents: [
                PublishMissTapEvent.self,
                PublishMissHoldEvent.self,
                PublishMissSlideEvent.self,
                PublishScoreEvent.self,
                PublishGameCompleteEvent.self
            ],
            matchEventRelay: CoopMatchEventRelay(),
            gameViewElements: [.gameplayArea, .scoreBoard]
        )

        // @Charisma attach with your evaluator
        let competitiveMode = ModeAttachment(
            modeName: "Rhythm Battle",
            hOManager: CompetitiveHOManager(),
            scoreSystem: DisruptorSystem(ScoreManager()),
            evaluator: DefaultEvaluator(),
            roomSetting: RoomSettingFactory.competitiveSetting,
            listeningMatchEvents: [
                PublishBombDisruptorEvent.self,
                PublishNoHintsDisruptorEvent.self,
                PublishDeathEvent.self,
                PublishScoreEvent.self
            ],
            matchEventRelay: CompetitiveMatchEventRelay(),
            gameViewElements: [
                .gameplayArea, .disruptorOptions, .matchFeed,
                .leaderboard, .livesCount
            ]
        )

        assemblies[defaultMode.modeName] = defaultMode
        assemblies[coopMode.modeName] = coopMode
        assemblies[competitiveMode.modeName] = competitiveMode

        gameModes.append(
            GameMode(image: "classic-mode", category: "Singleplayer", title: "Classic Mode",
                     caption: "Tap, Slide, Hold, Win!", page: Page.playPage, metaInfo: defaultMode.modeName))
        gameModes.append(
            GameMode(image: "catch-the-potato", category: "Multiplayer", title: "Catch The Potato",
                     caption: "Make up for your partner's misses!", page: Page.lobbyPage, metaInfo: coopMode.modeName))
        gameModes.append(
            GameMode(image: "rhythm-battle", category: "Multiplayer",
                     title: "Rhythm Battle",
                     caption: "Battle your friends with rhythm and strategy!", page: Page.lobbyPage,
                     metaInfo: competitiveMode.modeName))
    }

    /**
     Gets mode attachment before the game starts. Should only be called once as it will reset the existing game engine.
     */
    static func getModeAttachment(_ metaInfo: String) -> ModeAttachment {
        if !isPopulated {
            populate()
        }
        guard let selectedMode = assemblies[metaInfo] else {
            print("Requested mode not found, falling back to default")
            return defaultMode
        }
        selectedMode.clean()
        return selectedMode
    }

    static func getAllModes() -> [GameMode] {
        if !isPopulated {
            populate()
        }

        return gameModes
    }
}
