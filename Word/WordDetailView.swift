import SwiftUI

// MARK: - [1] 상세 화면 (WordDetailView)
struct WordDetailView: View {
    @EnvironmentObject var viewModel: WordViewModel
    @State private var word: Word
    @State private var originalWord: Word  // ✅ 원본 백업용
    @State private var isEditing = false
    
    init(word: Word) {
        _word = State(initialValue: word)
        _originalWord = State(initialValue: word)  // ✅ 초기값 동일하게 세팅
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WordDetailHeaderView(word: $word, isEditing: isEditing)
                Divider()
                WordDetailContentView(word: $word, isEditing: isEditing)
            }
            .padding()
        }
        .navigationTitle(isEditing ? Constants.Labels.editMode : Constants.Labels.wordDetail)
        .onTapGesture { hideKeyboard() }
        .toolbar {
            // ✅ 수정 모드일 때만 취소 버튼 표시
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    cancelButton
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                editToggleButton
            }
        }
    }
    
    // ✅ 취소 버튼: 원본으로 복원 후 수정 모드 OFF
    private var cancelButton: some View {
        Button(action: {
            word = originalWord
            isEditing = false
            hideKeyboard()
        }) {
            Text(Constants.Labels.cancel)
                .foregroundStyle(.red)
        }
    }
    
    private var editToggleButton: some View {
            Button(action: {
                if isEditing {
                    if word.term.trimmingCharacters(in: .whitespaces).isEmpty ||
                       word.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                        return
                    }
                    
                    // 🌟 [추가 방어막] 화면이 바뀌기 전에 열려있는 키보드를 안전하게 내려줌
                    hideKeyboard()
                    
                    viewModel.updateWord(word: word)
                } else {
                    // ✅ 수정 모드 ON 시점에 원본 백업
                    originalWord = word
                }
                isEditing.toggle()
            }) {
                Image(systemName: isEditing ? Constants.Icons.check : Constants.Icons.gear)
                    .foregroundStyle(
                        isEditing && (word.term.isEmpty || word.meaning.isEmpty)
                        ? .gray
                        : (isEditing ? .green : .gray)
                    )
            }
            .disabled(isEditing && (word.term.isEmpty || word.meaning.isEmpty))
        }
    
    // MARK: - [2] 상세 화면 헤더 (WordDetailHeaderView)
    struct WordDetailHeaderView: View {
        @Binding var word: Word
        let isEditing: Bool
        
        var body: some View {
            HStack {
                if isEditing {
                    TextField(Constants.Labels.editWord, text: $word.term)
                        .font(.system(size: 40, weight: .bold))
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(word.term).font(.system(size: 40, weight: .bold))
                }
                if !isEditing {
                    Button(action: { SpeechManager.shared.speak(text: word.term) }) {
                        Image(systemName: Constants.Icons.speaker)
                            .font(.title).foregroundStyle(.blue)
                    }
                }
            }
        }
    }
    
    // MARK: - [3] 상세 화면 본문 (WordDetailContentView)
    struct WordDetailContentView: View {
        @Binding var word: Word
        let isEditing: Bool
        
        var body: some View {
            Group {
                Text(Constants.Labels.meaningAndExample).font(.headline).foregroundStyle(.green)
                if isEditing {
                    TextField(Constants.Labels.meaning, text: $word.meaning)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField(Constants.Labels.pronunciation, text: Binding(
                        get: { word.pronunciation ?? "" },
                        set: { word.pronunciation = $0 }
                    )).textFieldStyle(.roundedBorder)
                    
                    TextField(Constants.Labels.example, text: Binding(
                        get: { word.example ?? "" },
                        set: { word.example = $0 }
                    )).textFieldStyle(.roundedBorder)
                } else {
                    Text(word.meaning).font(.title2)
                    
                    if let pron = word.pronunciation, !pron.isEmpty {
                        Text("\(Constants.Labels.pronunciation): \(pron)").foregroundStyle(.secondary)
                    }
                    
                    if let ex = word.example, !ex.isEmpty {
                        Text("\(Constants.Labels.example): \(ex)")
                            .padding().background(Color.white.opacity(0.5)).cornerRadius(8)
                    }
                }
            }
        }
    }
}
