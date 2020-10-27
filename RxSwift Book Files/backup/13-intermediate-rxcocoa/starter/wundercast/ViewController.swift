/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import RxSwift
import RxCocoa
import MapKit

class ViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    @IBOutlet private var mapButton: UIButton!
    @IBOutlet private var geoLocationButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    
    private let bag = DisposeBag()
    private let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        style()
        
        let currentLocation = locationManager.rx.didUpdateLocations
            .map { locations in locations[0] }
            .filter { location in
                return location.horizontalAccuracy < kCLLocationAccuracyHundredMeters
        }
        
        let geoInput = geoLocationButton.rx.tap.asObservable().do(onNext: {
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.startUpdatingLocation()
        })
        
        let geoLocation = geoInput.flatMap {
            return currentLocation.take(1)
        }
        
        let geoSearch = geoLocation.flatMap { location in
            return ApiController.shared.currentWeather(at: location.coordinate)
                .catchErrorJustReturn(.dummy)
        }
        
        let searchInput = searchCityName.rx.controlEvent(.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
        
        let textSearch = searchInput.flatMap { text in
            return ApiController.shared.currentWeather(city: text)
                .catchErrorJustReturn(.dummy)
        }
        
        let mapInput = mapView.rx.regionDidChangeAnimated
            .skip(1)
            .map {
                [unowned self] _ in
                self.mapView.centerCoordinate
                
        }
        
        let mapSearch = mapInput.flatMap { coordinate in
            return ApiController.shared.currentWeather(at: coordinate)
                .catchErrorJustReturn(.dummy)
        }
        
        let weatherAroundSearch = mapView.rx.newCenterPosition.flatMapLatest { coordinate in
            return ApiController.shared.currentWeather(at: coordinate)
                .catchErrorJustReturn(.dummy)
        }
        
        let search = Observable.merge(geoSearch, textSearch, mapSearch, weatherAroundSearch)
            .asDriver(onErrorJustReturn: .dummy)
        
        // - Previous search impl.
        //        let search = searchInput.flatMapLatest { text in
        //            return ApiController.shared.currentWeather(city: text)
        //                .catchErrorJustReturn(ApiController.Weather.dummy)
        //        }
        //        .asDriver(onErrorJustReturn: ApiController.Weather.dummy)
         
        let weather = Observable.merge(geoSearch, textSearch)
            .asDriver(onErrorJustReturn: .dummy)
        
        weather
            .map { $0.cityName }
            .drive(searchCityName.rx.text)
            .disposed(by: bag)
        
        weather
            .map { $0.coordinate }
            .drive(mapView.rx.positionUpdate)
            .disposed(by: bag)
        
        let weatherAroundSearchFloat = weatherAroundSearch.map { _ in true }
        let searchInputFlag = searchInput.map { _ in true }
        let geoInputFlag = geoInput.map { _ in true }
        let mapInputFlag = mapInput.map { _ in true }
        let searchRequestFlag = search.map { _ in false }.asObservable()
        let running = Observable.merge(searchInputFlag, geoInputFlag, mapInputFlag, searchRequestFlag, weatherAroundSearchFloat)
            .startWith(true)
            .asDriver(onErrorJustReturn: false)
        
        search.map { "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: bag)
        
        search.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)
        
        running
            .skip(1)
            .drive(activityIndicator.rx.isAnimating)
            .disposed(by: bag)
        
        running
            .drive(tempLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(iconLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(humidityLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(cityNameLabel.rx.isHidden)
            .disposed(by: bag)
        
        // location
        locationManager.rx.didUpdateLocations.subscribe { (locations) in
            print(locations)
        }
        .disposed(by: bag)
        
        // map
        mapButton.rx.tap.subscribe(onNext: {
            self.mapView.isHidden.toggle()
        })
            .disposed(by: bag)
        
        // set map delegate
        mapView.rx.setDelegate(self)
            .disposed(by: bag)
        
        // take and show overlays
        search.map { [$0.overlay()] }
            .drive(mapView.rx.overlays)
            .disposed(by: bag)
    
        
//        .asDriver(onErrorJustReturn: .dummy)
//        .map { [$0.overlay()] }
//        .drive(mapView.rx.overlays)
//        .disposed(by: bag)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        Appearance.applyBottomLine(to: searchCityName)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Style
    
    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
        mapView.mapType = .satelliteFlyover
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let overlay = overlay as? ApiController.Weather.Overlay else {
            return MKOverlayRenderer()
        }
        let overlayView = ApiController.Weather.OverlayView(overlay: overlay, overlayIcon: overlay.icon)
        return overlayView
    }
    
}
