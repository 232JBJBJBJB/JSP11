import Foundation

class APIManager {
    // 앱 전체에서 돌려쓸 수 있는 단 하나의 택배 기사님
    static let shared = APIManager()
    
    // 💡 1번 조원이 AWS 서버 켜면 여기 주소를 알려줄 거야! (지금은 가짜 주소)
    private let baseURL = "http://localhost:8080/api"
    
    private init() {} // 외부에서 함부로 기사님 새로 못 만들게 막기
    
    // 📥 [GET] AWS에서 내 단어 싹 다 가져오기
    func fetchWords() async throws -> [Word] {
        guard let url = URL(string: "\(baseURL)/words") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Word].self, from: data)
    }
    
    // 📤 [POST] AWS에 새 단어 저장하기
    func saveWord(word: Word) async throws {
        guard let url = URL(string: "\(baseURL)/words") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(word)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // 🗑️ [DELETE] AWS에서 단어 삭제하기
    func deleteWord(wordId: String) async throws {
        // 예: 주소/words/아이디값
        guard let url = URL(string: "\(baseURL)/words/\(wordId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // 🔄 [PUT] AWS에 단어 정보 업데이트하기 (별표 쳤을 때 등)
    func updateWord(word: Word) async throws {
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
