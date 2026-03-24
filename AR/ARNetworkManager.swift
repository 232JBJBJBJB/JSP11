import Foundation
import CoreMotion
import Combine

// MARK: - 1. 데이터 구조체 정의
struct SensorData: Codable {
    let pitch: Double
    let roll: Double
    let yaw: Double
}

struct CalculatedCoordinate: Codable {
    let word_id: String
    let screenX: Double
    let screenY: Double
}

// MARK: - 2. 네트워크 매니저 클래스
class ARNetworkManager: ObservableObject { // <--- 여기에 { 가 반드시 있어야 합니다!
    
    @Published var targetCoordinate: CalculatedCoordinate?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let motionManager = CMMotionManager()
    private let session = URLSession(configuration: .default)
    private var simulationTimer: Timer?
    
    // 연결 시뮬레이션 시작
    func connect() {
        print("🌐 [시뮬레이션 모드] 서버 연결 없이 로직을 테스트합니다.")
        startMotionUpdates()
        startSimulation()
    }
    
    // 센서 데이터 수집 로직
    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let _ = motion, error == nil else { return }
            }
        }
    }
    
    // 가짜 좌표 생성 시뮬레이션
    private func startSimulation() {
        simulationTimer?.invalidate()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let x = Double.random(in: 50...300)
            let y = Double.random(in: 100...600)
            
            let dummyJSON = """
            {
                "word_id": "simulated_01",
                "screenX": \(x),
                "screenY": \(y)
            }
            """
            
            guard let data = dummyJSON.data(using: .utf8) else { return }
            
            do {
                let coord = try JSONDecoder().decode(CalculatedCoordinate.self, from: data)
                DispatchQueue.main.async {
                    self?.targetCoordinate = coord
                    print("🎯 [수신 성공] 좌표: (\(Int(coord.screenX)), \(Int(coord.screenY)))")
                }
            } catch {
                print("❌ 디코딩 실패: \(error)")
            }
        }
    }
    
    func disconnect() {
        print("🔌 시뮬레이션 종료")
        simulationTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    private func receiveData() { }
    private func sendSensorData(_ data: SensorData) { }

}