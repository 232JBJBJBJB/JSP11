#include "ARBubbleRenderer.hpp"
#include <iostream>
#include <algorithm> 

ARBubbleRenderer::ARBubbleRenderer()
{
}

ARBubbleRenderer::~ARBubbleRenderer()
{
}

void ARBubbleRenderer::UpdateWords(const std::vector<ARWordData>& words) 
{
    currentWords = words;
}

void ARBubbleRenderer::Render(float screenWidth, float screenHeight) 
{
    for (ARWordData wordData : currentWords) {
        // 1. 실제 화면 픽셀 좌표 계산
        float absoluteX = wordData.relativeX * screenWidth;
        float absoluteY = wordData.relativeY * screenHeight;

        // 2. 폰트 크기 세팅
        float wordFontSize = 18.0f;
        float pronFontSize = 14.0f;
        float meaningFontSize = 14.0f;

        // 3. 텍스트 너비 계산
        float wordWidth = CalculateTextWidth(wordData.word, wordFontSize);
        float pronWidth = CalculateTextWidth(wordData.pronunciation, pronFontSize);
        float meaningWidth = CalculateTextWidth(wordData.meaning, meaningFontSize);

        // 4. 가장 긴 텍스트 기준 말풍선 크기 결정
        float maxTextWidth = std::max({ wordWidth, pronWidth, meaningWidth });

        float paddingX = 16.0f;
        float paddingY = 12.0f;
        float lineSpacing = 6.0f;

        float bubbleWidth = maxTextWidth + (paddingX * 2.0f);
        float bubbleHeight = wordFontSize + pronFontSize + meaningFontSize
            + (lineSpacing * 2.0f) + (paddingY * 2.0f);
        float cornerRadius = 10.0f;

        // 5. 말풍선 시작점
        float startX = absoluteX - (bubbleWidth / 2.0f);
        float startY = absoluteY - bubbleHeight - 20.0f;

        // 6. 반투명 배경 렌더링
        DrawRoundedRect(startX, startY, bubbleWidth, bubbleHeight, cornerRadius, 0.0f, 0.0f, 0.0f, 0.6f);

        // 7. 텍스트 렌더링
        float textStartX = startX + paddingX;
        float currentTextY = startY + paddingY;

        DrawTextLabel(wordData.word, textStartX, currentTextY, wordFontSize);
        currentTextY += wordFontSize + lineSpacing;

        DrawTextLabel(wordData.pronunciation, textStartX, currentTextY, pronFontSize);
        currentTextY += pronFontSize + lineSpacing;

        DrawTextLabel(wordData.meaning, textStartX, currentTextY, meaningFontSize);
    }
}

// --- 아래 3개의 헬퍼 함수는 사용하시는 그래픽스 라이브러리에 맞춰 작성 ---

float ARBubbleRenderer::CalculateTextWidth(const std::string& text, float fontSize) 
{
    // 임시 가라 로직. 실제로는 엔진의 글꼴 렌더링 API를 호출하여 픽셀 길이를 구함
    return text.length() * (fontSize * 0.5f);
}

void ARBubbleRenderer::DrawRoundedRect(float x, float y, float width, float height, float cornerRadius, float r, float g, float b, float alpha) 
{
    // TODO: 사각형 그리기 로직
}

void ARBubbleRenderer::DrawTextLabel(const std::string& text, float x, float y, float fontSize) 
{
    // TODO: 텍스트 그리기 로직
}