import Foundation
import SwiftUI
import Combine

// ==========================================
// 1. 데이터 모델 (제미나이가 줄 JSON 형태)
// ==========================================
struct ARWord: Codable, Identifiable {
    var id = UUID() // SwiftUI 리스트나 반복문(ForEach)에서 쓰기 위한 고유 ID
    let word: String
    let pronunciation: String
    let meaning: String
    var pos: String? // 🌟 조원의 품사 필터링을 위한 변수
    
    // 🌟 제미나이(혹은 C++ 엔진)가 줄 수도 있으니 옵셔널 처리 (좌표)
    var relativeX: Double?
    var relativeY: Double?
    
    // JSON 통신할 때 좌표값도 받으려면 CodingKeys에 꼭 추가해 줘야 해!
    enum CodingKeys: String, CodingKey {
        case word
        case pronunciation
        case meaning
        case pos
        case relativeX
        case relativeY
    }
}

// ==========================================
// ARViewModel - AIManager 연동 버전
// ==========================================
@MainActor
class ARViewModel: ObservableObject {
    @Published var discoveredWords: [ARWord] = []
    @Published var isAnalyzing = false
    @Published var errorMessage: String? = nil
    
    // ⚠️ [요구사항 2] 대기열 팝업 상태 변수 (현재는 백엔드 미완성으로 주석 처리)
    /*
    @Published var showQueuedAlert = false
    */
    
    // (GenerativeModel 직접 선언하던 부분은 AIManager로 통합했으니 삭제!)
    
    // ==========================================
    // 3. 제미나이 분석 실행 함수 (AIManager 연동)
    // ==========================================
    func analyzeScene(image: UIImage, targetLanguage: String, styleOption: String, targetPos: String) async {
        self.isAnalyzing = true
        self.errorMessage = nil
        self.discoveredWords.removeAll()
        
        // 🌟 [최적화 1] 이미지 다이어트
        guard let optimizedImage = resizeImage(image: image, targetWidth: 800) else {
            self.errorMessage = "이미지 최적화에 실패했습니다."
            self.isAnalyzing = false
            return
        }
        
        // ⚠️ [요구사항 2] 나중에 백엔드 API를 연동할 때 202 응답 처리 로직 뼈대 (주석 처리)
        /*
        // 추후 직접 서버(Spring Boot)로 통신할 때 아래와 같이 사용하세요.
        // let response = try await APIManager.shared.queueImageForLater(...)
        // if response.statusCode == 202 {
        //     DispatchQueue.main.async {
        //         self.showQueuedAlert = true
        //     }
        // }
        */
        
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
        3. 🌟 해당 사물이 사진의 어느 위치에 있는지 중심 좌표를 가로 비율(relativeX, 0.0 왼쪽 ~ 1.0 오른쪽)과 세로 비율(relativeY, 0.0 상단 ~ 1.0 하단)로 반드시 계산해서 소수점으로 포함해.
        4. 응답은 무조건 아래 JSON 형식으로만 줘. 마크다운(` ```json `)이나 다른 설명은 절대 넣지 마.
        
        [출력 예시]
        [
            {
                "word": "현지 언어 단어",
                "pronunciation": "발음 기호",
                "meaning": "한국어 뜻",
                "pos": "\(targetPos == "표준" ? "명사" : targetPos)",
                "relativeX": 0.5,
                "relativeY": 0.4
            }
        ]
        """
        
        do {
            // 🌟 핵심 변경: AIManager.shared.generateTextFromImage() 사용 (GPT-4o 폴백 포함)
            let resultText = try await AIManager.shared.generateTextFromImage(
                prompt: prompt,
                image: optimizedImage
            )
            
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
            
            // 🌟 UI 업데이트 (애니메이션 및 햅틱 반응)
            withAnimation {
                self.discoveredWords = decodedWords
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
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
