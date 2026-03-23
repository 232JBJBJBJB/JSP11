import Foundation
import CoreMotion
import Combine

// 1. 서버와 주고받을 데이터 구조체 정의
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
    
    // MARK: - Step 1: WebSocket 파이프라인 개통
    func connect() {
        // 서버 주소는 실제 AWS 서버 주소로 변경 필요
        let url = URL(string: "ws://your-aws-server-address:port")! 
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        print("🌐 WebSocket 연결 시도 중...")
        receiveData()      // 수신 대기 시작
        startMotionUpdates() // 센서 데이터 송신 시작
    }
    
    // MARK: - Step 2: 센서 데이터 택배 포장 및 송신
    private func startMotionUpdates() {
        // 초당 30~60회 갱신 설정 (이미지 가이드 준수)
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let motion = motion, error == nil else { return }
                
                // CoreMotion 데이터 추출
                let data = SensorData(
                    pitch: motion.attitude.pitch,
                    roll: motion.attitude.roll,
                    yaw: motion.attitude.yaw
                )
                
                self?.sendSensorData(data)
            }
        }
    }
    
    private func sendSensorData(_ data: SensorData) {
        guard let jsonData = try? JSONEncoder().encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("❌ 송신 에러: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Step 3: 좌표 데이터 수신 및 처리
    private func receiveData() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let coord = try? JSONDecoder().decode(CalculatedCoordinate.self, from: data) {
                        DispatchQueue.main.async {
                            // 메인 스레드에서 UI 데이터 갱신
                            self?.targetCoordinate = coord
                        }
                    }
                default: break
                }
                // 연속 수신을 위해 재귀 호출
                self?.receiveData() 
                
            case .failure(let error):
                print("❌ 수신 에러: \(error.localizedDescription)")
            }
        }
    }
    
    func disconnect() {
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}