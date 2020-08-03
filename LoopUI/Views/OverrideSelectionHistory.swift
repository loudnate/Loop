//
//  OverrideSelectionHistory.swift
//  LoopUI
//
//  Created by Anna Quinlan on 8/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit

public class OverrideHistoryViewModel: ObservableObject {
    var overrides: [TemporaryScheduleOverride]
    var glucoseUnit: HKUnit

    public init(
        overrides: [TemporaryScheduleOverride],
        glucoseUnit: HKUnit
    ) {
        self.overrides = overrides
        self.glucoseUnit = glucoseUnit
    }
}

public struct OverrideSelectionHistory: View {
    @ObservedObject var model: OverrideHistoryViewModel
    private var quantityFormatter: QuantityFormatter
    private var glucoseNumberFormatter: NumberFormatter
    private var durationFormatter: DateComponentsFormatter
    
    
    public init(model: OverrideHistoryViewModel) {
        self.model = model
        self.quantityFormatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: model.glucoseUnit)
            return quantityFormatter
        }()
        self.glucoseNumberFormatter = quantityFormatter.numberFormatter
        self.durationFormatter = {
            let formatter = DateComponentsFormatter()

            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short

            return formatter
        }()
    }
    
    public var body: some View {
        List(model.overrides, id: \.self) { override in
            Section {
                self.createCell(for: override)
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text(LocalizedString("Override History", comment: "Title for override history view")), displayMode: .inline)
    }
    
    private func makeTargetRangeText(from targetRange: ClosedRange<HKQuantity>) -> String {
        guard
            let minTarget = glucoseNumberFormatter.string(from: targetRange.lowerBound.doubleValue(for: model.glucoseUnit)),
            let maxTarget = glucoseNumberFormatter.string(from: targetRange.upperBound.doubleValue(for: model.glucoseUnit))
        else {
            return ""
        }

        return String(format: LocalizedString("%1$@ – %2$@ %3$@", comment: "The format for a glucose target range. (1: min target)(2: max target)(3: glucose unit)"), minTarget, maxTarget, quantityFormatter.string(from: model.glucoseUnit))
    }
    
    private func createCell(for override: TemporaryScheduleOverride) -> OverrideViewCell {
        let startTime = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
        
        var targetRange: String = ""
        if let range = override.settings.targetRange {
            targetRange = makeTargetRangeText(from: range)
        }

        var duration: String {
            // Don't use the durationFormatter if the interval is infinite
            if !override.duration.isFinite && override.scheduledEndDate == override.actualEndDate  {
                return "∞"
            }
            return durationFormatter.string(from: override.startDate, to: override.actualEndDate)!
        }
        
        let insulinNeeds = override.settings.insulinNeedsScaleFactor
        
        switch override.context {
        case .legacyWorkout:
            return OverrideViewCell(
                symbol: Text("🏃‍♂️"),
                name: Text("Workout"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds)
        case .preMeal:
            return OverrideViewCell(
                symbol: Text("🍽"),
                name: Text("Pre-Meal"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds)
        case .preset(let preset):
            return OverrideViewCell(
                symbol: Text(preset.symbol),
                name: Text(preset.name),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds)
        case .custom:
            return OverrideViewCell(
                symbol: Text("..."),
                name: Text("Custom"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds)
        }
    }
}
