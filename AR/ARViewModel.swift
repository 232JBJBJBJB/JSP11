import Foundation
import SwiftUI
import Combine

// ==========================================
// 1. 데이터 모델 (제미나이가 줄 JSON 형태)
// ==========================================
struct ARWord: Codable, Identifiable {
    var id = UUID()
    let word: String
    let pronunciation: String
    let meaning: String
    var pos: String?
    
    var relativeX: Double?
    var relativeY: Double?
    
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
    
    // ==========================================
    // 3. 제미나이 분석 실행 함수 (AIManager 연동)
    // ==========================================
    // 🌟 [핵심 변경] 분석이 끝난 후 C++ 처리가 완료된 '흑백+블러 이미지'를 반환하도록 수정!
    func analyzeScene(image: UIImage, targetLanguage: String, styleOption: String, targetPos: String, existingWords: [String] = []) async -> UIImage? {
        self.isAnalyzing = true
        self.errorMessage = nil
        self.discoveredWords.removeAll()
        
        guard let optimizedImage = resizeImage(image: image, targetWidth: 800) else {
            self.errorMessage = "이미지 최적화에 실패했습니다."
            self.isAnalyzing = false
            return nil
        }
        
        let posInstruction = targetPos == "표준"
            ? "화면에 보이는 가장 눈에 띄는 사물이나 특징(명사, 형용사 등)을"
            : "화면의 상황이나 사물을 묘사할 때 쓸 수 있는 '\(targetPos)'에 해당하는 단어만 엄격하게"
        
        let excludeInstruction = existingWords.isEmpty
            ? ""
            : "\n- 제외할 단어: [\(existingWords.joined(separator: ", "))] (이 단어들은 사용자가 이미 학습했으니 절대 출력하지 말고 다른 사물이나 특징을 찾아)"

        let prompt = """
        너는 똑똑한 원어민 AR 언어 선생님이야. 언어 학습에 유용한 핵심 단어 3~5개를 찾아줘.
        
        [설정]
        - 목표 언어: \(targetLanguage) (반드시 번체자 사용)
        - 방언/스타일: \(styleOption)\(excludeInstruction)
        
        [중요 규칙]
        1. 사진을 분석해서 \(posInstruction) 추출해.
        2. 반드시 한국어 뜻(meaning)은 명확하게 1~2개 단어로만 적어.
        3. 🌟 발음 기호(pronunciation): 반드시 대륙식 보통화(Mandarin) 기준의 '표준 한어병음(Hanyu Pinyin, 1~4성 숫자 표기)'으로만 적어. 광둥어(Jyutping)나 한국어 한자 독음(예: '있을 유')은 절대 포함하지 마.
        4. 🌟 해당 사물이 사진의 어느 위치에 있는지 중심 좌표를 가로 비율(relativeX, 0.0 왼쪽 ~ 1.0 오른쪽)과 세로 비율(relativeY, 0.0 상단 ~ 1.0 하단)로 반드시 계산해서 소수점으로 포함해.
        5. 응답은 무조건 아래 JSON 형식으로만 줘. 마크다운(` ```json `)이나 다른 설명은 절대 넣지 마.
        
        [출력 예시]
        [
            {
                "word": "현지 언어 단어(번체자)",
                "pronunciation": "발음 기호(한어병음)",
                "meaning": "한국어 뜻",
                "pos": "\(targetPos == "표준" ? "명사" : targetPos)",
                "relativeX": 0.5,
                "relativeY": 0.4
            }
        ]
        """
        
        do {
            let resultText = try await AIManager.shared.generateTextFromImage(
                prompt: prompt,
                image: optimizedImage
            )
            
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
            
            let filteredWords = decodedWords.filter { !existingWords.contains($0.word) }
            
            // =========================================================
            // 🌟 C++ 엔진에 분석된 단어와 컬러 포커스용 '가짜 박스' 좌표 쏴주기
            // =========================================================
            C_ClearARWords()
            
            for word in filteredWords {
                let rx = Float(word.relativeX ?? 0.5)
                let ry = Float(word.relativeY ?? 0.5)
                let boxSize: Float = 0.3
                
                C_UpdateARWords_V2(
                    word.word,
                    word.pronunciation,
                    word.meaning,
                    rx, ry,
                    max(0.0, rx - (boxSize / 2)),
                    max(0.0, ry - (boxSize / 2)),
                    min(1.0, rx + (boxSize / 2)),
                    min(1.0, ry + (boxSize / 2))
                )
            }
            
            // 🌟 [핵심 타이밍 마법] 단어 세팅이 끝났으니, 정지된 원본 사진을 C++로 보내서 흑백+말풍선을 그려옴!
            var finalProcessedImage: UIImage? = nil
            if !filteredWords.isEmpty {
                // 방금 찍었던 원본 사진(image)을 넣고 흑백 블러(applyBlur: true) 실행!
                finalProcessedImage = C_RenderEnhancedBubbles(image, true, 1.0)
            }
            // =========================================================
            
            withAnimation {
                self.discoveredWords = filteredWords
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
            self.isAnalyzing = false
            return finalProcessedImage // 🌟 완성된 흑백 사진을 뷰로 반환!
            
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
        return nil
    }
    
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
