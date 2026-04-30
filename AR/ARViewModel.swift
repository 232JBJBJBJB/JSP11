import Foundation
import SwiftUI
import Combine

struct ARWord: Codable, Identifiable {
    var id = UUID() // SwiftUI 리스트나 반복문(ForEach)에서 쓰기 위한 고유 ID
    let word: String
    let pronunciation: String
    let meaning: String
    let pos: String
    
    // 🌟 [3주차 대비] C++ 비전 엔진 조원이 넘겨줄 정밀 좌표값을 담을 그릇 (옵셔널)
    var relativeX: Double?
    var relativeY: Double?
    
    // JSON 통신할 때는 id, relativeX, relativeY는 빼고 기본 데이터 4개만 받도록 설정
    enum CodingKeys: String, CodingKey {
        case word
        case pronunciation
        case meaning
        case pos
    }
}
// ==========================================
// ARViewModel - AIManager 연동 버전
// GenerativeModel 직접 호출 → AIManager.shared 로 교체
// ==========================================
@MainActor
class ARViewModel: ObservableObject {
    @Published var discoveredWords: [ARWord] = []
    @Published var isAnalyzing = false
    @Published var errorMessage: String? = nil
    
    // ==========================================
    // 3. 제미나이 분석 실행 함수 (AIManager 연동)
    // ==========================================
    func analyzeScene(image: UIImage, targetLanguage: String, styleOption: String, targetPos: String) async {
        self.isAnalyzing = true
        self.errorMessage = nil
        self.discoveredWords.removeAll()
        
        // 이미지 최적화 (전송 속도 향상 + 429 방어)
        guard let optimizedImage = resizeImage(image: image, targetWidth: 800) else {
            self.errorMessage = "이미지 최적화에 실패했습니다."
            self.isAnalyzing = false
            return
        }
        
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
        2. 반드시 한국어 뜻(meaning)은 명확하게 1~2개 단어로만 적어.
        3. 응답은 무조건 아래 JSON 형식으로만 줘. 마크다운이나 다른 설명은 절대 넣지 마.
        
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
            // 🌟 핵심 변경: model.generateContent() → AIManager.shared.generateTextFromImage()
            // Gemini 실패 시 자동으로 GPT-4o로 폴백됨
            let resultText = try await AIManager.shared.generateTextFromImage(
                prompt: prompt,
                image: optimizedImage
            )
            
            // 어떤 AI가 응답했는지 로그
            let provider = AIManager.shared.lastUsedProvider == .gemini ? "Gemini" : "GPT-4o (폴백)"
            print("🤖 [\(provider)] AR 분석 원본 대답:\n\(resultText)")
            
            // JSON 청소 (마크다운 펜스 제거)
            var cleanedText = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedText.hasPrefix("```json") { cleanedText.removeFirst(7) }
            else if cleanedText.hasPrefix("```") { cleanedText.removeFirst(3) }
            if cleanedText.hasSuffix("```") { cleanedText.removeLast(3) }
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleanedText.data(using: .utf8) else {
                throw NSError(domain: "ParsingError", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "데이터를 변환할 수 없습니다."])
            }
            
            let decodedWords = try JSONDecoder().decode([ARWord].self, from: data)
            self.discoveredWords = decodedWords
            
        } catch {
            print("❌ AR 분석 에러: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("429") {
                self.errorMessage = "현재 사용자가 많아 AI가 바빠요. 5초 뒤에 다시 시도해 주세요!"
            } else {
                self.errorMessage = "분석 실패: \(error.localizedDescription)"
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        self.isAnalyzing = false
    }
    
    // 이미지 압축 유틸리티 (기존 유지)
    private func resizeImage(image: UIImage, targetWidth: CGFloat) -> UIImage? {
        let size = image.size
        let widthRatio = targetWidth / size.width
        let newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let compressedData = newImage?.jpegData(compressionQuality: 0.7) else { return nil }
        return UIImage(data: compressedData)
    }
}
