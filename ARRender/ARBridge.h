#pragma once

#ifndef ARBridge_h
#define ARBridge_h

#ifdef __cplusplus
extern "C" 
{
#endif

	void C_ClearARWords();
	void C_UpdateARWords(const char* word, const char* pron, const char* meaning, float relX, float relY);
	void C_RenderBubbles(float screenWidth, float screenHeight);

#ifdef __cplusplus
}
#endif

#endif /* ARBridge_h */