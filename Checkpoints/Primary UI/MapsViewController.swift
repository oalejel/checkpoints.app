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
    
//    private var clManager = CLLocationManager()
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
        
        PathFinder.shared.locationManager.delegate = self
        PathFinder.shared.locationManager.requestAlwaysAuthorization() // warning: move to a later part of the app (when go pressed)
    }
    
    // MARK: - "Public" functions for use by other classes
    
    func requestLocationPermissions() { // call when user first presses go?
        PathFinder.shared.locationManager.requestAlwaysAuthorization()
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
    
    var temporaryAnnotation: CheckpointAnnotation?
    func showTemporaryPin(mapItem: MKMapItem) {
        if let tempAnn = temporaryAnnotation {
            mapView.removeAnnotation(tempAnn)
        }
        temporaryAnnotation = CheckpointAnnotation()
        temporaryAnnotation!.coordinate = mapItem.placemark.coordinate
        mapView.addAnnotation(temporaryAnnotation!)
        
        var offsetCoord = mapItem.placemark.coordinate
        if offsetCoord.latitude > 0 {
            offsetCoord.latitude -= self.mapView.region.span.latitudeDelta * 0.1
        } else {
            offsetCoord.latitude += self.mapView.region.span.latitudeDelta * 0.1
        }
        mapView.setCenter(offsetCoord, animated: true)
    }
    
    // set `focus` to true to zoom the camera on the newly dropped pin
    func savePin(for mapItem: MKMapItem, focus: Bool) {
        
        var pointAnnotation: CheckpointAnnotation!
        if temporaryAnnotation != nil {
            pointAnnotation = temporaryAnnotation
            temporaryAnnotation = nil
        } else {
            pointAnnotation = CheckpointAnnotation()
            pointAnnotation.coordinate = mapItem.placemark.coordinate
            mapView.addAnnotation(pointAnnotation)
        }
        
        if focus {
            var offsetCoord = mapItem.placemark.coordinate
            if offsetCoord.latitude > 0 {
                offsetCoord.latitude -= self.mapView.region.span.latitudeDelta * 0.1
            } else {
                offsetCoord.latitude += self.mapView.region.span.latitudeDelta * 0.1
            }
            mapView.setCenter(offsetCoord, animated: true)
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
            PathFinder.shared.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            PathFinder.shared.locationManager.requestLocation() // no need for live location tracking for now. Just ask for zoom in.
            
        }
    }
    
    var didCenterOnce = false
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !didCenterOnce {
            if let myLoc = locations.first {
                let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                var offsetCoord = myLoc.coordinate
                if offsetCoord.latitude > 0 {
                    offsetCoord.latitude -= 0.007
                } else {
                    offsetCoord.latitude += 0.007
                }

                let region = MKCoordinateRegion(center: offsetCoord, span: span)
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // maybe show an error message?
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? CheckpointAnnotation else {
            return nil
        }
        let reuseIdentifier = "pin"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)

        if annotationView == nil {
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            annotationView.animatesDrop = true
            return annotationView
//            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
//            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        return annotationView

//        if let customPointAnnotation = annotation as? CheckpointAnnotation {
//            if let imageName = customPointAnnotation.imageName {
//                annotationView?.image = UIImage(named: imageName)
//            }
//
//            return annotationView
//        }
//
//        return nil
    }
    
    func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
        fatalError("not implemented")
    }
    

}
