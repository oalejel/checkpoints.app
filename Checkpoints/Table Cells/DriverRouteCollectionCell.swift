//
//  DriverRouteCollectionCell.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 8/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class DriverRouteCollectionCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    let CELL_ID = "DRIVER_CELL"
    
    var pathIndices: [Int]? {
        didSet {
            guard pathIndices != nil else { return }
            
            var pathLength = 0.0
            for indexIndex in 0..<pathIndices!.count {
                let loc1 = pathIndices![indexIndex]
                let loc2 = pathIndices![(indexIndex + 1) % pathIndices!.count] // wrap back around to start on last iteration
                pathLength += PathFinder.shared.destinationCollection.getDistance(between: loc1, and: loc2)
            }
                        
            let formatter = LengthFormatter()
            formatter.unitStyle = .medium
            formatter.numberFormatter.maximumSignificantDigits = 3

            let localizedDistString = formatter.string(fromMeters: pathLength)
            if pathIndices!.count == 2 {
                detailLabel.text = "1 stop, \(localizedDistString)"
            } else {
                detailLabel.text = "\(pathIndices!.count) stops, \(localizedDistString)"
            }
            
            tableView.reloadData()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        tableView.register(UINib(nibName: "RouteCell", bundle: nil), forCellReuseIdentifier: CELL_ID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pathIndices?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let pathIndices = pathIndices else {
            fatalError("reloading table on nil data")
        }
        if let cell = tableView.dequeueReusableCell(withIdentifier: CELL_ID) as? RouteCell {
            cell.isUserInteractionEnabled = false
            
            let mapItemIndex = pathIndices[indexPath.row]
            let item = PathFinder.shared.destinationCollection[mapItemIndex]
            let name = item.name ?? ""
            cell.distanceInMeters = 99
            cell.indexButton.setTitle("\(indexPath.row + 1)", for: .normal) // let's use 1-indexing
            cell.locationLabel.text = item.name ?? "place name"

            var dist: Double? = nil
            if indexPath.row != 0 {
                dist = PathFinder.shared.destinationCollection.getDistance(between: pathIndices[indexPath.row - 1],
                                     and: pathIndices[indexPath.row])
            }
            
            if indexPath.row == 0 {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: nil, sequenceType: .Start, hideSelection: true)
            } else if indexPath.row == pathIndices.count - 1 {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .End, hideSelection: true)
            } else {
                cell.setDistance(index: indexPath.row, title: name, distanceInMeters: dist!, sequenceType: .Incomplete, hideSelection: true)
            }
            cell.backgroundColor = backgroundColor
            
            return cell
        } else {
            fatalError("unable to deque route cell")
        }
        
    }

}
