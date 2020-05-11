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
    func searchViewControllerDidSelectARow(_ searchViewController: SearchViewController)
    func searchViewControllerDidSelectCloseAction(_ searchViewController: SearchViewController)
}

class SearchViewController: UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchBarDelegate,
    DetailHeaderViewDelegate {
    
    var searchResults = [CLLocation]()

    weak var delegate: SearchViewControllerDelegate?

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
        title = "Search"
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = "Row \(indexPath.row)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.searchViewControllerDidSelectARow(self)
    }
    
    // MARK: - SearchBarDelegate
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
//        containedViewDelegate?.shouldExpandOverlay()
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
    }

    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
        
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        
    }

    // MARK: - DetailHeaderViewDelegate

//    func detailHeaderViewDidSelectCloseAction(_ headerView: DetailHeaderView) {
//        delegate?.searchViewControllerDidSelectCloseAction(self)
//    }

    // MARK: - Private

    private func setUpView() {
        header.delegate = self
        header.searchBarDelegate = self
        
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        
        view.backgroundColor = .white
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
        tableView.pinToSuperview(edges: [.left, .right, .bottom])
        tableView.topAnchor.constraint(equalTo: header.bottomAnchor).isActive = true
        tableView.backgroundColor = .clear
        tableView.delegate = self
    }
}
