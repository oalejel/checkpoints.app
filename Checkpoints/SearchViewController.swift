//
//  SearchViewController.swift
//  OverlayContainer_Example
//
//  Created by Gaétan Zanella on 29/11/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewControllerDidSelectRow(_ searchViewController: SearchViewController)
    func searchViewControllerDidSelectCloseAction(_ searchViewController: SearchViewController)
    func searchViewControllerDidSearchString(_ string: String)
}

class SearchViewController: UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchBarDelegate,
    DetailHeaderViewDelegate {
    
    var searchResults = [MKMapItem]()
    var selectedMapItem: MKMapItem?
    weak var delegate: SearchViewControllerDelegate?
    var overlayContainerDelegate: OverlayContainerDelegate?

    private(set) lazy var header = Bundle.main.loadNibNamed("DetailHeaderView", owner: self, options: nil)![0] as! DetailHeaderView
    private(set) lazy var tableView = UITableView()

    // MARK: - Life Cycle

    init(showsCloseAction: Bool) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UIViewController

    override func loadView() {
        view = UIView()
        setUpView()
        title = "Search" // remove unless we need this or a full-screen view controller
        header.searchBar.delegate = self
        header.checkpointCountButton.isHidden = true // hide count when we havent added anything
    }
    
    func endEditing() {
        header.searchBar.resignFirstResponder()
    }
    
    func refreshSearchResults(_ mapItems: [MKMapItem]) {
        searchResults = mapItems
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mapItem = searchResults[indexPath.row]
        
        let cell = (tableView.dequeueReusableCell(withIdentifier: "cell") ?? LocationCell(style: .default, reuseIdentifier: "cell")) as! LocationCell
        cell.locationNameLabel.text = mapItem.name ?? "unkown name"
        cell.locationDetailLabel.text = mapItem.placemark.locality ?? "Locality"
        cell.backgroundColor = UIColor.init(white: 0.95, alpha: 1)
//        cell.locationNameLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        if #available(iOS 13.0, *) {
//            cell.locationDetailLabel.text = mapItem.pointOfInterestCategory?.rawValue ?? "Not a POI"
        } else {
            // Fallback on earlier versions
            
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        if searchResults.count == 0 {
//            UIView.animate(withDuration: 0.5) { // hide the table
//                self.tableView.isHidden = true
//            }
//        } else {
//            if self.tableView.isHidden { // show table view if it was hidden
//                UIView.animate(withDuration: 0.5) {
//                    self.tableView.isHidden = false
//                }
//            }
//        }
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedMapItem = searchResults[indexPath.row]
        delegate?.searchViewControllerDidSelectRow(self)
    }
    
    // MARK: - Custom Search Bar Behavior
    
//    func didStartSearch() {
//
//    }
//
//    func didEndSearch() {
//
//    }
//
//    func didChangeSearch() {
//
//    }
    
    // MARK: - SearchBarDelegate
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
//        containedViewDelegate?.shouldExpandOverlay()
        overlayContainerDelegate?.expandOverlay()
        if let searchString = searchBar.text {
            delegate?.searchViewControllerDidSearchString(searchString)
        }
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.resignFirstResponder()
//        searchResults.removeAll()
//        tableView.reloadData()
        return true
    }

//    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
//
//    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count != 0 {
            delegate?.searchViewControllerDidSearchString(searchText)
        } else {
            searchResults.removeAll()
            tableView.reloadData()
        }

    }

//    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
//        return true
//    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { // when search button in keyboard is pressed
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - DetailHeaderViewDelegate

//    func detailHeaderViewDidSelectCloseAction(_ headerView: DetailHeaderView) {
//        delegate?.searchViewControllerDidSelectCloseAction(self)
//    }

    // MARK: - Private

    private func setUpView() {
        header.delegate = self
        
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        
        view.backgroundColor = UIColor.init(white: 0.95, alpha: 1)
        view.addSubview(tableView)
        view.addSubview(header)
//        header.heightAnchor.constraint(equalToConstant: 70).isActive = true
        header.pinToSuperview(edges: [.left, .right])
        if #available(iOS 11.0, *) {
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            header.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor).isActive = true
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.pinToSuperview(edges: [.left, .right, .bottom])
        tableView.topAnchor.constraint(equalTo: header.bottomAnchor).isActive = true
        tableView.backgroundColor = .clear
        tableView.register(UINib(nibName: "LocationCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
}
