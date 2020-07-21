//
//  MapActivityStatus.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/19/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class MapActivityStatus {
    
    // start or stop animating. should only have one in app's view
    static var activityIndicator = { () -> UIActivityIndicatorView in
        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    static func toggleBusy(_ active: Bool) {
        DispatchQueue.main.async {
            if active {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }
    
}
