Shader "Hidden/PostEffect/TAA"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRender" }

        Pass
        {
            Name "TAA"

            Cull Off ZWrite Off ZTest Always

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;

            TEXTURE2D(_HistoryTex);
            SAMPLER(sampler_HistoryTex);

            float2 _Jitter;

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

            float4 frag(Varyings input) : SV_TARGET
            {
                float2 uv = input.uv - _Jitter;
                float3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                float3 history = SAMPLE_TEXTURE2D(_HistoryTex, sampler_HistoryTex, input.uv).rgb;
                return float4(lerp(color, history, 0.05), 1.0);
            }

            ENDHLSL
        }
    }
}
