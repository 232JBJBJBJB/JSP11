import Foundation
import SwiftUI
import Combine

// ==========================================
// QuizViewModel - AIManager 연동 버전
// GenerativeModel 직접 호출 → AIManager.shared 로 교체
// ==========================================
enum QuizState {
    case idle
    case loading
    case success(GeneratedQuiz)
    case failure(String)
}

// MARK: - GeneratedQuiz Model


@MainActor
class QuizViewModel: ObservableObject {
    @Published var state: QuizState = .idle
    @Published var targetLanguage: String = "중국어"

    // 사전 로딩된 퀴즈 창고
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
        // 창고에 미리 만들어둔 퀴즈가 있다면 즉시 반환
        if let readyQuiz = preloadedQuiz {
            self.state = .success(readyQuiz)
            self.preloadedQuiz = nil
            Task { await preloadNextQuiz(from: savedWords) }
            return
        }

        self.state = .loading
        await fetchQuizFromAI(from: savedWords, isPreload: false)
    }

    // MARK: - Private: 백그라운드 사전 퀴즈 생성
    private func preloadNextQuiz(from savedWords: [Word]) async {
        guard !isPreloading else { return }
        isPreloading = true
        await fetchQuizFromAI(from: savedWords, isPreload: true)
        isPreloading = false
    }

    // MARK: - Private: AI 통신 (AIManager로 교체)
    private func fetchQuizFromAI(from savedWords: [Word], isPreload: Bool) async {
        let prompt = buildPrompt(from: savedWords)

        do {
            // 🌟 핵심 변경: model.generateContent() → AIManager.shared.generateText()
            // Gemini 실패 시 자동으로 GPT-4o-mini로 폴백됨
            let rawText = try await AIManager.shared.generateText(prompt: prompt)
            
            let provider = AIManager.shared.lastUsedProvider == .gemini ? "Gemini" : "GPT-4o-mini (폴백)"
            print("🎯 [\(provider)] 퀴즈 생성 완료")

            // JSON 파싱은 백그라운드에서
            let quiz = try await Task.detached(priority: .userInitiated) {
                let cleaned = rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let data = cleaned.data(using: .utf8) else {
                    throw DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "UTF-8 변환 실패")
                    )
                }
                return try JSONDecoder().decode(GeneratedQuiz.self, from: data)
            }.value

            if isPreload {
                self.preloadedQuiz = quiz
            } else {
                self.state = .success(quiz)
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

    // MARK: - Private: 프롬프트 빌더 (기존 유지)
    private func buildPrompt(from savedWords: [Word]) -> String {
        let isReviewMode = !savedWords.isEmpty && Bool.random()
        let selectedStyle = quizStyles.randomElement() ?? quizStyles[0]

        let modeInstruction: String
        if isReviewMode {
            let seedWord = savedWords.randomElement()?.term ?? "Hello"
            modeInstruction = """
            [현재 모드: 복습 모드]
            사용자가 이미 학습 중인 단어: [ \(seedWord) ]
            이 단어를 '주제'나 '핵심 소재'로 활용해서 5지 선다형 퀴즈를 하나 만들어줘.
            """
        } else {
            modeInstruction = """
            [현재 모드: 새로운 단어 학습 모드]
            사용자에게 새로운 단어를 가르쳐주려고 해.
            \(targetLanguage) 빈출 단어 중 임의로 '새로운 단어' 하나를 네가 직접 선정해 줘.
            그리고 네가 선정한 그 단어를 '주제'나 '핵심 소재'로 활용해서 5지 선다형 퀴즈를 만들어줘.
            """
        }

        return """
        너는 '\(targetLanguage)' 전문 원어민 강사야.
        \(modeInstruction)

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
