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
@MainActor // 🌟 Swift 6 UI 업데이트 스레드 안전성 보장
class ARNetworkManager: ObservableObject {
    @Published var targetCoordinate: CalculatedCoordinate?
    @Published var isConnected: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let motionManager = CMMotionManager()
    private let session = URLSession(configuration: .default)
    
    // ==========================================
    // 🔗 [실전 모드] AWS 서버 연결 로직
    // ==========================================
    func connect() {
        guard webSocketTask == nil else { return }
        
        // 🔗 조원이 알려준 실제 AWS 웹소켓 서버 주소로 교체 필요 (wss://...)
        guard let url = URL(string: "wss://your-aws-server-address/ar") else {
            print("⚠️ [경고] 올바른 서버 URL이 아닙니다.")
            return
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        print("🌐 AWS 웹소켓 서버에 연결을 시도합니다.")
        
        Task { await receiveData() }
        startMotionUpdates()
    }
    
    // 센서 데이터 수집
    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion, error == nil else { return }
                let data = SensorData(pitch: motion.attitude.pitch, roll: motion.attitude.roll, yaw: motion.attitude.yaw)
                self.sendSensorData(data) // 수집된 데이터를 서버로 전송
            }
        }
    }
    
    // 센서 데이터를 JSON으로 서버에 전송
    private func sendSensorData(_ data: SensorData) {
        guard isConnected, let task = webSocketTask else { return }
        if let jsonData = try? JSONEncoder().encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            task.send(.string(jsonString)) { _ in }
        }
    }
    
    // 서버로부터 계산된 좌표 수신
    private func receiveData() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            if case .string(let text) = message,
               let data = text.data(using: .utf8),
               let coord = try? JSONDecoder().decode(CalculatedCoordinate.self, from: data) {
                self.targetCoordinate = coord
            }
            // 계속해서 다음 메시지 대기
            if isConnected { await receiveData() }
        } catch {
            print("🔌 서버 연결이 끊어졌습니다: \(error.localizedDescription)")
            self.isConnected = false
        }
    }
    
    // 연결 종료 및 정리
    func disconnect() {
        print("🔌 AR 네트워크 연결 종료")
        isConnected = false
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
}
