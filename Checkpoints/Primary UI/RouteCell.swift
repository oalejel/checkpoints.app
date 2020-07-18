//
//  RouteCell.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 7/16/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class RouteCell: UITableViewCell {

    @IBOutlet weak var indexButton: UIButton!
    @IBOutlet weak var distanceButton: UIButton!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var topIndexBar: UIView!
    @IBOutlet weak var bottomIndexBar: UIView!
    @IBOutlet weak var topDistanceBar: UIView!
    @IBOutlet weak var bottomDistanceBar: UIView!
    
    var distanceInMeters: Double? = 0.0
    
    enum RouteSequenceType {
        case Start, Complete, NextNonEndTarget, Incomplete, End, NextIsEndTarget
        // specify whether the cell is for a start, completed intermediate, next stage, or incomplete intermediate checkpoint
    }
    
    private var sequenceType: RouteSequenceType = .Start {
        didSet {
            // location labels
            
            switch sequenceType {
            case .Complete, .Start:
                locationLabel.textColor = .gray
                locationLabel.font = UIFont.systemFont(ofSize: locationLabel.font.pointSize, weight: .regular)
            case .NextIsEndTarget, .NextNonEndTarget:
                locationLabel.textColor = .systemBlue
                locationLabel.font = UIFont.systemFont(ofSize: locationLabel.font.pointSize, weight: .medium)
            default:
                locationLabel.textColor = .black
                locationLabel.font = UIFont.systemFont(ofSize: locationLabel.font.pointSize, weight: .regular)

            }
                        
            // index buttons
            switch sequenceType {
            case .Start, .Complete:
                indexButton.backgroundColor = .systemBlue
                indexButton.layer.borderColor = UIColor.systemBlue.cgColor
                indexButton.layer.borderWidth = 2
                indexButton.setTitleColor(.white, for: .normal)
            case .NextNonEndTarget, .NextIsEndTarget:
                indexButton.backgroundColor = .white
                indexButton.layer.borderColor = UIColor.systemBlue.cgColor
                indexButton.layer.borderWidth = 2
                indexButton.setTitleColor(.systemBlue, for: .normal)
            default:
                indexButton.backgroundColor = UIColor(white: 0.85, alpha: 1)
                indexButton.layer.borderWidth = 0
                indexButton.setTitleColor(.gray, for: .normal)
            }
            
            // top and bottom bars
            switch sequenceType {
            case .Start: // hide top
                topIndexBar.isHidden = true
                topDistanceBar.isHidden = true
                bottomIndexBar.isHidden = false
                bottomDistanceBar.isHidden = false
            case .Complete: // show all
                topIndexBar.isHidden = false
                topDistanceBar.isHidden = false
                bottomIndexBar.isHidden = false
                bottomDistanceBar.isHidden = false
            case .NextIsEndTarget: // hide bottom
                topIndexBar.isHidden = false
                topDistanceBar.isHidden = false
                bottomIndexBar.isHidden = true
                bottomDistanceBar.isHidden = true
            case .NextNonEndTarget: // only hide index bottom
                topIndexBar.isHidden = false
                topDistanceBar.isHidden = false
                bottomIndexBar.isHidden = true
                bottomDistanceBar.isHidden = false
            case .Incomplete: // only connect distance top and bottom
                topIndexBar.isHidden = true
                topDistanceBar.isHidden = false
                bottomIndexBar.isHidden = true
                bottomDistanceBar.isHidden = false
            case .End: // only connect top distance
                topIndexBar.isHidden = true
                topDistanceBar.isHidden = false
                bottomIndexBar.isHidden = true
                bottomDistanceBar.isHidden = true
            }
                        
            // distance label contents
            if sequenceType == .Start {
                distanceButton.setTitle("Start", for: .normal)
            } else {
                let formatter = LengthFormatter()
                formatter.unitStyle = .medium
                formatter.numberFormatter.maximumSignificantDigits = 3
                let distanceString = formatter.string(fromMeters: distanceInMeters ?? 0)
                distanceButton.setTitle(distanceString, for: .normal)
            }
            
            self.locationLabel.text = String(describing: sequenceType)
        }
    }
    
    func setDistance(index: Int, title: String, distanceInMeters: Double?, sequenceType: RouteSequenceType) {
        self.distanceInMeters = distanceInMeters
        self.sequenceType = sequenceType
        self.indexButton.setTitle("\(index + 1)", for: .normal) // let's use 1-indexing
        self.locationLabel.text = title
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        distanceButton.isUserInteractionEnabled = false
        distanceButton.contentEdgeInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
        distanceButton.layer.cornerRadius = 4
        indexButton.isUserInteractionEnabled = false
        indexButton.titleLabel?.adjustsFontSizeToFitWidth = true
        
        clipsToBounds = true
    }
    
    var didLayout = false
    override func layoutSubviews() {
        super.layoutSubviews()
        if !didLayout {
            didLayout = true
            indexButton.layer.cornerRadius = indexButton.frame.size.width / 2
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
