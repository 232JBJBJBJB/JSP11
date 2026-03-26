#import "ARBridge.h"
#import "ARBubbleRenderer.hpp"

// C++ 렌더러 인스턴스
static ARBubbleRenderer renderer;
static std::vector<ARWordData> tempWords;

void C_ClearARWords() 
{
    tempWords.clear();
    renderer.UpdateWords(tempWords);
}

void C_UpdateARWords(const char* word, const char* pron, const char* meaning, float relX, float relY) 
{
    ARWordData data;
    // Null 체크 후 C++ string으로 안전하게 변환
    data.word = word ? word : "";
    data.pronunciation = pron ? pron : "";
    data.meaning = meaning ? meaning : "";
    data.relativeX = relX;
    data.relativeY = relY;
    
    tempWords.push_back(data);
    renderer.UpdateWords(tempWords);
}

void C_RenderBubbles(float screenWidth, float screenHeight) 
{
    renderer.Render(screenWidth, screenHeight);
}