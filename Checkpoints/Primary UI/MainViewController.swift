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
}

enum UserState {
    case Searching, PreviewCheckpoint
}

class MainViewController: UINavigationController, OverlayContainerDelegate, UIViewControllerTransitioningDelegate {
    
    let overlayController = OverlayContainerViewController(style: .expandableHeight)
    private let overlayNavigationController = OverlayNavigationViewController()
    
    private let backdropViewController = BackdropViewController()
    private let searchViewController = SearchViewController(showsCloseAction: false)
    private let mapsViewController = MapsViewController()
    
    
    
    var state: UserState = .Searching
    
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

    private func notchHeight(for notch: OverlayNotch, availableSpace: CGFloat) -> CGFloat {
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
    func overlayNavigationViewController(_ navigationController: OverlayNavigationViewController, didShow viewController: UIViewController, animated: Bool) {
        
        if state == .Searching {
            
        } else if state == .PreviewCheckpoint {
//            if let cvc = viewController as? CheckpointViewController {
//                
//            }
        }
    }
}

extension MainViewController: SearchViewControllerDelegate {
    
    func searchViewControllerDidSelectRow(_ searchViewController: SearchViewController) {
        let alreadyAdded = PathFinder.shared.destinations.contains(searchViewController.selectedMapItem!)
        state = .PreviewCheckpoint
        if alreadyAdded {
            if let existingAnnotation = mapsViewController.mapView.annotations.first(where: { ($0 as? CheckpointAnnotation)?.mapItem == searchViewController.selectedMapItem }) {
                mapsViewController.mapView.selectAnnotation(existingAnnotation, animated: true)
            } else {
                fatalError("tried to find a checkpoint not on map")
            }
        } else { // temporarily show the pin on the map
            let cvc = CheckpointViewController(mapItem: searchViewController.selectedMapItem!, alreadyAdded: alreadyAdded)
            cvc.delegate = self
            overlayNavigationController.push(cvc, animated: true)
            mapsViewController.showPendingPin(mapItem: searchViewController.selectedMapItem!)
        }
    }
    
    func searchViewControllerDidSelectCloseAction(_ searchViewController: SearchViewController) {
        state = .Searching
    }

    func searchViewControllerDidSearchString(_ string: String) {
        mapsViewController.search(string: string)
    }
    
    func routePressed() {
        let rcv = RouteConfigController(nibName: nil, bundle: nil)
        overlayNavigationController.push(rcv, animated: true)
    }
}

extension MainViewController: LocationsDelegate {

    func focusOnMapItem(_ mapItem: MKMapItem) {
        mapsViewController.showPendingPin(mapItem: mapItem)
    }
    
    func addCheckpointToPath(mapItem: MKMapItem, focus: Bool) {
        PathFinder.shared.addDestination(mapItem: mapItem)
        searchViewController.clearEditing(refreshAddedCheckpoints: true)
        
        mapsViewController.savePin(for: mapItem, focus: focus)
        overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        
        refreshCheckpointsButton()
        
        if PathFinder.shared.destinations.count == 1 {
            PathFinder.shared.startLocationItem = mapItem // set to first location as default
        }
    }
    
    func removeCheckpointFromPath(mapItem: MKMapItem) {
        guard let removeIndex = PathFinder.shared.destinations.firstIndex(of: mapItem) else {
            fatalError("Attempted to remove checkpoint not in pathfinder")
        }
        
        DispatchQueue.main.async {
            self.mapsViewController.removePin(for: PathFinder.shared.destinations[removeIndex])
            PathFinder.shared.removeDestination(atIndex: removeIndex)
            self.refreshCheckpointsButton()
            
            if mapItem == PathFinder.shared.startLocationItem { // if the same as the set start location, set it to our first map item
                PathFinder.shared.startLocationItem = nil
                if !PathFinder.shared.destinations.isEmpty { // if we still have destinations
                    PathFinder.shared.startLocationItem = PathFinder.shared.destinations[PathFinder.shared.destIntermediateIndices[0]]
                }
            }
            
            self.searchViewController.tableView.reloadData()
        }
    }
    
    func refreshCheckpointsButton() {
        if PathFinder.shared.destinations.count > 0 {
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
        state = .Searching
        mapsViewController.removePendingAnnotation()
        if overlayNavigationController.topViewController is CheckpointViewController {
            print("] resigning search first responder")
            let _ = searchViewController.resignFirstResponder()
            overlayNavigationController.popViewController(animated: true)
            overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        }
    }
    
    func shouldPreviewCheckpoint(mapItem: MKMapItem) {
        state = .PreviewCheckpoint
        if overlayNavigationController.topViewController is CheckpointViewController {
            overlayNavigationController.popViewController(animated: false)
        }
        
        let cvc = CheckpointViewController(mapItem: mapItem, alreadyAdded: true)
        cvc.delegate = self
        state = .PreviewCheckpoint
        searchViewController.selectedMapItem = mapItem
        overlayNavigationController.push(cvc, animated: true)
    }
    
    func updatedSearchResults(mapItems: [MKMapItem]) {
        searchViewController.refreshSearchResults(mapItems)
    }
    
    func manualPinPlaced(for mapItem: MKMapItem) {
        let cvc = CheckpointViewController(mapItem: mapItem, alreadyAdded: false)
        cvc.delegate = self
        state = .PreviewCheckpoint
        overlayNavigationController.push(cvc, animated: true)
        // temporarily show the pin on the map
        mapsViewController.showPendingPin(mapItem: mapItem)
    }
}

extension MainViewController: OverlayContainerViewControllerDelegate {

    // MARK: - OverlayContainerViewControllerDelegate

    func numberOfNotches(in containerViewController: OverlayContainerViewController) -> Int {
        return OverlayNotch.allCases.count
    }

    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        heightForNotchAt index: Int,
                                        availableSpace: CGFloat) -> CGFloat {
        let notch = OverlayNotch.allCases[index]
        return notchHeight(for: notch, availableSpace: availableSpace)
    }

    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        scrollViewDrivingOverlay overlayViewController: UIViewController) -> UIScrollView? {
        if state == .Searching {
            return searchViewController.tableView
        } else if state == .PreviewCheckpoint {
//            if let scrollView = (navigationController?.topViewController as? CheckpointViewController)?.scrollView {
//                return scrollView
//            }
            return nil
        }
        
        fatalError("should match a scrollview")
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
