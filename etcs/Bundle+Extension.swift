import Foundation

extension Bundle {
    // 1. 금고에서 API 키를 꺼내오는 변수
    var geminiApiKey: String {
        // [Constants 적용] "Secrets", "plist"
        guard let filePath = Bundle.main.path(forResource: Constants.Config.secretsFile, ofType: Constants.Config.plistExtension) else {
            // [Constants 적용] 파일 없음 에러
            fatalError(Constants.FatalErrors.noSecretsFile)
        }
        
        // 3. 금고를 열어서 내용을 읽음
        guard let plist = NSDictionary(contentsOfFile: filePath) else {
            // [Constants 적용] 파일 읽기 실패 에러
            fatalError(Constants.FatalErrors.unreadableSecrets)
        }
        
        // [Constants 적용] "GEMINI_API_KEY"
        guard let value = plist.object(forKey: Constants.Config.apiKeyName) as? String else {
            // [Constants 적용] 키 없음 에러
            fatalError(Constants.FatalErrors.noApiKey)
        }
        
        return value
    }
}
