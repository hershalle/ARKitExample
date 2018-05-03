//
//  ARSceneView.swift
//  ARKitSample
//
//  Created by Shai Balassiano on 26/12/2017.
//  Copyright © 2017 Shai Balassiano. All rights reserved.
//

import ARKit

protocol ARSCNViewManagerDelegate: class {
    func arSCNViewController(_ arSCNViewController: ARSCNViewManager, didUpdate trackingTransform: matrix_float4x4)
    func arSCNViewController(_ arSCNViewController: ARSCNViewManager, didUpdate distance: Float)
    func arSCNViewController(_ arSCNViewController: ARSCNViewManager, didUpdate state: ARSCNViewManager.State)
    func arSCNViewController(_ arSCNViewController: ARSCNViewManager, didUpdate sampleBuffer: CMSampleBuffer)
}

class ARSCNViewManager: NSObject {
    
    enum State {
        enum Reason {
            case initializing
            case excessiveMotion
            case insufficientFeatures
            
            @available(iOS 11.3, *)
            case relocalizing
        }
        
        case trackingNormalWithAnchors
        case trackingNormalWithoutAnchors
        case trackingNotAvailable
        case trackingIsLimited(Reason)
        
        case sessionFail(error: Error)
        case sessionInterrupted
        case sessionResumed
    }
    
    var tracking = true
    private var measurementStartTransform: matrix_float4x4?
    weak var delegate: ARSCNViewManagerDelegate?
    
    private weak var sceneView: ARSCNView!
    init(sceneView: ARSCNView) {
        super.init()
        
        self.sceneView = sceneView
        setupSceneView()
    }
    
    private func setupSceneView() {
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.showsStatistics = true
        sceneView.session.delegate = self
    }
    
    private func sceneConfiguration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal, .vertical]
        return configuration
    }
    
    func start() {
        let configuration = sceneConfiguration()
        sceneView.session.run(configuration)
        sceneView.session.delegate = self
    }
    
    func pause() {
        sceneView.session.pause()
    }
    
    func startSendingDistanceFromCenterPoint() {
        let planeTestResults = sceneView.hitTest(sceneView.center, types: .featurePoint)
        measurementStartTransform = planeTestResults.first?.worldTransform
    }
    
    func startSendingTrackingFromCurrentPostion() {
        measurementStartTransform = sceneView.session.currentFrame?.camera.transform
    }
    
    func setOriginToCurrentCameraPosition() {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return
        }
        sceneView.session.setWorldOrigin(relativeTransform: cameraTransform)
    }
    
    private func resetTracking() {
        let configuration = sceneConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func tempTest() {
        let projectionMatrix = sceneView.session.currentFrame!.camera.projectionMatrix(for: UIInterfaceOrientation.landscapeRight, viewportSize: sceneView.bounds.size, zNear: -1, zFar: 1)
        let yScale = projectionMatrix[1,1] // = 1/tan(fovy/2)
        let yFovDegrees = 2 * atan(1/yScale) * 180/Float.pi
        let imageResolution = sceneView.session.currentFrame!.camera.imageResolution
        let xFovDegrees = yFovDegrees * Float(imageResolution.width / imageResolution.height)
        let aspectRatio = Float(imageResolution.width / imageResolution.height)

        print("yFovDegrees: \(yFovDegrees), aspectRatio: \(aspectRatio)")

//        // find fov
//        let projectionMatrix = sceneView.session.currentFrame!.camera.projectionMatrix
//        let yScale = projectionMatrix[1,1]
//        let yFov = 2 * atan(1 / yScale) // in radians
//        let yFovDegrees = yFov * 180 / Float.pi
//
//        let imageResolution = session.currentFrame!.camera.imageResolution
//        let xFov = yFov * Float(imageResolution.width / imageResolution.height)
    }
}

extension ARSCNViewManager: ARSCNViewDelegate {
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
            state = .trackingIsLimited(.excessiveMotion)
        case .limited(.insufficientFeatures):
            state = .trackingIsLimited(.insufficientFeatures)
        case .limited(.initializing):
            state = .trackingIsLimited(.initializing)
        case .limited(.relocalizing):
            state = .trackingIsLimited(.relocalizing)
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
            #if targetEnvironment(simulator)
                return SCNNode()
            #else
            let planeGeometry = ARSCNPlaneGeometry(device: sceneView.device!)!
            planeGeometry.update(from: planeAnchor.geometry)

            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)

            // Make the plane visualization semitransparent to clearly show real-world placement.
            planeNode.opacity = 0.25

            return planeNode
            #endif
        }
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let planeNode = constructPlaneNode(planeAnchor: planeAnchor)
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            
            guard let planeAnchor = anchor as? ARPlaneAnchor, let planeNode = self.sceneView.node(for: anchor)?.childNodes.first, let planeGeometry = planeNode.geometry as? ARSCNPlaneGeometry else {
                return
            }
            
            func update(planNode: SCNNode, from planeAnchor: ARPlaneAnchor) {
                // Plane estimation may shift the center of a plane relative to its anchor's transform.
//                planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)

                //Plane estimation may extend the size of the plane, or combine previously detected planes into a larger one. In the latter case, `ARSCNView` automatically deletes the corresponding node for one plane, then calls this method to update the size of the remaining plane.
                
//                planeGeometry.update(from: <#T##ARPlaneGeometry#>)
//                planeGeometry.width = CGFloat(planeAnchor.extent.x)
//                planeGeometry.height = CGFloat(planeAnchor.extent.z)
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

extension ARSCNViewManager: ARSessionDelegate {
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
        func descriptionFormat(from frame: ARFrame) -> CMVideoFormatDescription {
            let pixelBuffer = frame.capturedImage
            var videoFormatDescription: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoFormatDescription)
            return videoFormatDescription!
        }

        func sampleBuffer(from frame: ARFrame) -> CMSampleBuffer {
            let pixelBuffer = frame.capturedImage
            let videoFormatDescription = descriptionFormat(from: frame)

            let scale = CMTimeScale(NSEC_PER_SEC)
            let value = Int64(frame.timestamp * Double(scale))
            let presentationTimeStamp = CMTime(value: CMTimeValue(value), timescale: scale)
            var timingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: presentationTimeStamp, decodeTimeStamp: kCMTimeInvalid)

            var sampleBuffer: CMSampleBuffer?
            CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, videoFormatDescription, &timingInfo, &sampleBuffer)
            return sampleBuffer!
        }

        func sendSampleBufferToDelegate() {
            let newSampleBuffer = sampleBuffer(from: frame)
            DispatchQueue.main.async {
                self.delegate?.arSCNViewController(self, didUpdate: newSampleBuffer)
            }
        }
        
        func sendDistanceToDelegate() {
            DispatchQueue.main.async {
                if let measurementStartTransform = self.measurementStartTransform, let distance = self.distance(from: measurementStartTransform) {
                    self.delegate?.arSCNViewController(self, didUpdate: distance)
                }
            }
        }
        
        func sendTrackingToDelegate() {
            DispatchQueue.main.async {
                guard let measurementStartTransform = self.measurementStartTransform, let currentCameraTransform = self.sceneView.session.currentFrame?.camera.transform else {
                    return
                }
                
                let trackingTransform = measurementStartTransform - currentCameraTransform
                self.delegate?.arSCNViewController(self, didUpdate: trackingTransform)
            }
        }
        
        sendTrackingToDelegate()
    }
}
