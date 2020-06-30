//
//  RouteConfigController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 6/24/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class RouteConfigController: UIViewController {
    
    @IBOutlet weak var placeholderSquareView: UIView!
    @IBOutlet weak var routeInfoStack: UIStackView!
    @IBOutlet weak var computeButton: UIButton!
    
    @IBOutlet weak var stepperStackview: UIStackView!
    @IBOutlet weak var stepperSeparator: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.backgroundColor = .white
        
        computeButton.layer.cornerRadius = 10
        computeButton.layer.masksToBounds = true
        
        placeholderSquareView.isHidden = true
        
        let preview = MSTPreview(
            frame: .init(x: 0, y: 0, width: 64, height: 64),
            coordinates: PathFinder.shared.destinations.map { $0.placemark.coordinate })
        preview.addConstraints([
            preview.heightAnchor.constraint(equalToConstant: 64),
            preview.widthAnchor.constraint(equalToConstant: 64)
        ])
        
        preview.backgroundColor = placeholderSquareView.backgroundColor
        routeInfoStack.insertArrangedSubview(preview, at: 0)
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        setSingleTravelerMode(isSingle: sender.selectedSegmentIndex == 0)
    }
    
    func setSingleTravelerMode(isSingle: Bool) {
        if isSingle {
            
        } else {
            
        }
    }
    
    
}
