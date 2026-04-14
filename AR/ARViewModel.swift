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
    
    // 🌟 조원의 품사 필터링을 위한 변수
    var pos: String?
    
    // 🌟 제미나이가 안 줄 수도 있으니 옵셔널 처리
    var relativeX: Double?
    var relativeY: Double?
    
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
    
    // ⚠️ [요구사항 2] 대기열 팝업 상태 변수 (현재는 백엔드 미완성으로 주석 처리)
    /*
    @Published var showQueuedAlert = false
    */
    
    // 🌟 본인의 API 키로 세팅!
    private let model = GenerativeModel(
        name: "gemini-2.5-flash",
        apiKey: Bundle.main.geminiApiKey
    )
    
    // ==========================================
    // 3. 제미나이 분석 실행 함수
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
            let resultText = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let response = try await self.model.generateContent(prompt, optimizedImage)
                    guard let text = response.text else {
                        throw NSError(domain: "GeminiError", code: -1, userInfo: [NSLocalizedDescriptionKey: "응답 내용이 비어있습니다."])
                    }
                    print("🤖 제미나이의 원본 대답:\n\(text)")
                    return text
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "서버 응답이 30초를 초과했습니다. 다시 시도해주세요."])
                }
                
                guard let firstResult = try await group.next() else {
                    throw NSError(domain: "UnknownError", code: -1, userInfo: [NSLocalizedDescriptionKey: "알 수 없는 에러가 발생했습니다."])
                }
                
                group.cancelAll()
                return firstResult
            }
            
            var cleanedText = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedText.hasPrefix("```json") { cleanedText.removeFirst(7) }
            else if cleanedText.hasPrefix("```") { cleanedText.removeFirst(3) }
            if cleanedText.hasSuffix("```") { cleanedText.removeLast(3) }
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleanedText.data(using: .utf8) else {
                throw NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "데이터를 변환할 수 없습니다."])
            }
            
            let decodedWords = try JSONDecoder().decode([ARWord].self, from: data)
            
            // UI 업데이트
            withAnimation {
                self.discoveredWords = decodedWords
            }
            
        } catch {
            print("❌ 에러 발생: \(error.localizedDescription)")
            
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
        
        guard let compressedData = newImage?.jpegData(compressionQuality: 0.7) else { return nil }
        return UIImage(data: compressedData)
    }
}