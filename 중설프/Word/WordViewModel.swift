import Foundation
import SwiftUI
import Combine

@MainActor // 화면(UI)을 바꾸는 작업이 많아서 안전하게 메인 스레드에서 돌리도록 명시!
class WordViewModel: ObservableObject {
    @Published var words: [Word] = []
    
    // 1. 손님이 타자를 치는 즉시 바뀌는 글자 (UI 연결용)
    @Published var searchText: String = ""
    
    // 2. 주방장이 0.3초 기다렸다가 최종 확정 지은 글자 (실제 검색용)
    @Published var debouncedSearchText: String = ""
    
    // 🌟 [변신 1] 애플 사서(modelContext) 해고하고, 점장님(Repository) 모셔오기!
    private let repository: WordRepository
    
    // 🌟 [변신 2] 뷰모델이 태어날 때 어떤 점장님과 일할지 외부에서 정해줌 (의존성 주입)
    init(repository: WordRepository) {
        self.repository = repository
        
        // 검색 파이프라인 (기존과 동일)
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
    }
    
    var filteredWords: [Word] {
        if debouncedSearchText.isEmpty {
            return words
        } else {
            return words.filter { word in
                word.term.contains(debouncedSearchText) || word.meaning.contains(debouncedSearchText)
            }
        }
    }
        
    // 🌟 [변신 3] 도서관에서 책 꺼내오기 -> 점장님한테 구름(Firebase)에서 책 가져오라고 시키기!
    func loadWords() async {
        do {
            // 점장님이 인터넷에서 가져올 때까지 기다림(await)
            self.words = try await repository.fetchWords()
        } catch {
            print("데이터 로드 실패: \(error)")
        }
    }
    
    // 🌟 [변신 4] 책 추가하기 (인터넷 통신이 필요하므로 async 붙임)
    func addWord(term: String, meaning: String) async -> Bool {
        // 중복 체크는 폰에 있는 배열(words)에서 빠르게 검사
        if words.contains(where: { $0.term.lowercased() == term.lowercased() }) {
            return false
        }
        
        do {
            // 점장님한테 구름에 저장해달라고 부탁
            try await repository.addWord(term: term, meaning: meaning)
            // 저장이 끝나면 목록 다시 싹 새로고침
            await loadWords()
            return true
        } catch {
            print("단어 추가 실패: \(error)")
            return false
        }
    }
    
    // 🌟 [변신 5] 책 폐기하기 (인터넷 통신 필요)
    func deleteWord(at offsets: IndexSet) async {
        for index in offsets {
            let wordToDelete = words[index]
            do {
                // 점장님한테 구름에서 지워달라고 부탁
                try await repository.deleteWord(word: wordToDelete)
            } catch {
                print("단어 삭제 실패: \(error)")
            }
        }
        // 다 지우고 나면 목록 새로고침
        await loadWords()
    }
    
    // ----------------------------------------------------
    // 👇👇 여기가 방금 전 코드에서 누락됐던 핵심 부분이야! 👇👇
    // ----------------------------------------------------
    
    // 🌟 1. 상세 화면에서 단어 뜻/예문 등을 수정했을 때 부르는 함수
    func updateWord(word: Word) async {
        do {
            try await repository.updateWord(word: word) // 점장님한테 수정해달라고 요청
            await loadWords() // 완료되면 목록 새로고침
        } catch {
            print("단어 업데이트 실패: \(error)")
        }
    }
    
    // 🌟 2. 메인 화면에서 별표(즐겨찾기)를 눌렀을 때 부르는 함수
    func toggleMemorized(word: Word) async {
        var updatedWord = word
        updatedWord.isMemorized.toggle() // 별표 상태 반대로 뒤집기
        
        do {
            try await repository.updateWord(word: updatedWord) // 점장님한테 바뀐 별표 상태 저장해달라고 요청
            await loadWords() // 완료되면 목록 새로고침
        } catch {
            print("별표 업데이트 실패: \(error)")
        }
    }
}
