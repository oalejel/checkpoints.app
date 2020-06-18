//
//  CheckpointAnnotation.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/21/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import MapKit

class CheckpointAnnotation: MKPointAnnotation {
    var imageName: String?
    weak var mapItem: MKMapItem? // need to hold onto map item if we want to 
    
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
    }
}
