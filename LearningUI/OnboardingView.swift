import SwiftUI
import GoogleGenerativeAI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    
    // 🌟 사용자 화면 표시용 언어/스타일 텍스트
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    
    // 🌟 [핵심] SpeechManager가 실제로 읽어줄 때 사용할 애플 공식 음성 코드 (예: ko-KR, en-US)
    @AppStorage("targetVoiceCode") private var targetVoiceCode: String = "en-US"
    
    // 💡 Picker용 선택 변수와 텍스트 입력 변수 분리
    @State private var selectedLangOption: String = "영어"
    @State private var customLangInput: String = ""
    
    @State private var selectedStyleOption: String = "표준"
    @State private var customStyleInput: String = ""
    
    // 🌟 AI 로딩 및 에러 처리를 위한 상태 변수
    @State private var isProcessingVoiceCode: Bool = false
    @State private var errorMessage: String? = nil
    
    let languagePresets = ["영어", "일본어", "중국어", "스페인어", "프랑스어", Constants.Labels.customInput]
    let stylePresets = ["표준", "호주 사투리", "간사이 사투리", "홍콩 광둥어 느낌", Constants.Labels.customInput]
    
    // 🌟 버튼 활성화 조건 (빈칸 방지 + 로딩 중 클릭 방지)
    private var isFormValid: Bool {
        let isLangValid = selectedLangOption != Constants.Labels.customInput || !customLangInput.trimmingCharacters(in: .whitespaces).isEmpty
        let isStyleValid = selectedStyleOption != Constants.Labels.customInput || !customStyleInput.trimmingCharacters(in: .whitespaces).isEmpty
        return isLangValid && isStyleValid && !isProcessingVoiceCode
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 언어 선택 섹션
                Section(header: Text(Constants.Labels.onboardingLangHeader)) {
                    Picker(Constants.Labels.targetLanguage, selection: $selectedLangOption) {
                        ForEach(languagePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedLangOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.langPlaceholder, text: $customLangInput)
                    }
                }
                
                // 2. 억양/스타일 섹션
                Section(header: Text(Constants.Labels.onboardingStyleHeader), footer: Text(Constants.Labels.onboardingStyleFooter)) {
                    Picker(Constants.Labels.targetStyle, selection: $selectedStyleOption) {
                        ForEach(stylePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedStyleOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.stylePlaceholder, text: $customStyleInput)
                    }
                }
                
                // 3. 시작 버튼 및 에러 표시 섹션
                Section {
                    Button(action: {
                        Task {
                            await handleStartButton()
                        }
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
                    
                    // 에러 발생 시 폼 하단에 빨간 글씨로 안내
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 5)
                    }
                }
                .listRowBackground(Color.clear) // 버튼 주변 배경을 깔끔하게
            }
            .navigationTitle(Constants.Labels.onboardingTitle)
            .onAppear {
                // 앱이 켜질 때 이전에 저장해 둔 값이 있으면 세팅!
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
    
    // MARK: - 🌟 제미나이와 통신하여 BCP-47 음성 코드 받아오기
    private func handleStartButton() async {
        isProcessingVoiceCode = true
        errorMessage = nil
        
        let finalLang = (selectedLangOption == Constants.Labels.customInput) ? customLangInput.trimmingCharacters(in: .whitespaces) : selectedLangOption
        let finalStyle = (selectedStyleOption == Constants.Labels.customInput) ? customStyleInput.trimmingCharacters(in: .whitespaces) : selectedStyleOption
        
        // 1. 유저가 입력한 자연어 텍스트 저장 (UI 표시용)
        targetLanguage = finalLang
        targetVoiceStyle = finalStyle
        
        // 2. 제미나이 API 준비
        let apiKey = Bundle.main.geminiApiKey
        if apiKey.isEmpty {
            self.errorMessage = "API 키가 누락되었습니다."
            self.isProcessingVoiceCode = false
            return
        }
        
        let model = GenerativeModel(name: Constants.Config.modelName, apiKey: apiKey)
        
        let prompt = """
        사용자가 원하는 언어는 '\(finalLang)', 원하는 억양/사투리/스타일은 '\(finalStyle)'이야.
        애플의 iOS AVSpeechSynthesisVoice가 지원하는 공식 BCP-47 언어 코드(예: ko-KR, en-US, en-GB, ja-JP, zh-CN, zh-TW, zh-HK, fr-FR 등) 중에서 이 요구사항에 가장 알맞은 코드 딱 1개만 골라줘.
        
        무조건 다른 말 다 빼고 'ko-KR'처럼 코드만 딱 5글자로 대답해. 마침표나 설명 붙이면 절대 안 돼.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let aiVoiceCode = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !aiVoiceCode.isEmpty else {
                print("🚨 AI가 빈 값을 반환했습니다. 기본값 en-US로 세팅합니다.")
                targetVoiceCode = "en-US"
                hasSeenOnboarding = true
                return
            }
            
            print("🎙️ AI가 골라준 성우 코드: \(aiVoiceCode)")
            
            // 4. 진짜 코드 저장 및 온보딩 종료 (메인 화면으로 이동)
            targetVoiceCode = aiVoiceCode
            hasSeenOnboarding = true
            
        } catch {
            print("🚨 AI 성우 코드 매핑 에러: \(error.localizedDescription)")
            self.errorMessage = "성우 설정 중 오류가 발생했습니다. 다시 시도해 주세요."
            self.isProcessingVoiceCode = false
        }
    }
}
