//
//  SpinCommand.swift
//  PulsePace
//
//  Created by Charisma Kausar on 9/3/23.
//

class SpinCommand: InputCommand {
    override private init(action: @escaping InputCommand.Action, completion: InputCommand.Action? = nil) {
        super.init(action: action, completion: completion)
    }

    convenience init() {
        self.init(
            action: { _ in
                print("Spin")
//                receiver.checkOnInput(inputData: inputData)
            },
            completion: { _ in
//                receiver.checkOnInputEnd(inputData: inputData)
            }
        )
    }
}
