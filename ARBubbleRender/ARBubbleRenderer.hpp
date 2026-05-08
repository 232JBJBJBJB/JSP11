#ifndef ARBubbleRenderer_hpp
#define ARBubbleRenderer_hpp
#import "ARBridge.h"
#include <opencv2/opencv.hpp>
#include <string>
#include <vector>

struct ARWordData {
    std::string word;
    std::string pronunciation;
    std::string meaning;
    float xmin, ymin, xmax, ymax;
    float relativeX;
    float relativeY;
};

class ARBubbleRenderer {
private:
    std::vector<ARWordData> currentWords;

    // ³»ºÎ ·»´õ¸µ ÇïÆÛ ÇÔ¼ö
    int CalculateTextWidth(const std::string& text, double fontScale, int thickness);
    void DrawTransparentRoundedRect(cv::Mat& frame, cv::Rect rect, cv::Scalar color, int cornerRadius, double alpha);
    void DrawTextLabel(cv::Mat& frame, const std::string& text, cv::Point position, double fontScale, cv::Scalar color);

public:
    ARBubbleRenderer() = default;
    ~ARBubbleRenderer() = default;

    void UpdateWords(const std::vector<ARWordData>& words);

    void Render(cv::Mat& frame);
    void RenderEnhanced(cv::Mat& frame, bool applyBlur, float upscaleFactor);
};

#endif /* ARBubbleRenderer_hpp */
