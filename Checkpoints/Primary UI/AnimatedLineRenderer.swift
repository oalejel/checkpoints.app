//
//  AnimatedLineRenderer.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 8/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import MapKit
import UIKit

class AnimatedPolyline: MKPolyline {
        
    var animatedCoords: [CLLocationCoordinate2D] = []
//
//    init(coords: [CLLocationCoordinate2D]) {
//        super.init()
//        self.coords = coords
//    }
}

class AnimatedLineRenderer: MKOverlayRenderer {
    
    // kickstart animation of path
    // on change to zoom, scale the view, even if it is animating
    
    /// The map view may tile large overlays and distribute the rendering of each tile to separate threads. Therefore, the implementation of your draw(_:zoomScale:in:) method must be safe to run from background threads and from multiple threads simultaneously.
    var animatedPolyline: AnimatedPolyline?
    
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        animatedPolyline != nil
    }
    
    var animating = false
    var didRenderOnce = false
    var pathShape: CAShapeLayer?
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let animatedPolyline = animatedPolyline else { //}, mapRect.intersects(theMapRect) else {
             return
        }
        
        // draw without animating
        if !didRenderOnce {
            didRenderOnce = true
            
            
            let path = CGMutablePath()
            let cgPoints = animatedPolyline.animatedCoords.map { MKMapPoint($0) }.map(point(for:))
            path.addLines(between: cgPoints)
            context.addPath(path)

            
            let shape = CAShapeLayer()
            shape.path = path
            shape.borderWidth = MKRoadWidthAtZoomScale(zoomScale)
            shape.strokeColor = UIColor.systemBlue.cgColor
            shape.fillColor = nil
            self.pathShape = shape
            
            
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 2
            animation.autoreverses = true
            animation.repeatCount = .infinity
            shape.add(animation, forKey: "line")
//            layer.add(animation, forKey: "line")
            
//            context.addPath(shape.path!)
//            context.setStrokeColor(UIColor.systemBlue.cgColor)
//            context.setLineWidth(MKRoadWidthAtZoomScale(zoomScale) * 1)
//            context.strokePath()
            
            shape.draw(in: context)

            
        } else if !animating {
            animating = true
            
            // completion to set animating to false
        }
        // if animating, leave animation alone to finish
        
//        let path = CGMutablePath()
//        let cgPoints = animatedPolyline.animatedCoords.map { MKMapPoint($0) }.map(point(for:))
//        path.addLines(between: cgPoints)
//        context.addPath(path)
//
//        context.setStrokeColor(UIColor.systemBlue.cgColor)
//        context.setLineWidth(MKRoadWidthAtZoomScale(zoomScale) * 1)
//        context.strokePath()
    }
}
