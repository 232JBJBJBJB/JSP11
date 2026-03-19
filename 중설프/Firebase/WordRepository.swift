import Foundation
import FirebaseFirestore // 🌟 [핵심] 구글 화이트보드(Firestore)용 부품 가져오기!

// 📋 점장님이 반드시 해야 할 업무 리스트
protocol WordRepository {
    func fetchWords() async throws -> [Word]
    func addWord(term: String, meaning: String) async throws
    func deleteWord(word: Word) async throws
    func updateWord(word: Word) async throws // 🌟 [추가] 단어 수정/별표 변경 시 필요!
}


// ☁️ 구글 본사 파견 점장님 (진짜 통신하는 구현체)
class FirebaseWordRepository: WordRepository {
    
    private var db: Firestore {
        Firestore.firestore()
    }
    
    // 2. 데이터를 모아둘 '섹션(컬렉션)' 이름표
    private let collectionName = "words"
    
    
    // 📖 [Read] 구름에서 단어들 가져오기
    func fetchWords() async throws -> [Word] {
        // 화이트보드(Firestore)에서 'words' 구역의 모든 데이터를 가져와!
        let snapshot = try await db.collection(collectionName).getDocuments()
        
        // 가져온 데이터(JSON)를 우리 스위프트용 Word(구조체) 모양으로 슉슉 변환해!
        var words = snapshot.documents.compactMap { document in
            // Codable 덕분에 마법처럼 알아서 변환됨!
            try? document.data(as: Word.self)
        }
        
        // 최신에 추가한 단어가 맨 위로 오도록 정렬 (생성일자 기준)
        words.sort { $0.createdAt > $1.createdAt }
        
        return words
    }
    
    
    // ✍️ [Create] 구름에 새 단어 추가하기
    func addWord(term: String, meaning: String) async throws {
        let newWord = Word(term: term, meaning: meaning)
        
        // 단어의 고유번호(id)를 이름표 삼아서 화이트보드에 찰칵! 저장해
        try db.collection(collectionName)
            .document(newWord.id)
            .setData(from: newWord)
    }
    
    
    // 🗑️ [Delete] 구름에서 단어 지우기
    func deleteWord(word: Word) async throws {
        // 단어의 고유번호(id)를 찾아서 화이트보드에서 쓱싹 지워!
        try await db.collection(collectionName)
            .document(word.id)
            .delete()
    }
    
    
    // 🔄 [Update] 구름에 있는 단어 수정/별표 갱신하기
    func updateWord(word: Word) async throws {
        // 화이트보드에 같은 고유번호(id)가 있으면 알아서 새 내용으로 덮어써 줌! (수정)
        try db.collection(collectionName)
            .document(word.id)
            .setData(from: word)
    }
}
