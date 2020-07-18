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

// stores collection of mapitems and distances between each other
class DestinationTracker {
    private var orderedDestinations: [MKMapItem] = []
    private var intermediateIndices: [Int] = []
    private var distanceMatrix = [[Double]]() // distances in meters
    /*
        Distance Matrix storage format
        []
        [1-0]
        [2-0, 2-1]
        [3-0, 3-1, 3-2]
        ...
    */
    
    var count: Int {
        return orderedDestinations.count
    }
    
    var isEmpty: Bool {
        return orderedDestinations.isEmpty
    }
    
    func contains(_ item: MKMapItem) -> Bool {
        return orderedDestinations.contains(item)
    }
    
    var unsortedDestinations: [MKMapItem] {
        return orderedDestinations
    }
    
    func removeAll() {
        orderedDestinations.removeAll()
        intermediateIndices.removeAll()
        distanceMatrix.removeAll()
    }
    
    subscript(index: Int) -> MKMapItem {
        orderedDestinations[intermediateIndices[index]]
    }
    
    func append(_ mapItem: MKMapItem) {
        orderedDestinations.append(mapItem)
        intermediateIndices.append(intermediateIndices.count)
        distanceMatrix.append(Array(repeating: Double.infinity, count: distanceMatrix.count)) // prepare row of directions
    }
    
    func longestDistance() -> Double {
        return distanceMatrix.reduce(0.0) { biggest, row -> Double in
            let greatestInRow = row.reduce(0.0) { res, i -> Double in
                return res < i ? i : res
            }
            return biggest < greatestInRow ? greatestInRow : biggest
        }
    }
    
    func move(destinationAt index: Int, toIndex: Int) {
        let entry = intermediateIndices[index]
        intermediateIndices.remove(at: index)
        intermediateIndices.insert(entry, at: toIndex)
    }
    
    func indexOf(_ mapItem: MKMapItem) -> Int {
        let innerIndex = orderedDestinations.firstIndex(of: mapItem)!
        let userIndex = intermediateIndices.firstIndex(of: innerIndex)!
        return userIndex
    }
    
    func remove(atIndex: Int) {
        orderedDestinations.remove(at: intermediateIndices[atIndex])
        
        for i in ((intermediateIndices[atIndex] + 1)..<distanceMatrix.count) { // remove related entries in larger index rows
            distanceMatrix[i].remove(at: intermediateIndices[atIndex]) // index..<count rows have relevant entries
        }
        distanceMatrix.remove(at: intermediateIndices[atIndex]) // then delete the main row for this index
        intermediateIndices.remove(at: atIndex)
        
        // lastly, decrement all following entries of intermediate indexer, as whatever used to have index + i now has index + i - 1
        for i in (0..<intermediateIndices.count) {
            if intermediateIndices[i] >= atIndex {
                intermediateIndices[i] -= 1
            }
        }
    }
    
    // returns distance between destinations via user-facing indices (not based on indexing used in distance matrix)
    func getDistance(between index1: Int, and index2: Int) -> Double {
        if index1 == index2 { return 0.0 }
        let i1 = intermediateIndices[index1]
        let i2 = intermediateIndices[index2]
        let smallIndex = min(i1, i2)
        let bigIndex = max(i1, i2) // row indexed based on large number, since we have a triangle matrix filled out
        assert(distanceMatrix.count > bigIndex)
        assert(distanceMatrix[bigIndex].count > smallIndex)
        return distanceMatrix[bigIndex][smallIndex]
    }
    
    // sets distance between destinations via user-facing indices (not based on indexing used in distance matrix)
    func setDistance(between index1: Int, and index2: Int, distance: Double) {
        let i1 = intermediateIndices[index1]
        let i2 = intermediateIndices[index2]
        let smallIndex = min(i1, i2)
        let bigIndex = max(i1, i2) // row indexed based on large number, since we have a triangle matrix filled out
        assert(distanceMatrix.count > bigIndex)
        assert(distanceMatrix[bigIndex].count > smallIndex)
        distanceMatrix[bigIndex][smallIndex] = distance
    }
    
    //
    func distanceAfterCheckpoint(startIndex: Int, driverIndex: Int? = nil) -> Double {
        #warning("support mutliple drivers here")
        if let driverIndex = driverIndex {
            fatalError("not implemented for multiple drivers \(driverIndex)")
        } else {
            var dist = 0.0
            #warning("confirm that this includes RTH")
            for i in startIndex..<(intermediateIndices.count - 1) {
                dist += getDistance(between: i, and: i+1)
            }
            return dist
        }
    }
    
    func assertsomething() {
        let testMatrix: [[(Int, Int)]] = [
            [],
            [(1, 0)],
            [(2, 0), (2, 1)],
            [(3, 0), (3, 1), (3, 2)],
            [(4, 0), (4, 1), (4, 2), (4, 3)],
            [(5, 0), (5, 1), (5, 2), (5, 3), (5, 4)]
        ]

    }
}

class PathFinder {
    // MARK: - Properties
    static let shared = PathFinder() // shared singleton
    var locationManager = CLLocationManager()
    
    var startLocationItem: MKMapItem? // publicly define which item the user must begin their route with
    var firstRecordedCurrentLocation: MKMapItem? // convenient for marking where user had their "current location" marked when the app launched
    var mapUpdatedLocation: CLLocationCoordinate2D? {
        didSet {
            if let loc = mapUpdatedLocation {
                locationUpdateAwaitClosure = nil
                locationUpdateAwaitClosure?(mapUpdatedLocation ?? loc)
            }
        }
    }
    
    // array containing mapitems for all destinations with corresponding distances as stored in the distance matrix
    // the order of these destinations *never* changes; instead, we change the destIntermediateIndices array to avoid having to reorganize the distance matrix
//    private(set) var destinations: [MKMapItem] = []
//    private(set) var destIntermediateIndices: [Int] = [] // stores indexes that index into destinations, so that `destinations` never has to change ordering (even after delete)
    var destinationCollection = DestinationTracker()
    
    private var bestPath: [Int] = []
    private var bestPathDistance = Double.infinity
    private let destinationRequestSemaphore = DispatchSemaphore(value: 1)
//    private var distanceMatrix = [[Double]]() // distances in meters
    /*
        Distance Matrix storage format
        []
        [1-0]
        [2-0, 2-1]
        [3-0, 3-1, 3-2]
        ...
    */
    
    // used to check whether its safe to proceed
    private var incompleteJobCount = 0
    
    private var permutation = [Int]()
    
    struct PrimDatum {
        var visited = false
        var parentIndex = -1
        var minimalWeight = Double.infinity
    }
    private var primData = [PrimDatum]()
        
    // MARK: - Public operations
    
    // reorients distance matrix to account for change in indices
    func moveDestination(from currentIndex: Int, to otherIndex: Int) {
        destinationCollection.move(destinationAt: currentIndex, toIndex: otherIndex)
        // TODO: recompute `lastComputedPathDistance` distance
        assert(false)
    }
    
    private func waitOnIncompleteJobs() {
        destinationRequestSemaphore.wait()
        while incompleteJobCount != 0 {
            // release to allow access to these semaphores
            print("waiting")
            destinationRequestSemaphore.signal()
            destinationRequestSemaphore.wait()
        }
        destinationRequestSemaphore.signal()
    }
             
    
    // add destination and precalculate distances with other locations
    func addDestination(mapItem: MKMapItem) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            // no need to use mutex here, since addDestination is signaled by user interaction
            
            self.incompleteJobCount += 1
            print("waiting from adddest")
            self.destinationRequestSemaphore.wait() // block a remove operation
            
            self.destinationCollection.append(mapItem)
//            self.destinations.append(mapItem) // may want to compute edge weights to this destination
//            self.destIntermediateIndices.append(self.destIntermediateIndices.count) // first item -> gets index 0
            
//            self.distanceMatrix.append([])
            let rowIndex = self.destinationCollection.count - 1 // hold on to this in case we get another concurrent call?
//            self.distanceMatrix[rowIndex].reserveCapacity(rowIndex)
            print("about to loop on rows")
            for colIndex in (0..<rowIndex) { // only store connections to row many nodes to save space
                assert(mapItem != self.destinationCollection[colIndex]) // catch an old bug where same location was added
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
                        return
                    }
//                    assert(self.destinationCollection[rowIndex].count == colIndex)
                    self.destinationCollection.setDistance(between: rowIndex, and: colIndex, distance: etaResponse.distance)
                    etaSemaphore.signal() // indicate that we can move on to next iteration
                }
                etaSemaphore.wait() // wait on eta to finish adding distance to matrix
            }
            self.incompleteJobCount -= 1
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
    
    // warning: may want to add a progress update closure to give updates to the progress of the computation
    func computeIndividualOptimalPath(completion: (([MKMapItem]) -> Void)) {
        assert(destinationCollection.count > 1)
        computePathUpperBound()
        print("starting with path upper bound of weight: ", bestPathDistance)
        // WARNING: rotate bestPath so that index 0 has node 0 (start node)
        permutation = bestPath // start with best one so far to help search time
        generatePermutations(permLength: 1, growingDistance: 0.0)
        
        print("best permutation: ", bestPath)
    }
    
    // Note: in this case, the start destination must also be the end destination (for now)
    //      the TSP is optimized in such a way that does not consider paths returning back to
    //      the start location (destinations[0]). This should be optimal.
    func computeClusteredOptimalPath(numTravelers: Int,
                                     completion: (([[MKMapItem]]) -> Void)) {
        assert(numTravelers > destinationCollection.count)
        computeIndividualOptimalPath { (path) in
            
            /*
             option 1: intersperse go-to and return-to-home edges along first k vertices
             and shift last one back towards end, allowing the next to last edge to move forward a vertex iff
             it minimizes nah a greedy approach can find a local minimum and get stuck
            
            
             option 2: divide by average distance along path and allow the case where a line of points of increasing distance from the start are divided up between people equally, where the actual fair result weighs super far points with more weight and
            
             option 3: accumulated weight should involve cost of adding return to home cost of every point!!!!
             this properly weighs the cost of traveling to a super distant node over a close node
//            let distSplitThreshold = bestPathDistance + distanceMatrix.last!.reduce(0.0) { $0 + $1 }
            
            
             option +4: form clusters by cutting off k longest edges, and use that subset as an advisory alternative which
             may not be as "fair," but will reduce total gas spent significantly
            
            
             option 5: brute force: try all n^k possible ways to split up paths, but the objective
             you use to minimize cost / pick a path might not even be "correct" enough to be worth the processing time
             like, does making the paths as equal in distance traveled as possible even that desirable?
             */
            
            
            // test case to try: a horizontal line of 5 points, behind another horizontal line of 5 points offset such that
            // the left most node is beneath the right most node of the other set
            // a good program will split each line into separate paths if there are 2 travelers
            
            // current plan: use naive solution where distance between points and return to home is not considered, then compare against the approach which splits the path by cutting the 6 longest travel distances between points

            
            
            // WARNING: made the realization that a split TSP might not be optimal... subpaths in TSP are optimized and primed for future approach to points in other "clusters". The closest way to connect 7 points in a simple path might not include the best way to connect the first 4 of those points
            
            // we expect distance traveled between points to be about the same, so remove points returning to home to compute avg
            assert(bestPath[0] == 0)
            assert(bestPath.last! == 0)
            let avgDistGoal =
                (bestPathDistance
                - (destinationCollection.getDistance(between: bestPath[0], and: bestPath[1]) +
                    destinationCollection.getDistance(between: bestPath[bestPath.count - 2], and: bestPath.last!)))
                / Double(numTravelers)
            
            var pathSlices = [(Int, Int)]()
            var distanceAccumulator = 0.0
            var sliceStartIndexIndex = 1 // NOTE: this is an index into bestPath. Start at 1 to generalize skipping destinations[0]
            // WARNING: assuming bestPath[0] == destinations[0] and that bestPath.last == 0
            
            for i in 1..<bestPath.count-1 { // excludes connect from start to 2nd vertex and penultimate back to start
                let v1IndexIndex = i
                let v2IndexIndex = i + 1 // should never equal .count or .count - 1
                distanceAccumulator += destinationCollection.getDistance(between: bestPath[v1IndexIndex], and: bestPath[v2IndexIndex])
//                                     + distance(a: bestPath[v1IndexIndex], b: 0) // v1 to start location
//                                     + distance(a: bestPath[v1IndexIndex], b: 0) // v2 to start location
                
                // WARNING: once we form a slice, we want to make sure that others dont have the "sum weight" threshold
                // preventing division of remaining nodes over multiple ppl. edge case is that a huge number is lifted off of the backs of remaining travelers once the first slice of one location is taken out (a single outlier), and all other points are relatively close to each other,
                
                // if we surpass the avg expected distance, assign slice to the next traveler
                // this "comparison" must involve the consideration of connecting
                if distanceAccumulator > avgDistGoal {
                    pathSlices.append((sliceStartIndexIndex, i))
                    sliceStartIndexIndex = i + 1
                }
            }
            
            if sliceStartIndexIndex != bestPath.count - 1 { // close off the last slice if we havent split up to count - 2
                pathSlices.append((sliceStartIndexIndex, bestPath.count - 2)) // careful to account for going back to 0
            }
            
            // step 1: generate path
            // index-index pairs -> subpath index subarray slices -> arrays of mapItem arrays without RTH
            let subpathSlices = pathSlices.map { bestPath[$0.0..<$0.1] }
            
            // step 2: attempt to split path by cutting most distance points
            let sortedIndices = bestPath[1..<bestPath.count-1].sorted { (a, b) -> Bool in
                // descending by distance from start
                return destinationCollection.getDistance(between: 0, and: a) > destinationCollection.getDistance(between: 0, and: b)
            }
            let verticesCutSet = Set(sortedIndices[..<numTravelers])
            assert(destinationCollection.getDistance(between: sortedIndices[0], and: 0) > destinationCollection.getDistance(between: sortedIndices[1], and: 0))
            
            // step 2.2: find places to split to generate alternative path
            var alternativeSubpathSlices = [[Int]]()
            for i in 1..<bestPath.count - 2 {
                if verticesCutSet.contains(bestPath[i]) { // if a very distant node, decide to either attach to next node or previous node
                    if let prevNodeIndex = alternativeSubpathSlices.last?.last, i + 1 <= bestPath.count - 2 {
                        // case where we have a previous and next node
                        let nextNodeIndex = bestPath[i+1]
                        if destinationCollection.getDistance(between: prevNodeIndex, and: bestPath[i]) < destinationCollection.getDistance(between: bestPath[i], and: nextNodeIndex) {
                            // better to connect to previous node and form a new sequence
                            alternativeSubpathSlices[alternativeSubpathSlices.count - 1].append(bestPath[i])
                            alternativeSubpathSlices.append([]) // then append empty array for next node to be added to
                        } else {
                            // better to connect to next node in a new sequence
                            alternativeSubpathSlices.append([bestPath[i]])
                        }
                    } else if let _ = alternativeSubpathSlices.last?.last {
                        // case where we only have a previous node
                        // this means that this is the last node, and should be the only one visited by the last traveler
                        alternativeSubpathSlices.append([bestPath[i]])
                    } else if i + 1 <= bestPath.count - 2 {
                        // case where we have a next node and not a previous node
                        // hmmmmmmm maybe just isolate it from the rest?
                        // TODO: consider changing this behavior
                        alternativeSubpathSlices.append([bestPath[i]])
                        alternativeSubpathSlices.append([])
                    } else {
                        // case where we dont have a previous or next node. Simply append
                        alternativeSubpathSlices.append([bestPath[i]])
                    }
                } else {
                    if alternativeSubpathSlices.isEmpty {
                        alternativeSubpathSlices.append([bestPath[i]])
                    } else {
                        alternativeSubpathSlices[alternativeSubpathSlices.count - 1].append(bestPath[i])
                    }
                }
            }
            
            print("alternative subpath indices")
            print(alternativeSubpathSlices)
            assert(alternativeSubpathSlices.count == numTravelers)
            assert(pathSlices.count == numTravelers)
            assert(subpathSlices.reduce(0) { $0 + $1.count } == destinationCollection.count,
                   "incorrect destination count in pathSlices")
            assert(alternativeSubpathSlices.reduce(0) { $0 + $1.count } == destinationCollection.count,
                   "incorrect destination count in alternativeSubpathSlices")

                        
            // last step: compare our main subpath avg lengths with our alternative subpath lengths
            // as a heuristic, remove most expensive path from both to allow one outlier to exist
            let alternativeReconnectedSubpathLength = alternativeSubpathSlices.map { slice -> Double in
                var sum: Double = 0.0
                for i in 0..<slice.count - 1 {
                    sum += destinationCollection.getDistance(between: slice[i], and: slice[i + 1])
                }
                sum += destinationCollection.getDistance(between: slice[0], and: 0)
                sum += destinationCollection.getDistance(between: slice.last!, and: 0)
                return sum
            }.reduce(0.0) { $0 + $1 }
            
            let reconnectedSubpathLength = subpathSlices.map { slice -> Double in
                var sum: Double = 0.0
                for i in 0..<slice.count - 1 {
                    sum += destinationCollection.getDistance(between: slice[i], and: slice[i + 1])
                }
                sum += destinationCollection.getDistance(between: slice[0], and: 0)
                sum += destinationCollection.getDistance(between: slice.last!, and: 0)
                return sum
            }.reduce(0.0) { $0 + $1 }
            
            var subpathsOutput = [[MKMapItem]]() // should not include connections back to start (0 - ... - 0)
            // if better to take our heuristic-generated split, use it
            if alternativeReconnectedSubpathLength < reconnectedSubpathLength {
                subpathsOutput = alternativeSubpathSlices.map { $0.map { destinationCollection[$0] } }
            } else {
                subpathsOutput = subpathSlices.map { $0.map { destinationCollection[$0] } }
            }
            
            // call completion handler with our mapitem subpaths
            completion(subpathsOutput)
        }
    }
    
    func calculateDistanceFromCoordinate(coord: CLLocationCoordinate2D) -> Double {
        if let loc = locationManager.location {
            return loc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
        return -1
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
    
    public func threadSafeDistanceForUserIndices(_ a: Int, _ b: Int) -> Double {
        waitOnIncompleteJobs() // wait since we might still be adding the index
        return destinationCollection.getDistance(between: a, and: b)
    }
    
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
        bestPath.removeAll()
        bestPathDistance = .infinity
    }
    
    private func computePathUpperBound() {
        // TODO: make this work after proving that generatePermutations works
        bestPath = Array(0..<destinationCollection.count)
        bestPathDistance = 0.0
        for i in 0..<(bestPath.count - 1) {
            bestPathDistance += destinationCollection.getDistance(between: bestPath[i], and: bestPath[i + 1])
        }
        // connect end to beginning
        bestPathDistance += destinationCollection.getDistance(between: bestPath[0], and: bestPath[bestPath.count - 1])
    }
    
    private func generatePermutations(permLength: Int, growingDistance: Double) {
        print("perm", permutation, " length: ", permLength, " cost: ", growingDistance)
        if growingDistance > bestPathDistance {
            print("cutting out this permutation!")
            return
        }
        
        if permLength == permutation.count {
            let testDistance = growingDistance + destinationCollection.getDistance(between: 0, and: permutation.last!)
            print("testing by adding length: ", testDistance)
            if testDistance < bestPathDistance {
                print("better permutation!")
                bestPath = permutation
                bestPathDistance = testDistance
            }
            return
        }
        
        // TODO: test promising, though time isnt an issue for a couple destinations
//        if !promising(permLength, growingDistance) {
//            return
//        }
        
        for i in permLength..<permutation.count {
            permutation.swapAt(permLength, i)
            let nextEdge = destinationCollection.getDistance(between: permLength - 1, and: permLength)
            generatePermutations(permLength: permLength + 1, growingDistance: growingDistance + nextEdge)
            permutation.swapAt(permLength, i)
        }
    }
    
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
    private func promising(_ permLength: Int, _ pathDistance: Double) -> Bool {
        // compute MST on remaining vertices
        if permLength >= permutation.count - 3 { return true }// TODO: make this bound larger to avoid wasting time on MST when we just have a few points
        primData.reserveCapacity(permutation.count) // wont ever need more than this amount
        while primData.count < permutation.count { // most time optimal to keep equal to size of permutation
            primData.append(PrimDatum())
        }
        
        var numVisited = 1
        var currentVertex = permLength
        let mstCount = permutation.count - permLength
        var mstWeight = 0.0
        
        for i in 0..<mstCount { // reset entries we care about
            primData[i].visited = false
            primData[i].parentIndex = -1
            primData[i].minimalWeight = Double.infinity
        }
                
        while numVisited < mstCount {
            // minimize weights of newly available edges
            for i in permLength..<mstCount {
                if primData[i].visited { continue }
                let dist = destinationCollection.getDistance(between: permutation[i], and: permutation[currentVertex])
                if dist < primData[i].minimalWeight {
                    primData[i].minimalWeight = dist
                    primData[i].parentIndex = currentVertex
                }
            }
            
            // visit next unvisited vertex with lowest edge weight
            var minUnvisitedWeight = Double.infinity
            for v in (permLength+1)..<mstCount {
                if !primData[v].visited {
                    if primData[v].minimalWeight < minUnvisitedWeight {
                        currentVertex = v
                        minUnvisitedWeight = primData[v].minimalWeight
                    }
                }
            }
            
            mstWeight += primData[currentVertex].minimalWeight
            if mstWeight + pathDistance > bestPathDistance {
                return false // consider early exit
            }
            primData[currentVertex].visited = true
            numVisited += 1
        }
        
        var minLeftEdge = Double.infinity
        var minRightEdge = Double.infinity
        for i in permLength..<mstCount {
            let leftDist = destinationCollection.getDistance(between: permutation[0], and: permutation[i])
            let rightDist = destinationCollection.getDistance(between: permutation[permLength - 1], and: permutation[i])
            if leftDist < minLeftEdge {
                minLeftEdge = leftDist
            }
            if rightDist < minRightEdge {
                minRightEdge = rightDist
            }
        }
        
        return minLeftEdge + minRightEdge + mstWeight + pathDistance < bestPathDistance
    }
    
    // Locations helpers
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
    
}
