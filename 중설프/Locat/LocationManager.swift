import Foundation
import CoreLocation
import Combine

// 💡 NSObject를 상속받아야 CLLocationManagerDelegate 기능을 쓸 수 있어!
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // 화면(UI)에 바로 뿌려줄 데이터들 (위도/경도, 텍스트 주소)
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String = "위치 찾는 중... 🗺️"
    @Published var isAuthorized: Bool = false
    
    override init() {
        super.init()
        manager.delegate = self
        // 배터리를 좀 쓰더라도 GPS 정확도를 제일 높게 세팅! (사물 스캔용이니까)
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // 1. 위치 권한 묻기 (카메라 권한 물어볼 때 같이 부르면 돼)
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    // 2. 권한 상태가 바뀌면 자동으로 실행되는 델리게이트 함수
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation() // 허락받으면 위치 추적 시작!
        default:
            isAuthorized = false
            currentAddress = "위치 권한이 필요합니다."
        }
    }
    
    // 3. 위치가 업데이트될 때마다 위도/경도를 받아오는 함수
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        // 위도, 경도만 있으면 제미나이가 어딘지 잘 모르니까 텍스트 주소로 변환!
        fetchAddress(from: location)
    }
    
    // 4. 마법의 CLGeocoder (위도/경도 -> "부산광역시 해운대구 우동")
    private func fetchAddress(from location: CLLocation) {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "ko_KR") // 한국어 주소로 강제 설정
        
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
            if let _ = error {
                DispatchQueue.main.async { self.currentAddress = "주소를 찾을 수 없습니다." }
                return
            }
            
            guard let placemark = placemarks?.first else { return }
            
            // 시, 구, 동 데이터 뽑아내기
            let city = placemark.administrativeArea ?? ""       // 예: 부산광역시
            let locality = placemark.locality ?? ""             // 예: 해운대구
            let subLocality = placemark.subLocality ?? ""       // 예: 우동
            
            let address = "\(city) \(locality) \(subLocality)".trimmingCharacters(in: .whitespaces)
            
            DispatchQueue.main.async {
                self.currentAddress = address.isEmpty ? "알 수 없는 위치" : address
            }
        }
    }
}
