import SwiftUI

struct MainCameraView: View {
    // 🌟 1. 앱의 3대장 고용!
    @StateObject private var cameraManager = CameraManager.shared
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var arNetworkManager = ARNetworkManager()
    @StateObject private var wordVM = WordViewModel()
    
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    
    let posOptions = ["표준", "명사", "동사", "형용사", "부사"]
    
    @State private var frozenImage: UIImage? = nil
    @State private var captureAnimationValue: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                
                // ==========================================
                // 📸 카메라 영역
                // ==========================================
                Group {
                    if let frozen = frozenImage {
                        Image(uiImage: frozen)
                            .resizable()
                            .scaledToFill()
                    } else {
                        CameraPreview(session: cameraManager.session)
                    }
                }
                .ignoresSafeArea()
                .rotation3DEffect(
                    .degrees(captureAnimationValue * -5),
                    axis: (x: 1.0, y: 0.0, z: 0.0),
                    anchor: .center,
                    perspective: 0.5
                )
                .scaleEffect(1.0 - (captureAnimationValue * 0.03))
                .overlay(
                    Color.white.opacity(captureAnimationValue > 0.5 ? (1.0 - captureAnimationValue) * 2 : captureAnimationValue * 2).ignoresSafeArea()
                )
                
                // ==========================================
                // 🏷️ 품사 필터링 UI
                // ==========================================
                VStack {
                    VStack(spacing: 8) {
                        Text("인식할 품사 카테고리를 선택하세요")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("품사", selection: $wordVM.selectedPos) {
                            ForEach(posOptions, id: \.self) { pos in
                                Text(pos).tag(pos)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    .background(BlurView(style: .systemMaterial))
                    .cornerRadius(15)
                    .padding()
                    
                    Spacer()
                }
                
                // ==========================================
                // 🎯 AR UI 영역 (정지된 화면 위에 다중 말풍선 띄우기!)
                // ==========================================
                Group {
                    if let frozen = frozenImage, !arViewModel.discoveredWords.isEmpty {
                        ZStack {
                            // 🌟 화면 크기와 사진 크기 구하기
                            let screenSize = UIScreen.main.bounds.size
                            let imageSize = frozen.size
                            
                            // 🌟 선택된 품사에 맞는 단어들만 화면에 그리기
                            ForEach(arViewModel.discoveredWords.filter { wordVM.selectedPos == "표준" || $0.pos == wordVM.selectedPos }) { word in
                                
                                // 제미나이가 좌표를 정상적으로 줬을 때만 버블 생성
                                if let rx = word.relativeX, let ry = word.relativeY {
                                    
                                    // 🌟 마법의 번역기로 진짜 아이폰 좌표 계산!
                                    let realPoint = convertToScreenCoordinate(
                                        relativeX: rx,
                                        relativeY: ry,
                                        imageSize: imageSize,
                                        screenSize: screenSize
                                    )
                                    
                                    VStack(spacing: 4) {
                                        Text(word.word).font(.title).bold()
                                        Text(word.pronunciation).font(.caption)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                    .shadow(radius: 5)
                                    .position(x: realPoint.x, y: realPoint.y) // 계산된 진짜 좌표 적용
                                    .transition(.scale.combined(with: .opacity))
                                    .onAppear {
                                        // 🌟 단어가 뿅! 나타날 때 기분 좋은 햅틱 진동
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                            }
                        }
                    }
                }
                .animation(.easeInOut, value: arViewModel.discoveredWords.isEmpty)
                
                // ==========================================
                // 🕹️ 하단 버튼 영역
                // ==========================================
                VStack {
                    if frozenImage != nil && !arViewModel.isAnalyzing {
                        HStack {
                            Spacer()
                            Button(action: resetCamera) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                                    .padding(.top, 10).padding(.trailing, 20)
                            }
                            .transition(.scale)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            arNetworkManager.isConnected ? arNetworkManager.disconnect() : arNetworkManager.connect()
                        }) {
                            Image(systemName: arNetworkManager.isConnected ? "bolt.fill" : "bolt.slash.fill")
                                .foregroundColor(.white).padding().background(arNetworkManager.isConnected ? Color.green : Color.gray).clipShape(Circle())
                        }
                        
                        if frozenImage == nil || arViewModel.isAnalyzing {
                            Button(action: startAnalysis) {
                                HStack {
                                    if arViewModel.isAnalyzing {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text(" 제미나이 분석 중...")
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                        Text("이 공간 캡처 및 분석하기")
                                    }
                                }
                                .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(arViewModel.isAnalyzing ? Color.gray : Color.blue).cornerRadius(15)
                            }
                            .disabled(arViewModel.isAnalyzing)
                            .animation(.default, value: arViewModel.isAnalyzing)
                        }
                    }
                    .padding(.horizontal, 30).padding(.bottom, 30)
                }
                
                // ==========================================
                // 🚨 에러 팝업
                // ==========================================
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨").bold()
                        Text(error).multilineTextAlignment(.center)
                    }
                    .padding().background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 대기열 팝업 주석 처리 (유지)
                /*
                if arViewModel.showQueuedAlert { ... }
                */
                
            } else {
                DeniedCameraView()
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            arNetworkManager.startSimulation() // 시작 시 자동 연결
        }
        .onDisappear {
            arNetworkManager.disconnect()
        }
    }
    
    // ==========================================
    // 🌟 핵심 로직: 분석 시작
    // ==========================================
    private func startAnalysis() {
        guard let image = cameraManager.currentFrame else { return }
        
        // 카메라 셔터 누르는 듯한 햅틱 진동
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // 찰칵! 하는 플래시 애니메이션
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            captureAnimationValue = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            frozenImage = image
            cameraManager.stopSession()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            captureAnimationValue = 0.0
        }
        
        // 제미나이에게 사진과 프롬프트 전송
        Task {
            await arViewModel.analyzeScene(
                image: image,
                targetLanguage: targetLanguage,
                styleOption: targetVoiceStyle,
                targetPos: wordVM.selectedPos
            )
        }
    }
    
    // ==========================================
    // 🌟 마법의 좌표 번역기 (비율 좌표 -> 아이폰 화면 좌표)
    // ==========================================
    func convertToScreenCoordinate(relativeX: Double, relativeY: Double, imageSize: CGSize, screenSize: CGSize) -> CGPoint {
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = screenSize.width / screenSize.height
        
        var scaleFactor: CGFloat = 1.0
        var offsetX: CGFloat = 0.0
        var offsetY: CGFloat = 0.0
        
        // .scaledToFill 모드일 때의 오차 계산 로직
        if screenAspect > imageAspect {
            // 화면이 가로로 더 길 때 (위아래가 잘려나감)
            scaleFactor = screenSize.width / imageSize.width
            let scaledHeight = imageSize.height * scaleFactor
            offsetY = (scaledHeight - screenSize.height) / 2.0
        } else {
            // 화면이 세로로 더 길 때 (양옆이 잘려나감 - 아이폰 세로 모드는 보통 이럼!)
            scaleFactor = screenSize.height / imageSize.height
            let scaledWidth = imageSize.width * scaleFactor
            offsetX = (scaledWidth - screenSize.width) / 2.0
        }
        
        // 제미나이가 준 상대 좌표를 스케일에 맞게 불리고, 잘려나간(Offset) 만큼 빼주기!
        let finalX = (CGFloat(relativeX) * imageSize.width * scaleFactor) - offsetX
        let finalY = (CGFloat(relativeY) * imageSize.height * scaleFactor) - offsetY
        
        return CGPoint(x: finalX, y: finalY)
    }
    
    private func resetCamera() {
        withAnimation {
            frozenImage = nil
            arViewModel.discoveredWords.removeAll()
            arViewModel.errorMessage = nil
        }
        cameraManager.startSession()
    }
}

// ==========================================
// 하위 뷰 (블러 뷰 & 권한 거부 화면)
// ==========================================
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct DeniedCameraView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash").font(.system(size: 60)).foregroundColor(.gray)
            Text("AR 단어 인식을 위해\n카메라 권한이 꼭 필요해요 🥺")
                .font(.headline).foregroundColor(.white).multilineTextAlignment(.center)
            Button(action: {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }) {
                Text("설정 열기").font(.headline).foregroundColor(.white).padding().frame(width: 150).background(Color.blue).cornerRadius(10)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.9)).ignoresSafeArea()
    }
}
