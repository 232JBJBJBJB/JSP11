import SwiftUI

struct MainCameraView: View {
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
                // 📸 카메라 영역 및 AR 비주얼 필터
                // ==========================================
                Group {
                    if let frozen = frozenImage {
                        ZStack {
                            let screenSize = UIScreen.main.bounds.size
                            let imageSize = frozen.size
                            
                            // 1. 기본 배경 렌더링 (단어 인식 시 흑백 + 블러 효과 적용)
                            Image(uiImage: frozen)
                                .resizable()
                                .scaledToFill()
                                .grayscale(arViewModel.discoveredWords.isEmpty ? 0.0 : 1.0)
                                .blur(radius: arViewModel.discoveredWords.isEmpty ? 0 : 4)
                                .animation(.easeInOut(duration: 0.8), value: arViewModel.discoveredWords.isEmpty)
                            
                            // 2. 인식된 사물 영역 하이라이트 (컬러 스포트라이트)
                            if !arViewModel.discoveredWords.isEmpty {
                                Image(uiImage: frozen)
                                    .resizable()
                                    .scaledToFill()
                                    .mask(
                                        ZStack {
                                            ForEach(arViewModel.discoveredWords) { word in
                                                if let rx = word.relativeX, let ry = word.relativeY {
                                                    let pos = convertToScreenCoordinate(relativeX: rx, relativeY: ry, imageSize: imageSize, screenSize: screenSize)
                                                    Circle()
                                                        .frame(width: 220, height: 220)
                                                        .position(pos)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(
                                        ZStack {
                                            ForEach(arViewModel.discoveredWords) { word in
                                                if let rx = word.relativeX, let ry = word.relativeY {
                                                    let pos = convertToScreenCoordinate(relativeX: rx, relativeY: ry, imageSize: imageSize, screenSize: screenSize)
                                                    Circle()
                                                        .stroke(Color.cyan.opacity(0.4), lineWidth: 3)
                                                        .blur(radius: 3)
                                                        .frame(width: 220, height: 220)
                                                        .position(pos)
                                                }
                                            }
                                        }
                                    )
                                    .transition(.opacity)
                            }
                        }
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
                // 🎯 AR UI 오버레이 (단어 말풍선)
                // ==========================================
                Group {
                    if let frozen = frozenImage, !arViewModel.discoveredWords.isEmpty {
                        ZStack {
                            let screenSize = UIScreen.main.bounds.size
                            let imageSize = frozen.size
                            
                            ForEach(arViewModel.discoveredWords.filter { wordVM.selectedPos == "표준" || $0.pos == wordVM.selectedPos }) { word in
                                
                                if let rx = word.relativeX, let ry = word.relativeY {
                                    
                                    let realPoint = convertToScreenCoordinate(
                                        relativeX: rx,
                                        relativeY: ry,
                                        imageSize: imageSize,
                                        screenSize: screenSize
                                    )
                                    
                                    VStack(spacing: 4) {
                                        Text(word.word).font(.title).bold()
                                        Text(word.pronunciation).font(.caption)
                                        Text(word.meaning).font(.footnote)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                    .shadow(radius: 5)
                                    .position(x: realPoint.x, y: realPoint.y)
                                    .transition(.scale.combined(with: .opacity))
                                    .onAppear {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                            }
                        }
                    }
                    
                    // 네트워크 타겟팅 마커
                    if let liveCoord = arNetworkManager.targetCoordinate {
                        Circle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .position(x: CGFloat(liveCoord.screenX), y: CGFloat(liveCoord.screenY))
                            .animation(.linear(duration: 0.1), value: liveCoord.screenX)
                            .animation(.linear(duration: 0.1), value: liveCoord.screenY)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: arViewModel.discoveredWords.isEmpty)
                
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
                
            } else {
                DeniedCameraView()
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            arNetworkManager.connect()
        }
        .onDisappear {
            arNetworkManager.disconnect()
        }
    }
    
    // ==========================================
    // 🌟 핵심 로직: 분석 프로세스 실행
    // ==========================================
    private func startAnalysis() {
        guard let image = cameraManager.currentFrame else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
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
        
        Task {
            // 분석만 실행하고, UI 렌더링은 SwiftUI 프레임워크 단에서 처리합니다.
            let _ = await arViewModel.analyzeScene(
                image: image,
                targetLanguage: targetLanguage,
                styleOption: targetVoiceStyle,
                targetPos: wordVM.selectedPos,
                existingWords: wordVM.getExistingTerms()
            )
        }
    }
    
    // ==========================================
        // 🌟 화면 이탈 방지(Clamping)가 적용된 좌표 번역기
        // ==========================================
        func convertToScreenCoordinate(relativeX: Double, relativeY: Double, imageSize: CGSize, screenSize: CGSize) -> CGPoint {
            // 1. 원본 스케일 계산 (기존과 동일)
            let scaleFactor = max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
            let scaledWidth = imageSize.width * scaleFactor
            let scaledHeight = imageSize.height * scaleFactor
            let offsetX = (scaledWidth - screenSize.width) / 2.0
            let offsetY = (scaledHeight - screenSize.height) / 2.0
            
            // 2. AI가 알려준 원래 좌표
            let finalX = (CGFloat(relativeX) * scaledWidth) - offsetX
            let finalY = (CGFloat(relativeY) * scaledHeight) - offsetY
            
            // 3. 🌟 C++에서 훔쳐 온(?) 화면 테두리 고정 로직!
            // 말풍선의 대략적인 절반 크기를 여백(Margin)으로 설정해.
            // 글자 길이에 따라 다르겠지만, 가로 70, 세로 60 정도면 안전해.
            let marginX: CGFloat = 70.0
            let marginY: CGFloat = 60.0
            
            // x 좌표 방어: 화면 왼쪽 테두리(marginX)보다 작으면 밀어 넣고, 오른쪽 테두리보다 크면 당겨옴!
            let safeX = max(marginX, min(finalX, screenSize.width - marginX))
            
            // y 좌표 방어: 화면 위쪽, 아래쪽 테두리도 똑같이 방어!
            // (하단은 버튼 영역이 있으니 여백을 살짝 더 줘도 좋아. 예를 들어 screenSize.height - 100.0)
            let safeY = max(marginY, min(finalY, screenSize.height - marginY - 80.0)) // 하단 버튼 가리지 않게 추가 여백
            
            return CGPoint(x: safeX, y: safeY)
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
