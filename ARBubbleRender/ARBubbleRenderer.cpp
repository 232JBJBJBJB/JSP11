#include "ARBubbleRenderer.hpp"
#include <algorithm>

// 🌟 여기서 한 번 정의되었어!
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

void ARBubbleRenderer::DrawTransparentRoundedRect(cv::Mat& frame, cv::Rect rect, cv::Scalar color, int cornerRadius, double alpha) {
    cv::Rect safeRect = rect & cv::Rect(0, 0, frame.cols, frame.rows);
    if (safeRect.width <= 0 || safeRect.height <= 0) return;

    cv::Mat roi = frame(safeRect);
    cv::Mat overlay;
    roi.copyTo(overlay);

    int x = rect.x - safeRect.x;
    int y = rect.y - safeRect.y;

    cv::rectangle(overlay, cv::Point(x + cornerRadius, y), cv::Point(x + rect.width - cornerRadius, y + rect.height), color, cv::FILLED);
    cv::rectangle(overlay, cv::Point(x, y + cornerRadius), cv::Point(x + rect.width, y + rect.height - cornerRadius), color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + cornerRadius, y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + rect.width - cornerRadius, y + cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + cornerRadius, y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);
    cv::circle(overlay, cv::Point(x + rect.width - cornerRadius, y + rect.height - cornerRadius), cornerRadius, color, cv::FILLED);

    cv::addWeighted(overlay, alpha, roi, 1.0 - alpha, 0, roi);
}

void ARBubbleRenderer::DrawTextLabel(cv::Mat& frame, const std::string& text, cv::Point position, double fontScale, cv::Scalar color) {
    cv::putText(frame, text, position, cv::FONT_HERSHEY_SIMPLEX, fontScale, color, 1, cv::LINE_AA);
}

// 🚨 여기에 중복으로 있던 UpdateWords 함수를 지웠어!

void ARBubbleRenderer::RenderEnhanced(cv::Mat& frame, bool applyBlur, float upscaleFactor) {
    if (frame.empty()) return;

    if (upscaleFactor > 1.0f) {
        cv::resize(frame, frame, cv::Size(), upscaleFactor, upscaleFactor, cv::INTER_CUBIC);
    }

    int screenWidth = frame.cols;
    int screenHeight = frame.rows;

    if (applyBlur && !currentWords.empty()) {
        cv::Mat grayBackground;

        if (frame.channels() == 4) {
            cv::cvtColor(frame, grayBackground, cv::COLOR_RGBA2GRAY);
            cv::cvtColor(grayBackground, grayBackground, cv::COLOR_GRAY2RGBA);
        }
        else {
            cv::cvtColor(frame, grayBackground, cv::COLOR_BGR2GRAY);
            cv::cvtColor(grayBackground, grayBackground, cv::COLOR_GRAY2BGR);
        }

        cv::Scalar brightnessOffset = (frame.channels() == 4) ? cv::Scalar(40, 40, 40, 0) : cv::Scalar(40, 40, 40);
        cv::add(grayBackground, brightnessOffset, grayBackground);

        double bwAlpha = 0.7;
        cv::addWeighted(grayBackground, bwAlpha, frame, 1.0 - bwAlpha, 0.0, grayBackground);

        cv::Mat mask = cv::Mat::zeros(frame.size(), CV_8UC1);

        for (const ARWordData& wordData : currentWords) {
            float centerX = ((wordData.xmin + wordData.xmax) / 2.0f) * screenWidth;
            float centerY = ((wordData.ymin + wordData.ymax) / 2.0f) * screenHeight;

            cv::Point center(
                static_cast<int>(centerX),
                static_cast<int>(centerY)
            );

            float boxW = (wordData.xmax - wordData.xmin) * screenWidth;
            float boxH = (wordData.ymax - wordData.ymin) * screenHeight;

            int radius = static_cast<int>(std::max(boxW, boxH) / 2.0f * 0.85f);

            if (radius > 0) {
                cv::circle(mask, center, radius, cv::Scalar(255), cv::FILLED);
            }
        }

        cv::GaussianBlur(mask, mask, cv::Size(91, 91), 0);

        frame.copyTo(grayBackground, mask);
        frame = grayBackground;
    }
}
