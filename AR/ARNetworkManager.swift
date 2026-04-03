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
    
    // 🌟 시뮬레이션용 타이머 (합치면서 선언부 추가!)
    private var simulationTimer: Timer?
    
    // ==========================================
    // 🔗 [실전 모드] AWS 서버 연결 로직 (기본값)
    // ==========================================
    func connect() {
        guard webSocketTask == nil else { return }
        
        // 🔗 실제 AWS 서버 주소로 교체 필요 (wss://...)
        // 만약 주소가 비어있거나 테스트 중이라면 startSimulation()을 호출해도 됨!
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
        simulationTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // ==========================================
    // 🧪 [테스트 모드] 시뮬레이터 가짜 좌표 로직
    // ==========================================
    // AWS 서버가 닫혀있을 때 `connect()` 대신 이 함수를 호출하면 테스트 가능!
    
    func startSimulation() {
        print("🌐 [시뮬레이션 모드] 가짜 좌표 생성을 시작합니다.")
        isConnected = true
        simulationTimer?.invalidate()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    
                    // 1. Task에 들어가기 전에, 밖에서 상수로 꽁꽁 얼려두기!
                    guard let capturedSelf = self else { return }
                    
                    Task { @MainActor in
                        // 2. 안에서는 얼려둔 상수(capturedSelf)를 아주 평화롭게 사용
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
                            
                            // 🌟 self 대신 capturedSelf 사용!
                            capturedSelf.targetCoordinate = coord
                            print("🎯 [시뮬레이션 수신] 좌표: (\(Int(coord.screenX)), \(Int(coord.screenY)))")
                        } catch {
                            print("❌ 시뮬레이션 디코딩 실패: \(error)")
                        }
                    }
                }
    }
}
