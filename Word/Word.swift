import Foundation

// 🌟 AWS 서버와 통신도 하고, 리스트에도 띄우는 완벽한 모델
struct Word: Identifiable, Codable {
    var id: Int64?
    
    var term: String
    var meaning: String
    
    // 💡 서버에서 안 보내줄 수도 있으니 '?'를 붙여서 안전하게!
    var pos: String?
    var isMemorized: Bool?
    var isRevealed: Bool?
    
    var pronunciation: String?
    var koreanEx: String?
    var example: String?
    var usageContext: String?
    var createdAt: String?
    
    // 🌟 [핵심] Spring Boot의 얄미운 습관('is' 빼먹기)을 방어하는 통역기!
    enum CodingKeys: String, CodingKey {
        case id, term, meaning, pos
        case isMemorized = "memorized" // 서버가 "memorized"로 주면 내 변수 "isMemorized"에 넣어라!
        case isRevealed = "revealed"   // 서버가 "revealed"로 주면 내 변수 "isRevealed"에 넣어라!
        case pronunciation, koreanEx, example, usageContext, createdAt
    }
}

// 🎯 GeneratedQuiz는 Gemini AI 통신용이니까 완벽해! 그대로 유지!
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
