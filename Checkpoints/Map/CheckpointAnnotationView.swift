//
//  CheckpointAnnotationView.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/18/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import MapKit
import UIKit

class NumberedPinView: UIView {
    func drawRect() {
        
    }
    
}

final class LocationAnnotationView: MKAnnotationView {

    // MARK: Initialization

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

    // MARK: Setup

    private func setupUI() {
        backgroundColor = .clear

        let view = NumberedPinView()
        addSubview(view)

        view.frame = bounds
    }
}


