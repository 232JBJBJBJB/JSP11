import Foundation

// 🌟 AWS 서버와 통신(Codable)도 하고, 화면 리스트(Identifiable)에도 띄우는 완벽한 단일 모델!
struct Word: Identifiable, Codable {
    // 1번 조원(백엔드)의 DB에서 만들어줄 고유 ID (서버에 아직 저장 안 됐을 수 있으니 옵셔널 '?')
    var id: String?
    
    // 핵심 데이터
    var term: String
    var meaning: String
    
    // 학습 관련 데이터
    var isMemorized: Bool = false
    var isRevealed: Bool = false
    
    // 상세 스펙
    var pronunciation: String = ""
    var koreanEx: String = ""
    var example: String = ""
    var usageContext: String = ""
    
    // 생성 일자 (서버랑 통신할 땐 Date보단 String으로 주고받는 게 에러가 덜 나!)
    var createdAt: String = ""
}

// 🎯 GeneratedQuiz는 퀴즈용이니까 그대로 유지!
struct GeneratedQuiz: Identifiable, Codable {
    var id: String { question }
    let passage: String
    let question: String
    let options: [String]
    let answerIndex: Int
    
    var answerWord: String {
        return options[answerIndex]
    }
}
