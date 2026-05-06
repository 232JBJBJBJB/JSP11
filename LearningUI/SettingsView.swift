import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // 🌟 앱 전역 설정 (AppStorage라서 변경 즉시 전체 반영)
    @AppStorage("targetLanguage") private var targetLanguage: String = "영어"
    @AppStorage("targetVoiceStyle") private var targetVoiceStyle: String = "표준"
    @AppStorage("targetVoiceCode") private var targetVoiceCode: String = "en-US"

    // Picker 선택용 로컬 상태
    @State private var selectedLangOption: String = "영어"
    @State private var customLangInput: String = ""
    @State private var selectedStyleOption: String = "표준"
    @State private var customStyleInput: String = ""

    // 저장 상태
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var saveSuccess: Bool = false

    let languagePresets = ["영어", "일본어", "중국어", "스페인어", "프랑스어", Constants.Labels.customInput]
    let stylePresets = ["표준", "호주 사투리", "간사이 사투리", "홍콩 광둥어 느낌", Constants.Labels.customInput]

    private var isFormValid: Bool {
        let isLangValid = selectedLangOption != Constants.Labels.customInput
            || !customLangInput.trimmingCharacters(in: .whitespaces).isEmpty
        let isStyleValid = selectedStyleOption != Constants.Labels.customInput
            || !customStyleInput.trimmingCharacters(in: .whitespaces).isEmpty
        return isLangValid && isStyleValid && !isSaving
    }

    // 현재 선택값이 저장된 값과 다른지 확인 (변경사항이 있을 때만 저장 버튼 활성화)
    private var hasChanges: Bool {
        let finalLang = (selectedLangOption == Constants.Labels.customInput)
            ? customLangInput.trimmingCharacters(in: .whitespaces)
            : selectedLangOption
        let finalStyle = (selectedStyleOption == Constants.Labels.customInput)
            ? customStyleInput.trimmingCharacters(in: .whitespaces)
            : selectedStyleOption
        return finalLang != targetLanguage || finalStyle != targetVoiceStyle
    }

    var body: some View {
        NavigationStack {
            Form {
                // ==========================================
                // 현재 적용된 설정 표시
                // ==========================================
                Section(header: Text("현재 적용된 설정")) {
                    HStack {
                        Text("언어")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(targetLanguage)
                            .bold()
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Text("스타일")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(targetVoiceStyle)
                            .bold()
                            .foregroundStyle(.blue)
                    }
                }

                // ==========================================
                // 언어 선택
                // ==========================================
                Section(header: Text(Constants.Labels.onboardingLangHeader)) {
                    Picker(Constants.Labels.targetLanguage, selection: $selectedLangOption) {
                        ForEach(languagePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    // Picker 변경 시 저장 완료 상태 초기화
                    .onChange(of: selectedLangOption) { saveSuccess = false }

                    if selectedLangOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.langPlaceholder, text: $customLangInput)
                            .onChange(of: customLangInput) { saveSuccess = false }
                    }
                }

                // ==========================================
                // 억양/스타일 선택
                // ==========================================
                Section(
                    header: Text(Constants.Labels.onboardingStyleHeader),
                    footer: Text(Constants.Labels.onboardingStyleFooter)
                ) {
                    Picker(Constants.Labels.targetStyle, selection: $selectedStyleOption) {
                        ForEach(stylePresets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedStyleOption) { saveSuccess = false }

                    if selectedStyleOption == Constants.Labels.customInput {
                        TextField(Constants.Labels.stylePlaceholder, text: $customStyleInput)
                            .onChange(of: customStyleInput) { saveSuccess = false }
                    }
                }

                // ==========================================
                // 저장 버튼
                // ==========================================
                Section {
                    Button(action: {
                        Task { await saveSettings() }
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                                Text("저장 중...")
                            } else if saveSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                Text("저장 완료!")
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("설정 저장")
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    // 변경사항 있고 폼 유효할 때만 활성화
                    .disabled(!isFormValid || !hasChanges)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("언어 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                // 현재 저장된 값으로 Picker 초기값 세팅
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

    // ==========================================
    // MARK: - 저장 로직
    // ==========================================
    private func saveSettings() async {
        isSaving = true
        errorMessage = nil
        saveSuccess = false

        let finalLang = (selectedLangOption == Constants.Labels.customInput)
            ? customLangInput.trimmingCharacters(in: .whitespaces)
            : selectedLangOption
        let finalStyle = (selectedStyleOption == Constants.Labels.customInput)
            ? customStyleInput.trimmingCharacters(in: .whitespaces)
            : selectedStyleOption

        // 언어/스타일 즉시 저장
        targetLanguage = finalLang
        targetVoiceStyle = finalStyle

        // AI로 음성코드(BCP-47) 업데이트
        let prompt = """
        사용자가 원하는 언어는 '\(finalLang)', 원하는 억양/사투리/스타일은 '\(finalStyle)'이야.
        애플의 iOS AVSpeechSynthesisVoice가 지원하는 공식 BCP-47 언어 코드(예: ko-KR, en-US, en-GB, ja-JP, zh-CN, zh-TW, zh-HK, fr-FR 등) 중에서 이 요구사항에 가장 알맞은 코드 딱 1개만 골라줘.
        무조건 다른 말 다 빼고 'ko-KR'처럼 코드만 딱 5글자로 대답해. 마침표나 설명 붙이면 절대 안 돼.
        """

        do {
            let aiVoiceCode = try await AIManager.shared.generateText(prompt: prompt)
            let cleaned = aiVoiceCode.trimmingCharacters(in: .whitespacesAndNewlines)

            let provider = AIManager.shared.lastUsedProvider == .gemini ? "Gemini" : "GPT (폴백)"
            print("🎙️ [\(provider)] 성우 코드 업데이트: \(cleaned)")

            targetVoiceCode = cleaned.isEmpty ? "en-US" : cleaned
            saveSuccess = true
            isSaving = false

        } catch {
            print("🚨 설정 저장 에러: \(error.localizedDescription)")
            errorMessage = "저장 중 오류가 발생했습니다. 다시 시도해 주세요."
            isSaving = false
        }
    }
}