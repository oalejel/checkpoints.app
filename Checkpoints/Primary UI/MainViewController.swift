//
//  MainViewController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 4/23/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import OverlayContainer
import UIKit
import MapKit

class BackdropViewController: UIViewController {
    override func loadView() {
        view = PassThroughView()
        view.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
    }
}

protocol OverlayContainerDelegate {
    func minimizeOverlay()
    func expandOverlay()
    func getOverlayHeight() -> CGFloat
}

protocol HeightAdjustmentDelegate {
    func didChangeHeightState(state: UserState)
}

enum UserState: Equatable {
    case Searching, PreviewCheckpoint, Routing([CGFloat])//, CustomHeight(CGFloat)
}

protocol StatefulViewController {
    func getUserState() -> UserState
}

class MainViewController: UINavigationController, OverlayContainerDelegate, UIViewControllerTransitioningDelegate {
    
    func getOverlayHeight() -> CGFloat {
        // TODO: dont do this. either rename the function or have a better-defined height
        return fractionalNotchHeights(for: .minimum, availableSpace: overlayController.availableSpace)
    }
    
    let overlayController = OverlayContainerViewController(style: .expandableHeight)
    private let overlayNavigationController = OverlayNavigationViewController()
    
    private let backdropViewController = BackdropViewController()
    private let searchViewController = SearchViewController(showsCloseAction: false)
    private let mapsViewController = MapsViewController()
    
    var state: UserState = .Searching {
        didSet {
            print("NEW STATE: \(String(describing: state))")
            overlayController.invalidateNotchHeights() // trigger a height limit correction
            overlayController.drivingScrollView = currentDrivingScrollview()
        }
    }
    
    enum OverlayNotch: Int, CaseIterable {
        case minimum, medium, maximum
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // might not be the cleanest approach, but this makes it easier to divide extensions
        overlayController.delegate = self
        searchViewController.delegate = self
        mapsViewController.delegate = self
        mapsViewController.overlayContainerDelegate = self
        searchViewController.overlayContainerDelegate = self
        overlayNavigationController.delegate = self
        overlayController.viewControllers = [
            mapsViewController,
            backdropViewController,
            overlayNavigationController
        ]
        
        overlayNavigationController.view.layer.shadowColor = UIColor.black.cgColor
        overlayNavigationController.view.layer.shadowOpacity = 0.15
        overlayNavigationController.view.layer.shadowRadius = 9
        overlayNavigationController.view.layer.shadowOffset = .init(width: 0, height: 0)

        overlayNavigationController.push(searchViewController, animated: true)
        addChild(overlayController, in: view)
    }

    private func fractionalNotchHeights(for notch: OverlayNotch, availableSpace: CGFloat) -> CGFloat {
        switch notch {
        case .maximum:
            return availableSpace * 5 / 6
        case .medium:
            return availableSpace / 1.5
        case .minimum:
            return (availableSpace * 2 / 7) + 32
        }
    }
}

extension MainViewController: OverlayNavigationViewControllerDelegate {
    func overlayNavigationViewControllerDidPopViewController(_ navigationController: OverlayNavigationViewController, animated: Bool) {
        // adjust state depending on type of view controller
        if let stateful = navigationController.topViewController as? StatefulViewController {
            state = stateful.getUserState()
        }
//        if navigationController.topViewController is SearchViewController {
//            state = .Searching
//        } else if navigationController.topViewController is CheckpointViewController {
//            state = .PreviewCheckpoint
//        } else if navigationController.topViewController is RouteConfigController {
//            state = .
//        }
    }
    
    func overlayNavigationViewController(_ navigationController: OverlayNavigationViewController, didShow viewController: UIViewController, animated: Bool) {
        
        if state != .Searching && viewController is SearchViewController {
            state = .Searching
        } else if case let UserState.Routing(customHeight) = state, viewController is RouteConfigController || viewController is RouteResultViewController {
            overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
            state = .Routing(customHeight)
        }
    }
    
    
}

extension MainViewController: SearchViewControllerDelegate {
    
    func searchViewControllerDidSelectRow(_ searchViewController: SearchViewController) {
        let alreadyAdded = PathFinder.shared.destinationCollection.contains(searchViewController.selectedMapItem!)
        if alreadyAdded {
            if let existingAnnotation = mapsViewController.mapView.annotations.first(where: { ($0 as? CheckpointAnnotation)?.mapItem == searchViewController.selectedMapItem }) {
                mapsViewController.mapView.selectAnnotation(existingAnnotation, animated: true)
            } else {
                fatalError("tried to find a checkpoint not on map")
            }
        } else { // temporarily show the pin on the map
            let cvc = CheckpointViewController(mapItem: searchViewController.selectedMapItem!, alreadyAdded: alreadyAdded, showActions: true)
            cvc.delegate = self
            overlayNavigationController.push(cvc, animated: true)
            mapsViewController.showPendingPin(mapItem: searchViewController.selectedMapItem!)
        }
        state = .PreviewCheckpoint
    }
    
    func searchViewControllerDidSelectCloseAction(_ searchViewController: SearchViewController) {
        state = .Searching
    }

    func searchViewControllerDidSearchString(_ string: String) {
        mapsViewController.search(string: string)
    }
    
    func routePressed() {
        let rcv = RouteConfigController(delegate: self)
        overlayNavigationController.push(rcv, animated: true)
        state = .Routing([])
        rcv.heightDelegate = self

        // fit all annotations in mapview
        mapsViewController.previewSpanningTreeRoute()
    }
}

extension MainViewController: LocationsDelegate {
    
    func allowEditingPins() -> Bool {
        switch state {
        case .Searching, .PreviewCheckpoint:
            return true
        default:
            return false
        }
    }

    func focusOnMapItem(_ mapItem: MKMapItem) {
        mapsViewController.showPendingPin(mapItem: mapItem)
    }
    
    func addCheckpointToPath(mapItem: MKMapItem, focus: Bool) {
        PathFinder.shared.addDestination(mapItem: mapItem)
        if PathFinder.shared.destinationCollection.count == 0 {
            PathFinder.shared.startLocationItem = mapItem // set to first location as default
        }
        
        searchViewController.clearEditing(refreshAddedCheckpoints: true)
        
        mapsViewController.savePin(for: mapItem, focus: focus)
        overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        
        refreshCheckpointsButton()
    }
    
    func removeCheckpointFromPath(mapItem: MKMapItem) {
        let removeIndex = PathFinder.shared.destinationCollection.indexOf(mapItem)
        
        DispatchQueue.main.async {
            self.mapsViewController.removePin(for: PathFinder.shared.destinationCollection[removeIndex])
            PathFinder.shared.removeDestination(atIndex: removeIndex)
            self.refreshCheckpointsButton()
            
            if mapItem == PathFinder.shared.startLocationItem { // if the same as the set start location, set it to our first map item
                PathFinder.shared.startLocationItem = nil
                if !PathFinder.shared.destinationCollection.isEmpty { // if we still have destinations
                    PathFinder.shared.startLocationItem = PathFinder.shared.destinationCollection[0]
                }
            }
            
            self.searchViewController.tableView.reloadData()
        }
    }
    
    func makeStart(mapItem: MKMapItem) {
        DispatchQueue.main.async {
            PathFinder.shared.startLocationItem = mapItem
            self.searchViewController.tableView.reloadData()
        }
    }
    
    func isStart(mapItem: MKMapItem) -> Bool {
        return PathFinder.shared.startLocationItem == mapItem
    }
    
    func refreshCheckpointsButton() {
        if PathFinder.shared.destinationCollection.count > 1 {
            searchViewController.header.routeButton.isHidden = false
        } else {
            searchViewController.header.routeButton.isHidden = true
        }
//        var checkpointsText = "1 checkpoint added"
//        if PathFinder.shared.destinations.count != 1 {
//            checkpointsText = "\(PathFinder.shared.destinations.count) checkpoints added"
//        } else {
//            checkpointsText = "1 checkpoint added"
//        }
//        searchViewController.header.checkpointCountButton.setTitle(checkpointsText, for: .normal)
//
//        if PathFinder.shared.destinations.count == 0 {
//            searchViewController.header.checkpointCountButton.isHidden = true
//        } else {
//            searchViewController.header.checkpointCountButton.isHidden = false
//        }
    }
    
    func shouldEndCheckpointPreview() {
//        state = .Searching
        mapsViewController.removePendingAnnotation()
        if overlayNavigationController.topViewController is CheckpointViewController {
            print("] resigning search first responder")
            let _ = searchViewController.resignFirstResponder()
//            overlayNavigationController.popViewController(animated: true)
            overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        }
    }
    
    func shouldPreviewCheckpoint(mapItem: MKMapItem, showActions: Bool) {
//        state = .PreviewCheckpoint
        if overlayNavigationController.topViewController is CheckpointViewController {
            overlayNavigationController.popViewController(animated: false)
        }
        
        let cvc = CheckpointViewController(mapItem: mapItem, alreadyAdded: true, showActions: showActions)
        cvc.delegate = self
        state = .PreviewCheckpoint
        searchViewController.selectedMapItem = mapItem
        overlayNavigationController.push(cvc, animated: true)
    }
    
    func updatedSearchResults(mapItems: [MKMapItem]) {
        searchViewController.refreshSearchResults(mapItems)
    }
    
    func manualPinPlaced(for mapItem: MKMapItem) {
        let cvc = CheckpointViewController(mapItem: mapItem, alreadyAdded: false, showActions: true)
        cvc.delegate = self
        state = .PreviewCheckpoint
        overlayNavigationController.push(cvc, animated: true)
        // temporarily show the pin on the map
        mapsViewController.showPendingPin(mapItem: mapItem)
    }
}

extension MainViewController: HeightAdjustmentDelegate {
    func didChangeHeightState(state: UserState) {
        self.state = state // invalidates notch heights
//        overlayController.invalidateNotchHeights()
    }
}

extension MainViewController: RouteConfigDelegate {
    func cancellingRouteConfiguration() {
        print("TODO: cleanup route configuration preview on map")
    }
    
    func previewMST() {
        // fit all annotations in mapview
        mapsViewController.previewSpanningTreeRoute()
    }
}

extension MainViewController: OverlayContainerViewControllerDelegate {

    // MARK: - OverlayContainerViewControllerDelegate

    func numberOfNotches(in containerViewController: OverlayContainerViewController) -> Int {
        switch state {
            case .Searching:
                return OverlayNotch.allCases.count
            case .PreviewCheckpoint:
                return 1
//            case .CustomHeight:
//                return 1
            case .Routing(let heights):
                return max(heights.count, 1) // lets return the fitting height and a max height as possible heights
        }
    }

    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        heightForNotchAt index: Int,
                                        availableSpace: CGFloat) -> CGFloat {
        switch state {
        case .Searching:
            let notch = OverlayNotch.allCases[index]
            return fractionalNotchHeights(for: notch, availableSpace: availableSpace)
        case .PreviewCheckpoint:
//            let x = overlayNavigationController.topViewController!.view
            return overlayNavigationController.topViewController!.view.frame.size.height - 124 // TODO: fix this for all screens
//        case .CustomHeight(let frameHeight):
//            return frameHeight
        case .Routing(let optionalHeights):
            if optionalHeights.count > index {
                return optionalHeights[index]
            } else {
                return overlayNavigationController.topViewController!.view.frame.size.height + CGFloat(index)
            }
        }
    }

    
    private func currentDrivingScrollview() -> UIScrollView? {
        switch state {
        case .Searching:
            return searchViewController.tableView
        case .PreviewCheckpoint:
            return nil
        case .Routing:
            if let topVC = overlayNavigationController.topViewController as? RouteResultViewController {
                return topVC.tableView
            }
            return nil
        }
    }
    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        scrollViewDrivingOverlay overlayViewController: UIViewController) -> UIScrollView? {
        return currentDrivingScrollview()
    }

    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        shouldStartDraggingOverlay overlayViewController: UIViewController,
                                        at point: CGPoint,
                                        in coordinateSpace: UICoordinateSpace) -> Bool {
        switch state {
        case .Searching:
            let header = searchViewController.header
            let hitHeader = header.bounds.contains(coordinateSpace.convert(point, to: header))
            searchViewController.header.searchBar.resignFirstResponder()
            return hitHeader
        case .PreviewCheckpoint:
//            let vc = overlayNavigationController.topViewController!
//            let convertedPoint = coordinateSpace.convert(point, to: vc.view)
//            let yes = vc.view.bounds.contains(convertedPoint)
//            return yes
            return true
        case .Routing:
            return true
        }
    }

    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        willTranslateOverlay overlayViewController: UIViewController,
                                        transitionCoordinator: OverlayContainerTransitionCoordinator) {
        transitionCoordinator.animate(alongsideTransition: { [weak self] context in
            self?.backdropViewController.view.alpha = context.translationProgress()
            
            // if we moved down far enough, hide keyboard
            // warning: not doing its job, since something is strictly resigning keyboard control
            if context.targetTranslationHeight < context.maximumReachableHeight() {
                self?.searchViewController.endEditing()
            }
        }, completion: nil)
    }
    
    // MARK: - OverlayContainerDelegate
    
    func minimizeOverlay() {
        searchViewController.endEditing()
        overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
    }
    
    func expandOverlay() {
        overlayController.moveOverlay(toNotchAt: OverlayNotch.maximum.rawValue, animated: true)
    }

}
