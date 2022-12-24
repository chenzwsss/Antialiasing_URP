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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            #define TEXTURE2D_SAMPLER2D(textureName, samplerName) Texture2D textureName; SamplerState samplerName

            #define HALF_MAX_MINUS1 65472.0 // (2 - 2^-9) * 2^15

            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            float4 _MainTex_TexelSize;

            TEXTURE2D_SAMPLER2D(_HistoryTex, sampler_HistoryTex);

            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            TEXTURE2D_SAMPLER2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture);

            float2 _Jitter;
            float _Sharpness;

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

            float2 GetClosestFragment(float2 uv)
            {
                const float2 k = _CameraDepthTexture_TexelSize.xy;

                const float4 neighborhood = float4(
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv - k),
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv + float2(k.x, -k.y)),
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv + float2(-k.x, k.y)),
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv + k)
                );

            #if defined(UNITY_REVERSED_Z)
                #define COMPARE_DEPTH(a, b) step(b, a)
            #else
                #define COMPARE_DEPTH(a, b) step(a, b)
            #endif

                float3 result = float3(0.0, 0.0, SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv));
                result = lerp(result, float3(-1.0, -1.0, neighborhood.x), COMPARE_DEPTH(neighborhood.x, result.z));
                result = lerp(result, float3( 1.0, -1.0, neighborhood.y), COMPARE_DEPTH(neighborhood.y, result.z));
                result = lerp(result, float3(-1.0,  1.0, neighborhood.z), COMPARE_DEPTH(neighborhood.z, result.z));
                result = lerp(result, float3( 1.0,  1.0, neighborhood.w), COMPARE_DEPTH(neighborhood.w, result.z));

                return (uv + result.xy * k);
            }

            float4 ClipToAABB(float4 color, float3 minimum, float3 maximum)
            {
                // Note: only clips towards aabb center (but fast!)
                float3 center = 0.5 * (maximum + minimum);
                float3 extents = 0.5 * (maximum - minimum);

                // This is actually `distance`, however the keyword is reserved
                float3 offset = color.rgb - center;

                float3 ts = abs(extents / (offset + 0.0001));
                float t = saturate(Min3(ts.x, ts.y, ts.z));
                color.rgb = center + offset * t;
                return color;
            }

            float4 frag(Varyings input) : SV_TARGET
            {
                float2 uv = input.uv - _Jitter;
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                float4 topLeft = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - 0.5 * _MainTex_TexelSize.xy);
                float4 bottomRight = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + 0.5 * _MainTex_TexelSize.xy);

                float4 corners = 4.0 * (topLeft + bottomRight) - 2.0 * color;

                color += (color - (corners * 0.166667)) * 2.718282 * _Sharpness;
                color = clamp(color, 0.0, HALF_MAX_MINUS1);

                // Tonemap color and history samples
                float4 average = (corners + color) * 0.142857;

                float2 closest = GetClosestFragment(input.uv);
                float2 motion = SAMPLE_TEXTURE2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture, closest).xy;

                float4 history = SAMPLE_TEXTURE2D(_HistoryTex, sampler_HistoryTex, input.uv - motion);

                float motionLength = length(motion);

                float2 luma = float2(Luminance(average), Luminance(color));

                float nudge = lerp(4.0, 0.25, saturate(motionLength * 100.0)) * abs(luma.x - luma.y);

                float4 minimum = min(bottomRight, topLeft) - nudge;
                float4 maximum = max(topLeft, bottomRight) + nudge;

                // Clip history samples
                history = ClipToAABB(history, minimum.xyz, maximum.xyz);

                color = lerp(color, history, 0.05);
                color = clamp(color, 0.0, HALF_MAX_MINUS1);

                return color;
            }

            ENDHLSL
        }
    }
}
