//
//  CheckpointAnnotationView.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/18/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import MapKit
import UIKit

extension CGPoint {
    static func +(left: CGPoint, right: (CGFloat, CGFloat)) -> CGPoint {
//        print(left)
//        print(right)
        let out = CGPoint(x: left.x + right.0, y: left.y + right.1)
//        print(out)
        return out
    }
}


class NumberedPinView: UIView {
    var label = UILabel()
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        label.text = "10"
        label.textColor = .systemBlue
        label.sizeToFit()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        addSubview(label)
    }
    
    func setTitleNumber(_ i: Int) {
        label.text = "\(i)"
//        label.setNeedsDisplay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        print("draw rect")
        super.draw(rect)
        let path = UIBezierPath()
        let w = rect.size.width
        let h = rect.size.height
        let pad: CGFloat = 2
        let rad = (w / 2) - 2 * pad
        
        let topMiddle = CGPoint(x: w / 2, y: pad)
        let right = CGPoint(x: w - pad, y: pad + rad)
        let bottomMiddle = CGPoint(x: w / 2, y: h - 4)
        let left = CGPoint(x: pad, y: pad + rad)
        
        path.move(to: left)
        path.addCurve(to: topMiddle,
                      controlPoint1: left + (0, -rad * 0.5),
                      controlPoint2: topMiddle + (-rad * 0.6, 0))
        
        path.addCurve(to: right,
                      controlPoint1: topMiddle + (rad * 0.6, 0),
                      controlPoint2: right + (0, -rad * 0.5))
        
        path.addCurve(to: bottomMiddle,
                      controlPoint1: right + (0, rad * 0.7),
                      controlPoint2: bottomMiddle + (rad * 0.5, 0))
        
        path.addCurve(to: left,
                      controlPoint1: bottomMiddle + (-rad * 0.5, 0),
                      controlPoint2: left + (0, rad * 0.7))
        
        path.addCurve(to: topMiddle,
                      controlPoint1: left + (0, -rad * 0.5),
                      controlPoint2: topMiddle + (-rad * 0.5, 0))
        

        path.close()
        UIColor.systemBlue.setFill()
        path.fill()
        
        UIColor.white.setFill()
        let border: CGFloat = 4
        let circleRect = CGRect(x: pad + border, y: pad + border, width: w - 2 * (pad + border), height: w - 2 * (pad + border))
        let circle = UIBezierPath(ovalIn: circleRect)
        circle.close()
        circle.fill()
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.removeConstraints(label.constraints)
        addConstraints([
            label.centerYAnchor.constraint(equalTo: topAnchor, constant: w / 2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: border + pad + (0.1 * w)),
            trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: border + pad + (0.1 * w))
        ])
    }
}

final class NumberedAnnotationView: MKAnnotationView {

    // MARK: Initialization
    
    var pinView: NumberedPinView!

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        frame = CGRect(x: 0, y: 0, width: 40, height: 50)
        centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)

        canShowCallout = true
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTitleNumber(_ i: Int) {
        pinView.setTitleNumber(i)
    }

    // MARK: Setup

    private func setupUI() {
        backgroundColor = .clear

        pinView = NumberedPinView()
        addSubview(pinView)
        pinView.frame = bounds
    }
}


