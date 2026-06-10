Shader "AVProVideo/VR/InsideSphere Unlit (stereo+color) - Android OES ONLY Funique" 
{
	Properties 
	{
		_MainTex("Texture", 2D) = "black" {}
		_Overlay("Overlay", 2D) = "black" {}
		_Padding("Padding", Float) = -0.0001
		_Offset("Offset", Float) = -0.0001

		[KeywordEnum(None, Top_Bottom, Left_Right, Custom_UV)] Stereo ("Stereo Mode", Float) = 0
		//[KeywordEnum(None, Difference, Lighten, Add, Screen, Multiply)] Mask("Mask Mode", Float) = 0
		[KeywordEnum(None, Left, Right)] ForceEye ("Force Eye Mode", Float) = 0
		[Toggle(STEREO_DEBUG)] _StereoDebug ("Stereo Debug Tinting", Float) = 0
		[Toggle(USING_DEFAULT_TEXTURE)] _DefaultTexture ("Use Default Texture", Float) = 0
		[Toggle(APPLY_GAMMA)] _ApplyGamma("Apply Gamma", Float) = 0
		[Toggle(APPLY_GRID)] _ApplyGrid("Apply Grid", Float) = 0
		[Toggle(ANDROID)] _Android("Android", Float) = 0 
	}
	SubShader 
	{
		Tags{ "RenderType"="Opaque" "IgnoreProjector" = "True" "Queue" = "Background" }
		Pass
		{ 
			Cull Front
			//ZTest Always
			ZWrite On
			Lighting Off

			GLSLPROGRAM

			#pragma only_renderers gles gles3
			// TODO: replace use multi_compile_local instead (Unity 2019.1 feature)
			#pragma multi_compile MONOSCOPIC STEREO_TOP_BOTTOM STEREO_LEFT_RIGHT STEREO_CUSTOM_UV
			//#pragma multi_compile MASK_NONE MASK_DIFFERENCE MASK_LIGHTEN MASK_ADD MASK_SCREEN MASK_MULTIPLY
			#pragma multi_compile FORCEEYE_NONE FORCEEYE_LEFT FORCEEYE_RIGHT
			#pragma multi_compile __ STEREO_DEBUG
			#pragma multi_compile __ APPLY_GAMMA
			#pragma multi_compile __ USING_DEFAULT_TEXTURE
			#pragma multi_compile __ APPLY_GRID
			#pragma multi_compile __ ANDROID

			#extension GL_OES_EGL_image_external : require
			#extension GL_OES_EGL_image_external_essl3 : enable
			precision highp float;

#ifdef VERTEX
			//
			//  Vertex Start Point
			//
	#include "UnityCG.glslinc"
	#define SHADERLAB_GLSL
	#include "AVProVideo.cginc"
	#include "FLive.cginc"
			varying vec3 texVal;
			varying vec4 tint; // Color
			uniform vec4 _MainTex_ST;
			uniform mat4 _TextureMatrix;
		

			/// @fix: explicit TRANSFORM_TEX(); Unity's preprocessor chokes when attempting to use the TRANSFORM_TEX() macro in UnityCG.glslinc
			/// 	(as of Unity 4.5.0f6; issue dates back to 2011 or earlier: http://forum.unity3d.com/threads/glsl-transform_tex-and-tiling.93756/)
			vec2 transformTex(vec2 texCoord, vec4 texST) 
			{
				return (texCoord * texST.xy + texST.zw);
			}

			void main()
			{
				gl_Position = XFormObjectToClip(gl_Vertex); // SV_Position
				texVal.xy = gl_MultiTexCoord0.xy;
				texVal.xy = transformTex(gl_MultiTexCoord0.xy, _MainTex_ST);
	#if ANDROID
				texVal.x = 1.0 - texVal.x;
	#endif
				// Apply texture transformation matrix - adjusts for offset/cropping (when the decoder decodes in blocks that overrun the video frame size, it pads)
				texVal.xy = (_TextureMatrix * vec4(texVal.x, texVal.y, 0.0, 1.0)).xy;

	#if defined(STEREO_TOP_BOTTOM) || defined(STEREO_LEFT_RIGHT)
				bool isLeftEye = IsStereoEyeLeft();
				vec4 scaleOffset = GetStereoScaleOffset(isLeftEye, false);

				texVal.xy *= scaleOffset.xy;
				texVal.xy += scaleOffset.zw;
	#endif

				tint = GetStereoDebugTint(IsStereoEyeLeft());
			}
#endif

#ifdef FRAGMENT
	#include "UnityCG.glslinc"
	#define SHADERLAB_GLSL
	#include "AVProVideo.cginc"
			//
			//  Fragment Start Point
			//
			varying vec3 texVal;
			varying vec4 tint;

	#if defined(APPLY_GAMMA)
			vec3 GammaToLinear(vec3 col)
			{
				return col * (col * (col * 0.305306011 + 0.682171111) + 0.012522878);
			}
	#endif
			uniform vec4 _Color;
			uniform vec2 _Padding;
			uniform vec2 _Offset;
	#if defined(USING_DEFAULT_TEXTURE)
			uniform sampler2D _MainTex;
			uniform sampler2D _Overlay;
	#else 
			uniform samplerExternalOES _MainTex;
			uniform samplerExternalOES _Overlay;
	#endif
			uniform vec4 _MainTex_TexelSize;

			void main()
			{
				bool isleft = tint.g > 0.9;
				vec2 uv = texVal.xy;

	#if defined(STEREO_CUSTOM_UV)
				uv.xy += vec2(_Offset, _Offset); // Fixing edge line issue by scaling the texture a bit
				uv.y = 1.0 - uv.y;
				uv.xy = convert_texal(uv.xy, isleft, _MainTex_TexelSize, false);
				uv.y = 1.0 - uv.y;
	#endif
	#if defined(APPLY_GRID) 
				uv.y = 1.0 - uv.y;
				uv = Flive_UV(uv, grid_width, grid_height, grid);
				uv.y = 1.0 - uv.y;
	#endif

				vec4 col = vec4(1.0, 1.0, 1.0, 1.0);
	#if defined(STEREO_CUSTOM_UV)
			uv += (_MainTex_TexelSize.xy * 0.5);
			col = Texture2D(_MainTex, vec4(uv.x, uv.y, 0, 0));
	#else
		#if __VERSION__ < 300 
			col = texture2D(_MainTex, uv);
		#else
			col = texture(_MainTex, uv);
		#endif
	#endif
				col *= _Color;

	#if defined(APPLY_GAMMA)
				col.rgb = GammaToLinear(col.rgb);
	#endif

	#if defined(STEREO_DEBUG)
				if (int(_Time.z) % 5 == 0){
					col = vec4(uv.x, uv.y, 0.0, 1.0);
				}
	#endif

				gl_FragColor = col;
			}
#endif

			ENDGLSL
		}
	}

	Fallback "AVProVideo/VR/InsideSphere Unlit (stereo+fog)"
}