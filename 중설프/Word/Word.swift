import Foundation

struct Word: Identifiable, Codable {
    // 🌟 [변신 2] 파이어베이스는 UUID 대신 긴 '문자열(String)' ID를 좋아해!
    var id: String = UUID().uuidString
    
    var term: String
    var meaning: String
    var isMemorized: Bool = false
    var isRevealed: Bool = false
    
    // 상세 스펙
    var pronunciation: String = ""
    var koreanEx: String = ""
    var example: String = ""
    var usageContext: String = ""
    
    // 🌟 [변신 3 - 미래를 위한 떡밥!] 생성일자 추가
    var createdAt: Date = Date()
}

// 🎯 GeneratedQuiz는 이미 완벽해! (수정할 필요 0%)
struct GeneratedQuiz: Identifiable, Codable {
    var id: String { question } // 질문 자체를 ID로 사용 (간편함)
    let passage: String         // 독해 지문 (예: "철수는 __를 먹었다...")
    let question: String        // 문제 (예: "빈칸에 들어갈 단어는?")
    let options: [String]       // 보기 ["사과", "책상", "구름", "노래"]
    let answerIndex: Int        // 정답 번호 (예: 0)
    
    // 정답 확인용 도우미
    var answerWord: String {
        return options[answerIndex]
    }
}
