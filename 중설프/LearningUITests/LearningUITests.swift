import Testing
import SwiftData
import Foundation
@testable import LearningUI

struct LearningUITests {

    // --- [1번 문제] 단어 중복 검사 ---
    @Test("대소문자가 달라도 중복 단어로 걸러내는지 테스트")
    @MainActor
    func testDuplicateWord() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Word.self, configurations: config)
        let viewModel = WordViewModel()
        viewModel.modelContext = container.mainContext
        
        let firstTry = viewModel.addWord(term: "Apple", meaning: "사과")
        let secondTry = viewModel.addWord(term: "aPple", meaning: "애플")
        let thirdTry = viewModel.addWord(term: "Banana", meaning: "바나나")
        
        #expect(firstTry == true, "첫 번째 단어는 저장되어야 함")
        #expect(secondTry == false, "두 번째 단어는 중복이라 실패해야 함")
        #expect(thirdTry == true, "세 번째 단어는 저장되어야 함")
    }

    // --- [2번 문제] 검색 필터링 ---
        @Test("검색어를 입력하면 해당 단어만 잘 필터링되는지 테스트")
        @MainActor
        func testSearchFilter() async throws { // 👈 기다림(sleep)을 쓰기 위해 'async' 추가!
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Word.self, configurations: config)
            let viewModel = WordViewModel()
            viewModel.modelContext = container.mainContext
            
            _ = viewModel.addWord(term: "Apple", meaning: "사과")
            _ = viewModel.addWord(term: "Banana", meaning: "바나나")
            
            // 1. 기계가 검색창에 "App"을 입력함
            viewModel.searchText = "App"
            
            // 2. ⏳ [핵심!] 기계야, 주방장(디바운스)이 일할 수 있게 딱 0.5초만 숨 참아봐!
            try await Task.sleep(for: .seconds(0.5))
            
            // 3. 0.5초 뒤에 채점 시작!
            #expect(viewModel.filteredWords.count == 1, "검색 결과는 1개여야 함")
            #expect(viewModel.filteredWords.first?.term == "Apple", "검색된 단어는 Apple이어야 함")
        }
    
    // 👇 [새로 추가된 3번 문제] 퀴즈 생성 로직 검사!
    @Test("단어장이 비어있을 때 퀴즈 생성을 요청하면 에러를 뱉는지 테스트")
    @MainActor
    func testQuizGenerationWithEmptyWords() async throws {
        
        // 1. 준비 (Given): 퀴즈 뷰모델과 '텅 빈 단어장' 준비
        let quizViewModel = QuizViewModel()
        let emptyWords: [Word] = []
        
        // 2. 실행 (When): 빈 단어장으로 퀴즈를 만들어달라고 요청! (비동기 함수라 await 붙임)
        await quizViewModel.makeQuiz(from: emptyWords)
        
        // 3. 검증 (Then): 퀴즈는 안 만들어졌고, 에러 메시지가 Constants에 적힌 대로 잘 나왔는지 확인!
        #expect(quizViewModel.quiz == nil, "단어가 없으니 퀴즈는 nil이어야 해")
        #expect(quizViewModel.errorMessage == Constants.Errors.noSavedWords, "빈 단어장 에러 메시지가 떠야 해")
        #expect(quizViewModel.isLoading == false, "로딩 상태는 끝나 있어야 해")
    }
    
    @Test("퀴즈 화면에 처음 들어왔을 때 뷰모델의 초기값이 올바른지 테스트")
        @MainActor
        func testQuizViewModelInitialState() {
            // 1. 준비: 퀴즈 뷰모델을 갓 생성함
            let quizViewModel = QuizViewModel()
            
            // 2 & 3. 실행 및 검증: 처음 태어났을 땐 다 비어있고, 로딩도 안 돌고 있어야 정상!
            #expect(quizViewModel.quiz == nil, "처음엔 만들어진 퀴즈가 없어야 해")
            #expect(quizViewModel.isLoading == false, "처음엔 로딩 중이 아니어야 해")
            #expect(quizViewModel.errorMessage == nil, "처음엔 에러 메시지도 없어야 해")
        }
    
    @Test("단어 삭제(deleteWord) 기능이 잘 작동하는지 테스트")
        @MainActor
        func testDeleteWord() throws {
            // 1. 준비: 가짜 도서관 짓고 책 3권 넣기
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Word.self, configurations: config)
            let viewModel = WordViewModel()
            viewModel.modelContext = container.mainContext
            
            _ = viewModel.addWord(term: "Apple", meaning: "사과")
            _ = viewModel.addWord(term: "Banana", meaning: "바나나")
            _ = viewModel.addWord(term: "Cherry", meaning: "체리")
            
            // 2. 실행: 사용자가 두 번째 줄(Index 1)을 스와이프해서 지웠다고 가정!
            // (배열은 0부터 시작하니까, 1이 Banana야)
            let indexToSwipe = IndexSet(integer: 1)
            viewModel.deleteWord(at: indexToSwipe)
            
            // 3. 검증: 바나나가 진짜 사라졌는지 확인
            #expect(viewModel.words.count == 2, "책 3권 중 1권을 지웠으니 2권이 남아야 해")
            #expect(viewModel.words.contains(where: { $0.term == "Banana" }) == false, "도서관에 바나나는 더 이상 없어야 해")
        }
}
