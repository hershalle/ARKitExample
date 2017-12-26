//
//  ViewController.swift
//  ARKitSample
//
//  Created by Shai Balassiano on 25/12/2017.
//  Copyright © 2017 Shai Balassiano. All rights reserved.
//

import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {//ARSKViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var distanceLabel: UILabel!
    @IBOutlet var measureButton: UIButton!
    
    var measurementStartPoint: SCNVector3?
    
    fileprivate func setupSceneView() {
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.showsStatistics = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupSceneView()
        sceneView.session.delegate = self
    }
    
    fileprivate func setupSceneConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupSceneConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = "tracking normal"
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
        }
        
        statusLabel.text = message
    }
    
    @IBAction func didTap(startMeasurementButton: UIButton) {
        let planeTestResults = sceneView.hitTest(sceneView.center, types: .featurePoint)
        guard let result = planeTestResults.first else {
            print("faild")
            return
        }

        let resultWorldTransform = result.worldTransform
        let realWorldVector = SCNVector3.position(form: resultWorldTransform)

        measurementStartPoint = realWorldVector
        measureButton.setTitle("Reset", for: .normal)
    }

    
    func measurement(from startPoint: SCNVector3) -> Float? {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return nil
        }
        
        let endPoint = SCNVector3.position(form: cameraTransform)
        let distance = startPoint.distance(vector: endPoint)
        return distance
    }
    
    
    // ==========================
    // MARK: - ARSessionDelegate:
    // ==========================
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {

            guard let measurementStartPoint = self.measurementStartPoint, let distance = self.measurement(from: measurementStartPoint)?.description else {
                return
            }
            self.distanceLabel.text = distance
        }
    }
    // ==========================
    // MARK: - ARSessionObserver:
    // ==========================
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        updateSessionInfoLabel(for: currentFrame, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        updateSessionInfoLabel(for: currentFrame, trackingState: currentFrame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        updateSessionInfoLabel(for: currentFrame, trackingState: currentFrame.camera.trackingState)
    }

    // ==========================
    // MARK: - ARSCNViewDelegate:
    // ==========================
    func session(_ session: ARSession, didFailWithError error: Error) {
        statusLabel.text = "Session Failed - probably due to lack of camera access"
        resetTracking()
    }

    func sessionWasInterrupted(_ session: ARSession) {
        statusLabel.text = "Session interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        statusLabel.text = "Session resumed"
        resetTracking()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        func constructPlaneNode(planeAnchor: ARPlaneAnchor) -> SCNNode {
            let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, so
             rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            // Make the plane visualization semitransparent to clearly show real-world placement.
            planeNode.opacity = 0.25
            
            return planeNode
        }
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let planeNode = constructPlaneNode(planeAnchor: planeAnchor)
        node.addChildNode(planeNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            guard let planeAnchor = anchor as? ARPlaneAnchor, let planeNode = self.sceneView.node(for: anchor)?.childNodes.first, let planeGeometry = planeNode.geometry as? SCNPlane else {
                return
            }
            
            func update(planNode: SCNNode, from planeAnchor: ARPlaneAnchor) {
                // Plane estimation may shift the center of a plane relative to its anchor's transform.
                planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
                
                /*
                 Plane estimation may extend the size of the plane, or combine previously detected
                 planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
                 corresponding node for one plane, then calls this method to update the size of
                 the remaining plane.
                 */
                planeGeometry.width = CGFloat(planeAnchor.extent.x)
                planeGeometry.height = CGFloat(planeAnchor.extent.z)
            }
            
            update(planNode: planeNode, from: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            for childNode in node.childNodes {
                childNode.removeFromParentNode()
            }
        }
    }
    
//    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
//        return nil
//    }
}

