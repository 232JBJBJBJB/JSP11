import AVFoundation

class SpeechManager {
    // 1. [핵심!] 기획사 대표 전화번호 (싱글톤)
    // 앱 전체에서 이 'shared'라는 통로로만 성우에게 접근할 수 있어.
    static let shared = SpeechManager()
    
    // 2. 전속 성우 (View에서 데려옴, 이제 private으로 숨김)
    private let synthesizer = AVSpeechSynthesizer()
    
    // 3. 외부에서 함부로 다른 기획사를 새로 못 차리게 막음
    private init() {}
    
    // 4. 말하기 기능 (View에서 그대로 가져옴)
    func speak(text: String) {
        // 이미 말하고 있으면 멈춤
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        // 네가 공부하는 '중국 본토' 발음에 맞춘 zh-CN 세팅
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.45
        
        synthesizer.speak(utterance)
    }
}
