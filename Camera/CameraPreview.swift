import SwiftUI
import AVFoundation

// 1. 카메라 화면을 담을 전용 도화지(UIView)를 새로 만들기
class VideoPreviewView: UIView {
    // 이 뷰의 기본 레이어를 '카메라 전용 레이어'로 강제 지정!
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

// 2. 그 도화지를 SwiftUI로 가져오기
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        
        // 🌟 [수정 완료] videoLayer -> view.videoPreviewLayer 로 정확하게 지칭!
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 크기 조절은 SwiftUI와 VideoPreviewView가 알아서 하니까 여긴 텅 비워둬도 완벽해!
    }
}
