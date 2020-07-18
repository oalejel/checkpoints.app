//
//  MSTPreview.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 6/27/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit
import CoreLocation

class MSTPreview: UIView {
    var parentIndices: [Int]!
    var coordinates: [CLLocationCoordinate2D]!
    private var fractionalPositions: [(CGFloat, CGFloat)]!
    private var circleRadius: CGFloat = 1 // adjusted based on coordinate count
    
    init(frame: CGRect, coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        self.parentIndices = PathFinder.shared.computeCoordinateBasedMST(coordinates: coordinates)
        super.init(frame: frame)
        backgroundColor = .white
        
        var minX = coordinates.first!.longitude
        var minY = coordinates.first!.latitude
        var maxX = minX
        var maxY = minY
        for coord in coordinates {
            if minX > coord.longitude { minX = coord.longitude }
            if maxX < coord.longitude { maxX = coord.longitude }
            if minY > coord.latitude { minY = coord.latitude }
            if maxY < coord.latitude { maxY = coord.latitude }
        }
        
        // if we want to preserve the proportionality in distance of points, we must scale x and y axes along same number
        // so we just pick the number that is greater
        var stretchFactor = maxX - minX
        if stretchFactor < (maxY - minY) {
            stretchFactor = maxY - minY
        }
                
        // map each coordinate pair to 0-1 fractions along the min-max scales we created
        fractionalPositions = coordinates.map {
            (CGFloat(($0.longitude - minX) / stretchFactor), CGFloat(($0.latitude - minY) / stretchFactor))
        }
    }
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let mstColor = UIColor(red: 0.699, green: 0.453, blue: 0.398, alpha: 1)
            mstColor.set()
            let lineWidth: CGFloat = 1
            context.setLineWidth(lineWidth)
            
            func pointFromFractionalTuple(xyTuple: (CGFloat, CGFloat)) -> CGPoint {
                let a = xyTuple.0 * (0.6 * rect.size.width) + (0.2 * rect.size.width) // padding is 20% of box
                let b = rect.size.height - (xyTuple.1 * (0.6 * rect.size.height) + (0.2 * rect.size.height))
                return CGPoint(x: a, y: b)
            }
            
            let tranformedPoints = fractionalPositions.map(pointFromFractionalTuple)
            
            for i in 0..<parentIndices.count {
                let startPoint = tranformedPoints[i]
                let endPoint = tranformedPoints[parentIndices[i]]
                context.move(to: startPoint)
                context.addLine(to: endPoint)
                context.strokePath()
            }
            
            for point in tranformedPoints {
                // decide x and y positions using percentages along our padded width and height
                let radius = min(0.1 * rect.size.width, max(lineWidth + 1, rect.size.width / CGFloat((4 * coordinates.count))))
                context.addArc(center: point, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
                context.fillPath()
            }
        }
        
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.cgColor
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
