import SwiftUI
// 🗑️ import SwiftData 삭제 완료! (이제 AWS를 쓰니까 애플 로컬 DB는 필요 없어)
import FirebaseCore // 🌟 로그인(인증) 경비원을 위해 파이어베이스 뼈대는 남겨둠!

@main
struct LearningUIApp: App {
    
    // 파이어베이스 초기화 (인증 등 필수 기능 가동을 위해 유지)
    init() {
        FirebaseApp.configure()
    }
    
    // 💡 온보딩을 완료했는지 기억하는 로컬 변수 (기본값은 false)
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            // 조건문으로 시작 화면을 분기 처리!
            if hasSeenOnboarding {
                ContentView() // 💡(나중엔 MainCameraView로 바꾸거나, 탭바로 묶어주면 딱이야!)
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding) // 온보딩 화면 띄우기
            }
        }
    }
}
