import Foundation
import GoogleGenerativeAI
import UIKit

// MARK: - AI 에러 타입 정의
enum AIError: Error, LocalizedError {
    case bothProvidersFailed(geminiError: String, gptError: String)
    case imageOptimizationFailed
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .bothProvidersFailed(let g, let gpt):
            return "Gemini 실패: \(g)\nGPT 실패: \(gpt)"
        case .imageOptimizationFailed:
            return "이미지 최적화에 실패했습니다."
        case .emptyResponse:
            return "AI 응답이 비어있습니다."
        }
    }
}

// MARK: - 어떤 AI가 응답했는지 추적 (디버깅/로그용)
enum AIProvider {
    case gemini, gpt
}

// MARK: - AIManager (핵심: Gemini 먼저, 실패 시에만 GPT)
@MainActor
class AIManager {
    static let shared = AIManager()
    
    // 마지막으로 성공한 프로바이더 (로그용)
    private(set) var lastUsedProvider: AIProvider = .gemini
    
    private let geminiModel: GenerativeModel
    private let gptEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    // 폴백 판단 기준 HTTP 상태 코드
    private let fallbackStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    
    private init() {
        self.geminiModel = GenerativeModel(
            name: Constants.Config.modelName, // "gemini-2.5-flash"
            apiKey: Bundle.main.geminiApiKey
        )
    }
    
    // ==========================================
    // 📝 텍스트 전용 요청 (QuizViewModel, OnboardingView용)
    // ==========================================
    func generateText(prompt: String) async throws -> String {
        // 1차: Gemini 시도
        do {
            let result = try await callGeminiText(prompt: prompt)
            lastUsedProvider = .gemini
            print("✅ [Gemini] 텍스트 생성 성공")
            return result
        } catch {
            print("⚠️ [Gemini] 실패 → GPT 폴백 시도. 원인: \(error.localizedDescription)")
        }
        
        // 2차: GPT 폴백 (Gemini가 실패할 때만!)
        do {
            let result = try await callGPTText(prompt: prompt)
            lastUsedProvider = .gpt
            print("✅ [GPT 폴백] 텍스트 생성 성공")
            return result
        } catch let gptError {
            print("❌ [GPT 폴백] 도 실패: \(gptError.localizedDescription)")
            throw gptError
        }
    }
    
    // ==========================================
    // 🖼️ 이미지 포함 요청 (ARViewModel용)
    // ==========================================
    func generateTextFromImage(prompt: String, image: UIImage) async throws -> String {
        // 1차: Gemini 시도 (이미지 분석은 Gemini가 훨씬 저렴!)
        do {
            let result = try await callGeminiImage(prompt: prompt, image: image)
            lastUsedProvider = .gemini
            print("✅ [Gemini] 이미지 분석 성공")
            return result
        } catch {
            print("⚠️ [Gemini] 이미지 분석 실패 → GPT-4o 폴백 시도. 원인: \(error.localizedDescription)")
        }
        
        // 2차: GPT-4o 폴백 (Gemini 실패 시에만, 비용 주의!)
        do {
            let result = try await callGPTImage(prompt: prompt, image: image)
            lastUsedProvider = .gpt
            print("✅ [GPT-4o 폴백] 이미지 분석 성공")
            return result
        } catch let gptError {
            print("❌ [GPT-4o 폴백] 도 실패: \(gptError.localizedDescription)")
            throw gptError
        }
    }
    
    // ==========================================
    // MARK: - Private: Gemini 호출
    // ==========================================
    private func callGeminiText(prompt: String) async throws -> String {
        // 30초 타임아웃 적용
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let response = try await self.geminiModel.generateContent(prompt)
                guard let text = response.text, !text.isEmpty else {
                    throw AIError.emptyResponse
                }
                return text
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func callGeminiImage(prompt: String, image: UIImage) async throws -> String {
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let response = try await self.geminiModel.generateContent(prompt, image)
                guard let text = response.text, !text.isEmpty else {
                    throw AIError.emptyResponse
                }
                return text
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // ==========================================
    // MARK: - Private: GPT 호출 (텍스트, gpt-4o-mini)
    // ==========================================
    private func callGPTText(prompt: String) async throws -> String {
        let apiKey = Bundle.main.openAIApiKey
        
        var request = URLRequest(url: gptEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // 텍스트는 저렴한 mini 사용
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "GPTError", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "GPT 응답 오류 (HTTP \(statusCode))"])
        }
        
        return try parseGPTTextResponse(data: data)
    }
    
    // ==========================================
    // MARK: - Private: GPT 호출 (이미지, gpt-4o)
    // ==========================================
    private func callGPTImage(prompt: String, image: UIImage) async throws -> String {
        let apiKey = Bundle.main.openAIApiKey
        
        // 이미지를 base64로 인코딩
        guard let imageData = image.jpegData(compressionQuality: 0.7),
              !imageData.isEmpty else {
            throw AIError.imageOptimizationFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        var request = URLRequest(url: gptEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "gpt-4o", // 이미지 분석은 4o 필요 (4o-mini는 이미지 품질 낮음)
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low" // 💰 비용 절약: low detail 모드
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "GPTError", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "GPT-4o 응답 오류 (HTTP \(statusCode))"])
        }
        
        return try parseGPTTextResponse(data: data)
    }
    
    // ==========================================
    // MARK: - GPT 응답 파싱 (공통)
    // ==========================================
    private func parseGPTTextResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw AIError.emptyResponse
        }
        return content
    }
}

// ==========================================
// MARK: - Bundle Extension (OpenAI 키 추가)
// ==========================================
extension Bundle {
    var openAIApiKey: String {
        guard let filePath = Bundle.main.path(forResource: Constants.Config.secretsFile,
                                               ofType: Constants.Config.plistExtension) else {
            fatalError("🚨 Secrets.plist 파일을 찾을 수 없습니다.")
        }
        guard let plist = NSDictionary(contentsOfFile: filePath) else {
            fatalError("🚨 Secrets.plist를 읽을 수 없습니다.")
        }
        // Secrets.plist에 "OPENAI_API_KEY" 키로 GPT API 키를 추가해야 합니다!
        guard let value = plist.object(forKey: "OPENAI_API_KEY") as? String else {
            fatalError("🚨 Secrets.plist에 'OPENAI_API_KEY'가 없습니다.")
        }
        return value
    }
}