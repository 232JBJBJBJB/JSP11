import Foundation
import SwiftUI
import Combine

@MainActor
class WordViewModel: ObservableObject {
    // 🌟 가짜 로컬 DB 역할 (앱이 켜져 있는 동안 여기에 단어가 저장됨)
    @Published var words: [Word] = []
    
    // 🔍 검색 및 품사 필터 변수
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    
    // 🌟 [최적화] 카메라 뷰랑 똑같이 기본값을 "표준"으로 맞춰야 시작할 때 충돌이 안 나!
    @Published var selectedPos: String = "표준"
    
    @Published var isLoading = false
    
    init() {
        // 검색 파이프라인: 0.3초 대기 후 검색어 확정
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
        
        loadWords() // 시작할 때 데이터 불러오기
    }
    
    // MARK: - 🌟 핵심 필터링 로직
    var filteredWords: [Word] {
        words.filter { word in
            // 1. "표준"이면 다 보여주고, 아니면 품사가 일치하는지 확인
            let matchesPos = (selectedPos == "표준") || (word.pos == selectedPos)
            
            // 2. 검색어가 포함되는지 확인
            let matchesSearch = debouncedSearchText.isEmpty ||
                                word.term.lowercased().contains(debouncedSearchText.lowercased()) ||
                                word.meaning.lowercased().contains(debouncedSearchText.lowercased())
            
            // 두 조건을 모두 만족해야 화면에 나타남
            return matchesPos && matchesSearch
        }
    }
    
    // MARK: - 📥 [가짜 GET] 로컬 메모리에서 단어장 불러오기
    func loadWords() {
        // 지금은 로컬 배열(words)을 쓰니까 서버에서 가져올 필요 없음!
        print("💾 [로컬 DB] 단어장 로드 완료 (현재 \(words.count)개)")
    }
    
    // MARK: - 📤 [가짜 POST] 로컬 배열에 새 단어 추가하기
    func addWord(term: String, meaning: String, pos: String = "명사") async -> Bool {
        if words.contains(where: { $0.term.lowercased() == term.lowercased() }) {
            print("💡 이미 저장된 단어입니다.")
            return false
        }
        
        let newWord = Word(term: term, meaning: meaning, pos: pos)
        
        // AWS 대신 내 핸드폰(배열)에 바로 저장!
        self.words.append(newWord)
        print("💾 [로컬 DB] '\(term)' 저장 성공!")
        return true
    }
    
    // MARK: - 🗑️ [가짜 DELETE] 로컬 배열에서 단어 지우기
    func deleteWord(at offsets: IndexSet) {
        // AWS 삭제 통신 제거하고 배열에서 바로 쓱싹!
        words.remove(atOffsets: offsets)
        print("💾 [로컬 DB] 단어 삭제 성공!")
    }
    
    // MARK: - 🔄 [가짜 PUT] 로컬 배열의 단어 수정/업데이트하기
    func updateWord(word: Word) {
        if let index = words.firstIndex(where: { $0.id == word.id }) {
            words[index] = word
            print("💾 [로컬 DB] 단어 업데이트 성공!")
        }
    }
    
    // ⭐ 즐겨찾기(별표) 토글
    func toggleMemorized(word: Word) {
        var updatedWord = word
        updatedWord.isMemorized.toggle()
        updateWord(word: updatedWord)
    }
}
