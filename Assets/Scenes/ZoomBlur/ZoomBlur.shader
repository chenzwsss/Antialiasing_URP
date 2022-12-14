Shader "Hidden/PostEffect/ZoomBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 _FocusScreenPosition;
            float _FocusPower;
            int _FocusDetail;
            int _ReferenceResolutionX;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.texcoord;
                return output;
            }

            real4 frag(Varyings input) : SV_TARGET
            {
                float2 screenPoint = _FocusScreenPosition.xy + _ScreenParams.xy / 2;
                float2 uv = input.uv;
                float2 mousePos = screenPoint.xy / _ScreenParams.xy;
                float2 focus = uv - mousePos;
                real aspectX = _ScreenParams.x / _ReferenceResolutionX;
                real4 outColor = real4(0, 0, 0, 1);
                for (int i = 0; i < _FocusDetail; i++)
                {
                    float power = 1.0 - _FocusPower * (1.0 / _ScreenParams.x * aspectX) * float(i);
                    outColor.rgb += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, focus * power + mousePos).rgb;
                }
                outColor.rgb *= 1.0 / float(_FocusDetail);
                return outColor;
            }

            ENDHLSL
        }
    }
}
