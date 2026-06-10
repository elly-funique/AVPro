//-----------------------------------------------------------------------------
// Copyright 2015-2021 RenderHeads Ltd.  All rights reserverd.
//-----------------------------------------------------------------------------

//#define AVPRO_CHEAP_GAMMA_CONVERSION

// coordinate [min pos, max pos]
INLINE bool to_standard01(inout FLOAT2 uv_pixel, FLOAT2 rect_min, FLOAT2 rect_max, FLOAT2 size){
	// Check if the point is in the rect
	bool inbound = uv_pixel.x >= rect_min.x && uv_pixel.y >= rect_min.y && uv_pixel.x <= rect_max.x && uv_pixel.y <= rect_max.y;
	// Convert coordinate to 0 - 1
	if(inbound){
		// Make the corner [0, 0]
		uv_pixel.xy -= rect_min;
		// Make the range to [w, h]
		uv_pixel.xy *= (size / (rect_max - rect_min));
	}
	return inbound;
}
INLINE void to_rect01(inout FLOAT2 uv_pixel, FLOAT2 rect_min, FLOAT2 rect_max, FLOAT2 size){
	// To target rect [tw, th]
	uv_pixel.xy *= ((rect_max - rect_min) / size);
	// Move the corner to target rect corner
	uv_pixel += rect_min;
}
INLINE FLOAT2 convert_texal01(FLOAT2 oguv, bool leftEye, FLOAT4 size) {
#if defined (ANDROID)
	FLOAT2 _half = size.xy / 2.0;
	FLOAT2 o = oguv; // [0-1] [0-1]
	size.zw = FLOAT2(1.0, 1.0); // [1/7680, 1/4320]
#else
	FLOAT2 o = oguv * size.zw; // [0-1] [0-1]
	FLOAT2 single = FLOAT2(1.0, 1.0);
#endif
	float heightRatio = (size.w / 3.0); // 1440
	float heightRatio2 = (size.w / 3.0) * 2.0; // 2880
	float heightRatio_half = (size.w / 2.0); // 2160
	float widthRatio = (size.z / 4.0); // 1920
	float widthRatio2 = (size.z / 4.0) * 2.0; // 3840
	float widthRatio3 = (size.z / 4.0) * 3.0; // 5760
	float widthRatio3l = (size.z / 3.0); // 2560
	float widthRatio3l2 = (size.z / 3.0) * 2.0; // 5120
#if defined (ANDROID)
	if (leftEye) {
		o.y *= (2.0 / 3.0); // [0-2880]
		o.x *= (3.0 / 4.0); // [0-7560]
		if(o.x > (widthRatio3 - size.x)){
			o.x -= widthRatio3;
			o.x += size.x;
		}
	}else{
		if (o.y < heightRatio_half) { //  [0-2160]
			// 0.0 bottom left coner
			o.x *= 0.75; // [0-5760]
			o.y *= 2.0; // [0-4320]
			o.y *= (1.0 / 3.0); // [0-1440]
			o.y += heightRatio2; // [2880-4320]
			// and it should be [2881-4320]
			if(o.x > (widthRatio3 - size.x)){
				o.x -= widthRatio3;
				o.x += size.x;
			}
		}else{ // y > 2160
			if (o.x < widthRatio3l) { // [0-2560]
				// 0.0 bottom left coner
				o.x *= 3.0; // [0-7680]
				o.x *= (1.0 / 4.0); // [0-1920]
				o.x += widthRatio3; // [5760-7680]
				o.y -= heightRatio_half; // [1-2160]
				o.y *= 2.0; //[2-4320]
				o.y *= (1.0 / 3.0); // [0.666-1440]
				if(o.y < 0.0)
				{
					o.x -= widthRatio3;
					o.y += size.w;
					o.x -= size.x;
				}
				if (o.x < (widthRatio3 + size.x)){
					o.y += heightRatio2;
					o.x += widthRatio;
					o.x -= (size.x * 2.0);
				}
				if(o.x > (size.z - size.x)){
					o.y += heightRatio;
					o.x -= widthRatio;
					o.x += size.x;
				}
			}else if (o.x > widthRatio3l2) { // 0.666 - 1
				o.x -= widthRatio3l2;
				o.x *= 3.0;
				o.x *= (1.0 / 4.0);
				o.x += widthRatio3;
				o.y -= heightRatio_half;
				o.y *= 2.0;
				o.y *= (1.0 / 3.0);
				o.y += heightRatio2;
				if (o.y < heightRatio2 + size.y){
					o.y += size.y;
				}
				if (o.x < widthRatio3){
					o.y += heightRatio;
					o.x -= widthRatio;
					o.x += size.x;
				}
				if (o.x > (size.z - size.x)){
					o.y -= heightRatio2;
					o.x -= widthRatio;
					o.x += size.x;
				}
			}else{ // 0.333 - 0.666
				o.x -= widthRatio3l;
				o.x *= 3.0;
				o.x *= (1.0 / 4.0);
				o.x += widthRatio3;
				o.y -= heightRatio_half;
				o.y *= 2.0;
				o.y *= (1.0 / 3.0);
				o.y += heightRatio;
				if(o.y < heightRatio + size.y){
					o.y += heightRatio2;
					o.x -= widthRatio2;
				} 
				if(o.x > (size.z - size.x)){
					o.y += heightRatio;
					o.x -= widthRatio;
					o.x += size.x;
				}
			}
		}
	}
#else
	if (leftEye) {
		o.y *= (2.0/3.0);
		o.y += heightRatio;
		o.x *= (3.0/4.0) ;
		if(o.x > widthRatio3 - single.x){
			o.x -= widthRatio3;
			//o.x += size.x * 1.0;
		}
	}else{
		if (o.y > heightRatio_half) { // 0.5 - 1
			o.x *= (3.0/4.0);
			o.y -= heightRatio_half;
			o.y *= 2.0;
			o.y *= (1.0 / 3.0);
			if(o.x > widthRatio3 - single.x){
				o.x -= widthRatio3;
			}
		}else{ // 0 - 0.5
			if (o.x < widthRatio3l) { // 0 - 0.333
				// 0.0 top left corner
				o.x *= 3.0;
				o.x *= (1.0 / 4.0);
				o.x += widthRatio3;
				o.y *= 2.0; // 0 - 1
				o.y *= (1.0 / 3.0); // 0 - 0.333
				o.y += heightRatio2; // 0.666 - 1
				if(o.y > (size.w - single.y)){o.y -= (single.y);} 
				if(o.x < (widthRatio3 + single.x)){
					o.x += (single.x * 1.0);
				}
				else if(o.x > (size.z - single.x)){
					o.x -= single.x;
				}
			}else if (o.x > widthRatio3l2) { // 0.666 - 1
				o.x -= widthRatio3l2;
				o.x *= 3.0;
				o.x *= (1.0 / 4.0);
				o.x += widthRatio3;
				o.y *= 2.0;
				o.y *= (1.0 / 3.0);
				if(o.y > (heightRatio - single.y)){o.y -= (single.y * 1.0);} 
				if(o.x < (widthRatio3 + single.x)){
					//o.y += heightRatio;
					//o.x -= widthRatio;
					o.x += (single.x * 1.0);
				}
				else if(o.x > (size.z - single.x)){
					o.x -= single.x;
				}
			}else{ // 0.333 - 0.666
				o.x -= widthRatio3l;
				o.x *= 3.0;
				o.x *= (1.0 / 4.0);
				o.x += widthRatio3;
				o.y *= 2.0;
				o.y *= (1.0 / 3.0);
				o.y += heightRatio;
				if(o.y > (heightRatio2 - single.y * 1.0)){o.y -= (single.y * 1.0);} 
				if(o.x < (widthRatio3 + single.x)){
					o.x += (single.x * 1.0);
				}
				else if(o.x > (size.z - single.x)){
					o.x -= single.x;
				}
			}
		}
	}
	o *= size.xy;
#endif
	return o;
}
INLINE FLOAT2 convert_range01(FLOAT2 oguv, bool leftEye, FLOAT4 size){
	FLOAT2 o = oguv;
	size.zw = FLOAT2(1.0, 1.0);
	float heightRatio = (size.w / 3.0);
	float heightRatio2 = (size.w / 3.0) * 2.0;
	float heightRatio_half = (size.w / 2.0);
	float widthRatio = (size.z / 4.0);
	float widthRatio2 = (size.z / 4.0) * 2.0;
	float widthRatio3 = (size.z / 4.0) * 3.0;
	float widthRatio3l = (size.z / 3.0);
	float widthRatio3l2 = (size.z / 3.0) * 2.0;

#if defined (ANDROID)
	if(leftEye){
		if (to_standard01(o, FLOAT2(0.0, 0.0), size.zw, size.zw)) 
			to_rect01(o, FLOAT2(0, 0), FLOAT2(widthRatio3, heightRatio2), size.zw);
	}
	else{
		if (to_standard01(o, FLOAT2(0.0, 0.0), FLOAT2(size.z, size.w / 2.0), size.zw))
			to_rect01(o, FLOAT2(0, heightRatio2 + size.y), FLOAT2(widthRatio3, size.w), size.zw);
		else if (to_standard01(o, FLOAT2(0.0, (size.w / 2.0) + size.y), FLOAT2(widthRatio3l, size.w), size.zw))	
			to_rect01(o, FLOAT2(widthRatio3 + size.x, 0), FLOAT2(size.z, heightRatio), size.zw);
		else if (to_standard01(o, FLOAT2(widthRatio3l + size.x, (size.w / 2.0) + size.y), FLOAT2(widthRatio3l2, size.w), size.zw))	
			to_rect01(o, FLOAT2(widthRatio3 + size.x, heightRatio + size.y), FLOAT2(size.z, heightRatio2), size.zw);
		else if (to_standard01(o, FLOAT2(widthRatio3l2 + size.x, (size.w / 2.0) + size.y), size.zw, size.zw))	
			to_rect01(o, FLOAT2(widthRatio3 + size.x, heightRatio2 + size.y), size.zw, size.zw);
	}
#else
	if(leftEye){
		if (to_standard01(o, FLOAT2(0.0, 0.0), size.zw, size.zw)) 
			to_rect01(o, FLOAT2(0, heightRatio), FLOAT2(widthRatio3, size.w), size.zw);
	}
	else{
		if (to_standard01(o, FLOAT2(0.0, size.w / 2.0), size.zw, size.zw)) 
			to_rect01(o, FLOAT2(0, heightRatio), FLOAT2(widthRatio3, size.w), size.zw);
		if (to_standard01(o, FLOAT2(0.0, 0.0), FLOAT2(size.z, size.w / 2.0), size.zw)) 
			to_rect01(o, FLOAT2(widthRatio3, heightRatio), FLOAT2(size.z, size.w), size.zw);
		if (to_standard01(o, FLOAT2(0.0, 0.0), FLOAT2(size.z, size.w / 2.0), size.zw)) 
			to_rect01(o, FLOAT2(widthRatio3, heightRatio), FLOAT2(size.z, size.w), size.zw);
		if (to_standard01(o, FLOAT2(0.0, 0.0), FLOAT2(size.z, size.w / 2.0), size.zw)) 
			to_rect01(o, FLOAT2(widthRatio3, heightRatio), FLOAT2(size.z, size.w), size.zw);
	}
#endif
	return o;
}