import SwiftUI

// ==========================================
// OnboardingView - AIManager 연동 버전
// GenerativeModel 직접 호출 → AIManager.shared 로 교체
// ==========================================
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    @AppStorage("targetVoiceCode") private var targetVoiceCode: String = "en-US"
    
    @State private var selectedLangOption: String = "영어"
    @State private var customLangInput: String = ""
    @State private var selectedStyleOption: String = "표준"
    @State private var customStyleInput: String = ""
    
    @State private var isProcessingVoiceCode: Bool = false
    @State private var errorMessage: String? = nil
    
    let languagePresets = ["영어", "일본어", "중국어", "스페인어", "프랑스어", Constants.Labels.customInput]
    let stylePresets = ["표준", "호주 사투리", "간사이 사투리", "홍콩 광둥어 느낌", Constants.Labels.customInput]
    
    private var isFormValid: Bool {
        let isLangValid = selectedLangOption != Constants.Labels.customInput || !customLangInput.trimmingCharacters(in: .whitespaces).isEmpty
        let isStyleValid = selectedStyleOption != Constants.Labels.customInput || !customStyleInput.trimmingCharacters(in: .whitespaces).isEmpty
        return isLangValid && isStyleValid && !isProcessingVoiceCode
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(Constants.Labels.onboardingLangHeader)) {
                    Picker(Constants.Labels.targetLanguage, selection: $selectedLangOption) {
                        ForEach(languagePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedLangOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.langPlaceholder, text: $customLangInput)
                    }
                }
                
                Section(header: Text(Constants.Labels.onboardingStyleHeader),
                        footer: Text(Constants.Labels.onboardingStyleFooter)) {
                    Picker(Constants.Labels.targetStyle, selection: $selectedStyleOption) {
                        ForEach(stylePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedStyleOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.stylePlaceholder, text: $customStyleInput)
                    }
                }
                
                Section {
                    Button(action: {
                        Task { await handleStartButton() }
                    }) {
                        HStack {
                            if isProcessingVoiceCode {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                                Text("AI 성우 섭외 중...")
                            } else {
                                Text(Constants.Labels.startLearnSpot)
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 5)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(Constants.Labels.onboardingTitle)
            .onAppear {
                if languagePresets.contains(targetLanguage) {
                    selectedLangOption = targetLanguage
                } else {
                    selectedLangOption = Constants.Labels.customInput
                    customLangInput = targetLanguage
                }
                if stylePresets.contains(targetVoiceStyle) {
                    selectedStyleOption = targetVoiceStyle
                } else {
                    selectedStyleOption = Constants.Labels.customInput
                    customStyleInput = targetVoiceStyle
                }
            }
        }
    }
    
    // MARK: - AIManager 연동 (Gemini 실패 시 GPT 자동 폴백)
    private func handleStartButton() async {
        isProcessingVoiceCode = true
        errorMessage = nil
        
        let finalLang = (selectedLangOption == Constants.Labels.customInput)
            ? customLangInput.trimmingCharacters(in: .whitespaces)
            : selectedLangOption
        let finalStyle = (selectedStyleOption == Constants.Labels.customInput)
            ? customStyleInput.trimmingCharacters(in: .whitespaces)
            : selectedStyleOption
        
        targetLanguage = finalLang
        targetVoiceStyle = finalStyle
        
        let prompt = """
        사용자가 원하는 언어는 '\(finalLang)', 원하는 억양/사투리/스타일은 '\(finalStyle)'이야.
        애플의 iOS AVSpeechSynthesisVoice가 지원하는 공식 BCP-47 언어 코드(예: ko-KR, en-US, en-GB, ja-JP, zh-CN, zh-TW, zh-HK, fr-FR 등) 중에서 이 요구사항에 가장 알맞은 코드 딱 1개만 골라줘.
        무조건 다른 말 다 빼고 'ko-KR'처럼 코드만 딱 5글자로 대답해. 마침표나 설명 붙이면 절대 안 돼.
        """
        
        do {
            // 🌟 핵심 변경: model.generateContent() → AIManager.shared.generateText()
            // Gemini 실패 시 자동으로 GPT-4o-mini로 폴백됨
            let aiVoiceCode = try await AIManager.shared.generateText(prompt: prompt)
            let cleaned = aiVoiceCode.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let provider = AIManager.shared.lastUsedProvider == .gemini ? "Gemini" : "GPT (폴백)"
            print("🎙️ [\(provider)] 성우 코드: \(cleaned)")
            
            targetVoiceCode = cleaned.isEmpty ? "en-US" : cleaned
            hasSeenOnboarding = true
            
        } catch {
            print("🚨 성우 코드 매핑 에러: \(error.localizedDescription)")
            self.errorMessage = "성우 설정 중 오류가 발생했습니다. 다시 시도해 주세요."
            self.isProcessingVoiceCode = false
        }
    }
}
