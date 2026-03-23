import SwiftUI

struct MainCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var arViewModel = ARViewModel()
    
    // 🌟 [핵심 1] 온보딩에서 폰 메모리에 저장해 둔 '목표 언어'를 꺼내오기!
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    
    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // 🌟 결과 창: 제미나이가 찾은 단어들 띄워주기 (기존과 동일)
                    if !arViewModel.discoveredWords.isEmpty {
                        VStack(spacing: 10) {
                            Text("✨ 발견된 단어들")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(arViewModel.discoveredWords) { word in
                                HStack {
                                    Text(word.word)
                                        .font(.title2).bold()
                                    Text("(\(word.pronunciation))")
                                        .foregroundColor(.gray)
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
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                    
                    // 🌟 하단: AI 분석 버튼
                    Button(action: {
                        guard let image = cameraManager.currentFrame else { return }
                        
                        Task {
                            // 🌟 [핵심 2] "일본어"라고 고정했던 자리에 targetLanguage 변수를 쏙!
                            await arViewModel.analyzeScene(image: image, targetLanguage: targetLanguage)
                        }
                    }) {
                        HStack {
                            if arViewModel.isAnalyzing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text(" AI가 분석 중...")
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
                
                // 에러 창 (기존과 동일)
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨").bold()
                        Text(error).multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: arViewModel.errorMessage)
                }
                
            } else {
                VStack {
                    Image(systemName: Constants.Icons.cameraSlash)
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(Constants.Labels.cameraNoPermission)
                        .padding()
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
    }
}
