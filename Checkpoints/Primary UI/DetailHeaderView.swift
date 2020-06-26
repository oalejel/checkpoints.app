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
//    @IBOutlet weak var peopleButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var vstack: UIStackView!
//    @IBOutlet weak var checkpointCountButton: UIButton!
    @IBOutlet weak var routeButton: UIButton!
    
    enum State {
        case Search, LocationPreview
    }
    
    var state: State = .Search
    weak var delegate: DetailHeaderViewDelegate?
    weak var searchBarDelegate: UISearchBarDelegate?

    override func willMove(toSuperview newSuperview: UIView?) {
        searchBar.isUserInteractionEnabled = true
        
        routeButton.contentEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
        routeButton.layer.cornerRadius = 8
        routeButton.layer.masksToBounds = true
        routeButton.isHidden = true // hide til we have enough checkpoints
    }
            
}
