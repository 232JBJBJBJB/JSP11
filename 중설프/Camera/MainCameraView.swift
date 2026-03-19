import SwiftUI

struct MainCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager()
    
    // 🧠 3단계에서 만든 제미나이 뇌(ViewModel) 장착!
    @StateObject private var arViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                // 1. 카메라 화면 (배경)
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                VStack {
                    // 2. 상단: 내 위치 주소
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        Text(locationManager.currentAddress)
                            .font(.subheadline)
                            .bold()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // 🌟 3. 결과 창: 제미나이가 찾은 단어들 띄워주기
                    if !arViewModel.discoveredWords.isEmpty {
                        VStack(spacing: 10) {
                            Text("✨ 발견된 단어들")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(arViewModel.discoveredWords) { word in
                                HStack {
                                    Text(word.word) // 예: コーヒー
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
                    
                    // 🌟 4. 하단: AI 분석 버튼
                    Button(action: {
                        // 버튼 누르면 최신 프레임 캡처해서 제미나이한테 던지기!
                        guard let image = cameraManager.currentFrame else { return }
                        
                        Task {
                            // 목표 언어는 나중에 AppStorage에서 가져오면 됨 (일단 일본어 고정)
                            await arViewModel.analyzeScene(image: image, address: locationManager.currentAddress, targetLanguage: "일본어")
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
                    .disabled(arViewModel.isAnalyzing) // 분석 중일 땐 버튼 비활성화
                }
                
                // 에러 발생 시 알림창 띄우기
                if let error = arViewModel.errorMessage {
                    VStack {
                        Text("오류 발생 🚨")
                            .bold()
                        Text(error)
                            .multilineTextAlignment(.center)
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
                    Image(systemName: "camera.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("카메라 권한이 필요합니다.")
                        .padding()
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            locationManager.requestPermission()
        }
    }
}
