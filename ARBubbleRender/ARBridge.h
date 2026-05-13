#pragma once

#ifndef ARBridge_h
#define ARBridge_h

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#endif

#ifdef __cplusplus
extern "C" 
{
#endif

	void C_ClearARWords();
	void C_RenderBubbles(float screenWidth, float screenHeight);
	void C_UpdateARWords_V2(const char* word, const char* pron, const char* meaning,
		float relX, float relY,
		float xmin, float ymin, float xmax, float ymax);
#ifdef __OBJC__
	UIImage* C_RenderEnhancedBubbles(UIImage* inputImage, bool applyBlur, float upscaleFactor);
#endif

#ifdef __cplusplus
}
#endif

#endif /* ARBridge_h */

