//
//  Command.swift
//  PulsePace
//
//  Referenced from: https://khawerkhaliq.com/blog/swift-command-pattern/
//  Created by Charisma Kausar on 15/3/23.
//

protocol Command {
    associatedtype ActionArguments
    typealias Action = (ActionArguments) -> Void
    var action: Action { get }
    func execute(inputData: ActionArguments)
}

extension Command {
    func execute(inputData: ActionArguments) {
        action(inputData)
    }
}
