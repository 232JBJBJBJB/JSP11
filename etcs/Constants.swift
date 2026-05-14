import Foundation

struct Constants {
    struct Labels {
        static let appTitle = "나만의 단어장"
        static let word = "단어"
        static let meaning = "뜻"
        static let save = "저장"
        static let cancel = "취소"
        static let addWord = "단어 추가"
        static let quizTitle = "AI 독해 퀴즈"
        static let loading = "AI가 이야기를 만들고 있어요... 🤖"
        static let listen = "듣기"
        static let questionPrefix = "Q."
        static let nextQuiz = "다른 이야기 보기 🔄"
        static let startQuiz = "퀴즈 시작하기 ✨"
        static let newWordHeader = "새로운 단어 발견! 💡"
        static let emptyTitle = "오늘의 AI 독해 퀴즈"
        static let emptyDesc = "저장된 단어를 기반으로\n새로운 이야기를 만들어 드려요."
        static let editWord = "단어 수정"
        static let pronunciation = "발음"
        static let example = "예문"
        static let meaningAndExample = "📖 뜻 & 예문"
        static let editMode = "수정 모드"
        static let wordDetail = "단어 상세"
        static let searchPrompt = "단어 검색"
        static let onboardingLangHeader = "어떤 언어를 공부할까요?"
        static let targetLanguage = "목표 언어"
        static let onboardingStyleHeader = "원하는 억양이나 지역이 있나요?"
        static let onboardingStyleFooter = "AI가 해당 지역의 표현과 뉘앙스로 데이터를 만들어줍니다!"
        static let targetStyle = "음성/억양 스타일"
        static let customInput = "직접 입력"
        static let langPlaceholder = "예: 라틴어, 아랍어"
        static let stylePlaceholder = "예: 텍사스 슬랭, 상하이 방언"
        static let startLearnSpot = "런스팟 시작하기 🚀"
        static let onboardingTitle = "목표 설정"
        static let cameraNoPermission = "카메라 권한이 필요합니다."
        static let cameraPlaceholder = "세상을 비춰보세요 📸"
    }
    
    struct Icons {
        static let plus = "plus.circle.fill"
        static let check = "checkmark.circle.fill"
        static let gear = "gearshape.fill"
        static let trash = "trash"
        static let gameController = "gamecontroller.fill"
        static let star = "star"
        static let starFill = "star.fill"
        static let speaker = "speaker.wave.2.fill"
        static let speakerCircle = "speaker.wave.2.circle.fill"
        static let book = "book.pages.fill"
        static let plusApp = "plus.app.fill"
        static let xmark = "xmark.circle.fill"
        static let camera = "camera.viewfinder"
        static let cameraSlash = "camera.slash"
    }
    
    struct Errors {
        static let internetDisconnected = "인터넷 연결이 끊겼어요. 와이파이를 확인해주세요! 🛜"
        static let timeOut = "AI가 생각하느라 너무 오래 걸리네요. 잠시 후 다시 시도해주세요. ⏰"
        static let unknown = "알 수 없는 오류가 발생했어요."
        static let noSavedWords = "저장된 단어가 없어요! 단어를 먼저 추가해주세요."
        static let noResponse = "AI가 응답하지 않았어요."
        static let dataParseFailed = "데이터를 분석하는데 실패했어요."
        static let connectionLost = "통신 도중에 연결이 끊어졌어요. 다시 시도해주세요. 🔌"
        static let networkErrorPrefix = "통신 문제가 발생했어요."
        static let unknownErrorPrefix = "알 수 없는 문제가 생겼어요:"
    }
    
    struct Config {
        static let secretsFile = "Secrets"
        static let plistExtension = "plist"
        static let apiKeyName = "GEMINI_API_KEY"
        // 텍스트 전용(퀴즈): 빠른 모델, 이미지 분석: 고품질 모델
        static let textModelName = "gemini-2.0-flash"
        static let imageModelName = "gemini-2.5-flash"
    }
        
    struct FatalErrors {
        static let noSecretsFile = "🚨 Secrets.plist 파일을 찾을 수 없습니다."
        static let unreadableSecrets = "🚨 Secrets.plist를 읽을 수 없습니다."
        static let noApiKey = "🚨 Secrets.plist에 'GEMINI_API_KEY'가 없습니다."
    }
}
