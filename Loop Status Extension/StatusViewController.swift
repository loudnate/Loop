//
//  StatusViewController.swift
//  Loop Status Extension
//
//  Created by Bharat Mediratta on 11/25/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//

import CoreData
import HealthKit
import LoopUI
import NotificationCenter
import UIKit
import SwiftCharts

class StatusViewController: UIViewController, NCWidgetProviding {

    @IBOutlet weak var hudView: HUDView! {
        didSet {
            hudView.loopCompletionHUD.stateColors = .loopStatus
            hudView.glucoseHUD.stateColors = .cgmStatus
            hudView.glucoseHUD.tintColor = .glucoseTintColor
            hudView.basalRateHUD.tintColor = .doseTintColor
            hudView.reservoirVolumeHUD.stateColors = .pumpStatus
            hudView.batteryHUD.stateColors = .pumpStatus
        }
    }
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var glucoseChartContentView: ChartContentView!

    private lazy var charts: StatusChartsManager = {
        let charts = StatusChartsManager()

        charts.glucoseDisplayRange = (
            min: HKQuantity(unit: HKUnit.milligramsPerDeciliterUnit(), doubleValue: 100),
            max: HKQuantity(unit: HKUnit.milligramsPerDeciliterUnit(), doubleValue: 175)
        )

        return charts
    }()

    var statusExtensionContext: StatusExtensionContext?
    var defaults: UserDefaults?
    final var observationContext = 1

    var loopCompletionHUD: LoopCompletionHUDView! {
        get {
            return hudView.loopCompletionHUD
        }
    }

    var glucoseHUD: GlucoseHUDView! {
        get {
            return hudView.glucoseHUD
        }
    }

    var basalRateHUD: BasalRateHUDView! {
        get {
            return hudView.basalRateHUD
        }
    }

    var reservoirVolumeHUD: ReservoirVolumeHUDView! {
        get {
            return hudView.reservoirVolumeHUD
        }
    }

    var batteryHUD: BatteryLevelHUDView! {
        get {
            return hudView.batteryHUD
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        subtitleLabel.alpha = 0
        subtitleLabel.textColor = .subtitleLabelColor

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(openLoopApp(_:)))
        view.addGestureRecognizer(tapGestureRecognizer)

        defaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
        if let defaults = defaults {
            defaults.addObserver(
                self,
                forKeyPath: defaults.statusExtensionContextObservableKey,
                options: [],
                context: &observationContext
            )
        }

        self.charts.prerender()
        glucoseChartContentView.chartGenerator = { [unowned self] (frame) in
            return self.charts.glucoseChartWithFrame(frame)?.view
        }

        self.extensionContext?.widgetLargestAvailableDisplayMode = NCWidgetDisplayMode.expanded
        glucoseChartContentView.alpha = self.extensionContext?.widgetActiveDisplayMode == NCWidgetDisplayMode.compact ? 0 : 1
    }

    deinit {
        if let defaults = defaults {
            defaults.removeObserver(self, forKeyPath: defaults.statusExtensionContextObservableKey, context: &observationContext)
        }
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if (activeDisplayMode == NCWidgetDisplayMode.compact) {
            self.preferredContentSize = maxSize
        } else {
            self.preferredContentSize = CGSize(width: maxSize.width, height: 210)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: {
            (UIViewControllerTransitionCoordinatorContext) -> Void in
            if self.extensionContext?.widgetActiveDisplayMode == .compact {
                self.glucoseChartContentView.alpha = 0
            } else {
                self.glucoseChartContentView.alpha = 1
            }
        }, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
        })
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &observationContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        update()
    }
    
    @objc private func openLoopApp(_: Any) {
        if let url = Bundle.main.mainAppUrl {
            self.extensionContext?.open(url)
        }
    }

    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        let result = update()
        completionHandler(result)
    }
    
    @discardableResult
    func update() -> NCUpdateResult {
        guard let context = defaults?.statusExtensionContext else {
            return NCUpdateResult.failed
        }
        if let lastGlucose = context.glucose?.last {
            glucoseHUD.setGlucoseQuantity(lastGlucose.value,
               at: lastGlucose.startDate,
               unit: lastGlucose.unit,
               sensor: lastGlucose.sensor
            )
        }
        
        if let batteryPercentage = context.batteryPercentage {
            batteryHUD.batteryLevel = Double(batteryPercentage)
        }
        
        if let reservoir = context.reservoir {
            reservoirVolumeHUD.reservoirLevel = min(1, max(0, Double(reservoir.unitVolume / Double(reservoir.capacity))))
            reservoirVolumeHUD.setReservoirVolume(volume: reservoir.unitVolume, at: reservoir.startDate)
        }

        if let netBasal = context.netBasal {
            basalRateHUD.setNetBasalRate(netBasal.rate, percent: netBasal.percentage, at: netBasal.startDate)
        }

        if let loop = context.loop {
            loopCompletionHUD.dosingEnabled = loop.dosingEnabled
            loopCompletionHUD.lastLoopCompleted = loop.lastCompleted
        }

        subtitleLabel.alpha = 0

        if let eventualGlucose = context.eventualGlucose {
            let formatter = NumberFormatter.glucoseFormatter(for: eventualGlucose.unit)

            if let eventualGlucoseNumberString = formatter.string(from: NSNumber(value: eventualGlucose.value)) {
                subtitleLabel.text = String(
                    format: NSLocalizedString(
                        "Eventually %1$@ %2$@",
                        comment: "The subtitle format describing eventual glucose. (1: localized glucose value description) (2: localized glucose units description)"),
                    eventualGlucoseNumberString,
                    eventualGlucose.unit.glucoseUnitDisplayString
                )
                subtitleLabel.alpha = 1
            }
        }

        let dateFormatter: DateFormatter = {
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short

            return timeFormatter
        }()


        if let glucose = context.glucose,
            glucose.count > 0 {
            let unit = glucose[0].unit
            let glucoseFormatter = NumberFormatter.glucoseFormatter(for: unit)

            charts.glucosePoints = glucose.map {
                ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.value, unitString: unit.unitString, formatter: glucoseFormatter)
                )
            }

            if let predictedGlucose = context.predictedGlucose {
                charts.predictedGlucosePoints = predictedGlucose.map {
                    ChartPoint(
                        x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                        y: ChartAxisValueDoubleUnit($0.value, unitString: unit.unitString, formatter: glucoseFormatter)
                    )
                }
            }
            
            charts.prerender()
            glucoseChartContentView.reloadChart()
        }

        // Right now we always act as if there's new data.
        // TODO: keep track of data changes and return .noData if necessary
        return NCUpdateResult.newData
    }
}
