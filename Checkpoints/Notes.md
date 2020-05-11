#  Notes

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
