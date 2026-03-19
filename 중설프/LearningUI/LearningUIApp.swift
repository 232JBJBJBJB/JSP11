import SwiftUI
import SwiftData
import FirebaseCore // 네가 추가한 파이어베이스!

@main
struct LearningUIApp: App {
    
    // 파이어베이스 초기화 (이미 네가 해둔 코드 그대로 두면 돼)
    init() {
        FirebaseApp.configure()
    }
    
    // 💡 온보딩을 완료했는지 기억하는 로컬 변수 (기본값은 false)
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            // 조건문으로 시작 화면을 분기 처리!
            if hasSeenOnboarding {
                ContentView() // 나중에는 이게 MainCameraView로 바뀔 거야!
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding) // 온보딩 화면 띄우기
            }
        }
    }
}
