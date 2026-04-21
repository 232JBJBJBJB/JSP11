import Foundation
import SwiftUI
import Combine
import GoogleGenerativeAI

// MARK: - Quiz State

enum QuizState {
    case idle
    case loading
    case success(GeneratedQuiz)
    case failure(String)
}

// MARK: - GeneratedQuiz Model

struct GeneratedQuiz: Codable {
    let passage: String
    let question: String
    let options: [String]
    let answerIndex: Int
}

// MARK: - QuizViewModel

@MainActor
class QuizViewModel: ObservableObject {
    @Published var state: QuizState = .idle
    @Published var targetLanguage: String = "중국어"

    private let model: GenerativeModel

    // 사전 로딩된 퀴즈 창고
    private var preloadedQuiz: GeneratedQuiz? = nil
    private var isPreloading: Bool = false

    private let quizStyles = [
        "A와 B의 자연스러운 대화 (Dialogue)",
        "짧은 에세이 또는 일기 (Essay)",
        "스마트폰 설정 화면 또는 앱 알림 메시지 (Mobile UI)",
        "공공장소 안내문 또는 사용 설명서 (Notice)"
    ]

    init() {
        let apiKey = Bundle.main.geminiApiKey
        self.model = GenerativeModel(name: Constants.Config.modelName, apiKey: apiKey)
    }

    // MARK: - Public: 퀴즈 요청 (버튼 클릭 시)

    func makeQuiz(from savedWords: [Word]) async {
        // ✅ 창고에 미리 만들어둔 퀴즈가 있다면 즉시 반환
        if let readyQuiz = preloadedQuiz {
            self.state = .success(readyQuiz)
            self.preloadedQuiz = nil

            // 사용자가 문제를 푸는 동안 다음 문제 백그라운드 생성
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

    // MARK: - Private: AI 통신 + 최적화 로직

    private func fetchQuizFromAI(from savedWords: [Word], isPreload: Bool) async {
        let prompt = buildPrompt(from: savedWords)

        do {
            // ✅ 10초 타임아웃: withThrowingTaskGroup으로 경쟁
            let rawText = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let response = try await self.model.generateContent(prompt)
                    guard let text = response.text else {
                        throw URLError(.badServerResponse)
                    }
                    return text
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10초
                    throw URLError(.timedOut)
                }
                // 먼저 완료된 Task의 결과를 사용하고 나머지는 취소
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            // ✅ Task.detached: JSON 파싱을 메인 스레드에서 완전히 격리
            // 마크다운 제거 → JSONDecoder 파싱을 백그라운드에서 처리
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

            // ✅ 사전 로딩이면 창고에 저장, 일반 요청이면 state 업데이트
            if isPreload {
                self.preloadedQuiz = quiz
            } else {
                self.state = .success(quiz)
                // 성공 직후 다음 퀴즈 미리 생성 시작
                Task { await preloadNextQuiz(from: savedWords) }
            }

        } catch let error as URLError where error.code == .timedOut {
            guard !isPreload else { return }
            self.state = .failure("요청 시간이 초과되었습니다. 다시 시도해주세요.")
        } catch {
            guard !isPreload else { return }
            self.state = .failure("퀴즈 생성에 실패했습니다: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: 프롬프트 빌더

    private func buildPrompt(from savedWords: [Word]) -> String {
        // ✅ O(1) 랜덤 추출: 배열 셔플 없이 randomElement() 사용
        let isReviewMode = !savedWords.isEmpty && Bool.random()
        let selectedStyle = quizStyles.randomElement() ?? quizStyles[0]

        let modeInstruction: String
        if isReviewMode {
            // ✅ O(1): savedWords 전체를 섞지 않고 단 하나의 단어만 즉시 추출
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
            \(targetLanguage) 빈출 단어(실생활에서 자주 쓰는 유용한 단어) 중 임의로 '새로운 단어' 하나를 네가 직접 선정해 줘.
            그리고 네가 선정한 그 단어를 '주제'나 '핵심 소재'로 활용해서 5지 선다형 퀴즈를 만들어줘.
            """
        }

        return """
        너는 '\(targetLanguage)' 전문 원어민 강사야.
        \(modeInstruction)

        [필수 조건]:
        1. 형식: 반드시 '\(selectedStyle)' 스타일.
        2. 언어: 철저하게 자연스러운 [\(targetLanguage)]로 작성할 것. (해당 언어의 표준 표기법을 따를 것).
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