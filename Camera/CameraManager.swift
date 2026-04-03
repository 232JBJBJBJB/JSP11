import AVFoundation
import SwiftUI
import Combine
import CoreImage


@MainActor
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var currentFrame: UIImage? = nil
    
    // 무거운 카메라 프레임을 처리할 전용 백그라운드 일꾼
    private let videoQueue = DispatchQueue(label: "camera.videoQueue", qos: .userInitiated)
    private let ciContext = CIContext() // 이미지 변환 엔진
    
    // 1. 권한 체크 (최신 문법으로 깔끔하게 정리)
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            // 백그라운드에서 카메라 세팅 실행
            Task.detached { await self.setupCamera() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    if granted {
                        Task.detached { await self.setupCamera() }
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    // 2. 카메라 세팅 (백그라운드에서 안전하게 실행되도록 nonisolated 적용)
    nonisolated private func setupCamera() async {
        // UI 변경을 위해 잠시 MainActor로 전환하여 session 접근
        await MainActor.run {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            
            // 바구니에 데이터가 찰 때마다 'videoQueue(백그라운드)'에서 처리하라고 지시!
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            session.commitConfiguration()
            
            // 카메라 작동 시작은 백그라운드 스레드에서 해야 경고(보라색 에러)가 안 뜸!
            let currentSession = self.session
            
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
    }
    
    // 3. 📸 데이터 바구니 (무거운 작업이므로 UI를 방해하지 않게 nonisolated 선언!)
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        // 🌟 무거운 변환 작업은 다 끝났으니, 가벼워진 완성본(uiImage)만 메인 화면으로 쏙! 던져주기
        Task { @MainActor in
            self.currentFrame = uiImage
        }
    }
}
