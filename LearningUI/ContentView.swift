import SwiftUI

// MARK: - 메인 화면 (ContentView)
struct ContentView: View {
    @StateObject var viewModel = WordViewModel()
    @StateObject var quizViewModel = QuizViewModel()
    
    @State private var newTerm: String = ""
    @State private var newMeaning: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(viewModel.filteredWords) { word in
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
            } // ZStack 닫기
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
