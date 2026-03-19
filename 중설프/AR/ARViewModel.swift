import SwiftUI
import AVFoundation
import Combine
import GoogleGenerativeAI

// 1. 제미나이가 뱉어낼 JSON 데이터를 담을 그릇 (구조체)
struct ARWord: Codable, Identifiable {
    var id = UUID()
    let word: String          // 예: "コーヒー" (목표 언어 단어)
    let pronunciation: String // 예: "코-히-" (발음)
    let meaning: String       // 예: "커피" (한국어 뜻)
    
    // 2번 조원(C++)에게 넘겨주기 위한 대략적인 화면상 위치 (0.0 ~ 1.0)
    let relativeX: Double
    let relativeY: Double
    
    // JSON에서 데이터를 받아올 때, id는 빼고 나머지 5개만 맞춰서 가져오라는 지도
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
    
    // 카메라 화면 캡처 함수 (CameraManager가 대신 해주므로 뼈대만 유지)
    func captureCurrentFrame(from session: AVCaptureSession) -> UIImage? {
        return nil
    }
    
    // 진짜 제미나이 API 연동 함수
    func analyzeScene(image: UIImage, address: String, targetLanguage: String) async {
        isAnalyzing = true
        errorMessage = nil
        
        // 1. Secrets.plist에서 API 키 꺼내오기
        guard let path = Bundle.main.path(forResource: Constants.Config.secretsFile, ofType: Constants.Config.plistExtension),
              let dict = NSDictionary(contentsOfFile: path),
              let apiKey = dict[Constants.Config.apiKeyName] as? String else {
            self.errorMessage = Constants.FatalErrors.noApiKey
            self.isAnalyzing = false
            return
        }
        
        // 2. 제미나이 모델 세팅
        let model = GenerativeModel(name: Constants.Config.modelName, apiKey: apiKey)
        
        // 3. 프롬프트 세팅
        let prompt = """
        너는 똑똑한 원어민 AR 언어 선생님이야.
        현재 사용자의 위치는 '\(address)'야.
        
        첨부된 사진을 보고, 이 장소에서 학습하기 가장 좋은 사물 3개를 찾아서 
        '\(targetLanguage)'로 번역해 줘.
        
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
            print("제미나이에게 전송 중... 🚀")
            
            // 4. 제미나이에게 사진과 텍스트 던지기
            let response = try await model.generateContent(prompt, image)
            
            guard let textResponse = response.text else {
                self.errorMessage = Constants.Errors.noResponse
                self.isAnalyzing = false
                return
            }
            
            // 5. 방어 로직 (마크다운 백틱 에러를 원천 차단하는 방식)
            let jsonMarker = String(repeating: "`", count: 3) + "json"
            let backtickMarker = String(repeating: "`", count: 3)
            
            let cleanedText = textResponse
                .replacingOccurrences(of: jsonMarker, with: "")
                .replacingOccurrences(of: backtickMarker, with: "")
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
