#  Notes

to consider
- may want to update "current location" default checkpoint to show that its no longer correct if the user moves. this requires repeatedly geouncoding a location as long as the coordinate is at least some threshold number of meters away from the last current location, in order to either update teh cell's address, or mark the originally added one as unfresh 
- consider making accent on left of checkpoint cell be based on a temperature color corresponding to distance from current location

must add features for convenience 
- should allow a location in maps to export to this app to add a checkpoint 
- should allow favorites list from gmaps or apple maps to get imported 

- need error handelr for when you try to travel somewhere impossible like hamburg germany
- keep searchviewcontroller from unconiently sliding down after a checkpoint is added since it confuses the user when they immediately reach over and miss the search bar
- find out why searching the letter z gave this error ``2020-07-02 17:03:54.141699-0400 Checkpoints[14182:3337929] *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Invalid update: invalid number of rows in section 1. The number of rows contained in an existing section after the update (3) must be equal to the number of rows contained in that section before the update (2), plus or minus the number of rows inserted or deleted from that section (0 inserted, 0 deleted) and plus or minus the number of rows moved into or out of that section (0 moved in, 0 moved out).'
``
- 

## App story - group of travelers 
Volunteer group would like to deliver grocies to a number of addresses. The organizer imports a csv file of addresses, sets the number of volunteers in the app, and marks the common starting location. The app then processes optimal ways to cluster nodes in such a way that the total drive distance for volunteers is acceptable. The app shows a map overlay depicting each of the paths taken in a different color, 

## Things to worry about
- "fairness" in travel time among multiple travelers can be hard to establish, especially when there are a few very distance points that shift the burden of travel on other travelers a certain way. Consider having a setting that allows outliers to be assigned to a single person. 
- addresses may need to be re-verified by CoreLocation, which could cause issues with any wrong data. Testing on example input should show whether this will be an issue. 
- There are easily demonstrable destination sets for which a single driver handling the full set of locations will spend 2x less time than if three people handled those locations together. Example: a cluster of nearby houses that are all nearly equally distant from the start location. Being able to detect such groups is important, and you might want to give warnings to the user so that they avoid this scenario.

### Required version 1 features 
- ability to import CSV or pasted text list of locations
- specifying number of travelers 
- specify start location of travel 
- export separated sequences of locations 
- optimize travel time by crow-flies distance 

### Things to leave for a later version 
- active directions built into the app
- specify start location for each traveler 
- optimize travel time by drive time 
- support specifying 

### Things for a much later version 
- specifying intermediate travel capabilities, like bus, bike, or foot travel starting from certain locations 
- 


## TSP slicing algorithm 
**Use case:** multiple travelers, making travel distance fair so that they have similar total travel distances.

For k travelers, perform TSP on full set of destinations, then split into k subpaths such that travel distances are about the same. 

I believe this solution is the optimal solution to the problem of making travel distances as fair as possible. However, using some heuristics would save time in case computation time takes too long.

## Clustering algorithm ()
**Use case:** multiple travelers, making travel distance fair so that they have similar total travel distances.

For k travelers, we form k clusters of locations that are selected based on minimizing the distance from a graudally updated set of k centroids. Then, assign those clusters to the k individuals and perform a TSP algorithm on each. 

This algorithm is flawed, since it is by definition not optimal unless clusters are formed through some TSP. Solution: use TSP slicing algorithm


## Resources
- Good paper on clustering algorithm: 
https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0201868
