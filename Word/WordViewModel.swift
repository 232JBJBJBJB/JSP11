import Foundation
import SwiftUI
import Combine

@MainActor // 화면(UI)을 바꾸는 작업이 많아서 안전하게 메인 스레드에서 돌리도록 명시!
class WordViewModel: ObservableObject {
    // 🌟 퓨전(통합)된 완전체 'Word' 모델 하나만 사용!
    @Published var words: [Word] = []
    
    // 검색용 텍스트 (UI 연결용 & 실제 검색용)
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    
    @Published var isLoading = false
    
    init() {
        // 검색 파이프라인 (0.3초 대기 후 검색어 확정)
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
    }
    
    // 🔍 검색 필터링 (통합된 Word의 속성인 'term'과 'meaning' 사용)
    var filteredWords: [Word] {
        if debouncedSearchText.isEmpty {
            return words
        } else {
            return words.filter { word in
                word.term.lowercased().contains(debouncedSearchText.lowercased()) ||
                word.meaning.lowercased().contains(debouncedSearchText.lowercased())
            }
        }
    }
    
    // 📥 [GET] AWS 서버에서 단어장 싹 다 당겨오기
    func loadWords() {
        Task {
            isLoading = true
            do {
                self.words = try await APIManager.shared.fetchWords()
            } catch {
                print("\(Constants.Errors.networkErrorPrefix) \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    // 📤 [POST] AWS 서버에 새 단어 추가하기
    func addWord(term: String, meaning: String) async -> Bool {
        // 중복 체크 (방어막 유지 - 이제 term으로 비교!)
        if words.contains(where: { $0.term.lowercased() == term.lowercased() }) {
            print("💡 이미 저장된 단어라서 서버에 보내지 않음!")
            return false
        }
        
        // 🌟 통합된 Word 구조체로 생성 (나머지 발음, 예문 등은 구조체 기본값이 들어감)
        let newWord = Word(term: term, meaning: meaning)
        
        do {
            try await APIManager.shared.saveWord(word: newWord)
            loadWords() // 저장 성공 시, 서버에서 최신 목록 다시 불러오기
            return true
        } catch {
            print("\(Constants.Errors.networkErrorPrefix) \(error.localizedDescription)")
            return false
        }
    }
    
    // 🗑️ [DELETE] AWS 서버에서 단어 지우기
    func deleteWord(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let wordToDelete = words[index]
                // 서버 DB에 삭제 요청을 하려면 고유 ID가 필요해!
                guard let wordId = wordToDelete.id else { continue }
                
                do {
                    try await APIManager.shared.deleteWord(wordId: wordId)
                } catch {
                    print("\(Constants.Errors.networkErrorPrefix) 삭제 실패: \(error.localizedDescription)")
                }
            }
            loadWords() // 지우고 나서 목록 새로고침
        }
    }
    
    // 🔄 [PUT] AWS 서버에 단어 수정/업데이트하기 (상세 화면에서 수정 시 호출)
    func updateWord(word: Word) {
        Task {
            do {
                try await APIManager.shared.updateWord(word: word)
                loadWords()
            } catch {
                print("\(Constants.Errors.networkErrorPrefix) 업데이트 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // ⭐ [PUT] 즐겨찾기(별표) 토글
    func toggleMemorized(word: Word) {
        var updatedWord = word
        updatedWord.isMemorized.toggle() // 별표 상태 반전!
        updateWord(word: updatedWord)    // 바뀐 상태를 서버로 전송
    }
}
