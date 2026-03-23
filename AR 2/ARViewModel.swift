import SwiftUI
import AVFoundation
import Combine
import GoogleGenerativeAI

// 1. 제미나이가 뱉어낼 JSON 데이터를 담을 그릇 (구조체)
struct ARWord: Codable, Identifiable {
    var id = UUID()
    let word: String          // 예: "コーヒー" 또는 "蘋果"
    let pronunciation: String // 예: "코-히-" 또는 "píng guǒ"
    let meaning: String       // 예: "커피" 또는 "사과"
    
    // 2번 조원(C++)에게 넘겨주기 위한 대략적인 화면상 위치 (0.0 ~ 1.0)
    let relativeX: Double
    let relativeY: Double
    
    enum CodingKeys: String, CodingKey {
        case word, pronunciation, meaning, relativeX, relativeY
    }
}

// 2. 인공지능 매니저 (제미나이와 통신하는 뷰모델)
@MainActor
class ARViewModel: ObservableObject {
    @Published var discoveredWords: [ARWord] = []
    @Published var isAnalyzing: Bool = false
    @Published var errorMessage: String? = nil
    
    // 카메라 화면 캡처 함수 (뼈대 유지)
    func captureCurrentFrame(from session: AVCaptureSession) -> UIImage? {
        return nil
    }
    
    // 🌟 진짜 제미나이 API 연동 함수 (address 파라미터 삭제 완료!)
    func analyzeScene(image: UIImage, targetLanguage: String) async {
        isAnalyzing = true
        errorMessage = nil
        
        // 1. API 키 꺼내오기 (QuizViewModel과 똑같이 깔끔한 방식으로 통일!)
        let apiKey = Bundle.main.geminiApiKey
        if apiKey.isEmpty {
            self.errorMessage = Constants.FatalErrors.noApiKey
            self.isAnalyzing = false
            return
        }
        
        // 2. 제미나이 모델 세팅
        let model = GenerativeModel(name: Constants.Config.modelName, apiKey: apiKey)
        
        // 3. 🌟 프롬프트 최적화 (위치 정보 제거 및 언어 디테일 추가)
        let prompt = """
        너는 똑똑한 원어민 AR 언어 선생님이야.
        
        첨부된 사진을 꼼꼼히 분석해서, 사진 속에서 언어 학습에 가장 유용하고 명확하게 보이는 핵심 사물 3개를 찾아줘.
        그리고 그 사물들의 이름을 '\(targetLanguage)'로 번역해 줘.
        (단, 목표 언어가 중국어일 경우, 중국 본토(Mainland)에서 일상적으로 자주 쓰는 어휘를 '번체자(Traditional)'로 표기할 것.)
        
        응답은 반드시 아래 JSON 배열 형식으로만 줘. 마크다운이나 다른 설명은 절대 추가하지 마. 오직 JSON 데이터만 출력해.
        [
            {
                "word": "단어",
                "pronunciation": "발음",
                "meaning": "뜻",
                "relativeX": 0.5,
                "relativeY": 0.5
            }
        ]
        """
        
        do {
            print("제미나이에게 시각 정보 전송 중... 🚀")
            
            // 4. 제미나이에게 사진과 텍스트 던지기
            let response = try await model.generateContent(prompt, image)
            
            guard let textResponse = response.text else {
                self.errorMessage = Constants.Errors.noResponse
                self.isAnalyzing = false
                return
            }
            
            // 5. 방어 로직 (마크다운 백틱 에러 원천 차단)
            let cleanedText = textResponse
                .replacingOccurrences(of: "`" + "`" + "`json", with: "")
                .replacingOccurrences(of: "`" + "`" + "`", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 6. 텍스트를 데이터(Data)로 변환
            guard let jsonData = cleanedText.data(using: .utf8) else {
                self.errorMessage = Constants.Errors.dataParseFailed
                self.isAnalyzing = false
                return
            }
            
            // 7. JSON 디코딩
            let decodedWords = try JSONDecoder().decode([ARWord].self, from: jsonData)
            
            // 8. 결과 저장 및 UI 업데이트
            self.discoveredWords = decodedWords
            print("🎉 분석 성공! \(decodedWords.count)개의 단어를 찾았어!")
            
        } catch {
            print("❌ 제미나이 통신 에러: \(error.localizedDescription)")
            self.errorMessage = "\(Constants.Errors.unknownErrorPrefix) \(error.localizedDescription)"
        }
        
        isAnalyzing = false
    }
}
