import Foundation
import SwiftUI
import Combine

@MainActor
class WordViewModel: ObservableObject {
    @Published var words: [Word] = []
    
    // 🔍 검색 및 품사 필터 변수
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    @Published var selectedPos: String = "명사" // 🌟 신규: 현재 선택된 품사 필터
    
    @Published var isLoading = false
    
    init() {
        // 검색 파이프라인: 0.3초 대기 후 검색어 확정 (기존 유지)
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
        
        loadWords() // 시작할 때 데이터 불러오기
    }
    
    // MARK: - 🌟 핵심 필터링 로직 (기능 추가)
    // 검색어 필터링에 '품사 필터' 조건을 추가하여 통합했습니다.
    var filteredWords: [Word] {
        words.filter { word in
            // 1. 품사가 일치하는지 확인
            let matchesPos = (word.pos == selectedPos)
            
            // 2. 검색어가 포함되는지 확인 (기존 로직)
            let matchesSearch = debouncedSearchText.isEmpty ||
                                word.term.lowercased().contains(debouncedSearchText.lowercased()) ||
                                word.meaning.lowercased().contains(debouncedSearchText.lowercased())
            
            // 두 조건을 모두 만족해야 화면에 나타남
            return matchesPos && matchesSearch
        }
    }
    
    // MARK: - 📥 [GET] AWS 서버에서 단어장 불러오기 (기존 유지)
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
    
    // MARK: - 📤 [POST] AWS 서버에 새 단어 추가하기 (기존 유지 + 품사 파라미터)
    func addWord(term: String, meaning: String, pos: String = "명사") async -> Bool {
        if words.contains(where: { $0.term.lowercased() == term.lowercased() }) {
            print("💡 이미 저장된 단어입니다.")
            return false
        }
        
        // 새 단어를 만들 때 품사(pos) 정보를 포함합니다.
        let newWord = Word(term: term, meaning: meaning, pos: pos)
        
        do {
            try await APIManager.shared.saveWord(word: newWord)
            loadWords() 
            return true
        } catch {
            print("\(Constants.Errors.networkErrorPrefix) \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 🗑️ [DELETE] AWS 서버에서 단어 지우기 (기존 유지)
    func deleteWord(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let wordToDelete = words[index]
                guard let wordId = wordToDelete.id else { continue }
                do {
                    try await APIManager.shared.deleteWord(wordId: wordId)
                } catch {
                    print("\(Constants.Errors.networkErrorPrefix) 삭제 실패: \(error.localizedDescription)")
                }
            }
            loadWords()
        }
    }
    
    // MARK: - 🔄 [PUT] AWS 서버에 단어 수정/업데이트하기 (기존 유지)
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
    
    // ⭐ [PUT] 즐겨찾기(별표) 토글 (기존 유지)
    func toggleMemorized(word: Word) {
        var updatedWord = word
        updatedWord.isMemorized.toggle()
        updateWord(word: updatedWord)
    }
}