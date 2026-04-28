import Foundation

class APIManager {
    static let shared = APIManager()
    
    // 💡 집 와이파이 주소로 업데이트됨!
    private let baseURL = "http://13.209.8.196:8080/api"
    
    private init() {}
    
    // 📥 [GET] 단어 싹 다 가져오기
    func fetchWords() async throws -> [Word] {
        guard let url = URL(string: "\(baseURL)/words") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Word].self, from: data)
    }
    
    // 📤 [POST] 새 단어 저장하기
    func saveWord(word: Word) async throws {
        guard let url = URL(string: "\(baseURL)/words") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(word)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // 🗑️ [수정됨] wordId 타입을 String에서 Int64로 변경!
    func deleteWord(wordId: Int64) async throws {
        // 숫자인 wordId를 문자열 주소 안에 넣을 땐 \(wordId)라고 쓰면 자동으로 변환돼!
        guard let url = URL(string: "\(baseURL)/words/\(wordId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // 🔄 [수정됨] word.id가 이제 Int64? 타입이므로 이에 맞춰 업데이트
    func updateWord(word: Word) async throws {
        // word.id에서 숫자를 꺼내와서 주소를 만들어
        guard let wordId = word.id, let url = URL(string: "\(baseURL)/words/\(wordId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(word)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}
