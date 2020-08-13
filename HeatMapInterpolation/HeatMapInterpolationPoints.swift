/* Copyright (c) 2020 Google Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
import GooglePlaces
import GoogleMaps
import GoogleMapsUtils

/// This class will create artificial points in surrounding locations with appropriate intensities interpolated by neighboring intensity values.
class HeatMapInterpolationPoints {
    
    /// The input data set
    private var data = [GMUWeightedLatLng]()
    
    /// The list of interpolated heat map points with weight
    private var heatMapPoints = [GMUWeightedLatLng]()
    
    /// Indicates the number of times k-means clustering should execute; will be set in the constructor to 25 by default
    private var clusterIterations: Int!
    
    /// Normalizing factors to convert from 2D to longitude and latitude; these values were needed since each GMUWeightedLatLng
    /// point contains a .point() field, which is a GQTPoint. The point value for the GQTPoint should be equivalent to a GMSMapPoint,
    /// with range [-1.0, 1.0]. I found that multiplying the latitude and longitude by the following numbers correctly converts the
    /// GQTPoint value (which was all from -1.0 to 1.0) to the latitude and longitude input (as CLLocationCoordinate2D).
    private let normalLat = 175.9783070993
    private let normalLong = 180.0
    
    /// The constructor to this class
    ///
    /// - Parameter givenClusterIterations: The number of iterations k-means clustering should go to.
    init(givenClusterIterations: Int = 25) {
        clusterIterations = givenClusterIterations
    }
    
    // MARK: Functions that parse given data needed to build an interpolated heat map from
    
    /// Adds a list of GMUWeightedLatLng objects to the input data set
    ///
    /// - Parameter latlngs: The list of GMUWeightedLatLng objects to add.
    public func addWeightedLatLngs(latlngs: [GMUWeightedLatLng]) {
        data.append(contentsOf: latlngs)
    }
    
    /// Adds a single GMUWeightedLatLng object to the input data set
    ///
    /// - Parameter latlngs: The list of GMUWeightedLatLng objects to add.
    public func addWeightedLatLng(latlng: GMUWeightedLatLng) {
        data.append(latlng)
    }
    
    /// Removes all previously supplied GMUWeightedLatLng objects
    public func removeAllData() {
        data.removeAll()
    }
    
    // MARK: Functions that directly contribute to the creation of interpolated points
        
    /// A helper function that calculates the straight-line distance between two coordinates
    ///
    /// - Parameters:
    ///   - lat1: The latitude value of the first point.
    ///   - long1: The longitude value of the second point.
    ///   - lat2: The latitude value of the second point.
    ///   - long2: The longitude value of the second point.
    /// - Returns: A double value representing the distance between the given points.
    private func distance(lat1: Double, long1: Double, lat2: Double, long2: Double) -> Double {
        
        // The GMSGeometryDistance function returns the distance between two coordinates in meters;
        // according to this source, https://en.wikipedia.org/wiki/Decimal_degrees, conversion from
        // meters to lat/long is around 111.32 kilometers per degree. Starting from this conversion,
        // I manually checked the distance returned by GMSGeometryDistance and the lat/long distance
        // and the normalizingFactor was found accordingly, which is pretty similar to the number
        // found in the source.
        let normalizingFactor = 111195.0837241998
        return GMSGeometryDistance(
            CLLocationCoordinate2D(latitude: lat1, longitude: long1),
            CLLocationCoordinate2D(latitude: lat2, longitude: long2)
        ) / normalizingFactor
    }
    
    /// Finds the average latitude and longitude values; see http://mathforum.org/library/drmath/view/63491.html
    ///
    /// - Parameter points: The list of points to take the average from.
    /// - Returns: A CLLocationCoordinate2D object resembling the average value.
    private func findAverage(points: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        var totalX: Double = 0
        var totalY: Double = 0
        var totalZ: Double = 0
        for point in points {
            totalX += cos(point.latitude * Double.pi / 180) * cos(point.longitude * Double.pi / 180)
            totalY += cos(point.latitude * Double.pi / 180) * sin(point.longitude * Double.pi / 180)
            totalZ += sin(point.latitude * Double.pi / 180)
        }
        totalX /= Double(points.count)
        totalY /= Double(points.count)
        totalZ /= Double(points.count)
        let long: Double = atan2(totalY, totalX)
        let central: Double = sqrt(totalY * totalY + totalX * totalX)
        let lat: Double = atan2(totalZ, central)
        return CLLocationCoordinate2D(
            latitude: lat * 180 / Double.pi,
            longitude: long * 180 / Double.pi
        )
    }
    
    /// A helper function that utilizes the k-cluster algorithm to cluster the input data points together into reasonable sets; the number of
    /// clusters is set so that the maximum distance between the center and any point is less than a set constant value. For more
    /// details, please visit https://stanford.edu/~cpiech/cs221/handouts/kmeans.html
    ///
    /// - Returns: A list of clusters, each of which is a list of CLLocationCoordinate2D objects.
    private func kcluster() -> [[CLLocationCoordinate2D]] {
        
        // Centers contain double values representing the center of their respective clusters found
        // in the clusters list
        var centers = [CLLocationCoordinate2D]()
        var clusters = [[CLLocationCoordinate2D]]()
        
        // Try to make as few clusters as possible; start with 1 and increment as needed
        var numClusters = 1
        
        if (data.count > 0) {
            
            // We need to keep on finding clusters until the maximum distance between the center
            // and any point in its cluster is under a specific preset value
            while true {
                
                // Set the first numClusters values in data set to be the initial cluster centers
                for i in 0...numClusters - 1 {
                    centers.append(CLLocationCoordinate2D(
                        latitude: data[i].point().y * normalLat,
                        longitude: data[i].point().x * normalLong)
                    )
                    let tempArray = [CLLocationCoordinate2D]()
                    clusters.append(tempArray)
                }
                
                // 25 iterations of updating the center and recalculating the points in that cluster
                // should be adequet, as k-means clustering has diminishing returns as the number of
                // iterations increases
                for _ in 0...clusterIterations {
                    
                    // Reset the clusters so that it can be updated
                    for i in 0...numClusters - 1 {
                        clusters[i].removeAll()
                    }
                    
                    // Finds the appropriate cluster for each data point
                    for point in data {
                        var minDistance: Double = distance(
                            lat1: point.point().y * normalLat,
                            long1: point.point().x * normalLong,
                            lat2: centers[0].latitude,
                            long2: centers[0].longitude
                        )
                        var index = 0
                        for i in 0...centers.count - 1 {
                            let tempDistance: Double = distance(
                                lat1: point.point().y * normalLat,
                                long1: point.point().x * normalLong,
                                lat2: centers[i].latitude,
                                long2: centers[i].longitude
                            )
                            if minDistance >= tempDistance {
                                minDistance = tempDistance
                                index = i
                            }
                        }
                        clusters[index].append(CLLocationCoordinate2D(
                            latitude: point.point().y * normalLat,
                            longitude: point.point().x * normalLong
                            )
                        )
                    }
                    
                    // Update the center values to reflect new cluster points
                    centers.removeAll()
                    for cluster in clusters {
                        centers.append(findAverage(points: cluster))
                    }
                }
                
                // Test if we can stop increasing the number of clusters
                var breaker = false
                for i in 0...numClusters - 1 {
                    for coord in clusters[i] {
                        let radius = distance(
                            lat1: centers[i].latitude,
                            long1: centers[i].longitude,
                            lat2: coord.latitude,
                            long2: coord.longitude
                        )
                        
                        // This is a set bound for the radius of each cluster; radius is defined
                        // here as the distance from a point in the cluster to the cluster center.
                        // If the radius is over 50 degrees, then the code will refine by creating
                        // more clusters; this number can be changed if larger or smaller clusters
                        // are desired.
                        if (radius > 50) {
                            breaker = true
                            break
                        }
                    }
                    if breaker {
                        break
                    }

                }
                if !breaker {
                    break
                }
                clusters.removeAll()
                centers.removeAll()
                numClusters += 1
            }
        }
        return clusters
    }
    
    /// A helper function that finds the intensity of a given point, represented by realLat and realLong, based on the input data set; this is
    /// calculated via formula here: https://gisgeography.com/inverse-distance-weighting-idw-interpolation/
    ///
    /// - Parameters:
    ///   - lat: The latitude value of the point.
    ///   - long: The longitude value of the point.
    ///   - n: The n-value, determining the range of influence the intensities found in the given data set has.
    /// - Returns: A list containing just the numerator and denominator
    private func findIntensity(lat: Double, long: Double, n: Double) -> [Double] {
        var numerator: Double = 0
        var denominator: Double = 0
        for point in self.data {
            let dist = self.distance(
                lat1: lat,
                long1: long,
                lat2: point.point().y * normalLat,
                long2: point.point().x * normalLong
            )
            let distanceWeight = pow(dist, Double(n))
            if distanceWeight == 0 {
                continue
            }
            numerator += (Double(point.intensity) / distanceWeight)
            denominator += (1 / distanceWeight)
        }
        return [numerator, denominator]
    }
    
    /// A helper function that finds the minimum and maximum longitude and latitude values that still contains a powerful enough
    /// intensity that it should be included in the data set
    ///
    /// - Parameters:
    ///     - input: A list of points that are in a cluster.
    ///     - n: The power value that determines the dropoff rate of intensities with respect to the distance from given points
    /// - Returns: A list of four integers representing the minimum and maximum longitude and latitude values
    private func findBounds(input: [CLLocationCoordinate2D], n: Double) -> [Int] {
        
        // Initialize the boundary values to something that must be updated immediately
        // 0: min lat, 1: min long, 2: max lat, 3: max long
        var ans = [0x7fffffff, 0x7fffffff, -0x7fffffff, -0x7fffffff]
        for coord in input {
            ans[0] = min(ans[0], Int(coord.latitude * 10))
            ans[1] = min(ans[1], Int(coord.longitude * 10))
            ans[2] = max(ans[2], Int(coord.latitude * 10))
            ans[3] = max(ans[3], Int(coord.longitude * 10))
        }
        return ans
    }
    
    /// Generates several heat maps based on the clusters with points not found in the data set interpolated by the inverse distance
    /// means interpolation algorithm and displays the heat maps on the given map; for more details, please visit
    /// https://en.wikipedia.org/wiki/Inverse_distance_weighting. I used the basic form.
    ///
    /// - Parameters:
    ///   - mapView: The map that we want to display the heat maps on.
    ///   - n: The n-value, determining the range of influence the intensities found in the given data set has.
    public func generateHeatMaps(n: Double) -> [GMUWeightedLatLng] {
        
        // It doesn't make too much sense to do interpolation on an n-value of less than 2 or
        // greater than 2.5; when n is higher, the denominator increases quicker, meaning the
        // overall value falls quicker as the distances increase, implying that a low n value will
        // query far too many points
        if n < 2 || n > 2.5 {
            return []
        }
        heatMapPoints.removeAll()
        
        // Clusters is the list of clusters that we intend to return
        let clusters = kcluster()
        for cluster in clusters {
            let bounds = findBounds(input: cluster, n: n)
            // A small n-value implies a large range of points that could be potentially be
            // affected, so it makes sense to increase the stride to improve runtime and the range
            // to improve the quality of the heat map
            let step = 3
            
            // These two values bound the search range of the heat map; any larger range provides
            // marginal improvements, if any, in the resulting heat map, as found via trial and
            // error and testing with various data sets
            let latRange = 150
            let longRange = 200
            
            // Search all the points between the bounds of the cluster; the offset indicates how
            // far beyond the bounds we want to query
            for i in stride(from: bounds[0] - latRange, to: bounds[2] + latRange, by: step) {
                
                // Since latitude ranges from -90 to 90 and the granularity is 0.1, we can move from
                // -900 to 900
                if i > 900 || i < -900 {
                    break
                }
                for j in stride(from: bounds[1] - longRange, to: bounds[3] + longRange, by: step) {
                    
                    // Since longitude ranges from -180 to 180 and the granularity is 0.1, we can
                    // move from -1800 to 1800
                    if j > 1800 || j < -1800 {
                        break
                    }
                    
                    // The variable, intensity, contains the numerator and denominator
                    let intensity = findIntensity(
                        lat: Double(i) / 10,
                        long: Double(j) / 10,
                        n: n
                    )
                    
                    // If the numerator value is too small, that point is worthless as it is too
                    // far away or too weak; if the denominator is 0, we get a divide by 0 error
                    if intensity[1] == 0 || intensity[0] < 3 {
                        continue
                    }
                    // Set the intensity based on IDW
                    let coords = GMUWeightedLatLng(
                        coordinate: CLLocationCoordinate2DMake(Double(i) / 10, Double(j) / 10),
                        intensity: Float(intensity[0] / intensity[1])
                    )
                    heatMapPoints.append(coords)
                }
            }
        }
        return heatMapPoints
    }
}
