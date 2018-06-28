//
//  NSUserDefaults.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit
import MinimedKit
import RileyLinkKit


extension UserDefaults {

    private enum Key: String {
        case activeBasalProfile = "com.loudnate.Naterade.activeBasalProfile"
        case basalRateSchedule = "com.loudnate.Naterade.BasalRateSchedule"
        case basalRateScheduleA = "com.loudnate.Naterade.BasalRateScheduleA"
        case basalRateScheduleB = "com.loudnate.Naterade.BasalRateScheduleB"
        case basalRateScheduleStandard = "com.loudnate.Naterade.BasalRateScheduleStandard"
        case carbRatioSchedule = "com.loudnate.Naterade.CarbRatioSchedule"
        case connectedPeripheralIDs = "com.loudnate.Naterade.ConnectedPeripheralIDs"
        case insulinModelSettings = "com.loopkit.Loop.insulinModelSettings"
        case loopSettings = "com.loopkit.Loop.loopSettings"
        case insulinSensitivitySchedule = "com.loudnate.Naterade.InsulinSensitivitySchedule"
        case pumpSettings = "com.loopkit.Loop.PumpSettings"
        case pumpState = "com.loopkit.Loop.PumpState"
    }

    var basalRateSchedule: BasalRateSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.basalRateSchedule.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.basalRateSchedule.rawValue)
        }
    }
    
    var basalRateScheduleA: BasalRateSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.basalRateScheduleA.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.basalRateScheduleA.rawValue)
        }
    }
    
    var basalRateScheduleB: BasalRateSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.basalRateScheduleB.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.basalRateScheduleB.rawValue)
        }
    }
    
    var basalRateScheduleStandard: BasalRateSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.basalRateScheduleStandard.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.basalRateScheduleStandard.rawValue)
        }
    }
    
    var activeBasalProfile: BasalProfile? {
        get {
            let rawValue = Key.activeBasalProfile.rawValue
            return BasalProfile(rawValue: integer(forKey: rawValue))
            
        }
        set {
            if let activeBasalProfile = newValue {
                set(activeBasalProfile.rawValue, forKey: Key.activeBasalProfile.rawValue)
            } else {
                removeObject(forKey: Key.activeBasalProfile.rawValue)
            }
        }
    }

    var carbRatioSchedule: CarbRatioSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.carbRatioSchedule.rawValue) {
                return CarbRatioSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.carbRatioSchedule.rawValue)
        }
    }

    var connectedPeripheralIDs: [String] {
        get {
            return array(forKey: Key.connectedPeripheralIDs.rawValue) as? [String] ?? []
        }
        set {
            set(newValue, forKey: Key.connectedPeripheralIDs.rawValue)
        }
    }

    var insulinModelSettings: InsulinModelSettings? {
        get {
            if let rawValue = dictionary(forKey: Key.insulinModelSettings.rawValue) {
                return InsulinModelSettings(rawValue: rawValue)
            } else {
                // Migrate the version 0 case
                let insulinActionDurationKey = "com.loudnate.Naterade.InsulinActionDuration"
                defer {
                    removeObject(forKey: insulinActionDurationKey)
                }

                let value = double(forKey: insulinActionDurationKey)
                return value > 0 ? .walsh(WalshInsulinModel(actionDuration: value)) : nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.insulinModelSettings.rawValue)
        }
    }

    var loopSettings: LoopSettings? {
        get {
            if let rawValue = dictionary(forKey: Key.loopSettings.rawValue) {
                return LoopSettings(rawValue: rawValue)
            } else {
                // Migrate the version 0 case
                defer {
                    removeObject(forKey: "com.loudnate.Naterade.DosingEnabled")
                    removeObject(forKey: "com.loudnate.Naterade.activeBasalProfile")
                    removeObject(forKey: "com.loudnate.Naterade.GlucoseTargetRangeSchedule")
                    removeObject(forKey: "com.loudnate.Naterade.MaximumBasalRatePerHour")
                    removeObject(forKey: "com.loudnate.Naterade.MaximumBolus")
                    removeObject(forKey: "com.loopkit.Loop.MinimumBGGuard")
                    removeObject(forKey: "com.loudnate.Loop.RetrospectiveCorrectionEnabled")
                    removeObject(forKey: "com.loudnate.Naterade.BasalRateScheduleA")
                    removeObject(forKey: "com.loudnate.Naterade.BasalRateScheduleB")
                    removeObject(forKey: "com.loudnate.Naterade.BasalRateScheduleStandard")
                }

                let glucoseTargetRangeSchedule: GlucoseRangeSchedule?
                if let rawValue = dictionary(forKey: "com.loudnate.Naterade.GlucoseTargetRangeSchedule") {
                    glucoseTargetRangeSchedule = GlucoseRangeSchedule(rawValue: rawValue)
                } else {
                    glucoseTargetRangeSchedule = nil
                }

                let suspendThreshold: GlucoseThreshold?
                if let rawValue = dictionary(forKey: "com.loopkit.Loop.MinimumBGGuard") {
                    suspendThreshold = GlucoseThreshold(rawValue: rawValue)
                } else {
                    suspendThreshold = nil
                }

                var maximumBasalRatePerHour: Double? = double(forKey: "com.loudnate.Naterade.MaximumBasalRatePerHour")
                if maximumBasalRatePerHour! <= 0 {
                    maximumBasalRatePerHour = nil
                }

                var maximumBolus: Double? = double(forKey: "com.loudnate.Naterade.MaximumBolus")
                if maximumBolus! <= 0 {
                    maximumBolus = nil
                }

                let settings = LoopSettings(
                    dosingEnabled: bool(forKey: "com.loudnate.Naterade.DosingEnabled"),
                    glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                    maximumBasalRatePerHour: maximumBasalRatePerHour,
                    maximumBolus: maximumBolus,
                    suspendThreshold: suspendThreshold,
                    retrospectiveCorrectionEnabled: bool(forKey: "com.loudnate.Loop.RetrospectiveCorrectionEnabled"),
                    basalProfileStandard: basalRateScheduleStandard,
                    basalProfileA: basalRateScheduleA,
                    basalProfileB: basalRateScheduleB,
                    activeBasalProfile: activeBasalProfile,
                    integralRetrospectiveCorrectionEnabled: bool(forKey: "com.loopkit.Loop.IntegralRetrospectiveCorrectionEnabled")
                )
                self.loopSettings = settings

                return settings
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.loopSettings.rawValue)
        }
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.insulinSensitivitySchedule.rawValue) {
                return InsulinSensitivitySchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.insulinSensitivitySchedule.rawValue)
        }
    }

    var pumpSettings: PumpSettings? {
        get {
            if let raw = dictionary(forKey: Key.pumpSettings.rawValue) {
                return PumpSettings(rawValue: raw)
            } else {
                // Migrate the version 0 case
                let standard = UserDefaults.standard
                defer {
                    standard.removeObject(forKey: "com.loudnate.Naterade.PumpID")
                    standard.removeObject(forKey: "com.loopkit.Loop.PumpRegion")
                }

                guard let pumpID = standard.string(forKey: "com.loudnate.Naterade.PumpID") else {
                    return nil
                }

                let settings = PumpSettings(
                    pumpID: pumpID,
                    // Defaults to 0 / northAmerica
                    pumpRegion: PumpRegion(rawValue: standard.integer(forKey: "com.loopkit.Loop.PumpRegion"))
                )

                self.pumpSettings = settings

                return settings
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.pumpSettings.rawValue)
        }
    }

    var pumpState: PumpState? {
        get {
            if let raw = dictionary(forKey: Key.pumpState.rawValue) {
                return PumpState(rawValue: raw)
            } else {
                // Migrate the version 0 case
                let standard = UserDefaults.standard
                defer {
                    standard.removeObject(forKey: "com.loudnate.Naterade.PumpModelNumber")
                    standard.removeObject(forKey: "com.loudnate.Naterade.PumpTimeZone")
                }

                var state = PumpState()

                if let pumpModelNumber = standard.string(forKey: "com.loudnate.Naterade.PumpModelNumber") {
                    state.pumpModel = PumpModel(rawValue: pumpModelNumber)
                }

                if let offset = standard.object(forKey: "com.loudnate.Naterade.PumpTimeZone") as? NSNumber,
                    let timeZone = TimeZone(secondsFromGMT: offset.intValue)
                {
                    state.timeZone = timeZone
                }

                self.pumpState = state

                return state
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.pumpState.rawValue)
        }
    }
}
