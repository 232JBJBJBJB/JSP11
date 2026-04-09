import SwiftUI

// MARK: - [1] 메인 화면 (ContentView)
struct ContentView: View {
    @StateObject var viewModel = WordViewModel()
    @StateObject var quizViewModel = QuizViewModel()
    
    @State private var newTerm: String = ""
    @State private var newMeaning: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredWords) { word in
                    // 리스트 줄 하나하나
                    WordListRowView(word: word, onToggleStar: {
                        viewModel.toggleMemorized(word: word)
                    })
                }
                .onDelete { indexSet in
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
            viewModel.loadWords()
        }
    }
    
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

// MARK: - [2] 상세 화면 (WordDetailView)
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
                WordDetailHeaderView(word: $word, isEditing: isEditing)
                Divider()
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
                if (word.term ?? "").trimmingCharacters(in: .whitespaces).isEmpty ||
                   (word.meaning ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    return
                }
                viewModel.updateWord(word: word)
            }
            isEditing.toggle()
        }) {
            Image(systemName: isEditing ? Constants.Icons.check : Constants.Icons.gear)
                .foregroundStyle(
                    isEditing && ((word.term ?? "").isEmpty || (word.meaning ?? "").isEmpty)
                    ? .gray
                    : (isEditing ? .green : .gray)
                )
        }
        .disabled(isEditing && ((word.term ?? "").isEmpty || (word.meaning ?? "").isEmpty))
    }
}

// MARK: - [3] 레고 블록들 (하위 컴포넌트)

struct WordDetailHeaderView: View {
    @Binding var word: Word
    let isEditing: Bool
    
    var body: some View {
        HStack {
            if isEditing {
                TextField(Constants.Labels.editWord, text: Binding(
                    get: { word.term ?? "" },
                    set: { word.term = $0 }
                ))
                .font(.system(size: 40, weight: .bold))
                .textFieldStyle(.roundedBorder)
            } else {
                Text(word.term ?? "").font(.system(size: 40, weight: .bold))
            }
            if !isEditing {
                Button(action: { SpeechManager.shared.speak(text: word.term ?? "") }) {
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
                TextField(Constants.Labels.meaning, text: Binding(
                    get: { word.meaning ?? "" },
                    set: { word.meaning = $0 }
                )).textFieldStyle(.roundedBorder)
                
                TextField(Constants.Labels.pronunciation, text: Binding(
                    get: { word.pronunciation ?? "" },
                    set: { word.pronunciation = $0 }
                )).textFieldStyle(.roundedBorder)
                
                TextField(Constants.Labels.example, text: Binding(
                    get: { word.example ?? "" },
                    set: { word.example = $0 }
                )).textFieldStyle(.roundedBorder)
            } else {
                Text(word.meaning ?? "").font(.title2)
                
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

struct WordListRowView: View {
    let word: Word
    let onToggleStar: () -> Void
    
    var body: some View {
        NavigationLink(destination: WordDetailView(word: word)) {
            HStack {
                Image(systemName: (word.isMemorized ?? false) ? Constants.Icons.starFill : Constants.Icons.star)
                    .foregroundStyle((word.isMemorized ?? false) ? .yellow : .gray)
                    .onTapGesture { onToggleStar() }
                
                VStack(alignment: .leading) {
                    Text(word.term ?? "").bold()
                    Text(word.meaning ?? "")
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
