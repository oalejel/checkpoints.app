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
    func shouldPreviewCheckpoint(mapItem: MKMapItem)
    func shouldEndCheckpointPreview()
    func manualPinPlaced(for mapItem: MKMapItem) // for long press to drop pin gesture
    func focusOnMapItem(_ mapItem: MKMapItem)
    func addCheckpointToPath(mapItem: MKMapItem)
}

class MapsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
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
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gc:)))
        longPress.minimumPressDuration = 0.6
        longPress.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(longPress)
        
        PathFinder.shared.locationManager.delegate = self
        PathFinder.shared.locationManager.requestAlwaysAuthorization() // warning: move to a later part of the app (when go pressed)
    }
    
    @objc func longPress(gc: UILongPressGestureRecognizer) {
        if gc.state == .began {
            let coordinate = mapView.convert(gc.location(ofTouch: 0, in: mapView), toCoordinateFrom: mapView)
            PathFinder.shared.computeMapItem(for: coordinate) { (mapItem) in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                guard let mapItem = mapItem else {
                    let unkownMapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate, addressDictionary: nil))
                    self.delegate?.manualPinPlaced(for: unkownMapItem)
                    return
                }
                self.delegate?.manualPinPlaced(for: mapItem)
            }
            
            gc.state = .ended
        }
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
    
    func removePendingAnnotation() {
        if let tempAnn = pendingAnnotation {
            mapView.removeAnnotation(tempAnn)
            pendingAnnotation = nil
        }
    }
    
    var pendingAnnotation: CheckpointAnnotation?
    func showPendingPin(mapItem: MKMapItem) {
        // deselect last selected pin
        mapView.deselectAnnotation(calledOutAnnotation, animated: true)
        calledOutAnnotation = nil

        removePendingAnnotation()
        pendingAnnotation = CheckpointAnnotation(mapItem: mapItem)
        pendingAnnotation!.coordinate = mapItem.placemark.coordinate
        pendingAnnotation?.title = mapItem.placemark.name ?? mapItem.placemark.title ?? "\(mapItem.placemark.coordinate.latitude), \(mapItem.placemark.coordinate.longitude)"
        mapView.addAnnotation(pendingAnnotation!)
        
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
        // deselect last selected pin
        mapView.deselectAnnotation(calledOutAnnotation, animated: true)
        calledOutAnnotation = nil
        
        var pointAnnotation: CheckpointAnnotation!
        if pendingAnnotation != nil { // if we already have a temporary pin, dont drop it again
            pointAnnotation = pendingAnnotation
            pendingAnnotation = nil
        } else {
            pointAnnotation = CheckpointAnnotation(mapItem: mapItem)
            pointAnnotation?.title = mapItem.placemark.name ?? mapItem.placemark.title ?? "\(mapItem.placemark.coordinate.latitude), \(mapItem.placemark.coordinate.longitude)"
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
            PathFinder.shared.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            PathFinder.shared.locationManager.requestLocation() // no need for live location tracking for now. Just ask for zoom in.
            
        }
    }
    
    var didCenterOnce = false
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if !didCenterOnce {
//            if let myLoc = locations.first {
//                let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                var offsetCoord = myLoc.coordinate
//                if offsetCoord.latitude > 0 {
//                    offsetCoord.latitude -= 0.007
//                } else {
//                    offsetCoord.latitude += 0.007
//                }
//
//                let region = MKCoordinateRegion(center: offsetCoord, span: span)
//                mapView.setRegion(region, animated: true)
//            }
//        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !didCenterOnce {
            didCenterOnce = true
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            var offsetCoord = userLocation.coordinate
            if offsetCoord.latitude > 0 {
                offsetCoord.latitude -= 0.007
            } else {
                offsetCoord.latitude += 0.007
            }

            let region = MKCoordinateRegion(center: offsetCoord, span: span)
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
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? CheckpointAnnotation else {
            return nil
        }
        let reuseIdentifier = "pin"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        annotationView?.canShowCallout = true
        
        if annotationView == nil {
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            annotationView.animatesDrop = true
            annotationView.canShowCallout = true
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
    
    var calledOutAnnotation: MKAnnotation?
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let selectedAnnotation = view.annotation {
            if selectedAnnotation.isEqual(pendingAnnotation) {
                // do nothing unique if selecting an already temporary pin
            } else {
                // if we have a temporary pin, remove it
                removePendingAnnotation()
                
                if selectedAnnotation.isEqual(mapView.userLocation) {
                    print("] shouldendcheckpointpreview")
                    delegate?.shouldEndCheckpointPreview() // removes preview vc and pending pin (redundantly)
                    
                } else {
                    if let selectedMapItem = (selectedAnnotation as? CheckpointAnnotation)?.mapItem {
                        delegate?.shouldPreviewCheckpoint(mapItem: selectedMapItem)
                    } else {
                        fatalError("no map item for selected annotation!")
                    }
                }
            }
            
            calledOutAnnotation = selectedAnnotation // remember in case we add another checkpoint
        } else {
            fatalError("selected annotationview has no annotation")
        }
    }
    
//    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
//        print("DEselected annotation: \(view.annotation!.title)")
//        print("view.annotation?.isEqual(mapView.userLocation): \(view.annotation?.isEqual(mapView.userLocation))")
//        print("view.annotation?.isEqual(calledOutAnnotation): \(view.annotation?.isEqual(calledOutAnnotation))")
//        // only want to remove preview when we are deselecting by tapping on map, NOT because tapping on
//        // another checkpoint. the latter case is already handled.
//
//    }
    
}
