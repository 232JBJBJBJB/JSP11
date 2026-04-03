import Foundation
import SwiftUI
import GoogleGenerativeAI
import Combine
// ==========================================
// 1. 데이터 모델 (제미나이가 줄 JSON 형태)
// ==========================================
struct ARWord: Codable, Identifiable {
    var id = UUID()
    let word: String
    let pronunciation: String
    let meaning: String
    
    // 🌟 [추가됨] 조원의 품사 필터링을 위한 변수
    var pos: String?
    
    // 🌟 [최적화됨] 제미나이가 안 줄 수도 있으니 옵셔널 처리
    var relativeX: Double?
    var relativeY: Double?
    
    // id는 우리가 앱에서 자체적으로 부여하므로 파싱에서 제외
    enum CodingKeys: String, CodingKey {
        case word, pronunciation, meaning, relativeX, relativeY, pos
    }
}

// ==========================================
// 2. AR 뷰모델 (두뇌 역할)
// ==========================================
@MainActor
class ARViewModel: ObservableObject {
    @Published var discoveredWords: [ARWord] = []
    @Published var isAnalyzing = false
    @Published var errorMessage: String? = nil
    
    // 🌟 본인의 API 키로 세팅!
    // (보안을 위해 보통 Config 파일에서 불러오지만, 여기선 예시로 둠)
    private let model = GenerativeModel(
        name: "gemini-2.5-flash",
        apiKey: Bundle.main.geminiApiKey // 🚨 네 API 키로 바꿔야 해!
    )
    
    // ==========================================
    // 3. 제미나이 분석 실행 함수 (품사 연동 완료)
    // ==========================================
    func analyzeScene(image: UIImage, targetLanguage: String, styleOption: String, targetPos: String) async {
        self.isAnalyzing = true
        self.errorMessage = nil
        self.discoveredWords.removeAll() // 기존 결과 초기화
        
        // 🌟 [최적화 1] 이미지 다이어트 (429 에러 방어 및 전송 속도 향상)
        guard let optimizedImage = resizeImage(image: image, targetWidth: 800) else {
            self.errorMessage = "이미지 최적화에 실패했습니다."
            self.isAnalyzing = false
            return
        }
        
        // 🌟 [추가됨] 선택한 품사에 따라 다르게 들어가는 마법의 주문서
        let posInstruction = targetPos == "표준"
            ? "화면에 보이는 가장 눈에 띄는 사물이나 특징(명사, 형용사 등)을"
            : "화면의 상황이나 사물을 묘사할 때 쓸 수 있는 '\(targetPos)'에 해당하는 단어만 엄격하게"

        let prompt = """
        너는 똑똑한 원어민 AR 언어 선생님이야. 언어 학습에 유용한 핵심 단어 3~5개를 찾아줘.
        
        [설정]
        - 목표 언어: \(targetLanguage)
        - 방언/스타일: \(styleOption)
        
        [중요 규칙]
        1. 사진을 분석해서 \(posInstruction) 추출해.
        (예: 형용사를 요청받았다면 '밝은', '넓은', '파란' 등을 추출하고, 동사라면 '앉다', '켜다' 등을 추출할 것)
        2. 반드시 한국어 뜻(meaning)은 명확하게 1~2개 단어로만 적어.
        3. 응답은 무조건 아래 JSON 형식으로만 줘. 마크다운(` ```json `)이나 다른 설명은 절대 넣지 마.
        
        [출력 예시]
        [
            {
                "word": "현지 언어 단어",
                "pronunciation": "발음 기호",
                "meaning": "한국어 뜻",
                "pos": "\(targetPos == "표준" ? "명사" : targetPos)"
            }
        ]
        """
        
        do {
            // 🌟 [최적화 2] 30초 타임아웃 레이스 (무한 로딩 방어막)
            let resultText = try await withThrowingTaskGroup(of: String.self) { group in
                
                // 트랙 1: 제미나이 통신
                group.addTask {
                    let response = try await self.model.generateContent(prompt, optimizedImage)
                    guard let text = response.text else {
                        throw NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: "응답 내용이 비어있습니다."])
                    }
                    
                    // 디버깅 단서 수집용 출력
                    print("🤖 제미나이의 원본 대답:\n\(text)")
                    return text
                }
                
                // 트랙 2: 30초 타이머
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "서버 응답이 30초를 초과했습니다. 다시 시도해주세요."])
                }
                
                guard let firstResult = try await group.next() else {
                    throw NSError(domain: "UnknownError", code: -1, userInfo: [NSLocalizedDescriptionKey: "알 수 없는 에러가 발생했습니다."])
                }
                
                group.cancelAll() // 먼저 끝난 쪽이 이기면 나머지 트랙 취소!
                return firstResult
            }
            
            // 🌟 [최적화 3] JSON 청소 (제미나이의 수다벽 차단)
            var cleanedText = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedText.hasPrefix("```json") {
                cleanedText.removeFirst(7)
            } else if cleanedText.hasPrefix("```") {
                cleanedText.removeFirst(3)
            }
            if cleanedText.hasSuffix("```") {
                cleanedText.removeLast(3)
            }
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // JSON 파싱
            guard let data = cleanedText.data(using: .utf8) else {
                throw NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "데이터를 변환할 수 없습니다."])
            }
            
            let decodedWords = try JSONDecoder().decode([ARWord].self, from: data)
            
            // UI 업데이트
            self.discoveredWords = decodedWords
            
        } catch {
            print("❌ 에러 발생: \(error.localizedDescription)")
            
            // 🌟 [최적화 4] 429 에러 친절하게 번역해주기
            if error.localizedDescription.contains("429") {
                self.errorMessage = "현재 사용자가 많아 AI가 바빠요. 5초 뒤에 다시 시도해 주세요!"
            } else {
                self.errorMessage = "분석 실패: \(error.localizedDescription)"
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        self.isAnalyzing = false
    }
    
    // ==========================================
    // 4. 이미지 압축 유틸리티 함수
    // ==========================================
    private func resizeImage(image: UIImage, targetWidth: CGFloat) -> UIImage? {
        let size = image.size
        let widthRatio  = targetWidth  / size.width
        let newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // JPEG 포맷으로 압축률 0.7 적용 (용량 대폭 감소)
        guard let compressedData = newImage?.jpegData(compressionQuality: 0.7) else { return nil }
        return UIImage(data: compressedData)
    }
}
