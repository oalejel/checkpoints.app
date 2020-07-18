//
//  RouteConfigController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 6/24/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

protocol RouteConfigDelegate {
    func cancellingRouteConfiguration() // good in case we want to modify map
    func previewMST()
}

class RouteConfigController: UIViewController, StatefulViewController {
    
    @IBOutlet weak var placeholderSquareView: UIView!
    @IBOutlet weak var routeInfoStack: UIStackView!
    @IBOutlet weak var computeButton: UIButton!
    
    @IBOutlet weak var mainStackview: UIStackView!
    
    @IBOutlet weak var stepperStackview: UIStackView!
    @IBOutlet weak var stepperSeparator: UIView!
    
    @IBOutlet weak var stepper: UIStepper!
    @IBOutlet weak var travelerCountLabel: UILabel!
    
    @IBOutlet weak var checkpointCountLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    var distanceLowerBound = 0.0 // distance in MST, used as an estimate for now
    var numTravelers = 1
    
    var delegate: RouteConfigDelegate?
    var heightDelegate: HeightAdjustmentDelegate?
    
    init(delegate: RouteConfigDelegate?) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    var startStackHeight: CGFloat = 0
    var largeHeight: CGFloat = 0
    var smallHeight: CGFloat = 0
    
    func getUserState() -> UserState {
        return .Routing([smallHeight, largeHeight])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredContentSize = self.view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )

        // Do any additional setup after loading the view.
        view.layer.cornerRadius = 26
        view.layer.masksToBounds = true
        view.backgroundColor = .white
        
        computeButton.layer.cornerRadius = 10
        computeButton.layer.masksToBounds = true
        
        placeholderSquareView.isHidden = true
        
        let preview = MSTPreview(
            frame: .init(x: 0, y: 0, width: 64, height: 64),
            coordinates: PathFinder.shared.destinationCollection.unsortedDestinations.map { $0.placemark.coordinate })
        preview.addConstraints([
            preview.heightAnchor.constraint(equalToConstant: 64),
            preview.widthAnchor.constraint(equalToConstant: 64)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedPreview))
        preview.addGestureRecognizer(tapGesture)
        
        preview.backgroundColor = placeholderSquareView.backgroundColor
        routeInfoStack.insertArrangedSubview(preview, at: 0)
        
        stepper.value = 2
        stepper.minimumValue = 2
        stepper.maximumValue = Double(PathFinder.shared.destinationCollection.count) // cant have more people than destinations
        self.stepperStackview.isHidden = true
        self.stepperSeparator.isHidden = true
        
        checkpointCountLabel.text = "\(PathFinder.shared.destinationCollection.count) checkpoints"
        
        for i in 0..<preview.parentIndices.count {
            distanceLowerBound += PathFinder.shared.threadSafeDistanceForUserIndices(i, preview.parentIndices[i])
        }
        // travel distance estimate is more realistic if we add
        // in the longest length a second time
        distanceLowerBound += PathFinder.shared.longestCheckpointDistance()
        
        startStackHeight = self.mainStackview.frame.size.height
    }
    
    var didLayout = false
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !didLayout {
            didLayout = true
            setSingleTravelerMode(isSingle: true)
        }
    }
    
    // MARK: - UI Helpers

    func updateTravelersDistanceText() {
        travelerCountLabel.text = "\(numTravelers) travelers"
        
        let formatter = LengthFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumSignificantDigits = 3

        if numTravelers == 1 {
            let distance = formatter.string(fromMeters: distanceLowerBound)
            distanceLabel.text = "\(distance) minimum"
        } else {
            // simple estimate by dividing number of travelers,
            // but not if they exceed number of destinations!
            let bestDivision = distanceLowerBound / Double(min(numTravelers, PathFinder.shared.destinationCollection.count))
            let distance = formatter.string(fromMeters: bestDivision)
            distanceLabel.text = "\(distance) minimum each"
        }
    }
    
    func setSingleTravelerMode(isSingle: Bool) {
        let start = mainStackview.frame.size.height

        if isSingle {
            // leave stepper with stale value, but update numTravelers
            numTravelers = 1
            updateTravelersDistanceText()
            UIView.animate(withDuration: 0.2) { // hide quickly
                self.stepper.alpha = 0
            }
        } else {
            // reset stepper
            numTravelers = 2
            stepper.value = 2
            
            // update labels
            updateTravelersDistanceText()
            
            // animate in
            UIView.animate(withDuration: 0.5, delay: 0.3, options: .curveEaseIn, animations: {
                self.stepper.alpha = 1
            }, completion: nil)
        }

        // always a half second animation for other components
        UIView.animate(withDuration: 0.5) {
            if isSingle {
                self.stepperStackview.isHidden = true
                self.stepperSeparator.isHidden = true
            } else {
                self.stepperStackview.isHidden = false
                self.stepperSeparator.isHidden = false
            }
        }
        
        let end = mainStackview.frame.size.height
        if start > end { // shrinking
            heightDelegate?.didChangeHeightState(state: .Routing([smallHeight])) //view.bounds.height - (start - end))
        } else if start == end { // small hack for first time this happens, where we need to adjust for the height
            print(view.frame.size.height)
            smallHeight = view.bounds.height - (startStackHeight - mainStackview.frame.size.height)
            largeHeight = view.bounds.height
            heightDelegate?.didChangeHeightState(state: .Routing([smallHeight]))
        } else {
            heightDelegate?.didChangeHeightState(state: .Routing([largeHeight])) //view.bounds.height - (start - end) - permanentViewOffset)
        }

    }
    
    // MARK: - IBActions and Callbacks
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        setSingleTravelerMode(isSingle: sender.selectedSegmentIndex == 0)
    }
    
    @IBAction func closePressed(_ sender: CloseButton) {
        delegate?.cancellingRouteConfiguration()
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func computePressed(_ sender: Any) {
        let passedOnState = UserState.Routing([smallHeight, UIScreen.main.bounds.height * 0.75])
        let rrvc = RouteResultViewController(state: passedOnState)
        navigationController?.pushViewController(rrvc, animated: true)
        heightDelegate?.didChangeHeightState(state: passedOnState)
    }
        
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        numTravelers = Int(sender.value)
        updateTravelersDistanceText()
    }
    
    @objc func tappedPreview() {
        delegate?.previewMST()
    }
}
