import Foundation
import CoreMotion
import Combine

// MARK: - 1. 데이터 구조체 정의 (이미지 가이드 준수)
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

class ARNetworkManager: ObservableObject {
    // UI 업데이트를 위한 발표자 (Step 3)
    @Published var targetCoordinate: CalculatedCoordinate?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let motionManager = CMMotionManager()
    private let session = URLSession(configuration: .default)
    private var simulationTimer: Timer?
    
    // MARK: - Step 1: 연결 시뮬레이션
    func connect() {
        print("🌐 [시뮬레이션 모드] 서버 연결 없이 로직을 테스트합니다.")
        
        // 1. 센서 데이터 수집 시작 (송신부 로직 확인용)
        startMotionUpdates()
        
        // 2. 가짜 데이터 수신 시작 (수신부 및 UI 확인용)
        startSimulation()
    }
    
    // MARK: - Step 2: 센서 데이터 수집 (실제 작동)
    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let motion = motion, error == nil else { return }
                
                // 센서 값 포장
                let data = SensorData(
                    pitch: motion.attitude.pitch,
                    roll: motion.attitude.roll,
                    yaw: motion.attitude.yaw
                )
                // 실제 서버 연결 시 사용: self?.sendSensorData(data)
            }
        }
    }
    
    // MARK: - Step 3: 좌표 수신 시뮬레이션 (2초마다 랜덤 좌표 생성)
    private func startSimulation() {
        simulationTimer?.invalidate()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let dummyJSON = """
            {
                "word_id": "simulated_word_01",
                "screenX": \(Double.random(in: 50...300)),
                "screenY": \(Double.random(in: 100...600))
            }
            """
            
            if let data = dummyJSON.data(using: .utf8) {
                do {
                    let coord = try JSONDecoder().decode(CalculatedCoordinate.self, from: data)
                    DispatchQueue.main.async {
                        self?.targetCoordinate = coord
                        print("🎯 [시뮬레이션] 수신 좌표: (\(Int(coord.screenX)), \(Int(coord.screenY)))")
                    }
                } catch {
                    print("❌ 디코딩 에러: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func disconnect() {
        print("🔌 연결 및 시뮬레이션 종료")
        simulationTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    private func receiveData() { }
    private func sendSensorData(_ data: SensorData) { }
}