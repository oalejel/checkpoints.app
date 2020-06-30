//
//  CloseButton.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 6/29/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class CloseButton: UIButton {
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundColor = UIColor(white: 0.8, alpha: 1)
            } else {
                backgroundColor = UIColor(white: 0.85, alpha: 1)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            UIColor.lightGray.set()
            
            // let x corners stretch to 10% of width / height
            let p: CGFloat = 1 - (rect.width / sqrt(2 * rect.width * rect.width))
            let topLeft = CGPoint(x: rect.width * p, y: rect.height * p)
            let topRight = CGPoint(x: rect.width * (1 - p), y: rect.height * p)
            let bottomLeft = CGPoint(x: rect.width * p, y: rect.height * (1 - p))
            let bottomRight = CGPoint(x: rect.width * (1 - p), y: rect.height * (1 - p))
            
            context.setLineCap(.round)
            context.setLineWidth(rect.width / 8)
            context.move(to: topLeft)
            context.addLine(to: bottomRight)
            context.strokePath()
            context.move(to: topRight)
            context.addLine(to: bottomLeft)
            context.strokePath()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setupView() {
        backgroundColor = UIColor(white: 0.85, alpha: 1)
        layer.cornerRadius = frame.size.width / 2
        layer.masksToBounds = true
    }
    
}
