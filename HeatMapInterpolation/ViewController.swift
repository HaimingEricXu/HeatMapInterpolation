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
    private var markers = [GMSMarker]()
    private var rendering = false
    
    @IBOutlet weak var renderButton: UIButton!
    
    private let alert = UIAlertController(
        title: "Render",
        message: "Enter an N value",
        preferredStyle: .alert
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        let camera = GMSCameraPosition.camera(withLatitude: -33.86, longitude: 145.20, zoom: 5.0)
        mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        view.addSubview(mapView)
        view.bringSubviewToFront(renderButton)
        alert.addTextField { (textField) in
            textField.text = ""
        }
        alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { [weak alert] (_) in
            // Force unwrapping is okay here because there has to be a text field (created above)
            self.executeHeatMap(nVal: Float(alert?.textFields![0].text ?? "0.0") ?? 0.0)
        }))
    }
    
    @IBAction func startRender(_ sender: Any) {
        self.present(alert, animated: true, completion: nil)
    }
    
    /// sync into background thread
    /// use a function with callback
    private func executeHeatMap(nVal: Float) {
        DispatchQueue.main.async {
            let activityView = UIActivityIndicatorView(style: .whiteLarge)
            activityView.center = self.view.center
            self.view.addSubview(activityView)
            self.view.bringSubviewToFront(activityView)
            activityView.startAnimating()
        }
        // is the rest of this on background thread?
        heatMapPoints.removeAll()
        heatMapLayer.weightedData = heatMapPoints
        heatMapLayer.map = nil
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
                let lat: Double = item["lat"] as? CLLocationDegrees ?? 0.0
                let lng: Double = item["lng"] as? CLLocationDegrees ?? 0.0
                append(lat: lat, long: lng)
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                markers.append(marker)
            }
            for marker in markers {
                marker.map = mapView
            }
        } catch {
            print(error.localizedDescription)
        }
        for point in data {
            let coords = GMUWeightedLatLng(
                coordinate: CLLocationCoordinate2DMake(point[0], point[1]),
                intensity: Float(point[2])
            )
            heatMapPoints.append(coords)
        }
        let interpolationController = HeatMapInterpolationPoints(dataset: data, n: Double(nVal))
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

extension UITextField {
    var floatValue : Float {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        let nsNumber = numberFormatter.number(from: text!)
        return nsNumber == nil ? 0.0 : nsNumber!.floatValue
    }
}
