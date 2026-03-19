import AVFoundation
import SwiftUI
import Combine
import CoreImage // 🌟 [추가] 카메라 데이터를 우리가 보는 이미지로 변환해 주는 공장

// 🌟 [변경] 바구니(Delegate) 역할을 하려면 NSObject와 AVCaptureVideoDataOutputSampleBufferDelegate를 선언해야 해!
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    
    // 📸 [추가] 백그라운드 일꾼이 건져 올린 '최신 프레임(사진)'을 보관하는 장소
    @Published var currentFrame: UIImage? = nil
    
    // 🌟 [핵심] 카메라 프레임을 처리할 전용 백그라운드 일꾼 (UI 멈춤 방지!)
    private let videoQueue = DispatchQueue(label: "camera.videoQueue", qos: .userInitiated)
    private let ciContext = CIContext() // 이미지 변환 엔진
    
    // ... (checkPermission 함수는 기존과 동일) ...
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            DispatchQueue.global(qos: .userInitiated).async { self.setupCamera() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { self.isAuthorized = granted }
                if granted {
                    DispatchQueue.global(qos: .userInitiated).async { self.setupCamera() }
                }
            }
        default:
            DispatchQueue.main.async { self.isAuthorized = false }
        }
    }
    
    // 2. 카메라 세팅 (바구니 추가!)
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // 🧺 [추가] 콸콸 쏟아지는 영상 데이터를 받을 바구니 설치
        let videoOutput = AVCaptureVideoDataOutput()
        
        // 🌟 [핵심] 바구니에 데이터가 찰 때마다 'videoQueue(백그라운드)'에서 처리하라고 지시!
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        session.startRunning()
    }
    
    // 3. 📸 [추가] 바구니에 데이터가 들어올 때마다(1초에 30~60번) 자동으로 실행되는 함수
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 1. 카메라 센서에서 날것의 데이터(Buffer) 꺼내기
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 2. 날것의 데이터를 다루기 쉬운 CIImage로 변환
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 3. 화면에 그리기 좋은 고품질 CGImage로 변환
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // 4. 아이폰을 세로로 들었을 때 사진이 안 돌아가게 방향(Orientation) 맞춰서 UIImage로 완성!
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        // 5. 완성된 사진을 뷰(UI)가 쓸 수 있도록 메인 스레드에 던져주기
        DispatchQueue.main.async {
            self.currentFrame = uiImage
        }
    }
}
