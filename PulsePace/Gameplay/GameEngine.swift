//
//  GameEngine.swift
//  PulsePace
//
//  Created by James Chiu on 13/3/23.
//

import Foundation

class GameEngine {
    var scoreSystem: ScoreSystem?
    var scoreManager: ScoreManager?
    var hitObjectManager: HitObjectManager?
    var matchFeedSystem: MatchFeedSystem?
    private var inputManager: InputManager?
    private var conductor: Conductor?

    var gameHOTable: [Entity: any GameHO]
    private var allObjects: Set<Entity>

    var match: Match?
    var eventManager = EventManager()
    private var systems: [System] = []

    lazy var objRemover: (Entity) -> Void = { [weak self] removedObject in
        guard let self = self else {
            fatalError("No active game engine to remove entities")
        }
        self.allObjects.remove(removedObject)
        guard let removedGameHO = self.gameHOTable.removeValue(forKey: removedObject) else {
            return
        }

        guard let scoreManager = self.scoreSystem?.scoreManager else {
            fatalError("All game engine instances should have a score manager")
        }
        if !removedGameHO.isHit {
            scoreManager.missCount += 1
        }
    }

    lazy var gameHOAdder: (any GameHO) -> Void = { [weak self] gameHO in
        self?.allObjects.insert(gameHO.wrappingObject)
        self?.gameHOTable[gameHO.wrappingObject] = gameHO
    }

    init(_ modeAttachment: ModeAttachment, match: Match? = nil) {
        self.allObjects = Set()
        self.gameHOTable = [:]
        self.scoreManager = ScoreManager()

        if let match = match {
            self.match = match
            eventManager.setMatchEventHandler(matchEventHandler: self)
            matchFeedSystem = MatchFeedSystem(playerNames: match.players)
            if let matchFeedSystem = matchFeedSystem {
                systems.append(matchFeedSystem)
            }
        }

        systems.append(InputSystem())

        modeAttachment.configEngine(self)
        guard let hitObjectManager = hitObjectManager, let scoreSystem = scoreSystem else {
            fatalError("Mode attachment should have initialized hit object manager and score system")
        }
        scoreSystem.scoreManager = scoreManager
        if let disruptorSystem = scoreSystem as? DisruptorSystem,
           let match = match {
            disruptorSystem.selectedTarget = match.players.first(where: { $0.key != UserConfig().userId })?.key
            ?? UserConfig().userId
        }
        systems.append(hitObjectManager)
        systems.append(scoreSystem)
        systems.forEach({ $0.registerEventHandlers(eventManager: self.eventManager) })
    }

    func load(_ beatmap: Beatmap) {
        hitObjectManager?.feedBeatmap(beatmap: beatmap, remover: objRemover)
        self.conductor = Conductor(bpm: beatmap.bpm)
    }

    func step(_ deltaTime: Double) {
        guard let conductor = conductor else {
            print("Cannot advance engine state without conductor")
            return
        }
        conductor.step(deltaTime)
        if let spawnGameHOs = hitObjectManager?.checkBeatMap(conductor.songPosition) {
            spawnGameHOs.forEach { gameHOAdder($0) }
        }

        // Update state of gameHO -> process all inputs on HO
        // -> delegate responses to respective system -> delegate UI display to renderer
        allObjects.forEach { object in
            if let gameHO = gameHOTable[object] {
                gameHO.updateState(currBeat: conductor.songPosition)
            } else {
                print("By game design params, all objects should have a hit object component")
            }
        }
        eventManager.handleAllEvents()
    }
}

extension GameEngine: MatchEventHandler {
    func publishMatchEvent(message: MatchEventMessage) {
        match?.dataManager.publishEvent(matchEvent: message)
    }

    func subscribeMatchEvents() {
        match?.dataManager.subscribeEvents(eventManager: eventManager)
    }
}

protocol MatchEventHandler: AnyObject {
    func publishMatchEvent(message: MatchEventMessage)
    func subscribeMatchEvents()
}
