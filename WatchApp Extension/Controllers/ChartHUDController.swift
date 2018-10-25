//
//  ChartHUDController.swift
//  Loop
//
//  Created by Bharat Mediratta on 6/26/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import WatchKit
import WatchConnectivity
import CGMBLEKit
import LoopKit
import SpriteKit
import os.log

final class ChartHUDController: HUDInterfaceController, WKCrownDelegate {
    @IBOutlet weak var basalLabel: WKInterfaceLabel!
    @IBOutlet weak var iobLabel: WKInterfaceLabel!
    @IBOutlet weak var cobLabel: WKInterfaceLabel!
    @IBOutlet weak var glucoseScene: WKInterfaceSKScene!
    @IBAction func setChartWindow1Hour() {
        scene.visibleDuration = .hours(2)
    }
    @IBAction func setChartWindow2Hours() {
        scene.visibleDuration = .hours(4)
    }
    @IBAction func setChartWindow3Hours() {
        scene.visibleDuration = .hours(6)
    }
    private let scene = GlucoseChartScene()
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
        }
    }
    private let log = OSLog(category: "ChartHUDController")
    private var hasInitialActivation = false

    override init() {
        super.init()

        loopManager = ExtensionDelegate.shared().loopManager
        NotificationCenter.default.addObserver(forName: .GlucoseSamplesDidChange, object: loopManager.glucoseStore, queue: nil) { [weak self] (note) in
            self?.log.default("Received GlucoseSamplesDidChange notification: %{public}@. Updating chart", String(describing: note.userInfo ?? [:]))

            DispatchQueue.main.async {
                self?.updateGlucoseChart()
            }
        }

        glucoseScene.presentScene(scene)
    }

    override func didAppear() {
        super.didAppear()

        log.default("didAppear")

        // Force an update when our pixels need to move
        let pixelsWide = scene.size.width * WKInterfaceDevice.current().screenScale
        let pixelInterval = scene.visibleDuration / TimeInterval(pixelsWide)

        timer = Timer.scheduledTimer(withTimeInterval: pixelInterval, repeats: true) { [weak self] _ in
            self?.scene.setNeedsUpdate()
        }
    }

    override func willDisappear() {
        super.willDisappear()

        log.default("willDisappear")

        timer = nil
    }

    override func willActivate() {
        super.willActivate()

        if glucoseScene.isPaused {
            log.default("willActivate() unpausing")
            glucoseScene.isPaused = false
        } else {
            log.default("willActivate() unpausing")
        }

        if !hasInitialActivation && UserDefaults.standard.startOnChartPage {
            log.default("Switching to start on Chart page")
            becomeCurrentPage()
        }

        hasInitialActivation = true

        loopManager.requestGlucoseBackfillIfNecessary()
    }

    override func didDeactivate() {
        super.didDeactivate()

        log.default("didDeactivate() pausing")
        glucoseScene.isPaused = true
    }

    override func update() {
        super.update()

        guard let activeContext = loopManager.activeContext else {
            return
        }

        let insulinFormatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()

            numberFormatter.numberStyle = .decimal
            numberFormatter.minimumFractionDigits = 1
            numberFormatter.maximumFractionDigits = 1

            return numberFormatter
        }()

        if let activeInsulin = activeContext.iob, let valueStr = insulinFormatter.string(from: activeInsulin) {
            iobLabel.setText(String(format: NSLocalizedString(
                    "%1$@ U",
                    comment: "The subtitle format describing units of active insulin. (1: localized insulin value description)"
                ),
                valueStr
            ))
        }

        if let carbsOnBoard = activeContext.cob {
            let carbFormatter = NumberFormatter()
            carbFormatter.numberStyle = .decimal
            carbFormatter.maximumFractionDigits = 0
            let valueStr = carbFormatter.string(from: carbsOnBoard)

            cobLabel.setText(String(format: NSLocalizedString(
                    "%1$@ g",
                    comment: "The subtitle format describing grams of active carbs. (1: localized carb value description)"
                ),
                valueStr!
            ))
        }

        if let tempBasal = activeContext.lastNetTempBasalDose {
            let basalFormatter = NumberFormatter()
            basalFormatter.numberStyle = .decimal
            basalFormatter.minimumFractionDigits = 1
            basalFormatter.maximumFractionDigits = 3
            basalFormatter.positivePrefix = basalFormatter.plusSign
            let valueStr = basalFormatter.string(from: tempBasal)

            let basalLabelText = String(format: NSLocalizedString(
                "%1$@ U/hr",
                comment: "The subtitle format describing the current temp basal rate. (1: localized basal rate description)"),
                                      valueStr!)
            basalLabel.setText(basalLabelText)
        }

        if glucoseScene.isPaused {
            log.default("update() unpausing")
            glucoseScene.isPaused = false
        }

        updateGlucoseChart()
    }

    func updateGlucoseChart() {
        guard let activeContext = loopManager.activeContext else {
            return
        }

        scene.predictedGlucose = activeContext.predictedGlucose?.values
        scene.correctionRange = loopManager.settings.glucoseTargetRangeSchedule
        scene.unit = activeContext.preferredGlucoseUnit

        loopManager.glucoseStore.getCachedGlucoseSamples(start: .earliestGlucoseCutoff) { (samples) in
            DispatchQueue.main.async {
                self.scene.historicalGlucose = samples
                self.scene.setNeedsUpdate()
            }
        }
    }
}
