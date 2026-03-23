//
//  QuizView.swift
//  LearningUI
//
//  Refactored for UI Componentization with State Machine
//

import SwiftUI

// MARK: - [1] 메인 화면 (조립 설명서)
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
    @State private var isSavingWord = false // 🌟 [추가] 단어 저장 중인지 확인하는 로컬 상태
    
    var body: some View {
        VStack {
            // 깔끔한 switch 문으로 상태 관리
            switch quizViewModel.state {
                
            case .idle:
                // [상황 1] 대기 화면 (에러 없음)
                QuizEmptyView(
                    errorMessage: nil,
                    isWordEmpty: wordViewModel.words.isEmpty,
                    onStart: requestNewQuiz
                )
                
            case .loading:
                // [상황 2] 로딩 중
                ProgressView(Constants.Labels.loading)
                    .controlSize(.large)
                
            case .success(let quiz):
                // [상황 3] 퀴즈 도착 (메인 게임 화면)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. 듣기 버튼 블록
                        QuizAudioButton(text: quiz.passage)
                        
                        // 2. 지문 박스 블록
                        QuizPassageView(text: quiz.passage)
                        
                        // 3. 질문 텍스트
                        Text("\(Constants.Labels.questionPrefix) \(quiz.question)")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        // 4. 보기 버튼들
                        ForEach(quiz.options.indices, id: \.self) { index in
                            QuizOptionButton(
                                index: index,
                                optionText: quiz.options[index],
                                answerIndex: quiz.answerIndex,
                                selectedOption: $selectedOption,
                                showResult: $showResult
                            )
                        }
                        
                        // 5. 다음 문제 버튼
                        if showResult {
                            Button(Constants.Labels.nextQuiz) {
                                requestNewQuiz()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                
            case .failure(let errorMessage):
                // [상황 4] 에러 발생 화면
                QuizEmptyView(
                    errorMessage: errorMessage,
                    isWordEmpty: wordViewModel.words.isEmpty,
                    onStart: requestNewQuiz
                )
            }
        }
        .navigationTitle(Constants.Labels.quizTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: Constants.Icons.plusApp)
                        .foregroundStyle(.blue)
                }
            }
        }
        // 단어 추가 시트 (Sheet)
        .sheet(isPresented: $showAddSheet) {
            addWordSheet
        }
    }
    
    // 로직: 다음 퀴즈 요청
    func requestNewQuiz() {
        selectedOption = nil
        showResult = false
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
                            isSavingWord = true // 🌟 버튼 누르면 로딩 시작!
                            let success = await wordViewModel.addWord(term: newQuizTerm, meaning: newQuizMeaning)
                            isSavingWord = false // 🌟 통신 끝나면 로딩 끝!
                            
                            if success {
                                showAddSheet = false
                                newQuizTerm = ""
                                newQuizMeaning = ""
                            }
                        }
                    }) {
                        // 🌟 통신 중이면 뱅글뱅글 애니메이션, 아니면 "저장" 글자 표시
                        if isSavingWord {
                            ProgressView()
                        } else {
                            Text(Constants.Labels.save)
                        }
                    }
                    // 🌟 빈칸이거나 통신 중일 때는 버튼 꾹 막아두기
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
            selectedOption = index
            showResult = true
        }) {
            HStack {
                Text("\(index + 1). \(optionText)")
                    .font(.body)
                    .foregroundStyle(.primary).textSelection(.enabled)
                Spacer()
                
                // 정답/오답 아이콘 표시 로직
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
        }
        .disabled(showResult)
    }
    
    // 테두리 색상 계산 로직
    var borderColor: Color {
        if selectedOption == index {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// 🧱 블록 2: 듣기 버튼
struct QuizAudioButton: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
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
            ).textSelection(.enabled)
    }
}

// 🧱 블록 4: 빈 화면 (에러 화면)
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
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWordEmpty)
        }
        .padding()
    }
}
