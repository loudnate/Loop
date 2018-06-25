//
//  UserDefaults+CGM.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


extension UserDefaults {
    private enum Key: String {
        case cgmSettings = "com.loopkit.Loop.cgmSettings"
    }

    var cgm: CGMType? {
        get {
            if let rawValue = dictionary(forKey: Key.cgmSettings.rawValue) {
                return CGMType(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.cgmSettings.rawValue)
        }
    }
}
