Shader "AVProVideo/VR/InsideSphere Unlit (stereo+fog) funique"
{
	Properties
	{
		_MainTex("Texture", 2D) = "black" {}
		_UV("UV", 2D) = "black" {}
		_GridGap("Grid Gap", Vector) = (18.0, 10.0, 0.75, 0.75)
		_GridTopDownOffset("Grid Offset", Vector) = (16.0, 16.0, 0.0, 0.0)
		_PixelShift("Pixel Shift", Range (-1, 1)) = 0.0

		[KeywordEnum(None, Top_Bottom, Left_Right, Custom_UV)] Stereo ("Stereo Mode", Float) = 0
		[KeywordEnum(None, Left, Right)] ForceEye ("Force Eye Mode", Float) = 0
		[Toggle(STEREO_DEBUG)] _StereoDebug ("Stereo Debug Tinting", Float) = 0
		[Toggle(APPLY_GRID)] _ApplyGrid("Apply Grid", Float) = 0
		[Toggle(ANDROID)] _Android("Android", Float) = 0
		// Apply the uv mapping
		[Toggle(UUV)] _UUV("UUV", Float) = 0
		[Toggle(APPLY_GAMMA)] _ApplyGamma("Gamma", Float) = 0
		[Toggle(DEFAULTUV)] _DEFAULTUV("DefaultUV", Float) = 0
		[KeywordEnum(POINT, BI, N64)] FILTER("N64", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "IgnoreProjector" = "True" "Queue" = "Background" "CanUseSpriteAtlas"="True" }
		ZWrite On
		//ZTest Always
		Cull Front
		Lighting Off

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "AVProVideo.cginc"

			// UV calculation require high precision float point number
#if APPLY_GAMMA || STEREO_CUSTOM_UV || APPLY_GRID
			#pragma target 3.0
			#pragma fragmentoption ARB_precision_hint_nicest
			#include "FLive.cginc"
#endif

			// Only import grid method when toggle is on
#if APPLY_GRID
			#include "Grid.cginc"
#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile MONOSCOPIC STEREO_TOP_BOTTOM STEREO_LEFT_RIGHT STEREO_CUSTOM_UV
			#pragma multi_compile FORCEEYE_NONE FORCEEYE_LEFT FORCEEYE_RIGHT
			#pragma multi_compile __ STEREO_DEBUG
			#pragma multi_compile __ APPLY_GRID
			#pragma multi_compile __ ANDROID
			#pragma multi_compile __ APPLY_GAMMA
			#pragma multi_compile __ UUV
			#pragma multi_compile __ DEFAULTUV
			#pragma multi_compile FILTER_POINT FILTER_BI FILTER_N64

			// Grid and Flive will use point filter texture
			// This means we need to calculate our own bilinear filter
#if STEREO_CUSTOM_UV || APPLY_GRID
	#if FILTER_N64 || FILTER_BI
		#define CUSTOM_BILINEAR 1
	#endif
#endif

			struct appdata
			{
				float4 vertex : POSITION; // vertex position
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0; // texture coordinate			
				float2 uv2 : TEXCOORD1; // texture coordinate			

#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_VERTEX_INPUT_INSTANCE_ID
#endif
			};

			struct v2f
			{
				float4 vertex : SV_POSITION; // clip space position
				float2 uv : TEXCOORD0; // texture coordinate
				UNITY_FOG_COORDS(1)
				float3 normal : NORMAL;
				float4 tint : COLOR;

#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_VERTEX_OUTPUT_STEREO
#endif
			};

			uniform sampler2D _MainTex;
			uniform sampler2D _UV;
			uniform float4 _MainTex_ST;
			uniform float4 _UV_ST;
			uniform float4 _MainTex_TexelSize;
			uniform float4 _GridGap;
			uniform float4 _GridTopDownOffset;
			uniform float _PixelShift;
			// Grid fixed dataset
#if APPLY_GRID
			const static int grid_width = 12.0;
			const static int grid_height = 6.0;
			const static float grid[72] = {51, 33, 67, 39, 22, 26, 20, 52, 44, 36, 54, 10, 23, 71, 66, 64, 29, 60, 11, 15, 8, 46, 68, 58, 63, 56, 49, 47, 5, 70, 3, 14, 62, 40, 69, 4, 9, 32, 55, 35, 42, 59, 16, 17, 57, 6, 37, 41, 61, 13, 43, 19, 2, 28, 31, 25, 53, 1, 34, 38, 18, 30, 24, 65, 7, 0, 45, 50, 12, 21, 48, 27};
			//const static float grid[72] = {66,58,53,31,36,29,46,65,21,37,12,19,69,50,32,20,43,44,61,52,7,70,5,13,63,56,6,72,54,17,62,55,38,2,59,40,10,47,60,4,34,48,41,51,9,67,22,28,71,27,68,1,8,57,11,39,26,45,24,42,18,49,33,25,16,64,15,3,23,35,30,14};
#endif
			

			v2f vert(appdata v)
			{
				v2f o;
#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_SETUP_INSTANCE_ID(v);						// calculates and sets the built-n unity_StereoEyeIndex and unity_InstanceID Unity shader variables to the correct values based on which eye the GPU is currently rendering
				UNITY_INITIALIZE_OUTPUT(v2f, o);				// initializes all v2f values to 0
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);		// tells the GPU which eye in the texture array it should render to
#endif
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				// Apply encryption first
#if !UUV
				o.uv.x = 1.0 - o.uv.x;
#endif
				// The purpoes of offset is apply simple scaling.
				// This only works with simple region scaling change
#if STEREO_TOP_BOTTOM | STEREO_LEFT_RIGHT
				float4 scaleOffset = GetStereoScaleOffset(IsStereoEyeLeft(), _MainTex_ST.y < 0.0);
				o.uv *= scaleOffset.xy;
				o.uv += scaleOffset.zw;
			
#endif
				o.normal = v.normal;
				o.tint = GetStereoDebugTint(IsStereoEyeLeft());
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				// IsStereoEyeLeft cannot called in fragment shader
				// But we have tint color to identify the eye
				bool isleft = i.tint.g > 0.9;
#if STEREO_DEBUG
				// The color output uv value
				float2 uv_debug;
				bool debug_display = int(_Time.z) % 2 == 0;
#endif
				// Some situation like tiling rearrange will require point filter texture
				// This will make videeo looks sharp and flickering
				// In order to solve pixel gap contrast issue
				// We need to manually bilinear filter our point filter texture
#if CUSTOM_BILINEAR
				float2 uvs[4];
				uvs[0] = i.uv; // We store og uv at position 0
	#if UUV && !DEFAULTUV
				uvs[0] = tex2Dlod(_UV, float4(uvs[0], 0.0, 0.0));
	#endif
#else
				float2 uv = i.uv;
	#if UUV && !DEFAULTUV
				uv = tex2Dlod(_UV, float4(uv, 0.0, 0.0));
	#endif
#endif

#if STEREO_CUSTOM_UV
	#if CUSTOM_BILINEAR
				// FLive pass, This will definitely using custom bilinear filter
				uvs[0].y = 1.0 - uvs[0].y;
				float2 uv_pixels = uvs[0] * _MainTex_TexelSize.zw;
				// Make four sample offset
				float4 uv_c = uvs[0].xxyy + float4(0.0, _MainTex_TexelSize.x, 0.0, _MainTex_TexelSize.y);
				// Solve the result shift UV coordinate
				// NOTICE: the four coordinate might not at the rectangle region
				// It all depend on where the UV coordinate at
				uvs[0] = convert_texal01(uv_c.xz, isleft, _MainTex_TexelSize); // 0, 0
				uvs[1] = convert_texal01(uv_c.yz, isleft, _MainTex_TexelSize); // 1, 0
				uvs[2] = convert_texal01(uv_c.xw, isleft, _MainTex_TexelSize); // 0, 1
				uvs[3] = convert_texal01(uv_c.yw, isleft, _MainTex_TexelSize); // 1, 1
				// Get the result fract pos, The 2D dimensional blend value
				float2 uv_ffrac = uvs[0] % _MainTex_TexelSize.xy;
				float2 uv_frac = uv_ffrac / _MainTex_TexelSize.xy;
	
				for(int i = 0; i < 4; i++)
				{
					uvs[i] += (_MainTex_TexelSize.xy * 0.5);
					uvs[i] = max(min(uvs[i], float2(1.0, 1.0)), float2(0.0, 0.0));
		#if ANDROID
					uvs[i].y = 1.0 - uvs[i].y;
		#endif
				}
	#else
				uv.y = 1.0 - uv.y;
				uv = convert_texal01(uv, isleft, _MainTex_TexelSize); // 0, 0
		#if ANDROID
				uv += (_MainTex_TexelSize.xy * 0.5);
		#endif
				uv = max(min(uv, float2(1.0, 1.0)), float2(0.0, 0.0));
		#if ANDROID
				uv.y = 1.0 - uv.y;
		#endif
	#endif
#endif

#if CUSTOM_BILINEAR
	#if APPLY_GRID
		#if STEREO_CUSTOM_UV
				// If stereo is on, This we pass FLive filter fist
				for(int i = 0; i < 4; i++){
					uvs[i].x += (_MainTex_TexelSize.x * 0.5);
					uvs[i].y -= (_MainTex_TexelSize.y * 0.5);
					uvs[i] = max(min(uvs[i], float2(1.0, 1.0)), float2(0.0, 0.0));
					uvs[i].y = 1.0 - uvs[i].y;
					uvs[i].xy = Flive_UV01(uvs[i].xy, grid_width, grid_height, grid, _MainTex_TexelSize, _GridGap, _GridTopDownOffset, _PixelShift);
					uvs[i].y = 1.0 - uvs[i].y;
					uvs[i].y = 1.0 - uvs[i].y;
				}
		#else
				// If not, this means we should sample here
				// Because first bilinear filter should do the sample uv coordinate job
				uvs[0] = max(min(uvs[0], float2(1.0, 1.0)), float2(0.0, 0.0));
				float4 uv_c = float4(0.0, _MainTex_TexelSize.x, 0.0, _MainTex_TexelSize.y);
				uvs[1].xy = uvs[0] + uv_c.yz; // 1, 0
				uvs[2].xy = uvs[0] + uv_c.xw; // 0, 1
				uvs[3].xy = uvs[0] + uv_c.yw; // 1, 1
				for(int i = 0; i < 4; i++){
			#if ANDROID
					uvs[i].y = 1.0 - uvs[i].y;
			#endif
					uvs[i].xy = Flive_UV01(uvs[i].xy, grid_width, grid_height, grid, _MainTex_TexelSize, _GridGap, _GridTopDownOffset, _PixelShift);
					uvs[i] = max(min(uvs[i], float2(1.0, 1.0)), float2(0.0, 0.0));
					uvs[i].y = 1.0 - uvs[i].y;
				}
				float2 uv_ffrac = uvs[0] % _MainTex_TexelSize.xy;
				float2 uv_frac = uv_ffrac / _MainTex_TexelSize.xy;
		#endif
	#endif
#else
	#if APPLY_GRID
		// If not, this means we should sample here
		// Because first bilinear filter should do the sample uv coordinate job
		uv = max(min(uv, float2(1.0, 1.0)), float2(0.0, 0.0));
		float2 uv_ffrac = uv % _MainTex_TexelSize.xy;
		float2 uv_frac = uv_ffrac / _MainTex_TexelSize.xy;
		#if ANDROID
		uv.y = 1.0 - uv.y;
		#endif
		uv.xy = Flive_UV01(uv.xy, grid_width, grid_height, grid, _MainTex_TexelSize, _GridGap, _GridTopDownOffset, _PixelShift);
		uv = max(min(uv, float2(1.0, 1.0)), float2(0.0, 0.0));
		uv.y = 1.0 - uv.y;
	#endif
#endif

				// VFlip issue, And GLSL HLSL coordinate issue
				// GLSL is bottom-left coordinate system, exoplayer will not vflip
				// HLSL is top-left coordnate system, winRT will vflip
#if !UUV && (APPLY_GRID || STEREO_CUSTOM_UV)
	#if !ANDROID
		#if CUSTOM_BILINEAR
				for(int i = 0; i < 4; i++){
					uvs[i].y = 1.0 - uvs[i].y;
				}
		#else
				uv.y = 1.0 - uv.y;
		#endif
	#endif
#endif


				fixed4 col = fixed4(0.0, 0.0, 0.0, 0.0);
				// This is the color assign part
				// If we custom bilinear filter in shader
				// We should blend the neighbor sample by 2D fract value 
#if CUSTOM_BILINEAR
	#if STEREO_DEBUG
				uv_debug = uvs[0];
	#endif
	#if FILTER_N64
				fixed4 texelA = SampleRGBA(_MainTex, uvs[0]); // 0, 0
				fixed4 texelB = SampleRGBA(_MainTex, uvs[1]); // 1, 0
				fixed4 texelC = SampleRGBA(_MainTex, uvs[2]); // 0, 1
				float2 corner0 = uvs[0];
				float2 corner1 = float2(0, _MainTex_TexelSize.y);
				float2 corner2 = float2(_MainTex_TexelSize.x, 0);
				float2 v0 = float2(corner1 - corner0);
				float2 v1 = float2(corner2 - corner0);
				float2 v2 = uv_ffrac.xy   - float2(corner0);
				float den = v0.x * v1.y - v1.x * v0.y;
				float lambda1 = abs((v2.x * v1.y - v1.x * v2.y) / den);
				float lambda2 = abs((v0.x * v2.y - v2.x * v0.y) / den);
				float lambda0 = 1.0 - lambda1 - lambda2;
				col = texelA*lambda0 + texelB*lambda1 + texelC*lambda2;
	#else
				fixed4 texelA = SampleRGBA(_MainTex, uvs[0]); // 0, 0
				fixed4 texelB = SampleRGBA(_MainTex, uvs[1]); // 1, 0
				fixed4 texelC = SampleRGBA(_MainTex, uvs[2]); // 0, 1
				fixed4 texelD = SampleRGBA(_MainTex, uvs[3]); // 1, 1
				col = lerp(lerp(texelA, texelB, uv_frac.x), lerp(texelC, texelD, uv_frac.x), 1.0 - uv_frac.y);
	#endif
#else
				// If not, then we just assign the simply sample the texture
	#if STEREO_DEBUG
				uv_debug = uv;
	#endif
				col = SampleRGBA(_MainTex, uv);	
				//col = SampleRGBA(_MainTex, SampleRGBA(_UV, og).xy);
#endif
	
#if APPLY_GAMMA
				// SampleRGBA is using tex2DLOD, which means that gamma will not apply automatically
				// Simply apply to it
				// col.rgb = GammaToLinear_ApproxPow(col.rgb);
#endif


#if STEREO_DEBUG
				if (debug_display){
					col = fixed4(uv_debug.x, uv_debug.y, 0.0, 1.0);
				}
#endif

				UNITY_APPLY_FOG(i.fogCoord, col);
				return fixed4(col.rgb, 1.0);
			}
			ENDCG
		}
	}
}
