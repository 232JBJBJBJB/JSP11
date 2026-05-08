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
        
        loadWords() // 앱 실행 시 서버에서 전체 데이터 불러오기
    }
    
    // MARK: - 🌟 핵심 필터링 로직
    var filteredWords: [Word] {
        words.filter { word in
            let matchesPos = (selectedPos == "표준") || (word.pos == selectedPos)
            let matchesSearch = debouncedSearchText.isEmpty ||
                                word.term.lowercased().contains(debouncedSearchText.lowercased()) ||
                                word.meaning.lowercased().contains(debouncedSearchText.lowercased())
            return matchesPos && matchesSearch
        }
    }
    
    // MARK: - 📥 [GET] 서버에서 단어장 불러오기
    func loadWords() {
        isLoading = true
        Task {
            do {
                // 🚀 APIManager 호출!
                let fetchedWords = try await APIManager.shared.fetchWords()
                self.words = fetchedWords
                print("✅ [통신 성공] 서버 데이터 로드 완료! (총 \(words.count)개)")
            } catch {
                print("❌ [통신 실패] 단어 가져오기 에러: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    // MARK: - 📤 [POST] 서버에 새 단어 저장하기 (중복 방지 포함)
    func addWord(term: String, meaning: String, pos: String = "명사") async -> Bool {
        // 🌟 [중복 방지] 시연 시 동일 단어 중복 저장을 막기 위한 로직
        let cleanedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if words.contains(where: { $0.term.trimmingCharacters(in: .whitespacesAndNewlines) == cleanedTerm }) {
            print("⚠️ [중복 방지] '\(cleanedTerm)'은(는) 이미 단어장에 있습니다.")
            return false // 저장하지 않고 종료
        }

        let newWord = Word(term: cleanedTerm, meaning: meaning, pos: pos)
        
        do {
            // 🚀 APIManager로 서버에 전송!
            try await APIManager.shared.saveWord(word: newWord)
            print("✅ [통신 성공] '\(cleanedTerm)' 서버에 저장 완료!")
            
            loadWords() // 목록 새로고침
            return true
        } catch {
            print("❌ [통신 실패] 단어 저장 에러: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 🗑️ [DELETE] 서버에서 단어 지우기
    func deleteWord(at offsets: IndexSet) {
        offsets.forEach { index in
            let wordToDelete = words[index]
            guard let wordId = wordToDelete.id else { return }
            
            Task {
                do {
                    try await APIManager.shared.deleteWord(wordId: wordId)
                    print("✅ [통신 성공] 단어 삭제 완료!")
                    loadWords()
                } catch {
                    print("❌ [통신 실패] 단어 삭제 에러: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 🔄 [PUT] 서버에 단어 정보 업데이트하기
    func updateWord(word: Word) {
        Task {
            do {
                try await APIManager.shared.updateWord(word: word)
                print("✅ [통신 성공] 단어 업데이트 완료!")
                loadWords()
            } catch {
                print("❌ [통신 실패] 단어 업데이트 에러: \(error.localizedDescription)")
            }
        }
    }
    
    // ⭐ 즐겨찾기(별표) 토글
    func toggleMemorized(word: Word) {
        var updatedWord = word
        updatedWord.isMemorized = !(updatedWord.isMemorized ?? false)
        updateWord(word: updatedWord)
    }
    
    // 🌟 [AR 연동용] 현재 저장된 단어 리스트 반환
    func getExistingTerms() -> [String] {
        return words.map { $0.term }
    }
}
