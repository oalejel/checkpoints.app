//
//  DetailHeaderView.swift
//  OverlayContainer_Example
//
//  Created by Gaétan Zanella on 30/11/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit

protocol DetailHeaderViewDelegate: AnyObject {
//    func detailHeaderViewDidSelectCloseAction(_ headerView: DetailHeaderView)
}

class DetailHeaderView: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var peopleButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var vstack: UIStackView!
    @IBOutlet weak var checkpointCountButton: UIButton!
    
    enum State {
        case Search, LocationPreview
    }
    
    var state: State = .Search
    weak var delegate: DetailHeaderViewDelegate?
    weak var searchBarDelegate: UISearchBarDelegate?

    override func willMove(toSuperview newSuperview: UIView?) {
        peopleButton.backgroundColor = UIColor(white: 0.9, alpha: 1)
        peopleButton.tintColor = .black
        peopleButton.layer.cornerRadius = 35/2
        searchBar.isUserInteractionEnabled = true
        
//        peopleButton.contentHorizontalAlignment = .fill
//        peopleButton.contentVerticalAlignment =  .fill
    }
    
    func previewLocation() {
//        if self.state == .Search { // modify UI
//            let label = UILabel()
//            label.text = labelText
//            let button = UIButton()
//            button.addTarget(self, action: #selector(exitContext), for: .touchUpInside)
//    //        button.backgroundColor = UIColor(white: 0.9, alpha: 1)
//            if #available(iOS 13.0, *) {
//                button.setImage(UIImage(systemName: "xmark"), for: .normal)
//            } else {
//                // Fallback on earlier versions
//            }
//            let hstack = UIStackView(arrangedSubviews: [
//                label, button
//            ])
//            vstack.insertArrangedSubview(hstack, at: 0)
//        } else {
//
//
//        }
//
//        //
    }
    
    // adds horizontal stack view with
    func insertExitableContextLabel(labelText: String) {
    }
    
    @objc func exitContext(button: UIButton) {
        
    }
    
}
