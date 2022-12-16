Shader "Hidden/PostEffect/FXAA"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRender" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "../../Shaders/Common.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
        CBUFFER_END

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

        #define ITERATIONS 12
        #define QUALITY 1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0
        static const float EDGE_STEPS[ITERATIONS] = { QUALITY };

        float _FxaaQualityEdgeThresholdMin;
        float _FxaaQualityEdgeThreshold;
        float _FxaaQualitySubpix;

        float _FxaaConsoleEdgeSharpness;

        #define FXAA_SPAN_MAX   (8.0)
        #define FXAA_REDUCE_MUL (1.0 / 8.0)
        #define FXAA_REDUCE_MIN (1.0 / 128.0)

        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv = input.texcoord;
            return output;
        }

        float3 GetSource(float2 uv, float2 offset = float2(0.0, 0.0))
        {
            uv += offset * _MainTex_TexelSize.xy;
            return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
        }

        // http://blog.simonrodriguez.fr/articles/2016/07/implementing_fxaa.html
        float4 FXAAQualityFrag(Varyings input) : SV_TARGET
        {
            float2 uv = input.uv;

            float3 colorCenter = GetSource(uv);

            // 采样点位置
            //  UpLeft       Up      UpRight
            //   Left      Center     Right
            // DownLeft     Down     DownRight

            // 当前纹素亮度
            float lumaCenter = Luminance(colorCenter);

            // 相邻上，下，左，右四个纹素的亮度
            float lumaDown = Luminance(GetSource(uv, float2(0.0, -1.0)));
            float lumaUp = Luminance(GetSource(uv, float2(0.0, 1.0)));
            float lumaLeft = Luminance(GetSource(uv, float2(-1.0, 0.0)));
            float lumaRight = Luminance(GetSource(uv, float2(1.0, 0.0)));

            // 最大的亮度和最小的亮度
            float lumaMin = Min5(lumaCenter, lumaDown, lumaUp, lumaLeft, lumaRight);
            float lumaMax = Max5(lumaCenter, lumaDown, lumaUp, lumaLeft, lumaRight);

            // 最大亮度和最小亮度的差作为对比度
            float lumaRange = lumaMax - lumaMin;

            // 对比度太小则跳过抗锯齿处理
            if (lumaRange < max(_FxaaQualityEdgeThresholdMin, lumaMax * _FxaaQualityEdgeThreshold))
            {
                return float4(colorCenter, 1.0);
            }

            // 对角线相邻的纹素的亮度
            float lumaDownLeft = Luminance(GetSource(uv, float2(-1.0, -1.0)));
            float lumaUpRight = Luminance(GetSource(uv, float2(1.0, 1.0)));
            float lumaUpLeft = Luminance(GetSource(uv, float2(-1.0, 1.0)));
            float lumaDownRight = Luminance(GetSource(uv, float2(1.0, -1.0)));

            // 沿着水平方向纹素亮度变化梯度
            float edgeHorizontal = abs(lumaDownLeft + lumaUpLeft - 2.0 * lumaLeft) + abs(lumaDown + lumaUp - 2.0 * lumaCenter) + abs(lumaDownRight + lumaUpRight - 2.0 * lumaRight);
            // 沿着垂直方向纹素亮度变化梯度
            float edgeVertical = abs(lumaUpRight + lumaUpLeft - 2.0 * lumaUp) + abs(lumaRight + lumaLeft - 2.0 * lumaCenter) + abs(lumaDownRight + lumaDownLeft - 2.0 * lumaDown);

            // 沿着水平方向纹素亮度变化梯度大，则边缘是水平的；沿着垂直方向纹素亮度变化梯度大，则边缘是垂直的
            bool isHorizontal = edgeHorizontal >= edgeVertical;

            // 通过边缘方向得到对应的正方向和负方向相邻的纹素亮度
            // 其中，在水平方向时，向右为正，向左为负；垂直方向时，向上为正，向下为负

            // 选择与当前纹素相反方向的两个相邻纹素亮度
            // 边缘是水平的时，取上、下两个纹素亮度；边缘是垂直的时，取左、右两个纹素亮度
            // 其中，左和下两个纹素作为相对于当前纹素的负方向纹素亮度；右和上作为正方向纹素亮度
            float lumaNegative = isHorizontal ? lumaDown : lumaLeft;
            float lumaPositive = isHorizontal ? lumaUp : lumaRight;

            // 计算出正方向和负方向上的亮度变化梯度
            float gradientNegative = abs(lumaNegative - lumaCenter);
            float gradientPositive = abs(lumaPositive - lumaCenter);

            // 取梯度较大的方向作为搜索的方向
            bool isNegativeDirectionSteepest = gradientNegative >= gradientPositive;

            // 相应搜索方向的梯度参考值，大于等于此值意味找到了边界
            float gradientScaled = 0.25 * max(gradientNegative, gradientPositive);

            // 一个纹素的步长
            // 水平方向时，y 方向向上偏移 0.5个纹素高度 _MainTex_TexelSize.y，到达边缘位置；垂直方向时，x 方向向右偏移 0.5 个纹素宽度 _MainTex_TexelSize.x，达到边缘位置
            float stepLength = isHorizontal ? _MainTex_TexelSize.y : _MainTex_TexelSize.x;

            float lumaLocalAverage;
            if (isNegativeDirectionSteepest)
            {
                // 负方向两素梯度较大时，要向负方向搜索，所以搜索步长值取反
                stepLength = -stepLength;

                // 计算其相邻处的亮度，即为当前纹素和搜索方向相邻纹素的边缘上的亮度值
                lumaLocalAverage = 0.5 * (lumaNegative + lumaCenter);
            }
            else
            {
                // 计算其相邻处的亮度，即为当前纹素和搜索方向相邻纹素的边缘上的亮度值
                lumaLocalAverage = 0.5 * (lumaPositive + lumaCenter);
            }

            // 偏移 0.5 个纹素宽/高，为搜索起点
            float2 currentUv = uv;
            if (isHorizontal)
            {
                currentUv.y += stepLength * 0.5;
            }
            else
            {
                currentUv.x += stepLength * 0.5;
            }

            // 每一次搜索的正方向偏移，边缘为水平时，水平偏移；边缘为垂直时，垂直偏移
            float2 offset = isHorizontal ? float2(_MainTex_TexelSize.x, 0.0) : float2(0.0, _MainTex_TexelSize.y);

            // uv1，uv2为相反的两个方向，同时搜索边界
            float2 uv1 = currentUv;
            float2 uv2 = currentUv;
            bool reached1 = false;
            bool reached2 = false;
            float lumaEnd1 = 0.0;
            float lumaEnd2 = 0.0;

            UNITY_UNROLL
            for (int i = 0; i < ITERATIONS; ++i)
            {
                // 反方向迭代
                if (!reached1)
                {
                    // uv减偏移
                    uv1 -= offset * EDGE_STEPS[i];
                    // 采样亮度
                    lumaEnd1 = Luminance(GetSource(uv1));
                    // 计算和起点亮度的差
                    lumaEnd1 -= lumaLocalAverage;
                    // 当梯度变化大于等于 gradientScaled 时，意味着到达了边界
                    reached1 = abs(lumaEnd1) >= gradientScaled;
                }

                // 正方向迭代
                if (!reached2)
                {
                    // uv加偏移
                    uv2 += offset * EDGE_STEPS[i];
                    // 采样亮度
                    lumaEnd2 = Luminance(GetSource(uv2));
                    // 计算和起点亮度的差
                    lumaEnd2 -= lumaLocalAverage;
                    // 当梯度变化大于等于 gradientScaled 时，意味着到达了边界
                    reached2 = abs(lumaEnd2) >= gradientScaled;
                }

                // 两个方向都找到边界后，跳出迭代
                if (reached1 && reached2)
                {
                    break;
                }
            }

            // 计算两个方向到边界末端的距离
            float distance1 = isHorizontal ? (uv.x - uv1.x) : (uv.y - uv1.y);
            float distance2 = isHorizontal ? uv2.x - uv.x : uv2.y - uv.y;

            // 哪个方向离边界末端更近
            bool isDirection1 = distance1 < distance2;
            // 取离边界末端最近的距离
            float distanceFinal = min(distance1, distance2);
            // 边界的长度
            float edgeThickness = distance1 + distance2;

            // 计算偏移
            // 这个偏移是相对于原纹素中心的偏移
            // 根据三角形相似可以计算出三角形斜边和垂直于边缘经过当前纹素中心点的交点距离边缘的长度为 distanceFinal / edgeThickness，则相对于原纹素中心的偏移就是 0.5 - distanceFinal / edgeThickness
            float pixelOffset = - distanceFinal / edgeThickness + 0.5;

            // 当前纹素亮度是否小于其相邻处的亮度
            bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;

            // 如果中心处纹素的亮度小于其相邻处的亮度，则两端的亮度增量应该为正的。(属于是相同的变化)
            bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

            // 如果亮度变化不正确，则不要偏移
            float finalOffset = correctVariation ? pixelOffset : 0.0;

            // 3x3 所有相邻纹素的亮度平均值
            float lumaAverage = 2.0 * (lumaDown + lumaUp + lumaLeft + lumaRight) + lumaDownLeft + lumaUpLeft + lumaDownRight + lumaUpRight;
            lumaAverage *= 1.0 / 12.0;

            // 在 3x3 邻域的亮度范围内，全局平均值与中心亮度之间的增量之比。
            float subPixelOffset1 = saturate(abs(lumaAverage - lumaCenter) / lumaRange);
            float subPixelOffset2 = smoothstep(0, 1, subPixelOffset1);

            // 根据此增量计算子像素偏移量。
            float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * _FxaaQualitySubpix;

            // 选取两个偏移中更大的那个
            finalOffset = max(finalOffset, subPixelOffsetFinal);

            // 计算最终的uv
            float2 finalUv = uv;
            if (isHorizontal)
            {
                finalUv.y += finalOffset * stepLength;
            }
            else
            {
                finalUv.x += finalOffset * stepLength;
            }

            return float4(GetSource(finalUv), 1.0);
        }

        float4 FXAAConsoleFrag(Varyings input) : SV_TARGET
        {
            float2 uv = input.uv;
            // 采样当前像素
            float3 colorCenter = GetSource(uv);

            // 当前纹素亮度
            float lumaCenter = Luminance(colorCenter);
            // 当前纹素四个顶点亮度
            float lumaNW = Luminance(GetSource(uv, float2(-0.5, 0.5)));
            float lumaNE = Luminance(GetSource(uv, float2(0.5, 0.5)));
            float lumaSW = Luminance(GetSource(uv, float2(-0.5, -0.5)));
            float lumaSE = Luminance(GetSource(uv, float2(0.5, -0.5)));

            // 最大的亮度和最小的亮度
            float lumaMin = Min5(lumaCenter, lumaNW, lumaNE, lumaSW, lumaSE);
            float lumaMax = Max5(lumaCenter, lumaNW, lumaNE, lumaSW, lumaSE);

            // 最大亮度和最小亮度的差作为对比度
            float lumaRange = lumaMax - lumaMin;

            // 对比度太小则跳过抗锯齿处理
            if (lumaRange < max(_FxaaQualityEdgeThresholdMin, _FxaaQualityEdgeThreshold * lumaMax))
            {
                return float4(colorCenter, 1.0);
            }

            // 根据四个顶点亮度算出边界的切线方向
            float2 dir;
            dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
            dir.y = ((lumaNW + lumaSW) - (lumaNE + lumaSE));

            // 归一化
            float2 dir1 = normalize(dir.xy);

            // 沿着切线方向分别向正反方向偏移一个单位方向采样结果
            float3 rgbN1 = GetSource(uv, -dir1);
            float3 rgbP1 = GetSource(uv, dir1);

            // 对于水平或者垂直的锯齿，由于切线的x,y分量都较小，导致上面2次采样覆盖不了需要混合的区域
            // dir1 向量分量的最小值的倒数，将 dir1 进行缩放。这样如果 dir1 的最小分量的值越小，就能采样到越远的地方
            float dirAbsMinTimesRcp = rcp(min(abs(dir1.x), abs(dir1.y)) * _FxaaConsoleEdgeSharpness);
            // 为了使 dir2 的值不至于太大，最后进行一次 clamp
            float2 dir2 = clamp(dir1.xy * dirAbsMinTimesRcp, -2.0, 2.0);

            // 继续沿着新的方向正负采样2次
            float3 rgbN2 = GetSource(uv, -dir2);
            float3 rgbP2 = GetSource(uv, dir2);

            float3 rgbA = rgbN1 + rgbP1;
            float3 rgbB = (rgbN2 + rgbP2) * 0.25 + rgbA * 0.25;

            float lumaB = Luminance(rgbB);

            float3 finalRgb = rgbB;
            // 第二次的亮度要保证在合适的范围内，超过则使用第一次的结果
            if (lumaB < lumaMin || lumaB > lumaMax)
            {
                finalRgb = rgbA * 0.5;
            }

            return float4(finalRgb, 1.0);
        }

        ENDHLSL

        Pass
        {
            Name "FXAA Quality"

            Cull Off ZWrite Off ZTest Always

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FXAAQualityFrag
            ENDHLSL
        }

        Pass
        {
            Name "FXAA Console"

            Cull Off ZWrite Off ZTest Always

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FXAAConsoleFrag
            ENDHLSL
        }
    }
}
