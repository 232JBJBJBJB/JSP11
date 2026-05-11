import SwiftUI

// MARK: - 메인 화면 (ContentView)
struct ContentView: View {
    @StateObject var viewModel = WordViewModel()
    @StateObject var quizViewModel = QuizViewModel()

    @State private var newTerm: String = ""
    @State private var newMeaning: String = ""

    // 🌟 설정 시트 표시 여부
    @State private var showSettings: Bool = false

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
                // ==========================================
                // 🌟 추가 1: 당겨서 새로고침 (Pull-to-Refresh) 기능!
                // ==========================================
                .refreshable {
                    viewModel.loadWords()
                }
                // ==========================================
                // 🌟 추가 2: 화면에 돌아올 때마다 확실하게 새로고침!
                // (기존 밖의 ZStack에 있던 걸 List에 딱 붙여서 확실히 동작하게 함)
                // ==========================================
                .onAppear {
                    viewModel.loadWords()
                }
                .safeAreaInset(edge: .bottom) {
                    AddWordBottomBarView(newTerm: $newTerm, newMeaning: $newMeaning, onAdd: addNewWord)
                }
                .navigationTitle(Constants.Labels.appTitle)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Constants.Labels.searchPrompt
                )
                .toolbar {
                    // ==========================================
                    // 🌟 왼쪽: 카메라 + 설정 버튼
                    // ==========================================
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 16) {
                            // 카메라 버튼
                            NavigationLink(destination: MainCameraView().environmentObject(viewModel)) {
                                Image(systemName: Constants.Icons.camera)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }

                            // 설정 버튼
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    // 오른쪽: 퀴즈 버튼
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(
                            destination: QuizView(quizViewModel: quizViewModel)
                                .environmentObject(viewModel)
                        ) {
                            Image(systemName: Constants.Icons.gameController)
                                .font(.title3)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
        }
    }

    private func addNewWord() {
        Task {
            let success = await viewModel.addWord(term: newTerm, meaning: newMeaning)
            if success {
                newTerm = ""
                newMeaning = ""
                // 🌟 추가 3: 하단 바에서 단어 추가 직후에도 목록 새로고침
                viewModel.loadWords()
            }
        }
    }
}
