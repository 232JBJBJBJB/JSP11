// 🌟 [복구 1] 마법의 키워드: AVFoundation 깐깐한 스레드 검사에서 제외!
@preconcurrency import AVFoundation
import SwiftUI
import Combine
import CoreImage

@MainActor
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // 🌟 [조원 코드 호환] 조원이 카메라 뷰에서 .shared를 썼으므로 싱글톤 인스턴스 추가!
    static let shared = CameraManager()
    
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var currentFrame: UIImage? = nil
    
    // 무거운 카메라 프레임을 처리할 전용 백그라운드 일꾼
    private let videoQueue = DispatchQueue(label: "camera.videoQueue", qos: .userInitiated)
    private let ciContext = CIContext() // 이미지 변환 엔진
    
    // 1. 권한 체크
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            Task { await self.setupCamera() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    if granted {
                        await self.setupCamera()
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    // 2. 카메라 세팅
    private func setupCamera() async {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        // 바구니에 데이터가 찰 때마다 'videoQueue'에서 처리
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        // =========================================================
        // 🌟 [핵심 마법 1] C++ 한테 넘기기 전에 물리적으로 세로(Portrait)로 찍기!
        // =========================================================
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        session.commitConfiguration()
        
        // 🌟 스레드 안전성 보장 (미리 꺼내서 백그라운드에 넘기기)
        let currentSession = self.session
        videoQueue.async {
            currentSession.startRunning()
        }
    }
    
    // ==========================================
    // 🌟 찰칵 모션 & 하드웨어 제어용 함수
    // ==========================================
    
    // 🛑 카메라 일시 정지 (캡처 화면 띄울 때 호출)
    func stopSession() {
        let currentSession = self.session // 스레드 격리 완벽 준수
        videoQueue.async {
            if currentSession.isRunning {
                currentSession.stopRunning()
                print("💤 카메라 세션을 잠재웁니다 (배터리 절약)")
            }
        }
    }
    
    // ▶️ 카메라 다시 시작 (다시 라이브로 돌아올 때 호출)
    func startSession() {
        let currentSession = self.session
        videoQueue.async {
            if !currentSession.isRunning {
                currentSession.startRunning()
                print("🚀 카메라 세션을 다시 깨웁니다")
            }
        }
    }
    
    // 3. 📸 데이터 바구니
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
        // 1. 카메라 센서 데이터를 Swift용 UIImage로 변환
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // =========================================================
        // 🌟 [핵심 마법 2] 하드웨어가 세로로 줬으니 꼬리표는 .up으로 세팅!
        // =========================================================
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            
        // =========================================================
        // 🌟 드디어 C++ (ARBridge) 다시 연결!
        // =========================================================
        if let processedImage = C_RenderEnhancedBubbles(uiImage, true, 1.0) {
            Task { @MainActor in
                self.currentFrame = processedImage
            }
        } else {
            Task { @MainActor in
                self.currentFrame = uiImage
            }
        }
    }
}
