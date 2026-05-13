#import "ARBridge.h"
#import "ARBubbleRenderer.hpp"
#import <opencv2/imgcodecs/ios.h> // iOS 전용 OpenCV 컨버터

static ARBubbleRenderer renderer;
static std::vector<ARWordData> tempWords;

void C_ClearARWords() {
    tempWords.clear();
    renderer.UpdateWords(tempWords);
}

UIImage* C_RenderBubblesOnImage(UIImage* inputImage) {
    if (!inputImage) return nil;

    cv::Mat frame;
    // 1. UIImage -> cv::Mat 변환
    UIImageToMat(inputImage, frame);

    // 2. C++ 렌더러를 통해 프레임 위에 말풍선 그리기
    renderer.Render(frame);

    // 3. cv::Mat -> UIImage 변환하여 Swift로 반환
    UIImage* resultImage = MatToUIImage(frame);
    
    return resultImage;
}

void C_UpdateARWords_V2(const char* word, const char* pron, const char* meaning, 
                        float relX, float relY, 
                        float xmin, float ymin, float xmax, float ymax) {
    ARWordData data;
    data.word = word ? word : "";
    data.pronunciation = pron ? pron : "";
    data.meaning = meaning ? meaning : "";
    data.relativeX = relX;
    data.relativeY = relY;
    data.xmin = xmin; data.ymin = ymin; data.xmax = xmax; data.ymax = ymax;
    
    tempWords.push_back(data);
    renderer.UpdateWords(tempWords);
}

UIImage* C_RenderEnhancedBubbles(UIImage* inputImage, bool applyBlur, float upscaleFactor) {
    if (!inputImage) return nil;
    cv::Mat frame;
    UIImageToMat(inputImage, frame);

    // 향상된 렌더러 호출
    renderer.RenderEnhanced(frame, applyBlur, upscaleFactor);

    return MatToUIImage(frame);
}
