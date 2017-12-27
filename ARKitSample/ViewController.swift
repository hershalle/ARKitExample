//
//  ViewController2.swift
//  ARKitSample
//
//  Created by Shai Balassiano on 26/12/2017.
//  Copyright © 2017 Shai Balassiano. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private var distanceLabel: UILabel!
    @IBOutlet private var statusLabel: UILabel!
    @IBOutlet private var measureButton: UIButton!

    private var arSCNViewController: ARSCNViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arSCNViewController = ARSCNViewController(sceneView: sceneView)
        arSCNViewController.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        arSCNViewController.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSCNViewController.pause()
    }
    
    @IBAction func didTap(startMeasurementButton: UIButton) {
        let planeTestResults = sceneView.hitTest(sceneView.center, types: .featurePoint)
        guard let resultWorldTransform = planeTestResults.first?.worldTransform else {
            print("faild")
            return
        }
        
        arSCNViewController.measurementStartTransform = resultWorldTransform
        measureButton.setTitle("Reset", for: .normal)
    }
}

extension ViewController: ARSCNViewControllerDelegate {
    func arSCNViewController(_ arSCNViewController: ARSCNViewController, didUpdate distance: Float) {
        distanceLabel.text = distance.description
    }
    
    func arSCNViewController(_ arSCNViewController: ARSCNViewController, didUpdate state: ARSCNViewController.State) {
        let message: String
        switch state {
        case .trackingNormalWithAnchors:
            message = "tracking normal"
        case .trackingNormalWithoutAnchors:
            message = "Move the device around to detect horizontal surfaces."
        case .trackingNotAvailable:
            message = "Tracking unavailable."
        case .trackingIsLimitedBecouseExcessiveMotion:
            message = "Tracking limited - Move the device more slowly."
        case .trackingIsLimitedBecouseInsufficientFeatures:
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
        case .initializing:
            message = "Initializing AR session."
        case .sessionFail(_):
            message = "Session Failed - probably due to lack of camera access"
        case .sessionInterrupted:
            message = "Session interrupted"
        case .sessionResumed:
            message = "Session resumed"
        }
        
        statusLabel.text = message
    }
}

