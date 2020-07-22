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
    private var nVal: Int
    private let minLat: Int = -3400
    private let minLong: Int = 14400
    private let maxLat: Int = -2700
    private let maxLong: Int = 16530
    private var newPoints = [GMUWeightedLatLng]()
    
    private let distanceScale: Double = 0 /// Should make the distanceWeights to be as close to 1 as possible
    
    init(dataset: [[Double]], n: Int) {
        data = dataset
        nVal = n
    }
    
    private func distance(lat1: Double, long1: Double, lat2: Double, long2: Double) -> Double {
        return sqrt(exponent(base: abs(lat2 - lat1), power: 2) + exponent(base: abs(long2 - long1), power: 2))
    }
    
    private func exponent(base: Double, power: Int) -> Double {
        let originalBase = base
        var ans = base
        for _ in 1...power {
            ans *= originalBase
        }
        return ans
    }
    
    public func interpolate() -> [GMUWeightedLatLng] {
        var counter: Int = 0
        for i in minLat...maxLat {
            for j in minLong...maxLong {
                let realLat: Double = Double(i) / 100
                let realLong: Double = Double(j) / 100
                var numerator: Double = 0
                var denominator: Double = 0
                for point in data {
                    let distanceWeight = exponent(
                        base: distance(
                            lat1: realLat,
                            long1: realLong,
                            lat2: point[0],
                            long2: point[1]
                        ),
                        power: nVal
                    )
                    if (distanceWeight > 20 || distanceWeight == 0) {
                        continue
                    }
                    numerator += (point[2] / distanceWeight)
                    denominator += (1 / distanceWeight)
                }
                if (denominator == 0) {
                    continue
                }
                let coords = GMUWeightedLatLng(
                    coordinate: CLLocationCoordinate2DMake(realLat, realLong),
                    intensity: Float(numerator / denominator)
                )
                newPoints.append(coords)
                counter += 1
                //print(String(numerator) + " " + String(denominator) + " " + String(numerator / denominator))
            }
        }
        print(counter)
        return newPoints
    }
}
