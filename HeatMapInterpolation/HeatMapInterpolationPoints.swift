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

class HeatMapInterpolationPoints {
    
    private var data: [[Double]]
    private var nVal: Double
    private let minLat: Int = -900
    private let minLong: Int = -1800
    private let maxLat: Int = 900
    private let maxLong: Int = 1800
    private var newPoints = [GMUWeightedLatLng]()
    
    private let distanceScale: Double = 0 /// Should make the distanceWeights to be as close to 1 as possible
    
    init(dataset: [[Double]], n: Double) {
        data = dataset
        nVal = n
    }
    
    private func distance(lat1: Double, long1: Double, lat2: Double, long2: Double) -> Double {
        return sqrt(pow(abs(lat2 - lat1), 2) + pow(abs(long2 - long1), 2))
    }
    
    public func interpolate() -> [GMUWeightedLatLng] {
        for i in minLat...maxLat {
            for j in minLong...maxLong {
                let realLat: Double = Double(i) / 10
                let realLong: Double = Double(j) / 10
                var numerator: Double = 0
                var denominator: Double = 0
                for point in data {
                    let dist = distance(
                        lat1: realLat,
                        long1: realLong,
                        lat2: point[0],
                        long2: point[1]
                    )
                    let distanceWeight = pow(dist, Double(nVal))
                    if distanceWeight == 0 {
                        continue
                    }
                    numerator += (point[2] / distanceWeight)
                    denominator += (1 / distanceWeight)
                }
                if denominator == 0 || numerator < 3 {
                    continue
                }
                let coords = GMUWeightedLatLng(
                    coordinate: CLLocationCoordinate2DMake(realLat, realLong),
                    intensity: Float(numerator / denominator)
                )
                newPoints.append(coords)
            }
        }
        return newPoints
    }
}
