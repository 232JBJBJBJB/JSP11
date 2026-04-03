import SwiftUI

struct MainCameraView: View {
    // 🌟 필요한 매니저들만 깔끔하게 고용!
    @StateObject private var wordVM = WordViewModel()
    @StateObject private var networkManager = ARNetworkManager()
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    
    let posOptions = ["명사", "동사", "형용사", "부사"]

    var body: some View {
        ZStack {
            // 1. 카메라 배경 (CameraManager.shared 사용 유지)
            CameraPreview(cameraManager: CameraManager.shared)
                .ignoresSafeArea()

            VStack {
                // 2. 🏷️ 품사 선택 상단 UI (추가된 기능)
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
                
                // 3. 🎯 실시간 AR 단어 표시 (기존 기능 유지 + 필터링 추가)
                if let target = networkManager.targetCoordinate {
                    // 필터링된 단어장(filteredWords)에서 서버 좌표 ID와 맞는 단어 검색
                    if let wordToShow = wordVM.filteredWords.first(where: { $0.id == target.word_id }) {
                        VStack {
                            Text(wordToShow.term) // 단어 표시
                                .font(.system(size: 45, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                                .shadow(color: .black, radius: 2)
                            
                            Text(wordToShow.meaning) // 뜻 표시
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(5)
                        }
                        .position(x: CGFloat(target.screenX), y: CGFloat(target.screenY))
                    }
                }
                
                Spacer()
                
                // 4. 하단 제어 및 분석 버튼 (기존 기능 유지)
                HStack(spacing: 20) {
                    // 연결 상태 버튼
                    Button(action: {
                        networkManager.isConnected ? networkManager.disconnect() : networkManager.connect()
                    }) {
                        Image(systemName: networkManager.isConnected ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(networkManager.isConnected ? Color.green : Color.gray)
                            .clipShape(Circle())
                    }
                    
                    // 분석 시작 버튼 (기존 제미나이 분석 기능 유지)
                    Button(action: {
                        wordVM.loadWords() // 최신 단어장 갱신
                    }) {
                        Text("새로운 환경 분석하기")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            networkManager.connect() // 시작 시 자동 연결
        }
        .onDisappear {
            networkManager.disconnect() // 종료 시 배터리 보호
        }
    }
}

// 블러 뷰는 별도 구조체로 유지
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}