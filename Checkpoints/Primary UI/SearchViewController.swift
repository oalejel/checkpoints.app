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
    func routePressed()
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
    }
    
    private func setUpView() {
        title = "Search" // remove unless we need this or a full-screen view controller

        header.delegate = self
        header.searchBar.delegate = self
        header.routeButton.addTarget(self, action: #selector(routePressed), for: .touchUpInside)
//        header.checkpointCountButton.isHidden = true // hide count when we havent added anything
        
        view.layer.cornerRadius = 26
        view.layer.masksToBounds = true
        
        view.backgroundColor = UIColor(white: 0.95, alpha: 1)
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
        tableView.register(UINib(nibName: "LocationCell", bundle: nil), forCellReuseIdentifier: "locationCell")
        tableView.register(UINib(nibName: "CheckpointCell", bundle: nil), forCellReuseIdentifier: "checkpointCell")
        tableView.isEditing = false // CHANGE THIS LINE WHEN YOU WANT TO ALLOW REORDERING BY DEFAULT
        self.tableView.tableFooterView = UIView(frame: .zero)
    }
    
    @objc func routePressed() {
        delegate?.routePressed()
    }

    func endEditing() {
        header.searchBar.resignFirstResponder()
    }
    
    func clearEditing(refreshAddedCheckpoints: Bool) {
        header.searchBar.resignFirstResponder()
        header.searchBar.text = ""
        searchResults = []
        DispatchQueue.main.async {
            if refreshAddedCheckpoints {
                self.tableView.reloadData()
            } else { // only updating search results
                self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
            }
        }
    }
    
    func refreshSearchResults(_ mapItems: [MKMapItem]) {
        guard let text = header.searchBar.text, text.count > 0 else { // if old search result for an empty string
            DispatchQueue.main.async {
                self.searchResults = []
                self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
            }
            return
        }
        DispatchQueue.main.async {
            self.searchResults = mapItems
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return searchResults.isEmpty ? nil : "Search Results"
        } else {
            if PathFinder.shared.destinationCollection.isEmpty {
                return nil
            } else if PathFinder.shared.destinationCollection.count == 1 {
                return "1 checkpoint"
            } else {
                return "\(PathFinder.shared.destinationCollection.count) checkpoints"
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = (tableView.dequeueReusableCell(withIdentifier: "locationCell") ?? LocationCell(style: .default, reuseIdentifier: "locationCell")) as! LocationCell
            let mapItem = searchResults[indexPath.row]
            
            var locationString: String?
            var detailString: String?
            markPrimaryAndSecondaryLocationLabels(mapItem: mapItem, mainString: &locationString, detailString: &detailString)
            cell.locationNameLabel.text = locationString
            cell.locationDetailLabel.text = detailString
            
            cell.backgroundColor = UIColor.init(white: 0.95, alpha: 1)
    //        cell.locationNameLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            if #available(iOS 13.0, *) {
    //            cell.locationDetailLabel.text = mapItem.pointOfInterestCategory?.rawValue ?? "Not a POI"
            }
            return cell
        } else {
            let cell = (tableView.dequeueReusableCell(withIdentifier: "checkpointCell") ?? CheckpointCell(style: .default, reuseIdentifier: "checkpointCell")) as! CheckpointCell
            let mapItem = PathFinder.shared.destinationCollection[indexPath.row]
            
            var locationString: String?
            var detailString: String?
            markPrimaryAndSecondaryLocationLabels(mapItem: mapItem, mainString: &locationString, detailString: &detailString)
            cell.checkpointNameLabel.text = locationString!
            cell.checkpointDetailLabel.text = detailString!
            cell.isCurrentLocation = mapItem == PathFinder.shared.firstRecordedCurrentLocation
            cell.isStartLocation = mapItem == PathFinder.shared.startLocationItem
            assert(PathFinder.shared.startLocationItem != nil) // should not be nil as long as we have one checkpoint
            
//            print("> mapitem.name \(mapItem.name ?? "NIL")")
//            print("> mapitem.placemark \(String(describing: mapItem.placemark))")
//            print("> mapitem.placemark.title \(mapItem.placemark.title ?? "nil")")
////            print("> mapitem placemark sublocality \(mapItem.placemark.subLocality)")
//            print("> maptiem.placemark.locality \(mapItem.placemark.locality ?? "NIL")")
//            print("> maptiem.coordinate.latitude \(Double(mapItem.placemark.coordinate.latitude))")
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        assert(sourceIndexPath.section == 1)
        assert(destinationIndexPath.section == 1)
        PathFinder.shared.moveDestination(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }
    
    // MARK: - Helpers
    
    private func markPrimaryAndSecondaryLocationLabels(mapItem: MKMapItem, mainString: inout String?, detailString: inout String?) {
        if let a = mapItem.name {
            mainString = a
        } else if let b = mapItem.placemark.title {
            mainString = b
        } else if let c = mapItem.placemark.subtitle {
            mainString = c
        } else if let d = mapItem.placemark.locality {
            mainString = d
        } else {
            mainString = String(format: "Lat: %+.2f, Lon: %.2f", mapItem.placemark.coordinate.latitude, mapItem.placemark.coordinate.longitude)
            detailString = ""
        }
        
        if detailString == nil {
            if let b = mapItem.placemark.title {
                detailString = b
            } else if let c = mapItem.placemark.subtitle {
                detailString = c
            } else if let d = mapItem.placemark.locality {
                detailString = d
            } else {
                detailString = String(format: "Lat: %+.2f, Lon: %.2f", mapItem.placemark.coordinate.latitude, mapItem.placemark.coordinate.longitude)
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return searchResults.count
        }
        return PathFinder.shared.destinationCollection.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        header.searchBar.resignFirstResponder()
        // deal with searched or added checkpoints
        if indexPath.section == 0 {
            selectedMapItem = searchResults[indexPath.row]
            delegate?.searchViewControllerDidSelectRow(self)
            
        } else {
            if let _ = tableView.cellForRow(at: indexPath) as? CheckpointCell {
                // show checkpoint view controller without add button -> show remove button
                selectedMapItem = PathFinder.shared.destinationCollection[indexPath.row]
                delegate?.searchViewControllerDidSelectRow(self)
            } else {
                fatalError("unexpected cell class")
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        header.searchBar.resignFirstResponder()
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

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults.removeAll()
            tableView.reloadData()
        } else {
            delegate?.searchViewControllerDidSearchString(searchText)
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


    
    override func resignFirstResponder() -> Bool {
        print("resigning first responder")
        let resign = super.resignFirstResponder()
        return resign && header.searchBar.resignFirstResponder()
    }
}
