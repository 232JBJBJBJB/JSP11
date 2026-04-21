import SwiftUI

// MARK: - [1] 메인 화면
struct QuizView: View {
    @EnvironmentObject var wordViewModel: WordViewModel
    @ObservedObject var quizViewModel: QuizViewModel
    
    // UI 상태
    @State private var selectedOption: Int? = nil
    @State private var showResult = false
    @State private var showAddSheet = false
    
    // 단어 추가용 상태
    @State private var newQuizTerm = ""
    @State private var newQuizMeaning = ""
    @State private var isSavingWord = false
    
    var body: some View {
        VStack {
            switch quizViewModel.state {
                
            case .idle:
                QuizEmptyView(
                    errorMessage: nil,
                    isWordEmpty: wordViewModel.words.isEmpty,
                    onStart: requestNewQuiz
                )
                
            case .loading:
                ProgressView("퀴즈를 준비하고 있습니다...")
                    .controlSize(.large)
                
            case .success(let quiz):
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        QuizAudioButton(text: quiz.passage)
                        QuizPassageView(text: quiz.passage)
                        
                        Text("\(Constants.Labels.questionPrefix) \(quiz.question)")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        ForEach(quiz.options.indices, id: \.self) { index in
                            QuizOptionButton(
                                index: index,
                                optionText: quiz.options[index],
                                answerIndex: quiz.answerIndex,
                                selectedOption: $selectedOption,
                                showResult: $showResult
                            )
                        }
                        
                        if showResult {
                            Button(Constants.Labels.nextQuiz) {
                                // 🌟 [4번 최적화] 다음 문제 버튼을 누를 때 가벼운 진동
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                requestNewQuiz()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                // 🌟 [2번 최적화] SwiftUI에게 '새로운 문제'임을 각인시켜 부드러운 애니메이션 유도
                .id(quiz.question) 
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: quiz.question)
                
            case .failure(let errorMessage):
                QuizEmptyView(
                    errorMessage: errorMessage,
                    isWordEmpty: wordViewModel.words.isEmpty,
                    onStart: requestNewQuiz
                )
            }
        }
        .navigationTitle(quizViewModel.targetLanguage + " 퀴즈") // 다국어 제목 동적 적용
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: Constants.Icons.plusApp)
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addWordSheet
        }
    }
    
    // 로직: 다음 퀴즈 요청
    func requestNewQuiz() {
        // 문제 전환 시 기존 선택 상태 초기화
        withAnimation {
            selectedOption = nil
            showResult = false
        }
        Task {
            await quizViewModel.makeQuiz(from: wordViewModel.words)
        }
    }
    
    // 뷰: 단어 추가 시트
    var addWordSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text(Constants.Labels.newWordHeader)) {
                    TextField(Constants.Labels.word, text: $newQuizTerm)
                    TextField(Constants.Labels.meaning, text: $newQuizMeaning)
                }
            }
            .navigationTitle(Constants.Labels.addWord)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Constants.Labels.cancel) {
                        showAddSheet = false
                        newQuizTerm = ""
                        newQuizMeaning = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            isSavingWord = true
                            let success = await wordViewModel.addWord(term: newQuizTerm, meaning: newQuizMeaning)
                            isSavingWord = false
                            
                            if success {
                                showAddSheet = false
                                newQuizTerm = ""
                                newQuizMeaning = ""
                            }
                        }
                    }) {
                        if isSavingWord {
                            ProgressView()
                        } else {
                            Text(Constants.Labels.save)
                        }
                    }
                    .disabled(newQuizTerm.trimmingCharacters(in: .whitespaces).isEmpty ||
                              newQuizMeaning.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSavingWord)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - [2] 레고 블록들 (하위 컴포넌트)

// 🧱 블록 1: 보기 버튼
struct QuizOptionButton: View {
    let index: Int
    let optionText: String
    let answerIndex: Int
    
    @Binding var selectedOption: Int?
    @Binding var showResult: Bool
    
    var body: some View {
        Button(action: {
            // 🌟 [4번 최적화] 즉각적인 햅틱 피드백 (손맛!)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // 🌟 정답/오답 결과가 딱딱하게 바뀌지 않고 스르륵 부드럽게 나타나게 함
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOption = index
                showResult = true
            }
        }) {
            HStack {
                Text("\(index + 1). \(optionText)")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                Spacer()
                
                if showResult {
                    if index == answerIndex {
                        Image(systemName: Constants.Icons.check).foregroundStyle(.green)
                    } else if index == selectedOption {
                        Image(systemName: Constants.Icons.xmark).foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            // 선택된 정답의 배경색을 살짝 깔아주어 입체감을 더함
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
        }
        .disabled(showResult)
    }
    
    // 테두리 색상 계산
    var borderColor: Color {
        if showResult {
            if index == answerIndex { return .green } // 정답은 무조건 초록
            if index == selectedOption { return .red } // 내가 고른 오답은 빨강
        }
        return selectedOption == index ? .blue : .gray.opacity(0.3)
    }
    
    // 배경 색상 계산 (UI 디테일 향상)
    var backgroundColor: Color {
        if showResult {
            if index == answerIndex { return .green.opacity(0.1) }
            if index == selectedOption { return .red.opacity(0.1) }
        }
        return .clear
    }
}

// 🧱 블록 2: 듣기 버튼
struct QuizAudioButton: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                SpeechManager.shared.speak(text: text)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: Constants.Icons.speakerCircle)
                        .font(.system(size: 24))
                    Text(Constants.Labels.listen)
                        .font(.headline)
                }
                .foregroundStyle(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.bottom, -10)
    }
}

// 🧱 블록 3: 지문 박스
struct QuizPassageView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title3)
            .lineSpacing(8)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .textSelection(.enabled)
    }
}

// 🧱 블록 4: 빈 화면 (대기/에러 화면)
struct QuizEmptyView: View {
    let errorMessage: String?
    let isWordEmpty: Bool
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: Constants.Icons.book)
                .font(.system(size: 80))
                .foregroundStyle(.blue.opacity(0.8))
            
            Text(Constants.Labels.emptyTitle)
                .font(.title2.bold())
            
            Text(Constants.Labels.emptyDesc)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Button(Constants.Labels.startQuiz) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWordEmpty)
        }
        .padding()
    }
}