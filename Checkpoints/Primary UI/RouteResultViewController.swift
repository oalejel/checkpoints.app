//
//  RouteResultViewController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class RouteResultViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

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
    
    @IBOutlet weak var nextDestStack: UIStackView!
    var driverNumber: Int? {
        didSet {
            refreshDriverIndexUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        PathFinder.shared.computeIndividualOptimalPath { routeArray in
            print("GOT OUTPUT: ")
            print(routeArray)
        }
        
        view.layer.cornerRadius = 26
        view.layer.masksToBounds = true

        // prepare initial contents
        refreshDriverIndexUI()
        
        startDirectionsButton.layer.cornerRadius = 10
        
        stopsRemainingLabel.text = "\(PathFinder.shared.destinationCollection.count - 2) stops remaining" // TODO: assume that 2 of the destinations include start and end?
        let remainingMeters = PathFinder.shared.destinationCollection.totalDistanceAfterCheckpoint(startIndex: 0)
        setDistanceLabel(meters: remainingMeters)
        
        // NOTE: distance remaining may be based on a reordering of the path, as the user is allowed to change the sequence of directions
        // TODO: support cancelling the computation operation with user intervention with the x button
        
        // Table view setup
        tableView.register(UINib(nibName: "RouteCell", bundle: nil), forCellReuseIdentifier: CELL_ID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = .always
        
//        tableView.selectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: false, scrollPosition: .none)
        tableView.separatorStyle = .none
    }
    
    
    
    
    // MARK: - UI Helpers
    
    func setDistanceLabel(meters: Double) {
        let formatter = LengthFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumSignificantDigits = 3
        distanceRemainingLabel.text = formatter.string(fromMeters: meters) + " total"

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
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: true)
        var rowsToUpdate: [IndexPath] = []
        if selectedStopIndex < indexPath.row {
            rowsToUpdate = (selectedStopIndex...indexPath.row).map {
                IndexPath(row: $0, section: 0)
            }
        } else {
            rowsToUpdate = (indexPath.row...selectedStopIndex).map {
                IndexPath(row: $0, section: 0)
            }
        }
        selectedStopIndex = indexPath.row
        tableView.selectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: true, scrollPosition: .middle)
        tableView.reloadRows(at: rowsToUpdate, with: .automatic)
        
        let selectedMapItem = PathFinder.shared.destinationCollection[indexPath.row]
        UIView.animate(withDuration: 0.2, delay: 0, options: .transitionCrossDissolve, animations: {
            self.nextDestinationLabel.text = selectedMapItem.name ?? selectedMapItem.placemark.subtitle ?? "\(selectedMapItem.placemark.coordinate.latitude), \(selectedMapItem.placemark.coordinate.longitude)"
            self.stopsRemainingLabel.text = "\(PathFinder.shared.destinationCollection.count - indexPath.row) stops remaining"
            let distanceRemaining = PathFinder.shared.destinationCollection.totalDistanceAfterCheckpoint(startIndex: indexPath.row)
            self.setDistanceLabel(meters: distanceRemaining)
        }, completion: nil)
    }
    
    // MARK: - Table View Datasource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PathFinder.shared.destinationCollection.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: CELL_ID) as? RouteCell {
            let xyz = PathFinder.shared.destinationCollection[indexPath.row].name ?? ""
            var dist: Double? = nil
            
            // first-cell exclusive behavior
            if indexPath.row != 0 {
                dist = PathFinder.shared.destinationCollection.getDistance(between: indexPath.row - 1, and: indexPath.row)
            }
            cell.isUserInteractionEnabled = indexPath.row != 0
            
            if indexPath.row == 0 {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: nil, sequenceType: .Start)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex != indexPath.row {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: dist!, sequenceType: .End)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex == indexPath.row {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: dist!, sequenceType: .NextIsEndTarget)
            } else if indexPath.row == selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: dist!, sequenceType: .NextNonEndTarget)
            } else if indexPath.row > selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: dist!, sequenceType: .Incomplete)
            } else if indexPath.row < selectedStopIndex {
                cell.setDistance(index: indexPath.row, title: xyz, distanceInMeters: dist!, sequenceType: .Complete)
            }

            return cell
        } else {
            fatalError("unable to deque route cell")
        }
    }

}
