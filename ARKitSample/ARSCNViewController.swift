//
//  ARSceneView.swift
//  ARKitSample
//
//  Created by Shai Balassiano on 26/12/2017.
//  Copyright © 2017 Shai Balassiano. All rights reserved.
//

import ARKit

protocol ARSCNViewControllerDelegate: class {
    func arSCNViewController(_ arSCNViewController: ARSCNViewController, didUpdate distance: Float)
    func arSCNViewController(_ arSCNViewController: ARSCNViewController, didUpdate state: ARSCNViewController.State)
}

class ARSCNViewController: NSObject {
    
    enum State {
        case trackingNormalWithAnchors
        case trackingNormalWithoutAnchors
        case trackingNotAvailable
        case trackingIsLimitedBecouseExcessiveMotion
        case trackingIsLimitedBecouseInsufficientFeatures
        case initializing
        case sessionFail(error: Error)
        case sessionInterrupted
        case sessionResumed
    }
    
    var measurementStartTransform: matrix_float4x4?
//    var measurementStartPoint: SCNVector3?
    weak var delegate: ARSCNViewControllerDelegate?
    
    private weak var sceneView: ARSCNView!
    init(sceneView: ARSCNView) {
        super.init()
        
        self.sceneView = sceneView
        setupSceneView()
    }
    
    private func setupSceneView() {
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.showsStatistics = true
        sceneView.session.delegate = self
    }
    
    private func sceneConfiguration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        return configuration
    }
    
    func start() {
        let configuration = sceneConfiguration()
        sceneView.session.run(configuration)
    }
    
    func pause() {
        sceneView.session.pause()
    }
    
    private func resetTracking() {
        let configuration = sceneConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

extension ARSCNViewController: ARSCNViewDelegate {
    private func state(from trackingState: ARCamera.TrackingState, in frame: ARFrame) -> State {
        let state: State
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            state = .trackingNormalWithoutAnchors
        case .normal:
            state = .trackingNormalWithAnchors
        case .notAvailable:
            state = .trackingNotAvailable
        case .limited(.excessiveMotion):
            state = .trackingIsLimitedBecouseExcessiveMotion
        case .limited(.insufficientFeatures):
            state = .trackingIsLimitedBecouseInsufficientFeatures
        case .limited(.initializing):
            state = .initializing
        }
        
        return state
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        
        let state = self.state(from: camera.trackingState, in: currentFrame)
        delegate?.arSCNViewController(self, didUpdate: state)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        let state = self.state(from: currentFrame.camera.trackingState, in: currentFrame)
        delegate?.arSCNViewController(self, didUpdate: state)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else {
            return
        }

        let state = self.state(from: currentFrame.camera.trackingState, in: currentFrame)
        delegate?.arSCNViewController(self, didUpdate: state)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.arSCNViewController(self, didUpdate: State.sessionFail(error: error))
        resetTracking()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        delegate?.arSCNViewController(self, didUpdate: State.sessionInterrupted)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        delegate?.arSCNViewController(self, didUpdate: State.sessionResumed)
        resetTracking()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        func constructPlaneNode(planeAnchor: ARPlaneAnchor) -> SCNNode {
            let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
            
            //SCNPlane is vertically oriented in its local coordinate space, so rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
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
                
                //Plane estimation may extend the size of the plane, or combine previously detected planes into a larger one. In the latter case, `ARSCNView` automatically deletes the corresponding node for one plane, then calls this method to update the size of the remaining plane.
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
}

extension ARSCNViewController: ARSessionDelegate {
    private func distance(from startTransform: matrix_float4x4) -> Float? {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return nil
        }
        
        let startPoint = SCNVector3.position(form: startTransform)
        let endPoint = SCNVector3.position(form: cameraTransform)
        let distance = startPoint.distance(vector: endPoint)
        return distance
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            guard let measurementStartTransform = self.measurementStartTransform, let distance = self.distance(from: measurementStartTransform) else {
                return
            }
            
            self.delegate?.arSCNViewController(self, didUpdate: distance)
        }
    }
}
