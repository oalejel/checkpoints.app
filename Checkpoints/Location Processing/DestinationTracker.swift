//
//  DestinationTracker.swift
//  Checkpoints
//
//  Created by Omar Al-Ejel on 8/24/20.
//  Copyright © 2020 Omar Al-Ejel. All rights reserved.
//

import Foundation
import MapKit

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
        print("APPEND - \(distanceMatrix.count) - \(mapItem.name ?? mapItem.placemark.subtitle ?? "no useful name?")")
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
        
    func assertsomething() {
        let _: [[(Int, Int)]] = [
            [],
            [(1, 0)],
            [(2, 0), (2, 1)],
            [(3, 0), (3, 1), (3, 2)],
            [(4, 0), (4, 1), (4, 2), (4, 3)],
            [(5, 0), (5, 1), (5, 2), (5, 3), (5, 4)]
        ]

    }
}
