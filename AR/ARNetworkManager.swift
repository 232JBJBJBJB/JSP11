import Foundation
import CoreMotion
import Combine

@MainActor
class ARNetworkManager: ObservableObject {
    @Published var targetCoordinate: CalculatedCoordinate?
    @Published var isConnected: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let motionManager = CMMotionManager()
    private let session = URLSession(configuration: .default)
    
    func connect() {
        guard webSocketTask == nil else { return }
        // 🔗 실제 AWS 서버 주소로 교체 필요
        guard let url = URL(string: "wss://your-aws-server-address/ar") else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        Task { await receiveData() }
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion, error == nil else { return }
            let data = SensorData(pitch: motion.attitude.pitch, roll: motion.attitude.roll, yaw: motion.attitude.yaw)
            self.sendSensorData(data)
        }
    }
    
    private func sendSensorData(_ data: SensorData) {
        guard isConnected, let task = webSocketTask else { return }
        if let jsonData = try? JSONEncoder().encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            task.send(.string(jsonString)) { _ in }
        }
    }
    
    private func receiveData() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            if case .string(let text) = message,
               let data = text.data(using: .utf8),
               let coord = try? JSONDecoder().decode(CalculatedCoordinate.self, from: data) {
                self.targetCoordinate = coord
            }
            if isConnected { await receiveData() }
        } catch {
            self.isConnected = false
        }
    }
    
    func disconnect() {
        isConnected = false
        motionManager.stopDeviceMotionUpdates()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
}