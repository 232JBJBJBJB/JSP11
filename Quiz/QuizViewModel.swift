import Foundation
import SwiftUI
import Combine
import GoogleGenerativeAI

// 🌟 신호등 역할을 할 Enum(상태 기계) 생성
enum QuizState {
    case idle // 퀴즈 출제 대기 중
    case loading // AI가 퀴즈 만드는 중 (로딩)
    case success(GeneratedQuiz) // 퀴즈 생성 성공! (데이터 포함)
    case failure(String) // 에러 발생 (에러 메시지 포함)
}

@MainActor
class QuizViewModel: ObservableObject {
    // 🌟 변수들을 'state' 하나로 통합! (처음엔 대기 상태로 시작)
    @Published var state: QuizState = .idle
    
    private let model: GenerativeModel
    
    init() {
        let apiKey = Bundle.main.geminiApiKey // 기존에 만들어둔 extension 활용
        // [Constants 적용] 모델 이름
        self.model = GenerativeModel(name: Constants.Config.modelName, apiKey: apiKey)
    }
    
    // 🌟 파라미터로 통합된 모델인 [Word]를 받음! (AWS에서 가져온 데이터)
    func makeQuiz(from savedWords: [Word]) async {
        // 로딩 시작!
        state = .loading
        
        // 1. 🎲 50:50 동전 던지기! (단어장이 비어있으면 강제로 '새 단어 모드')
        let isReviewMode = savedWords.isEmpty ? false : Bool.random()
        
        // 2. 모드에 따른 AI 지시사항(프롬프트) 작성
        let modeInstruction: String
        
        if isReviewMode {
            // 🟢 [복습 모드] 내 단어장에서 랜덤으로 하나 뽑기
            // 🚨 [변경점] 기존의 `!` 강제 추출 대신 안전하게 `?` 사용 후 기본값 처리 (앱 튕김 방지)
            let seedWord = savedWords.randomElement()?.term ?? "蘋果"
            modeInstruction = """
            [현재 모드: 복습 모드]
            사용자가 이미 학습 중인 단어: [ \(seedWord) ]
            이 단어를 '주제'나 '핵심 소재'로 활용해서 5지 선다형 퀴즈를 하나 만들어줘.
            """
        } else {
            // 🔵 [새 단어 모드] AI가 알아서 유용한 단어 하나 고르기
            modeInstruction = """
            [현재 모드: 새로운 단어 학습 모드]
            사용자에게 새로운 단어를 가르쳐주려고 해. 
            HSK 빈출 단어(실생활에서 자주 쓰는 유용한 단어) 중 임의로 '새로운 단어' 하나를 네가 직접 선정해 줘.
            그리고 네가 선정한 그 단어를 '주제'나 '핵심 소재'로 활용해서 5지 선다형 퀴즈를 만들어줘.
            """
        }
        
        let styles = [
            "A와 B의 자연스러운 대화 (Dialogue)",
            "짧은 에세이 또는 일기 (Essay)",
            "스마트폰 설정 화면 또는 앱 알림 메시지 (Mobile UI/Settings)",
            "공공장소 안내문 또는 사용 설명서 (Notice/Instruction)"
        ]
        
        let selectedStyle = styles.randomElement() ?? "짧은 에세이"
        
        // 3. 최종 프롬프트 조립
        let prompt = """
        너는 중국어 HSK 및 실생활 중국어 전문 강사야.
        
        \(modeInstruction)
        
        [필수 조건 - 아주 중요]:
        1. 글의 형식: 반드시 '\(selectedStyle)' 스타일로 작성할 것.
            - 설정 화면이라면: '개인정보 보호', '배터리', '알림' 같은 딱딱하고 간결한 어조.
            - 안내문이라면: '주의사항', '금지', '이용 방법' 같은 공적인 어조.
        2. 언어 스타일: '중국 본토(Mainland)' 표준어 어휘 + '번체자(Traditional)' 표기.
        3. 지문 길이: 2줄 정도로 아주 짧고 간결하게 작성할 것.
        
        4. ★ 빈칸(정답) 설정 ★:
            - 복습 모드든 새 단어 모드든, 빈칸 [____]에 들어갈 정답이 반드시 위에서 선정된 단어일 필요는 없음.
            - 핵심 단어는 글의 문맥(Context)을 만드는 데 사용하고, 정답은 그 문맥에서 문법적으로나 의미적으로 중요한 다른 단어(동사, 형용사, 접속사 등)여도 됨.
            - 사용자가 글을 끝까지 읽고 흐름을 파악해야 풀 수 있게 출제해.
        
        5. 질문: "다음 글의 빈칸에 들어갈 말로 가장 적절한 것은?" (한국어)
        6. 보기: 정답 1개, 오답 4개 (모두 번체자).
        
        [출력 형식]:
        오직 JSON 형식으로만 답해 (Markdown 없이).
        {
            "passage": "지문 내용...",
            "question": "문제...",
            "options": ["보기1", "보기2", "보기3", "보기4", "보기5"],
            "answerIndex": 0
        }
        """
        
        // 4. AI 요청 및 처리
        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else {
                state = .failure(Constants.Errors.noResponse)
                return
            }
            
            // 🧹 마크다운 찌꺼기 깔끔하게 지우기
            let cleanText = text.replacingOccurrences(of: "`" + "`" + "`json", with: "")
                                .replacingOccurrences(of: "`" + "`" + "`", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleanText.data(using: .utf8) {
                let decodedQuiz = try JSONDecoder().decode(GeneratedQuiz.self, from: data)
                // 🌟 성공: 데이터 파싱까지 완료되면 success 상태로 변경!
                state = .success(decodedQuiz)
            } else {
                state = .failure(Constants.Errors.dataParseFailed)
            }
        } catch {
            // 🚨 에러: 인터넷 끊김 등 각종 통신 에러 처리
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    state = .failure(Constants.Errors.internetDisconnected)
                case .timedOut:
                    state = .failure(Constants.Errors.timeOut)
                case .networkConnectionLost:
                    state = .failure(Constants.Errors.connectionLost)
                default:
                    state = .failure("\(Constants.Errors.networkErrorPrefix) (\(urlError.localizedDescription))")
                }
            } else {
                state = .failure("\(Constants.Errors.unknownErrorPrefix) \(error.localizedDescription) 😢")
            }
        }
    }
}
