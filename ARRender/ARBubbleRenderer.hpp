#ifndef ARBubbleRenderer_hpp
#define ARBubbleRenderer_hpp

#include <string>
#include <vector>

struct ARWordData {
    std::string word;
    std::string pronunciation;
    std::string meaning;
    float relativeX;
    float relativeY;
};

class ARBubbleRenderer {
private:
    std::vector<ARWordData> currentWords;

    float CalculateTextWidth(const std::string& text, float fontSize);
    void DrawRoundedRect(float x, float y, float width, float height, float cornerRadius, float r, float g, float b, float alpha);
    void DrawTextLabel(const std::string& text, float x, float y, float fontSize);

public:
    ARBubbleRenderer() = default;
    ~ARBubbleRenderer() = default;

    void UpdateWords(const std::vector<ARWordData>& words);
    void Render(float screenWidth, float screenHeight);
};

#endif /* ARBubbleRenderer_hpp */