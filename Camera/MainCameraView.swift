import SwiftUI

struct MainCameraView: View {
    // 🌟 1. 앱의 3대장 완벽 고용!
    @StateObject private var cameraManager = CameraManager.shared // 아까 싱글톤으로 맞춘 거 기억나지?
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var arNetworkManager = ARNetworkManager()
    
    // 🌟 2. 품사 전용 뷰모델 고용 (조원 아이디어)
    @StateObject private var wordVM = WordViewModel()
    
    // 환경 설정 데이터 (targetVoiceStyle 유지!)
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    
    // 품사 옵션 정의
    let posOptions = ["표준", "명사", "동사", "형용사", "부사"]
    
    // 🌟 3. 화면 멈춤 및 3D 애니메이션용 변수
    @State private var frozenImage: UIImage? = nil
    @State private var captureAnimationValue: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                
                // ==========================================
                // 📸 카메라 영역 (라이브 vs 멈춘 화면)
                // ==========================================
                Group {
                    if let frozen = frozenImage {
                        Image(uiImage: frozen)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // 🌟 아까 고친 session 파이프라인 연결!
                        CameraPreview(session: cameraManager.session)
                    }
                }
                .ignoresSafeArea()
                
                // 🌟 3D 찰칵 모션 및 하얀 섬광 연출
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
                // 🏷️ 품사 필터링 UI (조원 아이디어 이식)
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
                // 🎯 AR UI 영역 (제미나이 결과 + 품사 필터링)
                // ==========================================
                Group {
                    if let coord = arNetworkManager.targetCoordinate,
                       let matchedWord = arViewModel.discoveredWords.filter({ word in
                           wordVM.selectedPos == "표준" || word.pos == wordVM.selectedPos
                       }).first(where: { $0.id.uuidString == coord.word_id }) {
                        
                        VStack(spacing: 4) {
                            Text(matchedWord.word).font(.title).bold()
                            Text(matchedWord.pronunciation).font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .position(x: coord.screenX, y: coord.screenY)
                        .animation(.linear(duration: 0.1), value: coord.screenX)
                        
                    } else if !arViewModel.discoveredWords.isEmpty {
                        
                        VStack(spacing: 10) {
                            Text("✅ 분석 완료 (현재 필터: \(wordVM.selectedPos))")
                                .font(.headline).foregroundColor(.white).padding(.bottom, 5)
                            
                            ForEach(arViewModel.discoveredWords.filter { wordVM.selectedPos == "표준" || $0.pos == wordVM.selectedPos }) { word in
                                HStack {
                                    Text(word.word).font(.title3).bold()
                                    Text("(\(word.pronunciation))").foregroundColor(.gray)
                                    Spacer()
                                    Text(word.meaning)
                                }
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(10)
                                .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.horizontal, 30)
                    }
                }
                
                // ==========================================
                // 🕹️ 하단 버튼 영역
                // ==========================================
                VStack {
                    // 상단 X 버튼 (다시 찍기)
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
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // 서버 연결 상태 버튼
                        Button(action: {
                            arNetworkManager.isConnected ? arNetworkManager.disconnect() : arNetworkManager.connect()
                        }) {
                            Image(systemName: arNetworkManager.isConnected ? "bolt.fill" : "bolt.slash.fill")
                                .foregroundColor(.white).padding().background(arNetworkManager.isConnected ? Color.green : Color.gray).clipShape(Circle())
                        }
                        
                        // 제미나이 분석 버튼
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
                        }
                    }
                    .padding(.horizontal, 30).padding(.bottom, 30)
                }
                
                // 에러 팝업
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨").bold()
                        Text(error).multilineTextAlignment(.center)
                    }
                    .padding().background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 100)
                }
                
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
    // 🌟 핵심 로직: 분석 시작 (3D 모션 + 하드웨어 제어 + 품사 프롬프트)
    // ==========================================
    private func startAnalysis() {
        guard let image = cameraManager.currentFrame else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            captureAnimationValue = 1.0
        }
        
        // 0.3초 뒤 화면 고정 및 배터리 절약(stopSession)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            frozenImage = image
            cameraManager.stopSession()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            captureAnimationValue = 0.0
        }
        
        // 🌟 제미나이 호출 (언어 + 방언 + 조원이 선택한 품사까지 완벽 전달!)
        Task {
            await arViewModel.analyzeScene(
                image: image,
                targetLanguage: targetLanguage,
                styleOption: targetVoiceStyle,
                targetPos: wordVM.selectedPos
            )
        }
    }
    
    // 카메라 초기화
    private func resetCamera() {
        frozenImage = nil
        arViewModel.discoveredWords.removeAll()
        arViewModel.errorMessage = nil
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
