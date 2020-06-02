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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
