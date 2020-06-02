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
    case Searching, AddingCheckpoint
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
            return availableSpace * 2 / 7
        }
    }
}

extension MainViewController: OverlayNavigationViewControllerDelegate {
    func overlayNavigationViewController(_ navigationController: OverlayNavigationViewController, didShow viewController: UIViewController, animated: Bool) {
        
        if state == .Searching {
            
        } else if state == .AddingCheckpoint {
            if let cvc = viewController as? CheckpointViewController {
                
            }
        }
    }
}

extension MainViewController: SearchViewControllerDelegate {
    
    func searchViewControllerDidSelectRow(_ searchViewController: SearchViewController) {
        let cvc = CheckpointViewController(mapItem: searchViewController.selectedMapItem!)
        cvc.delegate = self
        state = .AddingCheckpoint
        overlayNavigationController.push(cvc, animated: true)
        // temporarily show the pin on the map
        mapsViewController.showTemporaryPin(mapItem: searchViewController.selectedMapItem!)
    }
    
    func searchViewControllerDidSelectCloseAction(_ searchViewController: SearchViewController) {
        
    }

    func searchViewControllerDidSearchString(_ string: String) {
        mapsViewController.search(string: string)
    }
}

extension MainViewController: CheckpointViewControllerDelegate {
    
    func addCheckpointToPath(mapItem: MKMapItem) {
        PathFinder.shared.addDestination(mapItem: mapItem)
        searchViewController.clearEditing(refreshAddedCheckpoints: true)
    
        mapsViewController.savePin(for: mapItem, focus: true)
        overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        
        var checkpointsText = "1 checkpoint added"
        if PathFinder.shared.destinations.count != 1 {
            checkpointsText = "\(PathFinder.shared.destinations.count) checkpoints added"
        } else {
            checkpointsText = "1 checkpoint added"
        }
        searchViewController.header.checkpointCountButton.setTitle(checkpointsText, for: .normal)
        searchViewController.header.checkpointCountButton.isHidden = false
    }
}

extension MainViewController: LocationsDelegate {
    func updatedSearchResults(mapItems: [MKMapItem]) {
        searchViewController.refreshSearchResults(mapItems)
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
        } else if state == .AddingCheckpoint {
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
        case .AddingCheckpoint:
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
