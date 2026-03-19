import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    
    // 💡 버그 해결: Picker용 선택 변수와 텍스트 입력 변수를 완전히 분리함!
    @State private var selectedLangOption: String = "영어"
    @State private var customLangInput: String = ""
    
    @State private var selectedStyleOption: String = "표준"
    @State private var customStyleInput: String = ""
    
    let languagePresets = ["영어", "일본어", "중국어", "스페인어", "프랑스어", Constants.Labels.customInput]
    let stylePresets = ["표준", "호주 사투리", "간사이 사투리", "홍콩 광둥어 느낌", Constants.Labels.customInput]
    
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
                    // 💡 저장할 때, "직접 입력"을 골랐으면 유저가 텍스트 필드에 친 글자를 진짜 변수에 넣음!
                    targetLanguage = (selectedLangOption == Constants.Labels.customInput) ? customLangInput : selectedLangOption
                    targetVoiceStyle = (selectedStyleOption == Constants.Labels.customInput) ? customStyleInput : selectedStyleOption
                    
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
            }
            .navigationTitle(Constants.Labels.onboardingTitle)
            // 💡 앱이 켜질 때 이전에 저장해 둔 값이 있으면 세팅해주는 센스!
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
}
