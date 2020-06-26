//
//  CheckpointCell.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/26/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class CheckpointCell: UITableViewCell {

    @IBOutlet weak var checkpointNameLabel: UILabel!
    @IBOutlet weak var checkpointDetailLabel: UILabel!
    @IBOutlet weak var isStartLocationLabel: UILabel!
    
    @IBOutlet weak var accentView: UIView!
    
    var isStartLocation = false {
        didSet {
            isStartLocationLabel.isHidden = !isStartLocation
        }
    }
    
    var isCurrentLocation = false {
        didSet {
            if isCurrentLocation { // replace current string
                
                let imageAttachment = NSTextAttachment()
                if #available(iOS 13.0, *) {
                    imageAttachment.image = UIImage(systemName: "location.fill")?.withTintColor(.systemBlue)
                    let fullString = NSMutableAttributedString(attachment: imageAttachment)
                    fullString.append(NSAttributedString(string: checkpointNameLabel.text ?? ""))
                    checkpointNameLabel.attributedText = fullString
                } else {
                    // Fallback on earlier versions
                    // keep string as is if no sfsymbols
                }

                checkpointNameLabel.textColor = .systemBlue
            } else {
                checkpointNameLabel.textColor = .black
            }
        }
    }
        
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        backgroundColor = UIColor(white: 0.95, alpha: 1)
        isStartLocationLabel.isHidden = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
