#include "ARBubbleRenderer.hpp"
#include <algorithm>

void ARBubbleRenderer::UpdateWords(const std::vector<ARWordData>& words) {
    currentWords = words;
}

void ARBubbleRenderer::Render(cv::Mat& frame) {
    if (frame.empty()) return;

    int screenWidth = frame.cols;
    int screenHeight = frame.rows;

    for (const auto& wordData : currentWords) {
        float absoluteX = wordData.relativeX * screenWidth;
        float absoluteY = wordData.relativeY * screenHeight;

        // OpenCV 폰트 설정
        int fontFace = cv::FONT_HERSHEY_SIMPLEX;
        double wordFontScale = 0.7;
        double subFontScale = 0.5;
        int thickness = 1;

        // 텍스트 너비 계산 (cv::getTextSize 활용)
        int wordWidth = CalculateTextWidth(wordData.word, wordFontScale, thickness);
        int pronWidth = CalculateTextWidth(wordData.pronunciation, subFontScale, thickness);
        int meaningWidth = CalculateTextWidth(wordData.meaning, subFontScale, thickness);

        int maxTextWidth = std::max({ wordWidth, pronWidth, meaningWidth });

        int paddingX = 20;
        int paddingY = 15;
        int lineSpacing = 10;

        // 텍스트 높이 추정 (기준 픽셀)
        int baseTextHeight = 15;

        int bubbleWidth = maxTextWidth + (paddingX * 2);
        int bubbleHeight = (baseTextHeight * 3) + (lineSpacing * 2) + (paddingY * 2);

        // 말풍선 사각형 영역 정의
        int startX = absoluteX - (bubbleWidth / 2);
        int startY = absoluteY - bubbleHeight - 30; // 객체보다 살짝 위에 띄움

        // 화면 밖으로 나가지 않도록 예외 처리
        startX = std::max(0, std::min(startX, screenWidth - bubbleWidth));
        startY = std::max(0, std::min(startY, screenHeight - bubbleHeight));

        cv::Rect bubbleRect(startX, startY, bubbleWidth, bubbleHeight);

        // 1. 반투명 배경 렌더링 (검은색, 투명도 60%)
        DrawTransparentRoundedRect(frame, bubbleRect, cv::Scalar(0, 0, 0), 15, 0.6);

        // 2. 텍스트 렌더링 (흰색)
        cv::Scalar textColor(255, 255, 255);
        int textX = startX + paddingX;
        int currentY = startY + paddingY + baseTextHeight;

        DrawTextLabel(frame, wordData.word, cv::Point(textX, currentY), wordFontScale, textColor);
        currentY += baseTextHeight + lineSpacing;

        DrawTextLabel(frame, wordData.pronunciation, cv::Point(textX, currentY), subFontScale, textColor);
        currentY += baseTextHeight + lineSpacing;

        DrawTextLabel(frame, wordData.meaning, cv::Point(textX, currentY), subFontScale, textColor);
    }
}

int ARBubbleRenderer::CalculateTextWidth(const std::string& text, double fontScale, int thickness) {
    int baseline = 0;
    cv::Size textSize = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, fontScale, thickness, &baseline);
    return textSize.width;
}

void ARBubbleRenderer::DrawTransparentRoundedRect(cv::Mat& frame, cv::Rect rect, cv::Scalar color, int cornerRadius, double alpha) {
    // 투명도 적용을 위해 원본 프레임을 복사하여 오버레이 생성
    cv::Mat overlay;
    frame.copyTo(overlay);

    // 둥근 사각형을 그리기 위한 내부 로직 (단순화를 위해 일반 꽉 찬 사각형 위에 둥근 모서리 덮어쓰기)
    cv::rectangle(overlay, cv::Point(rect.x + cornerRadius, rect.y), cv::Point(rect.x + rect.width - cornerRadius, rect.y + rect.height), color, cv::FILLED);
    cv::rectangle(overlay, cv::Point(rect.x, rect.y + cornerRadius), cv::Point(rect.x + rect.width, rect.y + rect.height - cornerRadius), color, cv::FILLED);
    cv::circle(overlay, cv::Point(rect.x + cornerRadius, rect.y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(rect.x + rect.width - cornerRadius, rect.y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(rect.x + cornerRadius, rect.y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(rect.x + rect.width - cornerRadius, rect.y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);

    // 원본 프레임과 오버레이를 alpha 값에 따라 합성
    cv::addWeighted(overlay, alpha, frame, 1.0 - alpha, 0, frame);
}

void ARBubbleRenderer::DrawTextLabel(cv::Mat& frame, const std::string& text, cv::Point position, double fontScale, cv::Scalar color) {
    cv::putText(frame, text, position, cv::FONT_HERSHEY_SIMPLEX, fontScale, color, 1, cv::LINE_AA);
}