#include "ARBubbleRenderer.hpp"
#include <algorithm>

void ARBubbleRenderer::UpdateWords(const std::vector<ARWordData>& words) {
    currentWords = words;
}

void ARBubbleRenderer::Render(cv::Mat& frame) {
    if (frame.empty()) return;

    int screenWidth = frame.cols;
    int screenHeight = frame.rows;

    for (const ARWordData& wordData : currentWords) {
        float absoluteX = wordData.relativeX * screenWidth;
        float absoluteY = wordData.relativeY * screenHeight;

        int fontFace = cv::FONT_HERSHEY_SIMPLEX;
        double wordFontScale = 0.7;
        double subFontScale = 0.5;
        int thickness = 1;

        int wordWidth = CalculateTextWidth(wordData.word, wordFontScale, thickness);
        int pronWidth = CalculateTextWidth(wordData.pronunciation, subFontScale, thickness);
        int meaningWidth = CalculateTextWidth(wordData.meaning, subFontScale, thickness);

        int maxTextWidth = std::max({ wordWidth, pronWidth, meaningWidth });

        int paddingX = 20;
        int paddingY = 15;
        int lineSpacing = 10;
        int baseTextHeight = 15;

        int bubbleWidth = maxTextWidth + (paddingX * 2);
        int bubbleHeight = (baseTextHeight * 3) + (lineSpacing * 2) + (paddingY * 2);

        int startX = (int)absoluteX - (bubbleWidth / 2);
        int startY = (int)absoluteY - bubbleHeight - 30;

        startX = std::max(0, std::min(startX, screenWidth - bubbleWidth));
        startY = std::max(0, std::min(startY, screenHeight - bubbleHeight));

        cv::Rect bubbleRect(startX, startY, bubbleWidth, bubbleHeight);
        DrawTransparentRoundedRect(frame, bubbleRect, cv::Scalar(0, 0, 0), 15, 0.6);

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

// 성능 개선: ROI(관심 영역)를 활용하여 투명 말풍선 렌더링 부하 대폭 감소
void ARBubbleRenderer::DrawTransparentRoundedRect(cv::Mat& frame, cv::Rect rect, cv::Scalar color, int cornerRadius, double alpha) {
    // 화면 범위를 벗어나지 않도록 안전 영역(ROI) 계산
    cv::Rect safeRect = rect & cv::Rect(0, 0, frame.cols, frame.rows);
    if (safeRect.width <= 0 || safeRect.height <= 0) return;

    // 전체 프레임이 아닌, 말풍선이 그려질 ROI 영역만 참조 및 복사
    cv::Mat roi = frame(safeRect);
    cv::Mat overlay;
    roi.copyTo(overlay);

    // 원본 rect 기준으로 safeRect 내에서의 오프셋 계산 (화면 경계에서 잘릴 때 모양 유지)
    int x = rect.x - safeRect.x;
    int y = rect.y - safeRect.y;

    // 둥근 사각형 그리기 (overlay 좌표계 기준)
    cv::rectangle(overlay, cv::Point(x + cornerRadius, y), cv::Point(x + rect.width - cornerRadius, y + rect.height), color, cv::FILLED);
    cv::rectangle(overlay, cv::Point(x, y + cornerRadius), cv::Point(x + rect.width, y + rect.height - cornerRadius), color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + cornerRadius, y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + rect.width - cornerRadius, y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + cornerRadius, y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + rect.width - cornerRadius, y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);

    // ROI 영역에만 블렌딩 적용
    cv::addWeighted(overlay, alpha, roi, 1.0 - alpha, 0, roi);
}

void ARBubbleRenderer::DrawTextLabel(cv::Mat& frame, const std::string& text, cv::Point position, double fontScale, cv::Scalar color) {
    cv::putText(frame, text, position, cv::FONT_HERSHEY_SIMPLEX, fontScale, color, 1, cv::LINE_AA);
}

void ARBubbleRenderer::RenderEnhanced(cv::Mat& frame, bool applyBlur, float upscaleFactor) {
    if (frame.empty()) return;

    // 1. 해상도 업스케일링
    if (upscaleFactor > 1.0f) {
        cv::resize(frame, frame, cv::Size(), upscaleFactor, upscaleFactor, cv::INTER_CUBIC);
    }

    int screenWidth = frame.cols;
    int screenHeight = frame.rows;

   // 2. 초고속 흑백 포커싱 필터 적용 (블러 제거로 연산량 최소화)
    if (applyBlur && !currentWords.empty()) { // (변수명 applyBlur는 밖에서 통제하므로 그대로 둡니다)
        cv::Mat grayBackground;

        // 1. 전체 화면 흑백 변환 (연산량 매우 적음)
        cv::cvtColor(frame, grayBackground, cv::COLOR_BGR2GRAY);
        cv::cvtColor(grayBackground, grayBackground, cv::COLOR_GRAY2BGR); // 사본과 채널 수를 맞춤

        cv::Mat mask = cv::Mat::zeros(frame.size(), CV_8UC1);

        for (const ARWordData& wordData : currentWords) {
            cv::Rect objectRect(
                wordData.xmin * screenWidth,
                wordData.ymin * screenHeight,
                (wordData.xmax - wordData.xmin) * screenWidth,
                (wordData.ymax - wordData.ymin) * screenHeight
            );
            cv::rectangle(mask, objectRect, cv::Scalar(255), cv::FILLED);
        }

        // 2. 무거운 블러 합성 대신, 흑백 배경 위에 원본 컬러 사물만 바로 덮어쓰기
        frame.copyTo(grayBackground, mask);
        frame = grayBackground;
    }

    // 3. 기존 말풍선 렌더링
    for (const ARWordData& wordData : currentWords) {
        float absoluteX = wordData.relativeX * screenWidth;
        float absoluteY = wordData.relativeY * screenHeight;

        int fontFace = cv::FONT_HERSHEY_SIMPLEX;
        double wordFontScale = 0.7;
        double subFontScale = 0.5;
        int thickness = 1;

        int wordWidth = CalculateTextWidth(wordData.word, wordFontScale, thickness);
        int pronWidth = CalculateTextWidth(wordData.pronunciation, subFontScale, thickness);
        int meaningWidth = CalculateTextWidth(wordData.meaning, subFontScale, thickness);

        int maxTextWidth = std::max({ wordWidth, pronWidth, meaningWidth });

        int paddingX = 20;
        int paddingY = 15;
        int lineSpacing = 10;
        int baseTextHeight = 15;

        int bubbleWidth = maxTextWidth + (paddingX * 2);
        int bubbleHeight = (baseTextHeight * 3) + (lineSpacing * 2) + (paddingY * 2);

        int startX = absoluteX - (bubbleWidth / 2);
        int startY = absoluteY - bubbleHeight - 30;

        startX = std::max(0, std::min(startX, screenWidth - bubbleWidth));
        startY = std::max(0, std::min(startY, screenHeight - bubbleHeight));

        cv::Rect bubbleRect(startX, startY, bubbleWidth, bubbleHeight);
        DrawTransparentRoundedRect(frame, bubbleRect, cv::Scalar(0, 0, 0), 15, 0.6);

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