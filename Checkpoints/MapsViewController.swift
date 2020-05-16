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

protocol LocationsDelegate {
    func updatedSearchResults(mapItems: [MKMapItem])
    
}

class MapsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    private var clManager = CLLocationManager()
    let mapView = MKMapView()
    var overlayContainerDelegate: OverlayContainerDelegate?
    
    var searchResults = [MKMapItem]()
    var delegate: LocationsDelegate?
    
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
    
    func search(string: String) {
        if (string.count == 0) { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = string
        request.region = mapView.region
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else {
                return
            }
            self.searchResults = response.mapItems
            self.delegate?.updatedSearchResults(mapItems: self.searchResults) // notify delegate of new data
        }

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
