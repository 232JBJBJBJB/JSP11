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
        // 🌟 1. 이 NavigationStack 전체를 뷰모델로 감싸야 해!
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
                .refreshable {
                    viewModel.loadWords()
                }
                // 🚨 여기에 있던 애매한 .environmentObject는 지웠어!
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
                            NavigationLink(destination: MainCameraView()) {
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
        // =======================================================
        // 🌟 2. [핵심 해결] NavigationStack 전체에 뷰모델을 확실하게 주입!
        // 이제 카메라 화면, 상세 화면, 퀴즈 화면 어디로 가든 절대 튕기지 않아.
        // =======================================================
        .environmentObject(viewModel)
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
                // 🌟 하단 바에서 단어 추가 직후에도 목록 새로고침
                viewModel.loadWords()
            }
        }
    }
}
