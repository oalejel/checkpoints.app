//
//  MapsViewController.swift
//  OverlayContainer_Example
//
//  Created by Gaétan Zanella on 29/11/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import MapKit
import UIKit
import CoreLocation

class MapsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    private var clManager = CLLocationManager()
    let mapView = MKMapView()
    var overlayContainerDelegate: OverlayContainerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(mapView)
        mapView.pinToSuperview()
        mapView.showsTraffic = true
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
        
        clManager.delegate = self
        clManager.requestAlwaysAuthorization() // warning: move to a later part of the app (when go pressed)

    }
    
    // MARK: - "Public" functions for use by other classes
    
    func requestLocationPermissions() { // call when user first presses go?
        clManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Mapview Delegate
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        // tell overlay to scroll down when mak is being scrolled
        overlayContainerDelegate?.minimizeOverlay()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            clManager.requestLocation() // no need for live location tracking for now. Just ask for zoom in.
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let myLoc = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            let region = MKCoordinateRegion(center: myLoc.coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // maybe show an error message?
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    

}
