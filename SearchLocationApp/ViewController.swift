import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate , AVSpeechSynthesizerDelegate{

    let mapView = MKMapView()

    var route: MKRoute?
    var steps: [MKRoute.Step] = []
    var stepCounter = 0
    var showMapRoute = false
    var navigationStarted = false
    var locationDistance: Double = 500
    
    var updateMap : Bool = false

    var speechSynth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    
    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        return locationManager
    }()


    lazy var directionLabel: UILabel = {
        let label = UILabel()
        label.text = "Where do you want to go ?"
        label.font = .boldSystemFont(ofSize: 10)
        label.tintColor = .black
        label.backgroundColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.clipsToBounds = true
        return label
    }()

    lazy var textField: UITextField = {
        let text = UITextField()
        text.placeholder = "Enter your destination"
        text.borderStyle = .roundedRect
        text.tintColor = .black
        text.backgroundColor = .white
        return text
    }()

    lazy var getDirectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get directions", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(getDirectionButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var startNavigationButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start Navigation", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(startNavigationButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [getDirectionButton, startNavigationButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        return stackView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(directionLabel)
        view.addSubview(textField)
        view.addSubview(buttonStackView)
        view.addSubview(mapView)
        
        locationManager.startUpdatingLocation()
        locationManager.requestWhenInUseAuthorization()
       
     
        mapView.showsUserLocation = true
        mapView.delegate = self
        locationManager.distanceFilter = 50.0
        speechSynth.delegate = self

        
        
        title = "Maps"
    }


    override func viewDidLayoutSubviews() {
        let topPadding: CGFloat = 20
        let elementWidth = view.bounds.width - 40
        let elementHeight: CGFloat = 40

        directionLabel.frame = CGRect(x: 20, y: view.safeAreaInsets.top + topPadding, width: elementWidth, height: elementHeight)
        textField.frame = CGRect(x: 20, y: directionLabel.frame.maxY + 10, width: elementWidth, height: elementHeight)
        buttonStackView.frame = CGRect(x: 20, y: textField.frame.maxY + 10, width: elementWidth, height: elementHeight)
        
        mapView.frame = CGRect(x: 0, y: buttonStackView.frame.maxY + 10, width: view.bounds.width, height: view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - buttonStackView.frame.maxY)
    }

    @objc func getDirectionButtonTapped() {
        guard let text = textField.text, !text.isEmpty else {
            return
        }
        textField.endEditing(true)

        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(text) { placemarks, error in
            if let error = error {
                print(error.localizedDescription)
        }
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No location found for the provided address.")
                return
            }
            let destinationCoordinate = location.coordinate

            self.drawRoute(to: destinationCoordinate)
           
        }
    }
    
    func drawRoute(to destinationCoordinate: CLLocationCoordinate2D) {
        guard let sourceCoordinate = locationManager.location?.coordinate else { return }
        
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        
        // Rota çizimi için yönlendirme isteği oluştur
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile  // Ulaşım türü, örneğin arabayla
        
        // Yönlendirme hesaplama
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print(error.localizedDescription)
            }
            guard let response = response , let route = response.routes.first else {return}
            self.route = route
            self.mapView.addOverlay(route.polyline)
            self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
            self.getRouteSteps(route: route)
        }
    }
    
    func getRouteSteps(route: MKRoute) {
        for monitoredRegion in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        
        let steps = route.steps
        self.steps = steps
        
        for i in 0..<steps.count {
            let step = steps[i]
            print(step.instructions)
            print(step.distance)
            
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)")
            locationManager.startMonitoring(for: region)
        }
        stepCounter += 1
        
        let message = "Yol tarifi başlatıldı: \(steps[stepCounter].instructions)."

        
              directionLabel.text = message
              
              let speechUtterance = AVSpeechUtterance(string: message)
              speechSynth.speak(speechUtterance)
              
              // Başlangıç adımına geç
              stepCounter += 1
    }



    
    @objc func startNavigationButtonTapped() {
        if !navigationStarted {
            showMapRoute = true
            startNavigationButton.endEditing(true)
            if let location = locationManager.location {
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
            navigationStarted = true
            startNavigationButton.setTitle("Stop Navigation", for: .normal)
        } else {
            if let route = route {
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
                self.steps.removeAll()
                self.stepCounter = 0
                navigationStarted = false
                startNavigationButton.setTitle("Start Navigation", for: .normal)
            }
        }
    }

    
    
   
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    
    
    
    
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
       
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let userLocation = self.locationManager.location?.coordinate {
                
                DispatchQueue.main.async {
                    self.centerViewToUserLocation(center: userLocation)
                }
            }
            print("Location access granted.")
        case .denied, .restricted:
            print("Location access denied.")
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
            print("Location access not determined.")
        @unknown default:
            fatalError("Unhandled authorization status.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("did enter region")
    }

    
    func centerViewToUserLocation(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: center, latitudinalMeters: locationDistance, longitudinalMeters: locationDistance )
        mapView.setRegion(region, animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let center = location.coordinate
            centerViewToUserLocation(center: center)
        }
    }

}
