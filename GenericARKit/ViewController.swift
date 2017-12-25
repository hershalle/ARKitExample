//
//  ViewController.swift
//  GenericARKit
//
//  Created by Shai Balassiano on 25/12/2017.
//  Copyright © 2017 Shai Balassiano. All rights reserved.
//

import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {//ARSKViewDelegate {

    var sceneView: ARSCNView {
        return view as! ARSCNView
    }
    
    fileprivate func setupSceneView() {
        sceneView.delegate = self
        
        let emptyScene = SKScene()
        emptyScene.scaleMode = .resizeFill
        emptyScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints, .showPhysicsShapes]
        sceneView.showsStatistics = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupSceneView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // ==========================
    // MARK: - ARSCNViewDelegate:
    // ==========================
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("Session Failed - probably due to lack of camera access")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("Session interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("Session resumed")
        sceneView.session.run(session.configuration!, options: [.resetTracking, .removeExistingAnchors])
    }

//    sceneView.session.configuration
    
//    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
//        return nil
//    }
}

