import Foundation
import SwiftUI
import Combine

@MainActor
class WordViewModel: ObservableObject {
    @Published var words: [Word] = []
    
    // 🔍 검색 및 품사 필터 변수
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    @Published var selectedPos: String = "표준"
    @Published var isLoading = false
    
    init() {
        // 검색 파이프라인
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
        
        loadWords() // 앱 켜질 때 진짜 서버에서 데이터 불러오기!
    }
    
    // MARK: - 🌟 핵심 필터링 로직 (그대로 유지)
    var filteredWords: [Word] {
        words.filter { word in
            let matchesPos = (selectedPos == "표준") || (word.pos == selectedPos)
            let matchesSearch = debouncedSearchText.isEmpty ||
                                word.term.lowercased().contains(debouncedSearchText.lowercased()) ||
                                word.meaning.lowercased().contains(debouncedSearchText.lowercased())
            return matchesPos && matchesSearch
        }
    }
    
    // MARK: - 📥 [진짜 GET] 서버에서 단어장 불러오기
    func loadWords() {
        isLoading = true
        Task {
            do {
                // 🚀 APIManager 호출!
                let fetchedWords = try await APIManager.shared.fetchWords()
                self.words = fetchedWords
                print("✅ [통신 성공] 서버에서 단어 가져오기 완료! (총 \(words.count)개)")
            } catch {
                print("❌ [통신 실패] 단어 가져오기 에러: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    // MARK: - 📤 [진짜 POST] 서버에 새 단어 저장하기
    func addWord(term: String, meaning: String, pos: String = "명사") async -> Bool {
        let newWord = Word(term: term, meaning: meaning, pos: pos)
        
        do {
            // 🚀 APIManager로 서버에 전송!
            try await APIManager.shared.saveWord(word: newWord)
            print("✅ [통신 성공] '\(term)' 서버에 저장 완료!")
            
            // 저장이 성공했으니, 서버에서 최신 목록 다시 불러오기
            loadWords()
            return true
        } catch {
            print("❌ [통신 실패] 단어 저장 에러: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 🗑️ [진짜 DELETE] 서버에서 단어 지우기
    func deleteWord(at offsets: IndexSet) {
        offsets.forEach { index in
            let wordToDelete = words[index]
            // ID가 없으면 삭제 불가
            guard let wordId = wordToDelete.id else { return }
            
            Task {
                do {
                    // 🚀 APIManager로 삭제 요청!
                    try await APIManager.shared.deleteWord(wordId: wordId)
                    print("✅ [통신 성공] 단어 삭제 완료!")
                    
                    // 삭제 성공 후 목록 새로고침
                    loadWords()
                } catch {
                    print("❌ [통신 실패] 단어 삭제 에러: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 🔄 [진짜 PUT] 서버에 단어 정보 업데이트하기 (별표 쳤을 때)
    func updateWord(word: Word) {
        Task {
            do {
                // 🚀 APIManager로 업데이트 요청!
                try await APIManager.shared.updateWord(word: word)
                print("✅ [통신 성공] 단어 업데이트 완료!")
                
                // 업데이트 후 목록 새로고침
                loadWords()
            } catch {
                print("❌ [통신 실패] 단어 업데이트 에러: \(error.localizedDescription)")
            }
        }
    }
    
    // ⭐ 즐겨찾기(별표) 토글
    func toggleMemorized(word: Word) {
        var updatedWord = word
        updatedWord.isMemorized.toggle()
        updateWord(word: updatedWord)
    }
}
