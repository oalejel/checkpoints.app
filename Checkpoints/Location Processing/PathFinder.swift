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

//protocol PathFinderDelegate {
//    func completedIndividualComputation(success: Bool, path: [MKMapItem])
//    func completedClusteredComputation(success: Bool, paths: [[MKMapItem]])
//}

class PathFinder {
    
    static let shared = PathFinder() // shared singleton
    var locationManager = CLLocationManager()
    
    private(set) var destinations = [MKMapItem]()
    private var bestPath = [Int]()
    private var bestPathDistance = Double.infinity
    let destinationRequestSemaphore = DispatchSemaphore(value: 1)
    
    private var distanceMatrix = [[Double]]() // distances in meters
    /*
        Distance Matrix storage format
        []
        [1-0]
        [2-0, 2-1]
        [3-0, 3-1, 3-2]
        ...
    */
    
    private var permutation = [Int]()
    
    struct PrimDatum {
        var visited = false
        var parentIndex = -1
        var minimalWeight = Double.infinity
    }
    private var primData = [PrimDatum]()
    
    // reorients distance matrix to account for change in indices
    func moveDestination(from currentIndex: Int, to otherIndex: Int) {
        assertReorganizeDistanceCorrectness() // (comment out later) test correctness of this crucial helper function
        
    }
    
    func assertReorganizeDistanceCorrectness() {

        let testMatrix: [[(Int, Int)]] = [
            [],
            [(1, 0)],
            [(2, 0), (2, 1)],
            [(3, 0), (3, 1), (3, 2)],
            [(4, 0), (4, 1), (4, 2), (4, 3)],
            [(5, 0), (5, 1), (5, 2), (5, 3), (5, 4)]
        ]
        
        // test swapping 0 -> 5
        var test1 = testMatrix
        reorganizeDistanceMatrix(from: 0, to: 5, matrix: &test1)
        /*
         [],
         [(1, 0)],
         [(2, 0), (2, 1)],
         [(3, 0), (3, 1), (3, 2)],
         [(4, 0), (4, 1), (4, 2), (4, 3)],
         [(5, 0), (5, 1), (5, 2), (5, 3), (5, 4)]
         
         [, (5, 1), (5, 2), (5, 3), (5, 4)]
         [(1, 0), ],
         [(2, 0), (2, 1)],
         [(3, 0), (3, 1), (3, 2)],
         [(4, 0), (4, 1), (4, 2), (4, 3)],
         []
        
        */
        assert(true)
        
        // test swapping 5 -> 0
        
        // test swapping 0 -> 1
        
        // test swapping 4 -> 3
        
        // test swapping 3 -> 4
        
    }
         
    private func reorganizeDistanceMatrix<T>(from _currentIndex: Int, to _otherIndex: Int, matrix: inout [[T]]) {
        // example: 3 -> 5 takes index 3 to 5
        // this would move the 3 entries in index 3 to the place of index 5, shifting 5 down to 4
        // index 5 (formerly items of index 3) need two entries to be adjusted to the proper length
        // this means that we need to move the entry at index 3 of the entries that we surpassed and append them to index 5's array of 3 entries
        
        
        // means that i want everything that was at index 3 to be represented as a 5, and 4 and 5 must now be represented by indices 3 and 4
        /*
            []
            [1-0]
            [2-0, 2-1]
            [3-0, 3-1, 3-2]
            [4-0, 4-1, 4-2, 4-3]
            -> move 2 to 4 (make c take the place of e)
         representation
            [] (0:a, 1:b, 2:c, 3:d, 4:e)
            [b-a]
            [c-a, c-b]
            [d-a, d-b, d-c]
            [e-a, e-b, e-c, e-d]
         -> final
         0->0 a[] (0:a, 1:b, 2:c, 3:d, 4:e)
         1->1 b[b-a]
         4->3 e[e-a, e-b] * moved this row from 4th index to 2nd index
         2->4 c[c-a, c-b, e-c] * placed entry in source row at `currentIndex` at end of the next row
         3->5 d[d-a, d-b, d-c, e-d] * placed the 1 + `currentIndex` entry at end of this row
        */
        assert(_currentIndex < distanceMatrix.count)
        assert(_otherIndex < distanceMatrix.count)
        if _currentIndex == _otherIndex { return }
        
        
        
        
        
        
        
        
        
        // garbage incorrect code:
//        // for consistency, make currentIndex < otherIndex
//        let currentIndex = min(_currentIndex, _otherIndex)
//        let otherIndex = max(_currentIndex, _otherIndex)
        
//        let movingRow = matrix[currentIndex]
//        matrix.remove(at: currentIndex)
//        matrix.insert(Array(movingRow[0..<currentIndex]), at: otherIndex)
//
//        // copy entries from back of moving row to
//        for transplantSourceIndex in currentIndex..<movingRow.count {
//            matrix[transplantSourceIndex + 1].append(movingRow[transplantSourceIndex])
//        }
    }
    
    // add destination and precalculate distances with other locations
    func addDestination(mapItem: MKMapItem) {
        destinations.append(mapItem) // may want to compute edge weights to this destination
        
        DispatchQueue.global(qos: .userInitiated).async {
            // no need to use mutex here, since addDestination is signaled by user interaction
            self.destinationRequestSemaphore.wait() // block a remove operation
            
            self.distanceMatrix.append([])
            let rowIndex = self.distanceMatrix.count - 1 // hold on to this in case we get another concurrent call?
            self.distanceMatrix[rowIndex].reserveCapacity(rowIndex)
            
           
            
            for colIndex in (0..<rowIndex) { // only store connections to row many nodes to save space
                let request = MKDirections.Request()
                request.source = self.destinations[colIndex]
                request.destination = mapItem
                request.requestsAlternateRoutes = false
                request.transportType = .automobile
                let directions = MKDirections(request: request)
                
                let etaSemaphore = DispatchSemaphore(value: 0)
                directions.calculateETA { (etaResponse, error) in
                    guard let etaResponse = etaResponse else {
                        print(error ?? "Unknown error trying to compute ETA")
                        // TODO: tell someone that this failed...
                        return
                    }
                    assert(self.distanceMatrix[rowIndex].count == colIndex)
                    self.distanceMatrix[rowIndex].append(etaResponse.distance)
                    etaSemaphore.signal() // indicate that we can move on to next iteration
                }
                etaSemaphore.wait() // wait on eta to finish adding distance to matrix
            }
            print(self.distanceMatrix)
            self.destinationRequestSemaphore.signal() // allow others to join
            
            // for now, calculate actual travel distance (by car)
            // ignore changes in traffic conditions, for example
            // won't be able to generate route paths on map unless we use the more
            //      expensive `calculate` option
        }
    }
    
    func removeDestination(atIndex index: Int) {
        self.destinationRequestSemaphore.wait()
        destinations.remove(at: index)
        distanceMatrix.remove(at: index)
        for i in (index..<distanceMatrix.count) {
            distanceMatrix[i].remove(at: index) // index..<count rows have relevant entries
        }
        self.destinationRequestSemaphore.signal()
    }
    
    // warning: may want to add a progress update closure to give updates to the progress of the computation
    func computeIndividualOptimalPath(completion: (([MKMapItem]) -> Void)) {
        assert(destinations.count > 1)
        computePathUpperBound()
        // WARNING: rotate bestPath so that index 0 has node 0 (start node)
        permutation = bestPath // start with best one so far to help search time
        generatePermutations(permLength: 1, growingDistance: 0.0)
    }
    
    // Note: in this case, the start destination must also be the end destination (for now)
    //      the TSP is optimized in such a way that does not consider paths returning back to
    //      the start location (destinations[0]). This should be optimal.
    func computeClusteredOptimalPath(numTravelers: Int,
                                     completion: (([[MKMapItem]]) -> Void)) {
        assert(numTravelers > destinations.count)
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
                - (distance(bestPath[0], bestPath[1]) + distance(bestPath[bestPath.count - 2], bestPath.last!)))
                / Double(numTravelers)
            
            var pathSlices = [(Int, Int)]()
            var distanceAccumulator = 0.0
            var sliceStartIndexIndex = 1 // NOTE: this is an index into bestPath. Start at 1 to generalize skipping destinations[0]
            // WARNING: assuming bestPath[0] == destinations[0] and that bestPath.last == 0
            
            for i in 1..<bestPath.count-1 { // excludes connect from start to 2nd vertex and penultimate back to start
                let v1IndexIndex = i
                let v2IndexIndex = i + 1 // should never equal .count or .count - 1
                distanceAccumulator += distance(bestPath[v1IndexIndex], bestPath[v2IndexIndex])
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
                return distance(0, a) > distance(0, b) // descending by distance from start
            }
            let verticesCutSet = Set(sortedIndices[..<numTravelers])
            assert(distance(sortedIndices[0], 0) > distance(sortedIndices[1], 0))
            
            // step 2.2: find places to split to generate alternative path
            var alternativeSubpathSlices = [[Int]]()
            for i in 1..<bestPath.count - 2 {
                if verticesCutSet.contains(bestPath[i]) { // if a very distant node, decide to either attach to next node or previous node
                    if let prevNodeIndex = alternativeSubpathSlices.last?.last, i + 1 <= bestPath.count - 2 {
                        // case where we have a previous and next node
                        let nextNodeIndex = bestPath[i+1]
                        if distance(prevNodeIndex, bestPath[i]) < distance(bestPath[i], nextNodeIndex) {
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
            assert(subpathSlices.reduce(0) { $0 + $1.count } == destinations.count,
                   "incorrect destination count in pathSlices")
            assert(alternativeSubpathSlices.reduce(0) { $0 + $1.count } == destinations.count,
                   "incorrect destination count in alternativeSubpathSlices")

                        
            // last step: compare our main subpath avg lengths with our alternative subpath lengths
            // as a heuristic, remove most expensive path from both to allow one outlier to exist
            let alternativeReconnectedSubpathLength = alternativeSubpathSlices.map { slice -> Double in
                var sum: Double = 0.0
                for i in 0..<slice.count - 1 {
                    sum += distance(slice[i], slice[i+1])
                }
                sum += distance(slice[0], 0)
                sum += distance(slice.last!, 0)
                return sum
            }.reduce(0.0) { $0 + $1 }
            
            let reconnectedSubpathLength = subpathSlices.map { slice -> Double in
                var sum: Double = 0.0
                for i in 0..<slice.count - 1 {
                    sum += distance(slice[i], slice[i+1])
                }
                sum += distance(slice[0], 0)
                sum += distance(slice.last!, 0)
                return sum
            }.reduce(0.0) { $0 + $1 }
            
            var subpathsOutput = [[MKMapItem]]() // should not include connections back to start (0 - ... - 0)
            // if better to take our heuristic-generated split, use it
            if alternativeReconnectedSubpathLength < reconnectedSubpathLength {
                subpathsOutput = alternativeSubpathSlices.map { $0.map { destinations[$0] } }
            } else {
                subpathsOutput = subpathSlices.map { $0.map { destinations[$0] } }
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
    
    private func distance(_ a: Int, _ b: Int) -> Double {
        if a == b { return 0.0 }
        let large = max(a,b)
        let small = min(a,b)
        return distanceMatrix[large][small]
    }
    
    private func resetPriorData() {
        distanceMatrix.removeAll()
        bestPath.removeAll()
        bestPathDistance = .infinity
    }
    
    private func computeOptimalTour() {
        computePathUpperBound() // updates pathUpperBound and Distance
        
    }
    
    private func computePathUpperBound() {
        // TODO: make this work after proving that generatePermutations works
        bestPath = Array(0..<destinations.count)
        bestPathDistance = 0.0
        for i in 0..<bestPath.count {
            bestPathDistance += distance(bestPath[i], bestPath[i+1 % bestPath.count])
        }
    }
    
    private func generatePermutations(permLength: Int, growingDistance: Double) {
        if growingDistance > bestPathDistance {
            return
        }
        
        if permLength == permutation.count {
            let testDistance = growingDistance + distance(0, permutation.last!)
            if testDistance < bestPathDistance {
                bestPath = permutation
                bestPathDistance = testDistance
            }
            return
        }
        
        if !promising(permLength, growingDistance) {
            return
        }
        
        for i in permLength..<permutation.count {
            swap(&permutation[permLength], &permutation[i])
            let nextEdge = distance(permutation[permLength - 1], permutation[permLength])
            generatePermutations(permLength: permLength + 1, growingDistance: growingDistance + nextEdge)
            swap(&permutation[permLength], &permutation[i])
        }
    }
    
    // tell whether adding the count - permLength nodes can possibly produce an optimal path
    private func promising(_ permLength: Int, _ pathDistance: Double) -> Bool {
        // compute MST on remaining vertices
        
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
                let dist = distance(permutation[i], permutation[currentVertex])
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
            let leftDist = distance(permutation[0], permutation[i])
            let rightDist = distance(permutation[permLength - 1], permutation[i])
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