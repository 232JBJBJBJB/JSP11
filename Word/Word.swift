import Foundation

// 🌟 AWS 서버와 통신(Codable)도 하고, 화면 리스트(Identifiable)에도 띄우는 완벽한 단일 모델!
struct Word: Identifiable, Codable {
        var id: Int64?
        
        var term: String
        var meaning: String
        
        // 💡 아래 필드들은 서버에서 안 보내줄 수도 있으니 '?'를 붙여서 안전하게!
        var pos: String?
        var isMemorized: Bool?    // 서버가 안 주면 nil
        var isRevealed: Bool?     // 서버가 안 주면 nil
        
        var pronunciation: String?
        var koreanEx: String?
        var example: String?
        var usageContext: String?
        var createdAt: String?
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
