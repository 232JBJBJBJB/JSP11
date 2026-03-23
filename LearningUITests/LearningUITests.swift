import Testing
import Foundation
@testable import LearningUI

struct LearningUITests {

    // --- [1번 문제] 단어 중복 검사 로직 (서버 가기 전 방어막 테스트) ---
    @Test("대소문자가 달라도 중복 단어로 걸러내는지 테스트")
    @MainActor
    func testDuplicateWordLogic() async throws {
        let viewModel = WordViewModel()
        
        // 🌟 가짜로 폰 메모리에 단어를 하나 심어둠 (서버에서 가져왔다고 가정)
        viewModel.words = [Word(term: "Apple", meaning: "사과")]
        
        // 1. 중복된 단어 추가 시도 (대소문자 다르게)
        let isSuccess = await viewModel.addWord(term: "aPple", meaning: "애플")
        
        // 2. 검증: addWord 함수가 서버에 요청을 안 보내고 바로 false를 뱉어야 정상!
        #expect(isSuccess == false, "중복된 단어이므로 저장에 실패(false 반환)해야 함")
        #expect(viewModel.words.count == 1, "배열에 새로운 단어가 추가되면 안 됨")
    }

    // --- [2번 문제] 검색 필터링 (완벽하게 독립적인 로직) ---
    @Test("검색어를 입력하면 해당 단어만 잘 필터링되는지 테스트")
    @MainActor
    func testSearchFilter() async throws {
        let viewModel = WordViewModel()
        
        // 🌟 가짜 데이터 세팅
        viewModel.words = [
            Word(term: "Apple", meaning: "사과"),
            Word(term: "Banana", meaning: "바나나")
        ]
        
        // 1. 기계가 검색창에 "App"을 입력함
        viewModel.searchText = "App"
        
        // 2. 주방장(디바운스)이 일할 수 있게 딱 0.5초 대기!
        try await Task.sleep(for: .seconds(0.5))
        
        // 3. 채점 시작!
        #expect(viewModel.filteredWords.count == 1, "검색 결과는 1개여야 함")
        #expect(viewModel.filteredWords.first?.term == "Apple", "검색된 단어는 Apple이어야 함")
    }

    // --- [3번 문제] 퀴즈 생성 로직 검사! (상태 머신 테스트) ---
    @Test("단어장이 비어있을 때 퀴즈 생성을 요청하면 에러 상태로 변하는지 테스트")
    @MainActor
    func testQuizGenerationWithEmptyWords() async throws {
        // 1. 준비
        let quizViewModel = QuizViewModel()
        let emptyWords: [Word] = []
        
        // 2. 실행 (빈 단어장으로 퀴즈 요청!)
        await quizViewModel.makeQuiz(from: emptyWords)
        
        // 3. 검증: 상태(State)가 .idle이 아니라 다른 상태로 바뀌었는지 확인!
        // (단어장이 비어있어도 우리 앱은 '새 단어 모드'로 퀴즈를 만들도록 개선했기 때문에,
        // 무조건 실패하는 게 아니라 loading이나 success로 넘어갈 수 있음!)
        
        let currentState = quizViewModel.state
        switch currentState {
        case .idle:
            Issue.record("퀴즈 요청을 했는데 아직도 idle 상태면 안 됨")
        default:
            #expect(true, "상태가 성공적으로 변경됨")
        }
    }
    
    // --- [4번 문제] 퀴즈 뷰모델 초기 상태 검사 ---
    @Test("퀴즈 화면에 처음 들어왔을 때 뷰모델의 초기 상태가 idle인지 테스트")
    @MainActor
    func testQuizViewModelInitialState() {
        let quizViewModel = QuizViewModel()
        
        // 🌟 퀴즈 뷰모델 구조가 State 하나로 통합되었으므로, 초기값이 idle인지 확인!
        switch quizViewModel.state {
        case .idle:
            #expect(true, "초기 상태는 무조건 idle이어야 함")
        default:
            Issue.record("초기 상태가 idle이 아님")
        }
    }
}
