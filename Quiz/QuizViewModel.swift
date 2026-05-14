import Foundation
import SwiftUI
import Combine

// ==========================================
// MARK: - Models
// ==========================================
enum QuizState {
    case idle
    case loading
    case success(GeneratedQuiz)
    case failure(String)
}

// ==========================================
// MARK: - QuizViewModel
// AIManager 연동 + 프리로드 + 빈도수 기반 추출
// ==========================================
@MainActor
class QuizViewModel: ObservableObject {
    @Published var state: QuizState = .idle
    @Published var targetLanguage: String = "중국어"

    // 🌟 사전 로딩된 퀴즈 창고 (0초 로딩의 비결!)
    private var preloadedQuiz: GeneratedQuiz? = nil
    private var isPreloading: Bool = false

    private let quizStyles = [
        "A와 B의 자연스러운 대화 (Dialogue)",
        "짧은 에세이 또는 일기 (Essay)",
        "스마트폰 설정 화면 또는 앱 알림 메시지 (Mobile UI)",
        "공공장소 안내문 또는 사용 설명서 (Notice)"
    ]

    // MARK: - Public: 퀴즈 요청 (버튼 클릭 시)
    func makeQuiz(from savedWords: [Word]) async {
        // 🌟 창고에 미리 만들어둔 퀴즈가 있다면 대기 시간 없이 즉시 반환!
        if let readyQuiz = preloadedQuiz {
            self.state = .success(readyQuiz)
            self.preloadedQuiz = nil
            // 퀴즈를 하나 꺼냈으니, 다음 퀴즈를 몰래 다시 만들어둠
            Task { await preloadNextQuiz(from: savedWords) }
            return
        }

        // 창고가 비어있다면 로딩 화면을 띄우고 실시간 생성
        self.state = .loading
        await fetchQuizFromAI(from: savedWords, isPreload: false)
    }

    // MARK: - Public: QuizView 진입 시 미리 로드 (뷰에서 onAppear로 호출)
    func preloadIfNeeded(from savedWords: [Word]) async {
        guard preloadedQuiz == nil, !isPreloading else { return }
        await preloadNextQuiz(from: savedWords)
    }

    // MARK: - Private: 백그라운드 사전 퀴즈 생성
    private func preloadNextQuiz(from savedWords: [Word]) async {
        guard !isPreloading else { return }
        isPreloading = true
        await fetchQuizFromAI(from: savedWords, isPreload: true)
        isPreloading = false
    }

    // MARK: - Private: AI 통신 및 핵심 로직 처리
    private func fetchQuizFromAI(from savedWords: [Word], isPreload: Bool) async {
        
        // 🌟 1. 출현 빈도수 기반 단어 정렬 (안 나온 단어부터 최우선 출제)
        let sortedWords = savedWords.sorted { word1, word2 in
            let count1 = word1.quizAppearCount ?? 0
            let count2 = word2.quizAppearCount ?? 0
            return count1 < count2
        }

        guard let targetWord = sortedWords.first else {
            guard !isPreload else { return }
            self.state = .failure("저장된 단어가 없습니다. 단어를 먼저 추가해 주세요.")
            return
        }

        let prompt = buildPrompt(for: targetWord)

        do {
            let rawText = try await AIManager.shared.generateText(prompt: prompt)
            
            let provider = AIManager.shared.lastUsedProvider == .gemini ? "Gemini" : "GPT-4o-mini (폴백)"
            print("🎯 [\(provider)] 퀴즈 생성 완료 (선정된 단어: \(targetWord.term))")

            // 🌟 2. 독립된 스레드에서 무거운 JSON 파싱 처리 (UI 끊김 방지)
            let quiz = try await Task.detached(priority: .userInitiated) {
                // CharacterSet 풀네임 명시로 스레드 격리 에러(Compiler Error) 완벽 차단!
                var cleaned = rawText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                if cleaned.hasPrefix("```json") { cleaned.removeFirst(7) }
                else if cleaned.hasPrefix("```") { cleaned.removeFirst(3) }
                if cleaned.hasSuffix("```") { cleaned.removeLast(3) }
                
                cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                guard let data = cleaned.data(using: .utf8) else {
                    throw DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "UTF-8 변환 실패")
                    )
                }
                return try JSONDecoder().decode(GeneratedQuiz.self, from: data)
            }.value

            // 🌟 3. 퀴즈에 출제된 단어의 출현 빈도수 1 증가시키기
            if let wordId = targetWord.id {
                Task {
                    await APIManager.shared.increaseQuizAppearCount(wordId: Int(wordId))
                }
            }

            // 🌟 4. 요청 목적에 맞게 분기 처리 (창고 저장 vs 즉시 화면 출력)
            if isPreload {
                self.preloadedQuiz = quiz
            } else {
                self.state = .success(quiz)
                // 현재 퀴즈를 화면에 뿌린 후, 곧바로 다음 퀴즈를 미리 만들러 감
                Task { await self.preloadNextQuiz(from: savedWords) }
            }

        } catch let error as URLError where error.code == .timedOut {
            guard !isPreload else { return }
            self.state = .failure("요청 시간이 초과되었습니다. 다시 시도해주세요.")
        } catch {
            guard !isPreload else { return }
            self.state = .failure("퀴즈 생성에 실패했습니다: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: 프롬프트 빌더 (특정 단어 타겟팅)
    private func buildPrompt(for word: Word) -> String {
        let selectedStyle = quizStyles.randomElement() ?? quizStyles[0]

        return """
        너는 '\(targetLanguage)' 전문 원어민 강사야.
        
        [현재 모드: 맞춤형 퀴즈 생성 모드]
        사용자가 지금 학습해야 할 최우선 단어는 [ \(word.term) (\(word.meaning)) ] 야.
        이 단어를 '주제'나 '핵심 소재' 혹은 '정답'으로 활용해서 5지 선다형 퀴즈를 하나 만들어줘.

        [필수 조건]:
        1. 형식: 반드시 '\(selectedStyle)' 스타일.
        2. 언어: 철저하게 자연스러운 [\(targetLanguage)]로 작성할 것.
        3. 길이: 2줄 정도로 짧고 간결하게.
        4. 빈칸: [____]에 들어갈 정답이 위 핵심 단어일 필요는 없으며 문법/의미적으로 중요한 단어로 출제.
        5. 질문: "다음 글의 빈칸에 들어갈 말로 가장 적절한 것은?" (이 질문만 한국어로 고정)
        6. 보기: 정답 1개, 오답 4개 (보기 내용은 모두 \(targetLanguage)).

        [출력 형식 - JSON만 반환 (Markdown 금지)]:
        {
            "passage": "지문 내용...",
            "question": "문제...",
            "options": ["보기1", "보기2", "보기3", "보기4", "보기5"],
            "answerIndex": 0
        }
        """
    }
}
