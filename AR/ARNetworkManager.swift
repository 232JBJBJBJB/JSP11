import Foundation
import CoreMotion
import Combine

// 📦 서버와 주고받을 데이터 구조체 (조원의 C++ 엔진 규격과 100% 동일하게 유지)
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

// 🌟 UI 업데이트를 완벽하게 보장하는 MainActor 선언
@MainActor
class ARNetworkManager: ObservableObject {
    
    // 🎯 화면에 단어를 띄울 목표 좌표 (UI가 이 변수만 쳐다보고 바뀔 거야!)
    @Published var targetCoordinate: CalculatedCoordinate?
    @Published var isConnected: Bool = false // UI에 연결 상태를 보여주기 위한 변수 추가
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let motionManager = CMMotionManager()
    private let session = URLSession(configuration: .default)
    
    // MARK: - Step 1: WebSocket 파이프라인 개통
    func connect() {
        // 중복 연결 방지
        guard webSocketTask == nil else { return }
        
        // 🌟 1번 조원의 AWS 주소 입력 (보안을 위해 wss 권장)
        guard let url = URL(string: "wss://your-aws-server-address/ar-endpoint") else {
            print("🚨 URL 형식이 잘못되었습니다.")
            return
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        print("🌐 WebSocket 연결 시도 중...")
        
        // 🌟 최신 비동기 문법(Task)으로 수신 대기 시작!
        Task { await receiveData() }
        
        startMotionUpdates()
    }
    
    // MARK: - Step 2: 센서 데이터 1초에 60번씩 송신
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ 이 기기에서는 자이로스코프/모션 센서를 지원하지 않습니다.")
            return
        }
        
        // 부드러운 AR을 위해 초당 60프레임(1/60) 갱신 설정
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        // 🌟 무거운 센서 읽기 작업은 메인 스레드(사장님)가 아닌 백그라운드 큐(알바생)에게 전담!
        let sensorQueue = OperationQueue()
        sensorQueue.qualityOfService = .userInteractive
        
        motionManager.startDeviceMotionUpdates(to: sensorQueue) { [weak self] (motion, error) in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let data = SensorData(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw
            )
            
            // 데이터 송신
            self.sendSensorData(data)
        }
    }
    
    private func sendSensorData(_ data: SensorData) {
        guard isConnected, let task = webSocketTask else { return }
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            
            task.send(message) { error in
                if let error = error {
                    print("❌ 송신 에러: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ JSON 인코딩 에러")
        }
    }
    
    // MARK: - Step 3: 백엔드에서 좌표 수신 (async/await 적용)
    private func receiveData() async {
        guard let task = webSocketTask else { return }
        
        do {
            // 서버에서 답장이 올 때까지 안전하게 기다림 (UI 안 멈춤!)
            let message = try await task.receive()
            
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8),
                   let coord = try? JSONDecoder().decode(CalculatedCoordinate.self, from: data) {
                    // @MainActor 덕분에 따로 DispatchQueue.main 안 써도 UI가 안전하게 갱신됨!
                    self.targetCoordinate = coord
                }
            case .data(let data):
                if let coord = try? JSONDecoder().decode(CalculatedCoordinate.self, from: data) {
                    self.targetCoordinate = coord
                }
            @unknown default:
                break
            }
            
            // 🌟 전화가 끊기지 않았다면, 다음 좌표를 받기 위해 자기 자신을 계속 다시 부름 (무한루프)
            if isConnected {
                await receiveData()
            }
            
        } catch {
            print("❌ 수신 에러 또는 연결 끊김: \(error.localizedDescription)")
            self.isConnected = false
        }
    }
    
    // MARK: - 퇴근 지시 (메모리 누수 방지)
    func disconnect() {
        isConnected = false
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("🔌 WebSocket 정상 종료됨")
    }
}
