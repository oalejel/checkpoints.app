//
//  CheckpointViewController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/16/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit
import MapKit

protocol CheckpointViewControllerDelegate {
    func addCheckpointToPath(mapItem: MKMapItem)
}

class CheckpointViewController: UIViewController {
    
    var scrollView = UIScrollView()
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var mapFocusButton: UIButton!
    
    var mapItem: MKMapItem
    var delegate: CheckpointViewControllerDelegate?
    
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true

        closeButton.backgroundColor = .lightGray
        closeButton.layer.cornerRadius = 15
        closeButton.layer.masksToBounds = true
        
        addButton.layer.cornerRadius = 8
        addButton.layer.masksToBounds = true
        
        nameLabel.text = mapItem.name ?? mapItem.placemark.title ?? "other name"

    }

    @IBAction func closePressed(_ sender: UIButton) {
//        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func addCheckpointPressed(_ sender: UIButton) {
        delegate?.addCheckpointToPath(mapItem: mapItem)
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
