//
//  GroupResultsController.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 8/2/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import UIKit

class GroupResultsController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, StatefulViewController, UICollectionViewDelegateFlowLayout {
    
    var delegate: RouteConfigDelegate!
    var finishedComputation = false // track in case we need to unhide before view appears
    
    func getUserState() -> UserState {
        return .GroupRoutingPreview
    }
        
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var avgDistanceLabel: UILabel!
    @IBOutlet weak var maxDistanceLabel: UILabel!
    @IBOutlet weak var minDistanceLabel: UILabel!
    
    @IBOutlet weak var avgStopsLabel: UILabel!
    @IBOutlet weak var maxStopsLabel: UILabel!
    @IBOutlet weak var minStopsLabel: UILabel!
    
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var collectionView: UICollectionView!
    let CELL_ID = "driver_cell"
    
    var numDrivers = 0
    
    init(numDrivers: Int, delegate: RouteConfigDelegate) {
        super.init(nibName: nil, bundle: nil)
        self.numDrivers = numDrivers
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 26
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true

        shareButton.layer.cornerRadius = 8
        shareButton.layer.masksToBounds = true
        
        pageControl.numberOfPages = numDrivers
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "DriverRouteCollectionCell", bundle: nil), forCellWithReuseIdentifier: CELL_ID)
        collectionView.isPagingEnabled = true
        collectionView.scrollIndicatorInsets = .zero
//        collectionView.setCollectionViewLayout(<#T##layout: UICollectionViewLayout##UICollectionViewLayout#>, animated: <#T##Bool#>, completion: <#T##((Bool) -> Void)?##((Bool) -> Void)?##(Bool) -> Void#>)
        
        
        PathFinder.shared.computeClusteredOptimalPath(numTravelers: numDrivers) { groupedRouteArrays in
            print(groupedRouteArrays)
        }
        
        
        // ---- start computation with handler
        PathFinder.shared.computeIndividualOptimalPath { routeArray in
            
        }

    }
    
    @IBAction func closePressed(_ sender: UIButton) {
        self.delegate.showPinAnnotations()
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func sharePressed(_ sender: UIButton) {
        
    }
    
    // MARK: - Collection View Delegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var unpadded = collectionView.frame.size
//        unpadded.height -= 0
        unpadded.width -= 24
        return unpadded
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    // MARK: - Scrollview delegate
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageIndex = Int(scrollView.contentOffset.x + 40 / scrollView.frame.size.width) // adding 40 for now to account for some padding
        pageControl.currentPage = pageIndex
    }
    
    // MARK: - Collection View Datasource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numDrivers
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CELL_ID, for: indexPath) as? DriverRouteCollectionCell else {
            fatalError("unrecognized cell dequeued")
        }
        let lighterGray = UIColor(white: 0.95312, alpha: 1)
        cell.backgroundColor = lighterGray
        cell.layer.cornerRadius = 10
        cell.layer.masksToBounds = true
        cell.tableView.backgroundColor = lighterGray
        
        return cell
    }
    
}
