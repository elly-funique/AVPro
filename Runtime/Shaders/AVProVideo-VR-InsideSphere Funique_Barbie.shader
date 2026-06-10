Shader "AVProVideo/VR/InsideSphere Unlit (stereo+fog) barbie"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "black" {}
		_Overlay("Overlay", 2D) = "black" {}
		_ChromaTex("Chroma", 2D) = "white" {}
		// 0 for normal
		// 1 for flive
		_Mode("Mode", int) = 0


		[KeywordEnum(None, Top_Bottom, Left_Right, Custom_UV)] Stereo ("Stereo Mode", Float) = 0
		[KeywordEnum(None, Difference, Lighten, Add, Screen, Multiply)] Mask("Mask Mode", Float) = 0
		[KeywordEnum(None, Left, Right)] ForceEye ("Force Eye Mode", Float) = 0
		[Toggle(STEREO_DEBUG)] _StereoDebug ("Stereo Debug Tinting", Float) = 0
		[KeywordEnum(None, EquiRect180)] Layout("Layout", Float) = 0
		[Toggle(HIGH_QUALITY)] _HighQuality ("High Quality", Float) = 0
		[Toggle(APPLY_GAMMA)] _ApplyGamma("Apply Gamma", Float) = 0
		[Toggle(USE_YPCBCR)] _UseYpCbCr("Use YpCbCr", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "IgnoreProjector" = "True" "Queue" = "Background" }
		ZWrite On
		//ZTest Always
		Cull Front
		Lighting Off

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "AVProVideo.cginc"
#if HIGH_QUALITY || APPLY_GAMMA
			#pragma target 3.0
#endif
			#pragma vertex vert
			#pragma fragment frag

			//#define STEREO_DEBUG 1
			//#define HIGH_QUALITY 1

			#pragma multi_compile_fog
			// TODO: replace use multi_compile_local instead (Unity 2019.1 feature)
			#pragma multi_compile MONOSCOPIC STEREO_TOP_BOTTOM STEREO_LEFT_RIGHT STEREO_CUSTOM_UV
			#pragma multi_compile MASK_NONE MASK_DIFFERENCE MASK_LIGHTEN MASK_ADD MASK_SCREEN MASK_MULTIPLY
			#pragma multi_compile FORCEEYE_NONE FORCEEYE_LEFT FORCEEYE_RIGHT
			#pragma multi_compile __ STEREO_DEBUG
			#pragma multi_compile __ HIGH_QUALITY
			#pragma multi_compile __ APPLY_GAMMA
			#pragma multi_compile __ USE_YPCBCR
			#pragma multi_compile __ LAYOUT_EQUIRECT180

			struct appdata
			{
				fixed4 vertex : POSITION; // vertex position
#if HIGH_QUALITY
				fixed3 normal : NORMAL;
#else
				fixed2 uv : TEXCOORD0; // texture coordinate			
#if STEREO_CUSTOM_UV
				fixed2 uv2 : TEXCOORD1;	// Custom uv set for right eye (left eye is in TEXCOORD0)
#endif
#endif

#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_VERTEX_INPUT_INSTANCE_ID
#endif
			};

			struct v2f
			{
				fixed4 vertex : SV_POSITION; // clip space position
#if HIGH_QUALITY
				fixed3 normal : TEXCOORD0;
				
#if STEREO_TOP_BOTTOM | STEREO_LEFT_RIGHT
				fixed4 scaleOffset : TEXCOORD1; // texture coordinate
				UNITY_FOG_COORDS(2)
#else
				UNITY_FOG_COORDS(1)
#endif
#else
				fixed2 uv : TEXCOORD0; // texture coordinate
				UNITY_FOG_COORDS(1)
#endif

#if STEREO_DEBUG
				fixed4 tint : COLOR;
#endif

#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_VERTEX_OUTPUT_STEREO
#endif
			};

			uniform sampler2D _MainTex;
			uniform sampler2D _Overlay;
			uniform int _Mode;
#if USE_YPCBCR
			uniform sampler2D _ChromaTex;
			uniform fixed4x4 _YpCbCrTransform;
#endif
			uniform fixed4 _MainTex_ST;

			v2f vert (appdata v)
			{
				v2f o;

#ifdef UNITY_STEREO_INSTANCING_ENABLED
				UNITY_SETUP_INSTANCE_ID(v);						// calculates and sets the built-n unity_StereoEyeIndex and unity_InstanceID Unity shader variables to the correct values based on which eye the GPU is currently rendering
				UNITY_INITIALIZE_OUTPUT(v2f, o);				// initializes all v2f values to 0
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);		// tells the GPU which eye in the texture array it should render to
#endif

				o.vertex = XFormObjectToClip(v.vertex);

#if !HIGH_QUALITY
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
#endif

	#if STEREO_CUSTOM_UV 
				o.uv.xy = TRANSFORM_TEX(v.uv2, _MainTex);
				o.uv.xy = fixed2(o.uv.x, o.uv.y);
	#else
				o.uv.xy = fixed2(1.0-o.uv.x, o.uv.y);
	#endif

#if STEREO_TOP_BOTTOM | STEREO_LEFT_RIGHT
				fixed4 scaleOffset = GetStereoScaleOffset(IsStereoEyeLeft(), _MainTex_ST.y < 0.0);

	#if !HIGH_QUALITY
				o.uv.xy *= scaleOffset.xy;
				o.uv.xy += scaleOffset.zw;
	#else
				o.scaleOffset = scaleOffset;
	#endif
#elif STEREO_CUSTOM_UV && !HIGH_QUALITY
				if (!IsStereoEyeLeft())
				{
					o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
					o.uv.xy = fixed2(o.uv.x, o.uv.y);
				}
#endif

#if HIGH_QUALITY
				o.normal = v.normal;
#endif

				#if STEREO_DEBUG
				o.tint = GetStereoDebugTint(IsStereoEyeLeft());
				#endif

				UNITY_TRANSFER_FOG(o, o.vertex);

				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed2 uv;

#if HIGH_QUALITY
				fixed3 n = normalize(i.normal);

				fixed M_1_PI = 1.0 / 3.1415926535897932384626433832795;
				fixed M_1_2PI = 1.0 / 6.283185307179586476925286766559;
				uv.x = 0.5 - atan2(n.z, n.x) * M_1_2PI;
				uv.y = 0.5 - asin(-n.y) * M_1_PI;
				uv.x += 0.75;
				uv.x = fmod(uv.x, 1.0);
				//uv.x = uv.x % 1.0;
				uv.xy = TRANSFORM_TEX(uv, _MainTex);
				#if LAYOUT_EQUIRECT180
				uv.x = ((uv.x - 0.5) * 2.0) + 0.5;
				#endif
				#if STEREO_TOP_BOTTOM | STEREO_LEFT_RIGHT
				uv.xy *= i.scaleOffset.xy;
				uv.xy += i.scaleOffset.zw;
				#endif
#else
				uv = i.uv;
#endif
				fixed4 col;
#if USE_YPCBCR
				col = SampleYpCbCr(_MainTex, _ChromaTex, uv, _YpCbCrTransform);
#else
				col = SampleRGBA(_MainTex, uv);
#endif

				fixed4 ocol;
#if MASK_ADD
				ocol = SampleRGBA(_Overlay, uv);
				col += ocol;
#elif MASK_DIFFERENCE
				ocol = SampleRGBA(_Overlay, uv);
				col = abs(col - ocol);
#elif MASK_LIGHTEN
				ocol = SampleRGBA(_Overlay, uv);
				col = max(col, ocol);
#elif MASK_SCREEN
				ocol = SampleRGBA(_Overlay, uv);
				col = fixed4(1.0, 1.0, 1.0, 1.0) - ((fixed4(1.0, 1.0, 1.0, 1.0) - col) * (fixed4(1.0, 1.0, 1.0, 1.0) - ocol));
#elif MASK_MULTIPLY
				ocol = SampleRGBA(_Overlay, uv);
				col *= ocol;
#endif

#if STEREO_DEBUG
				col *= i.tint;
#endif

				UNITY_APPLY_FOG(i.fogCoord, col);
				return fixed4(col.rgb, 1.0);
			}
			ENDCG
		}
	}
}
