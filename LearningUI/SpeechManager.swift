import AVFoundation
import SwiftUI

class SpeechManager {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    @AppStorage("targetVoiceCode") private var targetVoiceCode: String = "en-US"
    
    private init() {}
    
    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 🌟 제미나이한테 물어볼 필요 없이, 이미 저장된 코드를 바로 꽂아넣음! (지연 시간 0초)
        utterance.voice = AVSpeechSynthesisVoice(language: targetVoiceCode)
        utterance.rate = 0.45
        
        synthesizer.speak(utterance)
    }
}
