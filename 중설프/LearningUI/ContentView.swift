import SwiftUI


// MARK: - [1] 상세 화면 (WordDetailView)
struct WordDetailView: View {
    @EnvironmentObject var viewModel: WordViewModel // 수정 완료 후 저장을 위해 뷰모델 호출
    @State private var word: Word // 🌟 struct로 바뀌었으니 @State로 변수 선언!
    @State private var isEditing = false
    
    // 처음에 눌러서 들어온 단어를 @State에 쏙 넣어줌
    init(word: Word) {
        _word = State(initialValue: word)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 🧱 1. 헤더 블록 (단어 + 스피커) - 이제 $word 처럼 Binding으로 넘겨줌
                WordDetailHeaderView(word: $word, isEditing: isEditing)
                
                Divider()
                
                // 🧱 2. 상세 내용 블록 (뜻, 발음, 예문)
                WordDetailContentView(word: $word, isEditing: isEditing)
            }
            .padding()
        }
        .navigationTitle(isEditing ? Constants.Labels.editMode : Constants.Labels.wordDetail)
        .onTapGesture { hideKeyboard() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                editToggleButton
            }
        }
    }
    
    private var editToggleButton: some View {
        Button(action: {
            if isEditing {
                if word.term.trimmingCharacters(in: .whitespaces).isEmpty ||
                   word.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                    return
                }
                // 🌟 [수정 완료 시] 구름(Firebase)에 업데이트 해달라고 점장님한테 요청!
                Task {
                    await viewModel.updateWord(word: word)
                }
            }
            isEditing.toggle()
        }) {
            Image(systemName: isEditing ? Constants.Icons.check : Constants.Icons.gear)
                .foregroundStyle(
                    isEditing && (word.term.trimmingCharacters(in: .whitespaces).isEmpty || word.meaning.trimmingCharacters(in: .whitespaces).isEmpty)
                    ? .gray
                    : (isEditing ? .green : .gray)
                )
        }
        .disabled(
            isEditing && (
                word.term.trimmingCharacters(in: .whitespaces).isEmpty ||
                word.meaning.trimmingCharacters(in: .whitespaces).isEmpty
            )
        )
    }
}

// MARK: - [2] 메인 화면 (ContentView)
struct ContentView: View {
    // 🌟 [핵심!] 알바생이 태어날 때 '구글 파견 점장님'을 짝지어줌!
    @StateObject var viewModel = WordViewModel(repository: FirebaseWordRepository())
    @StateObject var quizViewModel = QuizViewModel()
    
    @State private var newTerm: String = ""
    @State private var newMeaning: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredWords) { word in
                    WordListRowView(word: word, onToggleStar: {
                        // 🌟 별표 누를 때도 클라우드(Firebase)에 저장해야 하니까 Task로 감쌈
                        Task {
                            await viewModel.toggleMemorized(word: word)
                        }
                    })
                }
                .onDelete { indexSet in
                    // 🌟 단어 지울 때도 클라우드(Firebase) 통신하니까 Task로 감쌈
                    Task {
                        await viewModel.deleteWord(at: indexSet)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) {
                AddWordBottomBarView(newTerm: $newTerm, newMeaning: $newMeaning, onAdd: addNewWord)
            }
            .navigationTitle(Constants.Labels.appTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Constants.Labels.searchPrompt)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: MainCameraView()) {
                            Image(systemName: Constants.Icons.camera)
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: QuizView(quizViewModel: quizViewModel).environmentObject(viewModel)) {
                        Image(systemName: Constants.Icons.gameController)
                            .font(.title3)
                    }
                }
            }
        }
        .onAppear {
            // 🌟 화면 켜질 때 클라우드(Firebase)에서 단어 가져오기
            Task {
                await viewModel.loadWords()
            }
        }
    }
    
    // 🌟 단어 추가도 클라우드(Firebase) 통신이라 Task로 감쌈
    private func addNewWord() {
        Task {
            let success = await viewModel.addWord(term: newTerm, meaning: newMeaning)
            if success {
                newTerm = ""
                newMeaning = ""
            }
        }
    }
}

// MARK: - [3] 레고 블록들 (하위 컴포넌트)

// 🧱 블록 1: 상세 화면의 상단 헤더
struct WordDetailHeaderView: View {
    @Binding var word: Word // 🌟 @Bindable 대신 @Binding으로 변경
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

// 🧱 블록 2: 상세 화면의 뜻/발음/예문 부분
struct WordDetailContentView: View {
    @Binding var word: Word // 🌟 @Bindable 대신 @Binding으로 변경
    let isEditing: Bool
    
    var body: some View {
        Group {
            Text(Constants.Labels.meaningAndExample).font(.headline).foregroundStyle(.green)
            if isEditing {
                TextField(Constants.Labels.meaning, text: $word.meaning).textFieldStyle(.roundedBorder)
                TextField(Constants.Labels.pronunciation, text: $word.pronunciation).textFieldStyle(.roundedBorder)
                TextField(Constants.Labels.example, text: $word.example).textFieldStyle(.roundedBorder)
            } else {
                Text(word.meaning).font(.title2)
                if !word.pronunciation.isEmpty { Text("\(Constants.Labels.pronunciation): \(word.pronunciation)").foregroundStyle(.secondary) }
                if !word.example.isEmpty {
                    Text("\(Constants.Labels.example): \(word.example)")
                        .padding().background(Color.white.opacity(0.5)).cornerRadius(8)
                }
            }
        }
    }
}

// 🧱 블록 3: 메인 화면의 단어 리스트 '한 줄' (이건 변경 없음)
struct WordListRowView: View {
    let word: Word
    let onToggleStar: () -> Void
    
    var body: some View {
        NavigationLink(destination: WordDetailView(word: word)) {
            HStack {
                Image(systemName: word.isMemorized ? Constants.Icons.starFill : Constants.Icons.star)
                    .foregroundStyle(word.isMemorized ? .yellow : .gray)
                    .onTapGesture {
                        onToggleStar()
                    }
                
                VStack(alignment: .leading) {
                    Text(word.term).bold()
                    Text(word.meaning)
                        .foregroundStyle(.black)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.4))
    }
}

// 🧱 블록 4: 메인 화면의 하단 '단어 추가 바' (이건 변경 없음)
struct AddWordBottomBarView: View {
    @Binding var newTerm: String
    @Binding var newMeaning: String
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                TextField(Constants.Labels.word, text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                TextField(Constants.Labels.meaning, text: $newMeaning)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: onAdd) {
                    Image(systemName: Constants.Icons.plus)
                        .font(.title)
                }
                .disabled(
                    newTerm.trimmingCharacters(in: .whitespaces).isEmpty ||
                    newMeaning.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
