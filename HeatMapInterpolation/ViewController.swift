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

import UIKit
import GoogleMaps
import GooglePlaces
import GoogleMapsUtils

class ViewController: UIViewController {

    /// The heat map,  its data set, and other color setup
    private let heatMapLayer: GMUHeatmapTileLayer = GMUHeatmapTileLayer()
    private var heatMapPoints = [GMUWeightedLatLng]()
    private let gradientColors = [UIColor.green, UIColor.red]
    private let gradientStartheatMapPoints = [NSNumber(0.2), NSNumber(1.0)]
    
    private var mapView = GMSMapView()
    private var data = [[Double]]()

    override func viewDidLoad() {
        super.viewDidLoad()
        let camera = GMSCameraPosition.camera(withLatitude: -33.86, longitude: 145.20, zoom: 6.0)
        mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        self.view.addSubview(mapView)

        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: -33.86, longitude: 145.20)
        marker.title = "Sydney"
        marker.snippet = "Australia"
        marker.map = mapView
        
        let marker2 = GMSMarker()
        marker2.position = CLLocationCoordinate2D(latitude: -32, longitude: 145.20)
        marker2.title = "Sydney"
        marker2.snippet = "Australia"
        marker2.map = mapView
        executeHeatMap()
    }
    
    private func executeHeatMap() {
        do {
            guard let path = Bundle.main.url(forResource: "dataset", withExtension: "json") else {
                print("Data set path error")
                return
            }
            let data = try Data(contentsOf: path)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let object = json as? [[String: Any]] else {
                print("Could not read the JSON file or file is empty")
                return
            }
            for item in object {
                // Given the way the code parses through the json file, the lat and long can be
                // retrieved via item like a dictionary
                let lat: Double = item["lat"] as? CLLocationDegrees ?? 0.0
                let lng: Double = item["lng"] as? CLLocationDegrees ?? 0.0
                append(lat: lat, long: lng)
                
                // Creates a weighted coordinate for that lat and long; a weighted coordinate is
                // how the heatmap gets different colors
                let coords = GMUWeightedLatLng(
                    coordinate: CLLocationCoordinate2DMake(lat, lng),
                    intensity: 1.0
                )
                heatMapPoints.append(coords)
            }
        } catch {
            print(error.localizedDescription)
        }
        let interpolationController = HeatMapInterpolationPoints(dataset: data, n: 16)
        heatMapPoints.append(contentsOf: interpolationController.interpolate())
        heatMapLayer.weightedData = heatMapPoints
        heatMapLayer.map = mapView
        heatMapLayer.gradient = GMUGradient(
            colors: gradientColors,
            startPoints: gradientStartheatMapPoints,
            colorMapSize: 256
        )
    }
    
    private func append(lat: Double, long: Double) {
        var index: Int = 0
        for key in data {
            if key[0] == lat && key[1] == long {
                data[index][2] += 1
                return
            }
            index += 1
        }
        let temp: [Double] = [lat, long, 1]
        data.append(temp)
    }
}

