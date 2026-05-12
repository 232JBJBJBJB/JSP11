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
                // 🌟 바깥으로 빼낸 뷰들을 여기서 안전하게 호출!
                WordDetailHeaderView(word: $word, isEditing: isEditing)
                Divider()
                WordDetailContentView(word: $word, isEditing: isEditing)
            }
            .padding()
        }
        .navigationTitle(isEditing ? Constants.Labels.editMode : Constants.Labels.wordDetail)
        .onTapGesture { dismissKeyboard() }
        .toolbar {
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
    
    // ✅ 취소 버튼
    private var cancelButton: some View {
        Button(action: {
            word = originalWord
            isEditing = false
            dismissKeyboard()
        }) {
            Text(Constants.Labels.cancel)
                .foregroundStyle(.red)
        }
    }
    
    // ✅ 수정/저장 토글 버튼
    // ✅ 수정/저장 토글 버튼
        private var editToggleButton: some View {
            Button(action: {
                if isEditing {
                    if word.term.trimmingCharacters(in: .whitespaces).isEmpty ||
                       word.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                        return
                    }
                    
                    // 1. 열려있는 키보드를 강제로 내림
                    dismissKeyboard()
                    
                    // 2. 화면을 먼저 읽기 모드로 돌려놓음
                    isEditing = false
                    
                    // 🌟 3. [진짜 핵심 방어막] Task가 잠들기 전에 뷰모델을 미리 꽉 잡아둔다!
                    // 이렇게 하면 화면이 어떻게 변하든 상관없이 안전하게 뷰모델을 쓸 수 있어.
                    let safeViewModel = viewModel
                    
                    // 4. 안전망: UI가 완전히 안정화된 후(0.15초 뒤)에 업데이트!
                    Task {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        // EnvironmentObject 대신, 미리 잡아둔 safeViewModel을 사용!
                        safeViewModel.updateWord(word: word)
                    }
                    
                } else {
                    originalWord = word
                    isEditing = true
                }
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
    
    // 🌟 안전한 키보드 내리기 함수 (확실한 처리를 위해 추가)
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// ========================================================
// 🌟 아까 WordDetailView 안에 갇혀있던 녀석들을 바깥으로 구출!
// ========================================================

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
