//
//  VideoCameraView.swift
//  Astralink
//
//  Created by Ido Schragenheim on 27/07/2017.
//  Copyright © 2017 Astralink. All rights reserved.
//

import UIKit
import AVFoundation

class VideoCameraView: UIView {
    
    let videoLayer = AVSampleBufferDisplayLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    private func setup() {
        self.layer.addSublayer(videoLayer)
        videoLayer.videoGravity = .resizeAspectFill
        isUserInteractionEnabled = false
        layer.backgroundColor = UIColor.purple.cgColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        videoLayer.frame = bounds
    }
}

