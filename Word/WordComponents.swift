import SwiftUI

// MARK: - [1] 리스트 행 (WordListRowView)
struct WordListRowView: View {
    let word: Word
    let onToggleStar: () -> Void
    
    var body: some View {
        NavigationLink(destination: WordDetailView(word: word)) {
            HStack {
                // ✅ [버그 수정] onTapGesture → Button + .buttonStyle(.plain)
                // NavigationLink 내부에서 onTapGesture를 쓰면 탭 이벤트가 충돌함
                // Button + .buttonStyle(.plain)으로 분리하면 별표 탭이 NavigationLink로 전달되지 않음
                Button {
                    onToggleStar()
                } label: {
                    Image(systemName: (word.isMemorized ?? false) ? Constants.Icons.starFill : Constants.Icons.star)
                        .foregroundStyle((word.isMemorized ?? false) ? .yellow : .gray)
                }
                .buttonStyle(.plain)
                
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

// MARK: - [2] 단어 추가 하단 바 (AddWordBottomBarView)
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

// MARK: - [3] 키보드 숨기기 확장 (View Extension)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}