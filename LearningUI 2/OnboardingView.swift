import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    
    // 💡 Picker용 선택 변수와 텍스트 입력 변수 분리
    @State private var selectedLangOption: String = "영어"
    @State private var customLangInput: String = ""
    
    @State private var selectedStyleOption: String = "표준"
    @State private var customStyleInput: String = ""
    
    let languagePresets = ["영어", "일본어", "중국어", "스페인어", "프랑스어", Constants.Labels.customInput]
    let stylePresets = ["표준", "호주 사투리", "간사이 사투리", "홍콩 광둥어 느낌", Constants.Labels.customInput]
    
    // 🌟 [디테일 추가] 버튼을 눌러도 되는 상태인지 검사하는 로컬 변수
    private var isFormValid: Bool {
        let isLangValid = selectedLangOption != Constants.Labels.customInput || !customLangInput.trimmingCharacters(in: .whitespaces).isEmpty
        let isStyleValid = selectedStyleOption != Constants.Labels.customInput || !customStyleInput.trimmingCharacters(in: .whitespaces).isEmpty
        return isLangValid && isStyleValid
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
                
                // 3. 시작 버튼
                Button(action: {
                    // 💡 저장할 때, "직접 입력"을 골랐으면 유저가 친 글자를, 아니면 선택된 프리셋을 저장!
                    targetLanguage = (selectedLangOption == Constants.Labels.customInput) ? customLangInput.trimmingCharacters(in: .whitespaces) : selectedLangOption
                    targetVoiceStyle = (selectedStyleOption == Constants.Labels.customInput) ? customStyleInput.trimmingCharacters(in: .whitespaces) : selectedStyleOption
                    
                    print("로컬 저장 완료: \(targetLanguage) - \(targetVoiceStyle)")
                    hasSeenOnboarding = true
                }) {
                    Text(Constants.Labels.startLearnSpot)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                .disabled(!isFormValid) // 🌟 [디테일 추가] 빈칸이면 버튼을 꾹! 막아버림
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
}
