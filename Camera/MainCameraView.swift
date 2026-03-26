import SwiftUI

struct MainCameraView: View {
    // 🌟 앱의 3대장 고용!
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var arNetworkManager = ARNetworkManager()
    
    // 온보딩에서 골랐던 목표 언어
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    
    var body: some View {
        ZStack {
            // 📸 1. 카메라 권한이 허락되었을 때의 화면
            if cameraManager.isAuthorized {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // ==========================================
                // 🌟 [핵심 AR UI 영역]
                // ==========================================
                if let coord = arNetworkManager.targetCoordinate,
                   let matchedWord = arViewModel.discoveredWords.first(where: { $0.id.uuidString == coord.word_id }) {
                    
                    // [상황 A] 진짜 AR 화면: AWS 서버에서 좌표(X,Y)가 날아오면 사물 위에 띄움!
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
                    
                    // [상황 B] 임시 대기 화면: 제미나이가 단어는 찾았는데, 아직 AWS 좌표가 없을 때 화면 중앙에 리스트로 보여줌!
                    VStack(spacing: 10) {
                        Text("✅ 제미나이 분석 완료 (AR 좌표 대기중)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                        
                        ForEach(arViewModel.discoveredWords) { word in
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
                // ==========================================
                
                // 🕹️ 하단 UI (버튼 등)
                VStack {
                    Spacer()
                    
                    // 통신 상태 표시 (디버깅용)
                    if arNetworkManager.isConnected {
                        Text("🟢 AR 엔진 연결됨")
                            .font(.caption).bold()
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                    
                    // 제미나이 분석 버튼
                    Button(action: {
                        guard let image = cameraManager.currentFrame else { return }
                        Task {
                            await arViewModel.analyzeScene(image: image, targetLanguage: targetLanguage)
                        }
                    }) {
                        HStack {
                            if arViewModel.isAnalyzing {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text(" 제미나이 분석 중...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("이 공간 분석하기")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(arViewModel.isAnalyzing ? Color.gray : Color.blue)
                        .cornerRadius(15)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                    .disabled(arViewModel.isAnalyzing)
                }
                
                // 에러 메시지 팝업
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨").bold()
                        Text(error).multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .position(x: UIScreen.main.bounds.width / 2, y: 100)
                }
                
            } else {
                // 📸 2. 카메라 권한이 없을 때의 화면 (아까 날아갔던 부분 복구!)
                VStack {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("카메라 권한이 필요합니다.")
                        .padding()
                }
            }
        }
        // 🌟 뷰 생명주기 관리
        .onAppear {
            cameraManager.checkPermission()
            
            // 🚨 AWS 진짜 주소 받기 전까지는 에러 나니까 임시로 주석 처리!
            // arNetworkManager.connect()
        }
        .onDisappear {
            arNetworkManager.disconnect()
        }
    }
}
