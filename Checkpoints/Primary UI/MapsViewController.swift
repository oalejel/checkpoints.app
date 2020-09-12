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
    func attemptAllowEditingPins() -> Bool 
    func updatedSearchResults(mapItems: [MKMapItem])
    func shouldPreviewCheckpoint(mapItem: MKMapItem, showActions: Bool)
    func shouldEndCheckpointPreview()
    func manualPinPlaced(for mapItem: MKMapItem) // for long press to drop pin gesture
    func focusOnMapItem(_ mapItem: MKMapItem)
    func addCheckpointToPath(mapItem: MKMapItem, focus: Bool)
    func removeCheckpointFromPath(mapItem: MKMapItem)
    func makeStart(mapItem: MKMapItem)
    func isStart(mapItem: MKMapItem) -> Bool
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
        mapView.showsCompass = false
        mapView.showsPointsOfInterest = true
//        if let compassView = mapView.subviews.filter({ $0.isKindOfClass(NSClassFromString("MKCompassView")!) }).first {
//            compassView.frame = CGRectMake(15, 30, 36, 36)
//        }
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gc:)))
        longPress.minimumPressDuration = 0.6
        longPress.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(longPress)
        
        PathFinder.shared.locationManager.delegate = self
        PathFinder.shared.locationManager.requestAlwaysAuthorization() // warning: move to a later part of the app (when go pressed)
    }
    
    @objc func longPress(gc: UILongPressGestureRecognizer) {
        if !(delegate?.attemptAllowEditingPins() ?? false) { return } // ignore if not allowed to add pins
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
//        if offsetCoord.latitude > 0 {
        offsetCoord.latitude -= self.mapView.region.span.latitudeDelta * 0.1
//        } else {
//            offsetCoord.latitude += self.mapView.region.span.latitudeDelta * 0.1
//        }
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
            pointAnnotation.viewType = .Pin
            pointAnnotation?.title = mapItem.placemark.name ?? mapItem.placemark.title ?? "\(mapItem.placemark.coordinate.latitude), \(mapItem.placemark.coordinate.longitude)"
            pointAnnotation.coordinate = mapItem.placemark.coordinate
            mapView.addAnnotation(pointAnnotation)
        }
        
        if focus {
            var offsetCoord = mapItem.placemark.coordinate
//            if offsetCoord.latitude > 0 {
            offsetCoord.latitude -= self.mapView.region.span.latitudeDelta * 0.1
//            } else {
//                offsetCoord.latitude += self.mapView.region.span.latitudeDelta * 0.1
//            }
            mapView.setCenter(offsetCoord, animated: true)
        }
    }
    
    func removePin(for mapItem: MKMapItem) {
        mapView.deselectAnnotation(calledOutAnnotation, animated: true)
        if let p = pendingAnnotation { mapView.removeAnnotation(p) }
        pendingAnnotation = nil
        if let matchingAnnotation = mapView.annotations.first(where: {
            ($0 as? CheckpointAnnotation)?.mapItem == mapItem
        }) {
            mapView.removeAnnotation(matchingAnnotation)
        } else {
            fatalError("Attempted to remove annotation that doesnt exist")
        }
    }
    
    func previewSpanningTreeRoute() {
        var totalMapRect = MKMapRect.null
        for ann in self.mapView.annotations {
            let annotationPoint = MKMapPoint(ann.coordinate)
            let mapRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
            totalMapRect = totalMapRect.union(mapRect)
        }
        
        let topPadding: CGFloat = 32
        let overlayHeight = overlayContainerDelegate?.getOverlayHeight() ?? 8
        let hPadding = max(view.bounds.size.height - (topPadding + CGFloat(totalMapRect.height)), overlayHeight + topPadding) + 32
        mapView.setVisibleMapRect(totalMapRect, edgePadding: UIEdgeInsets(top: topPadding, left: 16, bottom: hPadding, right: 16), animated: true)
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
    
    
    // required for location delegate
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
//                let region = MKCoordinateRegion(center: offsetCoord, span: span)
//                mapView.setRegion(region, animated: true)
//            }
//        }
    }
    
    var didCenterOnce = false
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
            
            // only do this once. Warning: if user moves, the default start position wont move with them
            PathFinder.shared.computeMapItem(for: userLocation.coordinate) { (currentMapItem) in
                print("updating current location mapitem")
                if let sureItem = currentMapItem {
                    PathFinder.shared.firstRecordedCurrentLocation = sureItem
                    if PathFinder.shared.destinationCollection.isEmpty {
                        print("adding pin and destination for current location")
                        self.delegate?.addCheckpointToPath(mapItem: sureItem, focus: false)
                    }
                } else {
                    print("error: couldnt figure out map item for the current location")
                }
            }
        }
        
        // update pathfinder's live user location
        PathFinder.shared.mapUpdatedLocation = userLocation.coordinate
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // maybe show an error message?
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
    
    // MARK: - Overlays
    
//    func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
//
//    }
//
//    func mapView(_ mapView: MKMapView, didAddOverlayViews overlayViews: [Any]) {
//
//    }
    
//    func mapView(_ mapView: MKMapView, viewFor overlay: MKOverlay) -> MKOverlayView {
//
//    }
    
//    var animatedRenderer: AnimatedLineRenderer?
//    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//        guard let animatedLine = overlay as? AnimatedPolyline else {
//            return MKOverlayRenderer()
//        }
//
//        let renderer = AnimatedLineRenderer(overlay: overlay)
//        renderer.animatedPolyline = animatedLine
//        animatedRenderer = renderer
//        return renderer
//
////        let polylineRenderer = MKPolylineRenderer(overlay: polyline)
////        polylineRenderer.strokeColor = .systemBlue
////        polylineRenderer.lineWidth = 6
////        polylineRenderer.lineDashPattern = [0.7, 0.3]
////        polylineRenderer.lineCap = .round
////        return polylineRenderer
//    }
    
//    var drawingTimer: Timer?
//    var currentPolyLine: MKPolyline?
//    func animate(route: [CLLocationCoordinate2D], duration: TimeInterval, completion: (() -> Void)?) {
//            guard route.count > 0 else { return }
//            var currentStep = 1
//            let totalSteps = route.count
//            let stepDrawDuration = duration/TimeInterval(totalSteps)
//            var previousSegment: MKPolyline?
//
//            drawingTimer = Timer.scheduledTimer(withTimeInterval: stepDrawDuration, repeats: true) { [weak self] timer in
//                guard let self = self else {
//                    // Invalidate animation if we can't retain self
//                    timer.invalidate()
//                    completion?()
//                    return
//                }
//
//                if let previous = previousSegment {
//                    // Remove last drawn segment if needed.
//                    self.mapView.removeOverlay(previous)
//                    previousSegment = nil
//                }
//
//                guard currentStep < totalSteps else {
//                    // If this is the last animation step...
//                    let finalPolyline = MKPolyline(coordinates: route, count: route.count)
//                    self.mapView.addOverlay(finalPolyline)
//                    // Assign the final polyline instance to the class property.
//                    self.currentPolyLine = finalPolyline
//                    timer.invalidate()
//                    completion?()
//                    return
//                }
//
//                // Animation step.
//                // The current segment to draw consists of a coordinate array from 0 to the 'currentStep' taken from the route.
//                let subCoordinates = Array(route.prefix(upTo: currentStep))
//                let currentSegment = MKPolyline(coordinates: subCoordinates, count: subCoordinates.count)
//                self.mapView.addOverlay(currentSegment)
//
//                previousSegment = currentSegment
//                currentStep += 1
//            }
//        }

    
    // MARK: - Annotations
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? CheckpointAnnotation else {
            return nil
        }
        
        var reuseID = "numbered_pin_ID"
        if annotation.viewType == .Pin { reuseID = "pin_ID"}
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID)
        
        switch annotation.viewType {
        case .Pin:
            if annotationView == nil {
                let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                pinView.animatesDrop = true
                annotationView = pinView
            }
        case .Numbered(let num):
//            print("pin num: \(num), place: \(annotation.title)")
            if annotationView == nil {
                let numberedView = NumberedAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                annotationView = numberedView
            }
            //String(annotation.title!.split(separator: " ")[1]))
            (annotationView as! NumberedAnnotationView).setTitleNumber(String(num))
        }
        
        annotationView!.canShowCallout = true
        annotationView!.annotation = annotation
        return annotationView
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
                        let showActions = delegate?.attemptAllowEditingPins() ?? false 
                        delegate?.shouldPreviewCheckpoint(mapItem: selectedMapItem, showActions: showActions)
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
