import SwiftUI

// MARK: - [1] 상세 화면 (WordDetailView)
struct WordDetailView: View {
    @EnvironmentObject var viewModel: WordViewModel
    @State private var word: Word
    @State private var isEditing = false
    
    init(word: Word) {
        _word = State(initialValue: word)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 헤더 블록 (단어 + 스피커)
                WordDetailHeaderView(word: $word, isEditing: isEditing)
                
                Divider()
                
                // 2. 상세 내용 블록 (뜻, 발음, 예문)
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
                // 🌟 [수정 완료 시] 뷰모델이 스스로 Task를 처리하므로 바로 호출!
                viewModel.updateWord(word: word)
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
    // 🌟 [최강 핵심!] 파이어베이스 점장님 해고 완료! 이제 빈 괄호로 깔끔하게 시작!
    @StateObject var viewModel = WordViewModel()
    @StateObject var quizViewModel = QuizViewModel()
    
    @State private var newTerm: String = ""
    @State private var newMeaning: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredWords) { word in
                    WordListRowView(word: word, onToggleStar: {
                        // 🌟 뷰모델이 Task를 품고 있어서, View에서는 깔끔하게 함수만 호출!
                        viewModel.toggleMemorized(word: word)
                    })
                }
                .onDelete { indexSet in
                    // 🌟 여기도 귀찮은 Task/await 삭제!
                    viewModel.deleteWord(at: indexSet)
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
            // 🌟 앱 켜질 때도 깔끔하게 한 줄로 AWS에서 단어 땡겨오기!
            viewModel.loadWords()
        }
    }
    
    // 🌟 이 녀석만 async 유지! (성공 여부 Bool 값을 받아와서 텍스트를 지워야 하니까)
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
// 👇 이 아래 블록들(WordDetailHeaderView, WordDetailContentView, WordListRowView, AddWordBottomBarView)은
// 완벽하게 뷰(UI) 역할만 하고 있어서 수정할 곳이 0군데야! 네가 준 코드 그대로 쓰면 돼.

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

struct WordDetailContentView: View {
    @Binding var word: Word
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
