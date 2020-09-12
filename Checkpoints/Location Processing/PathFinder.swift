//
//  PathFinder.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 5/16/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import Foundation
import MapKit
import CoreLocation

class PathFinder {
    
    // MARK: - Properties
    
    static let shared = PathFinder() // shared singleton
    var locationManager = CLLocationManager()
    
    var firstRecordedCurrentLocation: MKMapItem? // convenient for marking where user had their "current location" marked when the app launched
    // publicly define which item the user must begin their route with
    var startLocationItem: MKMapItem? {
        didSet {
            if let item = startLocationItem {
                if let sourceIndex = destinationCollection.unsortedDestinations.firstIndex(of: item) {
                    destinationCollection.move(destinationAt: sourceIndex, toIndex: 0) // make new start
                } else {
                    fatalError("unable to change start location in collection")
                }
            }
        }
    }
    
    var mapUpdatedLocation: CLLocationCoordinate2D? {
        didSet {
            if let loc = mapUpdatedLocation {
                locationUpdateAwaitClosure = nil
                locationUpdateAwaitClosure?(mapUpdatedLocation ?? loc)
            }
        }
    }
    
    // object managing ordering and distance matrix of destination map items
    // when pathfinder has multiple drivers, it builts a third layer of abstraction over the intermediateIndices
    // array, such that intermediateIndices is not modified in the generation of different permutations
    var destinationCollection = DestinationTracker()
    
    //    private var bestPath: [Int] = []
    //    private var bestPathDistance = Double.infinity
    private let destinationRequestSemaphore = DispatchSemaphore(value: 1)
    
    // used to check whether its safe to proceed
    private var incompleteJobCount = 0
    private var taskProgressDenominator = 0
    private var taskProgressNumerator = 0
    
    //    private var permutation = [Int]()
    
    // MARK: - Public operations
    
    // reorients distance matrix to account for change in indices
    func moveDestination(from currentIndex: Int, to otherIndex: Int) {
        destinationCollection.move(destinationAt: currentIndex, toIndex: otherIndex)
        // TODO: recompute `lastComputedPathDistance` distance
        assert(false)
    }
        
    // add destination and precalculate distances with other locations
    func addDestination(mapItem: MKMapItem) {
        DispatchQueue.global(qos: .default).async {
            // no need to use mutex here, since addDestination is signaled by user interaction
            MapActivityStatus.toggleBusy(true)
            self.incompleteJobCount += 1
            let childEdgeCount = self.destinationCollection.count
            self.taskProgressDenominator = 1 //TODO: CHANGE += childEdgeCount
            
            #warning("though appended, we are not guaranteed that distances will be ready at this point")
            self.destinationCollection.append(mapItem)
            
            print("waiting from adddest")
            self.destinationRequestSemaphore.wait() // block a remove operation
            var asTheCrowFlies = false
            let rowIndex = self.destinationCollection.count - 1 // hold on to this in case we get another concurrent call?
            print("about to loop on rows")
            for var colIndex in (0..<rowIndex) { // only store connections to row many nodes to save space
                assert(mapItem != self.destinationCollection[colIndex]) // catch an old bug where same location was added
                
                let coord1 = mapItem.placemark.coordinate
                let clloc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
                let coord2 = self.destinationCollection[colIndex].placemark.coordinate
                let clloc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
                let straightDistance = clloc1.distance(from: clloc2)
                
                func _increment_progress() {
                    self.taskProgressNumerator += 1
                    let lastPercent = self.currentTaskProgress
                    let newPercent = Float(self.taskProgressNumerator) / Float(self.taskProgressDenominator)
                    if self.currentTaskProgress - lastPercent > 0.01 { // if delta is > 1%, update progress
                        self.currentTaskProgress = newPercent // calls setter to update UI
                    }
                }
                
                // if we are in atcf mode OR the distance is very small, dont waste a request
                if asTheCrowFlies || straightDistance < 200 {
                    print(">>>> USING ESTIMATED DIST")
                    _increment_progress()
                    self.destinationCollection.setDistance(between: rowIndex, and: colIndex, distance: straightDistance)
                } else {
                    let request = MKDirections.Request()
                    request.source = self.destinationCollection[colIndex]
                    request.destination = mapItem
                    request.requestsAlternateRoutes = false
                    request.transportType = .automobile
                    let directions = MKDirections(request: request)
                    
                    let etaSemaphore = DispatchSemaphore(value: 0)
                    print("gonna calc eta")
                    
                    directions.calculateETA { (etaResponse, error) in
                        print("got eta calculation")
                        guard let etaResponse = etaResponse else {
                            print(error ?? "Unknown error trying to compute ETA")
                            // TODO: tell someone that this failed and rollback changes....
                            
                            // case 1: too many requests made at one time, start a timer to repeat the request
                            if let mapError = error as? MKError,
                                let geoErrorDict = mapError.errorUserInfo["MKErrorGEOErrorUserInfo"] as? [String : Any],
                                let underError = geoErrorDict["NSUnderlyingError"] as? NSError,
                                let resetTime = underError.userInfo["timeUntilReset"] as? NSNumber {
                                print(resetTime)
                                
                                print("SWITCHING TO STRAIGHT DISTANCE ESTIMATES")
                                //                                print("SLEEPING TO WAIT FOR RESET TIME!")
                                //                                sleep(UInt32(truncating: resetTime))
                                asTheCrowFlies = true
                                colIndex -= 1
                            } else { // case 2? catch issue where destination is impossible to find directions to (like middle of ocean)
                                fatalError("FATAL: find way to handle case where eta cant be computed")
                            }
                            
                            return
                        }
                        
                        _increment_progress()
//                        print("\(self.destinationCollection[colIndex]) -> \(mapItem) = \(etaResponse.distance)")
                        self.destinationCollection.setDistance(between: rowIndex, and: colIndex, distance: etaResponse.distance)
                        etaSemaphore.signal() // indicate that we can move on to next iteration
                    }
                    
                    etaSemaphore.wait() // wait on eta to finish adding distance to matrix
                }
                
            }
            
            self.incompleteJobCount -= 1
            //            self.taskProgressDenominator -= childEdgeCount
            if self.incompleteJobCount == 0 {
                self.taskProgressDenominator = 1 // cannot have divide by zero
                self.taskProgressNumerator = 0
                MapActivityStatus.toggleBusy(false)
            }
            self.destinationRequestSemaphore.signal() // allow others to join
            print("signaled from adddest")
            
            // for now, calculate actual travel distance (by car)
            // ignore changes in traffic conditions, for example
            // won't be able to generate route paths on map unless we use the more
            //      expensive `calculate` option
        }
    }
    
    // index based on intermediate indexer
    func removeDestination(atIndex index: Int) {
        print("wait from removedest")
        incompleteJobCount += 1
        self.destinationRequestSemaphore.wait()
        print("got into remove sem")
        destinationCollection.remove(atIndex: index)
        incompleteJobCount -= 1
        self.destinationRequestSemaphore.signal()
    }
    
    // MARK: - Long Task Progress Communication
    
    // calls completion when there are no more pending incomplete destination requests
    func notifyOnRequestCompletion(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .default).async {
            self.destinationRequestSemaphore.wait()
            while self.incompleteJobCount != 0 {
                // release to allow access to these semaphores
//                print("waiting")
                self.destinationRequestSemaphore.signal()
                self.destinationRequestSemaphore.wait()
            }
            self.destinationRequestSemaphore.signal()
            DispatchQueue.main.async { completion() }
        }
    }
    
    // MARK: - Route computation
    
    func computeIndividualOptimalPath(completion: @escaping (([Int]) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            assert(self.destinationCollection.count > 1)
            let estimates = self.computePathUpperBound()
            var bestPath = estimates.0
            var bestPathDistance = estimates.1
            
            // estimating how many permutation branches we want to track
            self.taskProgressNumerator = 0
            (self.taskProgressDenominator, self.permCheckDepth) = self.cutoffFactorial(n: self.destinationCollection.count)
            
            print("starting with path upper bound of weight: ", bestPathDistance)
            // start with best one so far to help search time
            (bestPath, bestPathDistance) = self.computeBestSubpathPermutation(startPath: bestPath, upperBoundEstimate: bestPathDistance)
            
            // do some shifting
            bestPath.append(bestPath.first!)
            bestPath.reverse()
            bestPath.removeLast()
            
            print("best permutation (user indices): ", bestPath)
            completion(bestPath)
        }
    }
    
    // Note: in this case, the start destination must also be the end destination (for now)
    //      the TSP is optimized in such a way that does not consider paths returning back to
    //      the start location (destinations[0]). This should be optimal.
    func computeGroupOptimalPath(numTravelers: Int, completion: @escaping (([[Int]]) -> Void)) {
        assert(numTravelers < destinationCollection.count)

        var bestComboSplitIndices = [[Int]]()
//        var bestComboSD = Double.infinity
        var bestComboScore = Double.infinity
        var bestInfo = [([Int], Double)]()
        // TODO: estimating how many branches we want to track
        self.taskProgressNumerator = 0
        self.taskProgressDenominator = Int.max
        self.permCheckDepth = Int.max
//        (self.taskProgressDenominator, self.permCheckDepth) = self.cutoffFactorial(n: self.destinationCollection.count)
        
        var comboIndices = Array(repeating: [Int](), count: numTravelers)
        var stars = Set(1..<destinationCollection.count)
        func generateCombinations(start: Int, end: Int, index: Int) {
            if index == numTravelers {
        //        print(comboIndices)
                // end recursive call - test possible splits among each bar
        //        print("extras: \(stars)")
                var starray = Array(stars)
                
                func addRest() {
                    if starray.isEmpty {
                        
//                        if comboIndices[1] == [5] {
//                            print("here")
//                        }
                        // completed combination
                        // calculate optimal TSP for each of the driver groupings
                        let optimalSubpathInfo = comboIndices.map { testPath in
                            // generate permutation -- test path does not include index 0 (aka always the start location)
                            return computeBestSubpathPermutation(startPath: [0] + testPath)
                        }
                        
                        // do a statistical analysis on the distances calculated for this route
                        // we want to make sure that everyone drives about the same distance
                        
                        let meanDistance = optimalSubpathInfo.reduce(0.0) { return $0 + $1.1 } / Double(numTravelers)
                        // standard deviation as score
                        let score = sqrt((1 / Double(numTravelers)) * optimalSubpathInfo.reduce(0.0) { $0 + pow($1.1 - meanDistance, 2) })
                        
                        let optimalSubpaths = optimalSubpathInfo.map { $0.0 }
                        print("Testing ", comboIndices, " - best permutations: ", optimalSubpaths)
                        
//                        let sumOfSquares = optimalSubpathInfo.reduce(0.0) {
//                            $0 + pow($1.1, 2)
//                        }
//                        let score = sqrt(sumOfSquares) // l2norm
                        print("COMPARE: \n\t \(optimalSubpathInfo) \n\t vs \(bestInfo) \n\t (new score = \(score), old score = \(bestComboScore)")
                        
                        if bestComboScore > score {
                            print("\t✅ BETTER SCORE")
                            bestComboScore = score
                            bestComboSplitIndices = optimalSubpaths
                            bestInfo = optimalSubpathInfo // REMOVE THIS AFER DONE DEBUGGING
                        } else {
                            print("\t🆇 WORSE SCORE")
                        }
                        return
                    }
                    
                    // generate all possible ways to append a number to each of the sublists
                    for t in 0..<numTravelers {
                        // try appending to first, then recursive call attempt to add to next
                        comboIndices[t].append(starray.last!)
                        starray.removeLast() // OPTIMIZE BY KEEPING AN INDEX TRACKING WHERE WE ARE REMOVING FROM IN DEEPER CALLS
                        addRest()
                        let last = comboIndices[t].last!
                        comboIndices[t].removeLast()
                        starray.append(last)
                    }
                }
                addRest()
                
                return
            }
            
            var i = start
            while i <= end && (end - i + 1) >= (numTravelers - index) {
                comboIndices[index].append(i)
                stars.remove(i)
                generateCombinations(start: i + 1, end: end, index: index + 1)
                stars.insert(i)
                comboIndices[index].removeFirst()
                if index == 0 { break } // leave 0 index in place
                i += 1
            }
        }

        
        // kickstart test of every possible way to group points into numTravelers bins
        // start index of 1 so that we do not include start location (index 0) in subpath groupings
        generateCombinations(start: 1, end: self.destinationCollection.count - 1, index: 0)
        print("DONE: \(bestComboSplitIndices)")
        // call completion handler with our mapitem subpaths
        completion(bestComboSplitIndices)
        
    }
    
    func calculateDistanceFromCoordinate(coord: CLLocationCoordinate2D) -> Double {
        if let loc = locationManager.location {
            return loc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
        return -1
    }
    
    // MARK: - Task percentage progress
    
    // allow ui code to set a handler to get completion-percentage updates
    // note: there is NO GUARANTEE that the percentage will be updated all the way up to 100%
    var currentTaskProgressUpdateHandler: ((Float) -> Void)? = nil
    var currentTaskProgress: Float = 0.0 {
        didSet {
            currentTaskProgressUpdateHandler?(currentTaskProgress)
        }
    }
    func setProgressPercentageUpdateHandler(handler: @escaping (Float) -> Void) {
        currentTaskProgress = 0.0 // do not set numerator or denominator here, as a task may be in progress when this is called
        currentTaskProgressUpdateHandler = handler
    }
    
    // MARK: - Private Member Functions
    
    // uses raw indices (not based on intermediate indexer)
    //    private func distanceForRawIndices(_ a: Int, _ b: Int) -> Double {
    //        waitOnIncompleteJobs()
    //        if a == b { return 0.0 }
    //        let large = max(a,b)
    //        let small = min(a,b)
    //        return distanceMatrix[large][small]
    //    }
    
    //    public func threadSafeDistanceForUserIndices(_ a: Int, _ b: Int) -> Double {
    //        notifyOnRequestCompletion(completion: <#() -> Void#>) // wait since we might still be adding the index
    //        return destinationCollection.getDistance(between: a, and: b)
    //    }
    
    // meters
    public func longestCheckpointDistance() -> Double {
        return destinationCollection.longestDistance()
    }
    
    var locationUpdateAwaitClosure: ((CLLocationCoordinate2D) -> Void)? = nil
    public func awaitLocationUpdate(_ completion: @escaping (CLLocationCoordinate2D) -> Void) {
        self.locationUpdateAwaitClosure = completion
    }
    
    private func resetPriorData() {
        //        distanceMatrix.removeAll()
        destinationCollection.removeAll()
        //        bestPath.removeAll()
        //        bestPathDistance = .infinity
    }
    
    // MARK: - Private Computation Functionality
    
    // warning: may want to add a progress update closure to give updates to the progress of the computation
    var permCheckDepth = 0 // depth at which to increment our branch progress count
    private func computeBestSubpathPermutation(startPath: [Int], upperBoundEstimate: Double = .infinity) -> ([Int], Double) {
        var bestPath = startPath
        var bestPathDistance = upperBoundEstimate
        func genPermsRec(permutation: inout [Int], permLength: Int, growingDistance: Double) {
//            print("perm", permutation, " length: ", permLength, " cost: ", growingDistance)
            if growingDistance > bestPathDistance {
                print("cutting out this permutation!")
                return
            }
            
            if permLength == permCheckDepth {
                taskProgressNumerator += 1
                let oldPercent = currentTaskProgress
                let newPercent = Float(self.taskProgressNumerator) / Float(self.taskProgressDenominator)
                if newPercent - oldPercent > 0.01 {
                    currentTaskProgress = newPercent
                }
            }
            
            if permLength == permutation.count {
                let fullCycleDistance = growingDistance + destinationCollection.getDistance(between: 0, and: permutation.last!)
//                print("testing by adding length: ", testDistance)
                if fullCycleDistance < bestPathDistance {
//                    print("better permutation!")
                    bestPath = permutation
                    bestPathDistance = fullCycleDistance
                }
                return
            }
            
            // TODO: test promising, though time isnt an issue for a couple destinations
            if !promising(&permutation, permLength, growingDistance, bestPathDistance) {
                return
            }
            
            for i in permLength..<permutation.count {
                permutation.swapAt(permLength, i)
                let nextEdge = destinationCollection.getDistance(between: permutation[permLength - 1], and: permutation[permLength])
                genPermsRec(permutation: &permutation, permLength: permLength + 1, growingDistance: growingDistance + nextEdge)
                permutation.swapAt(permLength, i)
            }
        }
        var startPerm = startPath
        genPermsRec(permutation: &startPerm, permLength: 1, growingDistance: 0)
        return (bestPath, bestPathDistance)
    }
    
    private func computePathUpperBound() -> ([Int], Double) {
        print("START fasttsp")
        // TODO: make this work after proving that generatePermutations works
        /*
         bestPath = Array(0..<destinationCollection.count)
         bestPathDistance = 0.0
         for i in 0..<(bestPath.count - 1) {
         bestPathDistance += destinationCollection.getDistance(between: bestPath[i], and: bestPath[i + 1])
         }
         // connect end to beginning
         bestPathDistance += destinationCollection.getDistance(between: bestPath[0], and: bestPath[bestPath.count - 1])
         
         */
        
        var partialPath: [Int] = []
        partialPath.reserveCapacity(destinationCollection.count)
        let arbitraryStartIndex = 0 // arbitrarily pick start node
        
        // make start of partial path by adding closest vertex to start
        var minStartPairWeight = Double.infinity
        var minStartPairIndex = 0
        for i in 1..<destinationCollection.count {
            let testWeight = destinationCollection.getDistance(between: i, and: arbitraryStartIndex)
            if testWeight < minStartPairWeight {
                minStartPairIndex = i
                minStartPairWeight = testWeight
            }
        }
        
        // have partial path ready
        partialPath.append(arbitraryStartIndex)
        partialPath.append(minStartPairIndex)
        
        // repeatedly add arbitrary vertex k while minimizing C_ik + C_kj - C_ij
        // i can start from index 0, and only consider a vertex if its not the
        // arbitrary start, or the minstartindex
        for raw_test_index in 0..<destinationCollection.count {
            if raw_test_index == arbitraryStartIndex || raw_test_index == minStartPairIndex { continue }
            
            // find an adj pair of indices in our partialPath vertex that minimizes the above cost function
            var bestSpliceWeight = Double.infinity
            var leftWeight = destinationCollection.getDistance(between: partialPath.first!, and: raw_test_index)
            var rightWeight: Double = 0
            var leftIndex = 0
            
            for partialIndex in 0..<(partialPath.count - 1) {
                if partialIndex == raw_test_index { continue}
                
                let originalCost = destinationCollection.getDistance(between: partialPath[partialIndex], and: partialPath[partialIndex + 1])
                // no need to update left and right repetitively
                rightWeight = destinationCollection.getDistance(between: partialPath[partialIndex + 1], and: raw_test_index)
                
                // now consider the new potential cost of inserting between
                // partialPath[partialIndex] and partialPath[partialIndex + 1]
                let saved = leftWeight + rightWeight - originalCost
                if saved < bestSpliceWeight {
                    leftIndex = partialIndex
                    bestSpliceWeight = saved
                }
                
                // updated for next loop iteration
                leftWeight = rightWeight
            }
            
            leftWeight = destinationCollection.getDistance(between: partialPath.first!, and: raw_test_index)
            rightWeight = destinationCollection.getDistance(between: partialPath.last!, and: raw_test_index)
            // consider attaching to tip
            let endConnectionLength = destinationCollection.getDistance(between: partialPath.first!, and: partialPath.last!)
            if leftWeight + rightWeight - endConnectionLength < bestSpliceWeight {
                partialPath.append(raw_test_index)
            } else { // otherwise, attach to an intermediate index
                partialPath.insert(raw_test_index, at: leftIndex + 1)
            }
        }
        
        var weightSum = 0.0
        // now sum up weigt
        for i in 0..<(destinationCollection.count - 1) {
            weightSum += destinationCollection.getDistance(between: partialPath[i], and: partialPath[i + 1])
        }
        weightSum += destinationCollection.getDistance(between: partialPath.first!, and: partialPath.last!)
        //        bestPathDistance = weightSum
        //        bestPath = partialPath
        print("END fasttsp")
        return (partialPath, weightSum)
    }
    
    
    // MARK: - Heuristics
    
    struct PrimDatum {
        var visited = false
        var parentIndex = -1
        var minimalWeight = Double.infinity
    }
    private var primData = [PrimDatum]()
    
    func computeCoordinateBasedMST(coordinates: [CLLocationCoordinate2D]) -> [Int] {
        var localPrimData = [PrimDatum]()
        localPrimData.reserveCapacity(coordinates.count) // wont ever need more than this amount
        while localPrimData.count < coordinates.count { // most time optimal to keep equal to size of permutation
            localPrimData.append(PrimDatum())
        }
        
        var numVisited = 1
        var currentVertex = 0
        let mstCount = coordinates.count
        var mstWeight = 0.0
        
        for i in 0..<mstCount { // reset entries we care about
            localPrimData[i].visited = false
            localPrimData[i].parentIndex = -1
            localPrimData[i].minimalWeight = Double.infinity
        }
        
        while numVisited < mstCount {
            // minimize weights of newly available edges
            for i in 0..<mstCount {
                if localPrimData[i].visited { continue }
                // using degrees gives a distance approximation.
                let dist = sqrt(pow(coordinates[i].latitude - coordinates[currentVertex].latitude, 2) + pow(coordinates[i].longitude - coordinates[currentVertex].longitude, 2))
                if dist < localPrimData[i].minimalWeight {
                    localPrimData[i].minimalWeight = dist
                    localPrimData[i].parentIndex = currentVertex
                }
            }
            
            // visit next unvisited vertex with lowest edge weight
            var minUnvisitedWeight = Double.infinity
            for v in 1..<mstCount {
                if !localPrimData[v].visited {
                    if localPrimData[v].minimalWeight < minUnvisitedWeight {
                        currentVertex = v
                        minUnvisitedWeight = localPrimData[v].minimalWeight
                    }
                }
            }
            
            mstWeight += localPrimData[currentVertex].minimalWeight
            localPrimData[currentVertex].visited = true
            numVisited += 1
        }
        
        return localPrimData.map { $0.parentIndex }
    }
    
    // tell whether adding the count - permLength nodes can possibly produce an optimal path
    private func promising(_ permutation: inout [Int], _ permLength: Int, _ pathDistance: Double, _ bestPathDistance: Double) -> Bool {
        // compute MST on remaining vertices
        //        if permLength >= permutation.count - 3 { return true }// TODO: make this bound larger to avoid wasting time on MST when we just have a few points
        
        primData.reserveCapacity(permutation.count) // wont ever need more than this amount
        for i in 0..<primData.count { // reset all entries (could change to only change from permLength)
            primData[i].visited = false
            primData[i].parentIndex = -1
            primData[i].minimalWeight = Double.infinity
        }
        while primData.count < permutation.count { // most time optimal to keep equal to size of permutation
            primData.append(PrimDatum())
        }
        
        var numVisited = 1
        var currentVertex = permLength
        let mstCount = permutation.count - permLength
        var mstWeight = 0.0
        
        // start at first coordinate
        primData[permLength].visited = true
        primData[permLength].minimalWeight = 0
        
        while numVisited < mstCount {
            // minimize weights of newly available edges
            for i in permLength..<permutation.count {
                if primData[i].visited { continue }
                let dist = destinationCollection.getDistance(between: permutation[i], and: permutation[currentVertex])
                if dist < primData[i].minimalWeight {
                    primData[i].minimalWeight = dist
                    primData[i].parentIndex = currentVertex
                }
            }
            
            // visit next unvisited vertex with lowest edge weight
            var minUnvisitedWeight = Double.infinity
            for v in (permLength+1)..<primData.count {
                if !primData[v].visited {
                    if primData[v].minimalWeight < minUnvisitedWeight {
                        currentVertex = v
                        minUnvisitedWeight = primData[v].minimalWeight
                    }
                }
            }
            
            mstWeight += primData[currentVertex].minimalWeight
            if mstWeight > bestPathDistance {
                return false // consider early exit
            }
            primData[currentVertex].visited = true
            numVisited += 1
        }
        
        var minLeftEdge = Double.infinity
        var minRightEdge = Double.infinity
        for i in permLength..<permutation.count {
            let leftDist = destinationCollection.getDistance(between: permutation[0], and: permutation[i])
            let rightDist = destinationCollection.getDistance(between: permutation[permLength - 1], and: permutation[i])
            if leftDist < minLeftEdge {
                minLeftEdge = leftDist
            }
            if rightDist < minRightEdge {
                minRightEdge = rightDist
            }
        }
        
//        print(permLength, " mst total weight = ", minLeftEdge + minRightEdge + mstWeight + pathDistance, "path part: ", pathDistance)
        return minLeftEdge + minRightEdge + mstWeight + pathDistance < bestPathDistance
    }
    
    // MARK: - Location Services Helpers
    
    func computeMapItem(for coordinate: CLLocationCoordinate2D, completion: @escaping (MKMapItem?) -> ()) {
        let x = CLGeocoder()
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        x.reverseGeocodeLocation(loc) { (placemarks, error) in
            if let e = error {
                print(e)
                print("Error computing address")
                completion(nil)
            }
            if let pm = placemarks?.first {
                let mapItem = MKMapItem(placemark: MKPlacemark(placemark: pm))
                completion(mapItem)
            }
        }
    }
    
    // MARK: - Computation Helpers
    
    // this is used to figure out how many branches we want to wait for before we update our % progress tracker
    // for now, cut off is 5 factorial
    // returns tuple of branch number we expect and number of branches and depth to check at for permutation of n entries
    private func cutoffFactorial(n: Int) -> (Int, Int) { // fac returning nil if more than we care for
        assert(n < 120)
        var mult = n - 2
        var out = n - 1
        while out * mult < 150 && mult > 2 {
            out *= mult
            mult -= 1
        }
        return (out, n - mult) // n = 100 --> 99, n = 5 -> 5 --> 4 * 3 --> 12
    }
    
    
}
