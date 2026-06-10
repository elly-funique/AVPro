INLINE FLOAT2 Flive_UV01(FLOAT2 uv, int hw, int hh, float map[72], FLOAT4 size, FLOAT4 gap, FLOAT4 _offset, float shift) {
	uv.x -= (size.x * shift);
	FLOAT2 local_uv = FLOAT2(uv * FLOAT2(hw, hh) % 1.0); // [0-1] [0-1]
	INT2 p = min(INT2(uv.x * hw, uv.y * hh), INT2(hw, hh)); // [0-hw] [0-hh]
	FLOAT2 leng = FLOAT2(1.0 / hw, 1.0 / hh); // [0-1/hw] [0-1/hh]
	int index = p.y * hw + p.x;
	int select_k = map[index];
	INT2 tp = INT2(select_k % hw, floor(select_k / hw));
	FLOAT2 diff = leng * (FLOAT2(1.0, 1.0) - (size.xy * gap.xy)); // [0-hw] [0-hh]
	if(int(tp.y) == 0){
		// top area
		diff.y *= _offset.w;
//#if defined(ANDROID)
		gap.w += _offset.y;
//#endif
	}
	else if(int(tp.y) == hh - 1){
		// bottom area
		diff.y /= _offset.w;
		gap.w -= _offset.y;
	}
	// Position (corner)
	// Local rect scale
	// Offset
	return (tp * leng) + (local_uv * diff) + (size.xy * gap.zw);
	//return (tp * leng) + (local_uv * leng);
}