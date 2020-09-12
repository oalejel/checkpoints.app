//
//  GroupResultsController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 8/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class GroupResultsController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, StatefulViewController, UICollectionViewDelegateFlowLayout {
    
    var delegate: RouteConfigDelegate!
    var finishedComputation = false // track in case we need to unhide before view appears
    
    func getUserState() -> UserState {
        return .GroupRoutingPreview
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var avgDistanceLabel: UILabel!
    @IBOutlet weak var maxDistanceLabel: UILabel!
    @IBOutlet weak var minDistanceLabel: UILabel!
    
    @IBOutlet weak var avgStopsLabel: UILabel!
    @IBOutlet weak var maxStopsLabel: UILabel!
    @IBOutlet weak var minStopsLabel: UILabel!
    
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var collectionView: UICollectionView!
    let CELL_ID = "driver_cell"
    
    var numDrivers = 0
    var optimalGroupingArray: [[Int]]?
    
    init(numDrivers: Int, delegate: RouteConfigDelegate) {
        super.init(nibName: nil, bundle: nil)
        self.numDrivers = numDrivers
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 26
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        
        shareButton.layer.cornerRadius = 8
        shareButton.layer.masksToBounds = true
        
        pageControl.numberOfPages = numDrivers
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "DriverRouteCollectionCell", bundle: nil), forCellWithReuseIdentifier: CELL_ID)
        collectionView.isPagingEnabled = true
        collectionView.scrollIndicatorInsets = .zero
        //        collectionView.setCollectionViewLayout(<#T##layout: UICollectionViewLayout##UICollectionViewLayout#>, animated: <#T##Bool#>, completion: <#T##((Bool) -> Void)?##((Bool) -> Void)?##(Bool) -> Void#>)
        titleLabel.text = "\(numDrivers) Driver Routes"
        
        PathFinder.shared.computeGroupOptimalPath(numTravelers: numDrivers) { groupedRouteArrays in
            // NOTE: these paths include start index 0
            self.finishedComputation = true
            self.optimalGroupingArray = groupedRouteArrays
            
            var minStops = Int.max
            var maxStops = 0
            var avgStops = 0
            var maxDistance = 0.0
            var minDistance = Double.infinity
            var avgDistance = 0.0
            
            for pathIndices in groupedRouteArrays {
                if pathIndices.count - 1 < minStops {
                    minStops = pathIndices.count - 1
                }
                if pathIndices.count - 1 > maxStops {
                    maxStops = pathIndices.count - 1
                }
                
                var pathLength = 0.0
                for indexIndex in 0..<(pathIndices.count){
                    let loc1 = pathIndices[indexIndex]
                    let loc2 = pathIndices[(indexIndex + 1) % pathIndices.count] // wrap back around to start on last iteration
                    pathLength += PathFinder.shared.destinationCollection.getDistance(between: loc1, and: loc2)
                }
                
                if pathLength > maxDistance {
                    maxDistance = pathLength
                }
                if pathLength < minDistance {
                    minDistance = pathLength
                }
                avgDistance += pathLength
                avgStops += pathIndices.count - 1 // dont include start location in number of stops
            }
            
//            // adjust stops by 1 since we dont want to include start
//            minStops
//            maxStops
            // perform division for averages
            avgDistance /= Double(groupedRouteArrays.count)
            avgStops /= groupedRouteArrays.count
                
            let formatter = LengthFormatter()
            formatter.unitStyle = .medium
            formatter.numberFormatter.maximumSignificantDigits = 3
            
            self.avgDistanceLabel.text = formatter.string(fromMeters: avgDistance) + " average"
            self.maxDistanceLabel.text = formatter.string(fromMeters: maxDistance) + " maximum"
            self.minDistanceLabel.text = formatter.string(fromMeters: minDistance) + " minimum"
            
            if avgStops == 1 {
                self.avgStopsLabel.text = "1 stop average"
            } else {
                self.avgStopsLabel.text = "\(avgStops) stops average"
            }
            
            if minStops == 1 {
                self.minStopsLabel.text = "1 stop minimum"
            } else {
                self.minStopsLabel.text = "\(minStops) stops minimum"
            }
            
            if maxStops == 1 {
                self.maxStopsLabel.text = "1 stop maximum"
            } else {
                self.maxStopsLabel.text = "\(maxStops) stops maximum"
            }
            
            self.didFocusOnDriver(index: 0)
            self.collectionView.reloadData()
            
            if self.viewWillAppearedCalled {
                self.togglePrimaryUIVisibility(hidden: false, animated: self.viewDidAppearCalled)
            }
        }
    }
    
    var viewWillAppearedCalled = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !viewWillAppearedCalled && finishedComputation {
            viewWillAppearedCalled = true // set in two places in case bad interleaving likely?
            togglePrimaryUIVisibility(hidden: false, animated: false)
        }
        viewWillAppearedCalled = true
    }
    
    var viewDidAppearCalled = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidAppearCalled = true
    }
    
    // MARK: - UI Helpers
    
    // call to remove progress bar
    func togglePrimaryUIVisibility(hidden: Bool, animated: Bool) {
        func show() {
            avgDistanceLabel.isHidden = hidden
            avgStopsLabel.isHidden = hidden
            minStopsLabel.isHidden = hidden
            minDistanceLabel.isHidden = hidden
            maxStopsLabel.isHidden = hidden
            maxDistanceLabel.isHidden = hidden
                        
//            refreshDriverIndexUI() // must also do this to account for multiple drivers
        }
        
        if animated {
            UIView.animate(withDuration: 1, animations: show)
        } else {
            show()
        }
        
        if hidden {
//            nextDestinationLabel.text = "Route"
        } else {
//            nextDestinationLabel.text = "Next Stop"
        }
    }
    
    func setDistanceLabel(meters: Double) {
        let formatter = LengthFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumSignificantDigits = 3
//        distanceRemainingLabel.text = formatter.string(fromMeters: meters) + " left"
    }
    
    @IBAction func closePressed(_ sender: UIButton) {
        self.delegate.showPinAnnotations()
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func sharePressed(_ sender: UIButton) {
        
    }
    
    // MARK: - Driver selection handlers
    
    func didFocusOnDriver(index: Int) {
        pageControl.currentPage = index
        if let group = optimalGroupingArray?[index] {
            delegate.showNumberedAnnotations(pathIndices: group)
        }
    }
    
    // MARK: - Collection View Delegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var unpadded = collectionView.frame.size
        //        unpadded.height -= 0
        unpadded.width -= 24
        return unpadded
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    // MARK: - Scrollview delegate
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageIndex = Int((scrollView.contentOffset.x + 40) / scrollView.frame.size.width) % numDrivers // adding 40 for now to account for some padding
        didFocusOnDriver(index: pageIndex)
    }
    
    // MARK: - Collection View Datasource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numDrivers
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let optimalGroupingArray = optimalGroupingArray else {
            fatalError("attempting to reload table on nil data")
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CELL_ID, for: indexPath) as? DriverRouteCollectionCell else {
            fatalError("unrecognized cell dequeued")
        }
        let lighterGray = UIColor(white: 0.95312, alpha: 1)
        cell.backgroundColor = lighterGray
        cell.layer.cornerRadius = 10
        cell.layer.masksToBounds = true
        cell.tableView.backgroundColor = lighterGray
        cell.titleLabel.text = "Driver \(indexPath.row + 1)"
        cell.pathIndices = optimalGroupingArray[indexPath.row]
        
        return cell
    }
    
}
