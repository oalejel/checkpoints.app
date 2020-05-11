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
//    @IBOutlet weak var searchBar: UISearchBar!
    
    weak var delegate: DetailHeaderViewDelegate?
//    weak var searchBarDelegate: UISearchBarDelegate?

    override func willMove(toSuperview newSuperview: UIView?) {
        peopleButton.backgroundColor = UIColor(white: 0.9, alpha: 1)
        peopleButton.tintColor = .black
        peopleButton.layer.cornerRadius = 35/2
//        peopleButton.contentHorizontalAlignment = .fill
//        peopleButton.contentVerticalAlignment =  .fill
    }
    
}
