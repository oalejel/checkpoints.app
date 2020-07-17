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
        
        let formatter = LengthFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumSignificantDigits = 3
        let remainingMeters = PathFinder.shared.destinationCollection.totalDistanceAfterCheckpoint(startIndex: 0)
        stopsRemainingLabel.text = "\(PathFinder.shared.destinationCollection.count - 2) stops remaining" // TODO: assume that 2 of the destinations include start and end?
        distanceRemainingLabel.text = formatter.string(fromMeters: remainingMeters) + " total"
        
        // NOTE: distance remaining may be based on a reordering of the path, as the user is allowed to change the sequence of directions
        // TODO: support cancelling the computation operation with user intervention with the x button
        
        // Table view setup
        tableView.register(UINib(nibName: "RouteCell", bundle: nil), forCellReuseIdentifier: CELL_ID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: false, scrollPosition: .none)
        tableView.separatorStyle = .none
    }
    
    
    // MARK: - UI Helpers
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
        PathFinder.shared.destinationCollection[0].openInMaps(launchOptions: nil)
    }
    
    @IBAction func closePressed(_ sender: Any) {
        
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: true)
        selectedStopIndex = indexPath.row
        tableView.selectRow(at: IndexPath(row: selectedStopIndex, section: 0), animated: true, scrollPosition: .middle)
    }
    
    // MARK: - Table View Datasource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PathFinder.shared.destinationCollection.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: CELL_ID) as? RouteCell {
            if indexPath.row == 0 {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .Start)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex != indexPath.row {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .End)
            } else if indexPath.row == PathFinder.shared.destinationCollection.count - 1 && selectedStopIndex == indexPath.row {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .NextIsEndTarget)
            } else if indexPath.row == selectedStopIndex {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .NextNonEndTarget)
            } else if indexPath.row > selectedStopIndex {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .Incomplete)
            } else if indexPath.row < selectedStopIndex {
                cell.setDistance(distanceInMeters: 12.1, sequenceType: .Complete)
            }

            return cell
        } else {
            fatalError("unable to deque route cell")
        }
    }

}
