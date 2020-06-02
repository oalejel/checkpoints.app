//
//  LocationManager.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/11/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import MapKit
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    private var clManager = CLLocationManager()
    
    override init() {
        super.init()
        clManager.delegate = self
        clManager.requestAlwaysAuthorization() // warning: move to a later part of the app (when go pressed)
    }
    
    // MARK: - "Public" functions for use by other classes
    
    func requestLocationPermissions() { // call when user first presses go?
        clManager.requestAlwaysAuthorization()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            clManager.requestLocation() // no need for live location tracking for now. Just ask for zoom in.
        }
    }
    
    func calculateDistanceFromCoordinate(coord: CLLocationCoordinate2D) -> Double {
        if let loc = clManager.location {
            return loc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
        return -1
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let myLoc = locations.first {
            print("> location manager updated current location")
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    
    
    
}
