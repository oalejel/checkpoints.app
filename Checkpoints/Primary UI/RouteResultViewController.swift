//
//  RouteResultViewController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class RouteResultViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, StatefulViewController {
    
    

    @IBOutlet weak var startDirectionsButton: UIButton!
    @IBOutlet weak var closeButton: CloseButton!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stopsRemainingLabel: UILabel!
    @IBOutlet weak var distanceRemainingLabel: UILabel!
    @IBOutlet weak var nextDestinationLabel: UILabel!
    @IBOutlet weak var driverLabel: UILabel!
    @IBOutlet weak var nextStopFooter: UILabel!
    
    var selectedStopIndex = 1 // start at the first location after "start point"
    
    let CELL_ID = "routecell"
    
    @IBOutlet weak var infoAndButtonStack: UIStackView!
    @IBOutlet weak var nextDestStack: UIStackView!
    var driverNumber: Int? {
        didSet {
            refreshDriverIndexUI()
        }
    }
    
    var heldState: UserState!
    var delegate: RouteConfigDelegate!
    var optimalRouteArray: [Int]?
    
    var finishedComputation = false // track in case we need to unhide before view appears
    
    init(state: UserState, delegate: RouteConfigDelegate) {
        super.init(nibName: nil, bundle: nil)
        self.heldState = state
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getUserState() -> UserState {
        return heldState
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // automatically hide everything in case loading the path takes a while
        self.togglePrimaryUIVisibility(hidden: true, animated: false)
        
        PathFinder.shared.setProgressPercentageUpdateHandler { (percent) in
            print("new percent: \(percent)")
        }
        
        // ---- essential ui setup
        view.layer.cornerRadius = 26
        view.layer.masksToBounds = true

        // prepare initial contents
        refreshDriverIndexUI()
        startDirectionsButton.layer.cornerRadius = 10
                
        // NOTE: distance remaining may be based on a reordering of the path, as the user is allowed to change the sequence of directions
        // TODO: support cancelling the computation operation with user intervention with the x button
        
        // Table view setup
        tableView.register(UINib(nibName: "RouteCell", bundle: nil), forCellReuseIdentifier: CELL_ID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.separatorStyle = .none
        
        // ---- start computation with handler
        PathFinder.shared.computeIndividualOptimalPath { routeArray in
//            print("GOT OUTPUT:", routeArray)
            DispatchQueue.main.async {
                self.finishedComputation = true
                self.optimalRouteArray = routeArray
                self.delegate.showNumberedAnnotations(pathIndices: routeArray)
                
                // if view already appeared, we must show primary UI here
                if self.viewWillAppearedCalled {
                    self.togglePrimaryUIVisibility(hidden: false, animated: true)
                }
                
                self.stopsRemainingLabel.text = "\(PathFinder.shared.destinationCollection.count - 2) stops remaining" // TODO: assume that 2 of the destinations include start and end?

                let remainingMeters = PathFinder.shared.destinationCollection.distanceAfterCheckpoint(startIndex: 0)
                self.setDistanceLabel(meters: remainingMeters)
                
                self.tableView.reloadData()
                //        tableView.selectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: false, scrollPosition: .none)
                self.tableView.selectRow(at: IndexPath(row: self.selectedStopIndex, section: 0), animated: false, scrollPosition: .none)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
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
            driverLabel.isHidden = hidden
            infoAndButtonStack.isHidden = hidden
            tableView.isHidden = hidden
            nextStopFooter.isHidden = hidden
            
            refreshDriverIndexUI() // must also do this to account for multiple drivers
        }
        
        if animated {
            UIView.animate(withDuration: 1, animations: show)
        } else {
            show()
        }
        
        if hidden {
            nextDestinationLabel.text = "Route"
        } else {
            nextDestinationLabel.text = "Next Stop"
        }
    }
    
    func setDistanceLabel(meters: Double) {
        let formatter = LengthFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumSignificantDigits = 3
        distanceRemainingLabel.text = formatter.string(fromMeters: meters) + " left"
    }
    
    func refreshDriverIndexUI() {
        if let num = driverNumber {
            driverLabel?.text = "Driver \(num)"
            nextStopFooter.isHidden = false
//            driverLabel.isHidden = false
//            nextDestStack.axis = .horizontal
//            nextDestStack.alignment = .firstBaseline
        } else {
//            driverLabel.isHidden = true
//            nextDestStack.axis = .vertical
//            nextDestStack.alignment = .leading
            driverLabel?.text = "Next stop"
            nextStopFooter.isHidden = true
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func startDirectionsPressed(_ sender: UIButton) {
        PathFinder.shared.destinationCollection[selectedStopIndex].openInMaps(launchOptions: nil)
    }
    
    @IBAction func closePressed(_ sender: Any) {
        self.delegate.showPinAnnotations()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: true)
        DispatchQueue.main.async {
            var rowsToUpdate: [IndexPath] = []
            if self.selectedStopIndex < indexPath.row {
                rowsToUpdate = (self.selectedStopIndex...indexPath.row).map {
                    IndexPath(row: $0, section: 0)
                }
            } else {
                rowsToUpdate = (indexPath.row...self.selectedStopIndex).map {
                    IndexPath(row: $0, section: 0)
                }
            }
            self.selectedStopIndex = indexPath.row
            tableView.selectRow(at: IndexPath(row: self.selectedStopIndex, section: 0), animated: true, scrollPosition: .middle)
            tableView.reloadRows(at: rowsToUpdate, with: .none)
            
            let selectedMapItem = PathFinder.shared.destinationCollection[ indexPath.row]
            
            UIView.transition(with: self.view, duration: 0.2, options: [.curveEaseInOut, .transitionCrossDissolve], animations: {
                self.nextDestinationLabel.text = selectedMapItem.name ?? selectedMapItem.placemark.subtitle ?? "\(selectedMapItem.placemark.coordinate.latitude), \(selectedMapItem.placemark.coordinate.longitude)"
                
                let stopsRemaining = PathFinder.shared.destinationCollection.count - indexPath.row
                self.stopsRemainingLabel.text = "\(stopsRemaining)"
                if stopsRemaining == 1 {
                    self.stopsRemainingLabel.text! += " stop remaining"
                } else {
                    self.stopsRemainingLabel.text! += " stops remaining"
                }
                
                let distanceRemaining = PathFinder.shared.destinationCollection.distanceAfterCheckpoint(startIndex: indexPath.row - 1)
                self.setDistanceLabel(meters: distanceRemaining)

            }, completion: nil)
        }
    }
    
    // MARK: - Table View Datasource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return optimalRouteArray?.count ?? 0
//        return PathFinder.shared.destinationCollection.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let optimalRouteArray = optimalRouteArray else {
            fatalError("should not be loading cells when no route defined")
        }
        if let cell = tableView.dequeueReusableCell(withIdentifier: CELL_ID) as? RouteCell {
            let name = PathFinder.shared.destinationCollection[optimalRouteArray[indexPath.row]].name ?? ""
            var dist: Double? = nil
            
            // first-cell exclusive behavior
            if indexPath.row != 0 {
                dist = PathFinder.shared.destinationCollection.getDistance(between: optimalRouteArray[indexPath.row - 1],
                                     and: optimalRouteArray[indexPath.row])
            }
            cell.isUserInteractionEnabled = indexPath.row != 0
            
            if indexPath.row == 0 {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: nil, sequenceType: .Start)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex != indexPath.row {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .End)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex == indexPath.row {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .NextIsEndTarget)
            } else if indexPath.row == selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .NextNonEndTarget)
            } else if indexPath.row > selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .Incomplete)
            } else if indexPath.row < selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .Complete)
            }

            return cell
        } else {
            fatalError("unable to deque route cell")
        }
    }
    
    // MARK: - User Progress Tracking
    
    @objc func willEnterForeground() {
        // check that we are closer to the current destination than the previous checkpoint. if so, move on to the next index
        // only if we have more destinations to reach
        if selectedStopIndex < PathFinder.shared.destinationCollection.count - 1 {
            print("awaiting loc update to check if we arrived")
            PathFinder.shared.awaitLocationUpdate { currentCoord in
                print("comparing cur to next destination!!!")
                let lastCoord = PathFinder.shared.destinationCollection[self.selectedStopIndex - 1].placemark.coordinate
                let nextCoord = PathFinder.shared.destinationCollection[self.selectedStopIndex].placemark.coordinate
                
                var distToLast = pow(lastCoord.latitude - currentCoord.latitude, 2)
                distToLast += pow(lastCoord.longitude - currentCoord.longitude, 2)
                
                var distToNext = pow(nextCoord.latitude - currentCoord.latitude, 2)
                distToNext += pow(nextCoord.longitude - currentCoord.longitude, 2)
                if distToLast > distToNext {
                    DispatchQueue.main.async {
                        self.tableView(self.tableView, didSelectRowAt: IndexPath(row: self.selectedStopIndex + 1, section: 0))
                    }
                } else {
                    print("closer to last dest than current")
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
