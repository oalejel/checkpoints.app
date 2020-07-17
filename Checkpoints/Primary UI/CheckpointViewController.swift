//
//  CheckpointViewController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/16/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit
import MapKit
import Contacts

//protocol CheckpointViewControllerDelegate {
//    func addCheckpointToPath(mapItem: MKMapItem)
//    func focusOnMapItem(_ mapItem: MKMapItem)
//}

class CheckpointViewController: UIViewController {
    
    var scrollView = UIScrollView()
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var mapFocusButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var makeStartButton: UIButton!
    
    @IBOutlet weak var existingCheckpointButtonsStack: UIStackView!
    
    var mapItem: MKMapItem
    var checkpointAlreadyAdded: Bool
    
    var delegate: LocationsDelegate? {
        didSet {
            updateSetStartButton()
        }
    }
    
    init(mapItem: MKMapItem, alreadyAdded: Bool) {
        self.mapItem = mapItem
        self.checkpointAlreadyAdded = alreadyAdded
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.layer.cornerRadius = 26
        view.layer.masksToBounds = true

//        closeButton.backgroundColor = .lightGray
//        closeButton.layer.cornerRadius = 15
//        closeButton.layer.masksToBounds = true
        
        let dist = PathFinder.shared.calculateDistanceFromCoordinate(coord: mapItem.placemark.coordinate) / 1609.34
        if dist < 11 {
            distanceLabel.text = String(format: "About %.1f mi from current location", dist)
        } else {
            distanceLabel.text = "About \(Int(dist)) mi from current location"
        }
        
        addButton.layer.cornerRadius = 8
        addButton.layer.masksToBounds = true
        removeButton.layer.cornerRadius = 8
        removeButton.layer.masksToBounds = true
        makeStartButton.layer.masksToBounds = true
        makeStartButton.layer.cornerRadius = 8
        
        nameLabel.text = mapItem.name ?? mapItem.placemark.subLocality ?? mapItem.placemark.locality ?? "Lat: \(mapItem.placemark.coordinate.latitude), Lon: \(mapItem.placemark.coordinate.longitude)"
        
        if let postal = mapItem.placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            addressLabel.text = formatter.string(from: postal)
        } else {
            addressLabel.text = "\(mapItem.placemark.coordinate)"
        }
        
        if checkpointAlreadyAdded {
            addButton.isHidden = true
            existingCheckpointButtonsStack.isHidden = false
        } else {
            addButton.isHidden = false
            existingCheckpointButtonsStack.isHidden = true
        }

        updateSetStartButton()
    }
    
    func updateSetStartButton() {
        if delegate?.isStart(mapItem: mapItem) ?? false {
            makeStartButton?.isEnabled = true
            makeStartButton?.isHidden = true
        }
    }

    @IBAction func closePressed(_ sender: UIButton) {
        delegate?.shouldEndCheckpointPreview()
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func addCheckpointPressed(_ sender: UIButton) {
        delegate?.addCheckpointToPath(mapItem: mapItem, focus: true)
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func focusPressed(_ sender: Any) {
        delegate?.focusOnMapItem(mapItem)
    }
    
    @IBAction func removeCheckpointPressed(_ sender: UIButton) {
        delegate?.removeCheckpointFromPath(mapItem: mapItem)
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func makeStartPressed(_ sender: Any) {
        delegate?.makeStart(mapItem: mapItem)
        UIView.animate(withDuration: 0.2) {
            self.makeStartButton.isHidden = true
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
