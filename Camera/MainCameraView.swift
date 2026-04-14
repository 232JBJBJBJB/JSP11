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
                // 🎯 AR UI 영역 (햅틱 및 애니메이션 추가됨)
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
                        // 🌟 새로운 단어마다 고유 ID 부여 -> onAppear가 정확히 한 번만 동작하게 함
                        .id(matchedWord.id)
                        .position(x: coord.screenX, y: coord.screenY)
                        // 🌟 [요구사항 1] 위치 이동을 부드럽게 (기존) & 등장/퇴장 시 스케일+투명도 애니메이션 (추가)
                        .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: coord.screenX)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            // 🌟 [요구사항 1] 단어가 처음 AR 화면에 매칭되어 나타날 때 햅틱 진동 발생!
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        
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
                        .transition(.opacity) // 🌟 리스트 등장 시 부드럽게
                    }
                }
                .animation(.easeInOut, value: arViewModel.discoveredWords.isEmpty) // 상태 변경 시 자연스러운 전환
                
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
                
                // 에러 팝업
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨").bold()
                        Text(error).multilineTextAlignment(.center)
                    }
                    .padding().background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // ==========================================
                // ⚠️ [요구사항 2] 서버 혼잡 시 대기열 접수 알림 팝업 (미리 준비, 주석 처리됨)
                // ==========================================
                /*
                if arViewModel.showQueuedAlert {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("서버가 혼잡합니다 ⏱️")
                            .font(.title3).bold()
                            .foregroundColor(.white)
                        Text("이미지를 대기열에 안전하게 저장했습니다.\n분석이 완료되면 푸시 알림으로 알려드릴게요!")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color.orange.opacity(0.95))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        // 4초 뒤에 알림창이 스르륵 사라지도록 설정
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation {
                                arViewModel.showQueuedAlert = false
                            }
                        }
                    }
                }
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
            await arViewModel.analyzeScene(
                image: image,
                targetLanguage: targetLanguage,
                styleOption: targetVoiceStyle,
                targetPos: wordVM.selectedPos
            )
        }
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