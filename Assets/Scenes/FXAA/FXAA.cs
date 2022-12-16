using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Custom/FXAA", typeof(UniversalRenderPipeline))]
public class FXAA : VolumeComponent, IPostProcessComponent
{
    public BoolParameter enabled = new BoolParameter(false);

    #region FXAAQuality

    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD_MIN define.
    // It is here now to allow easier tuning.
    // Trims the algorithm from processing darks.
    //   0.0833 - upper limit (default, the start of visible unfiltered edges)
    //   0.0625 - high quality (faster)
    //   0.0312 - visible limit (slower)
    // Special notes when using FXAA_GREEN_AS_LUMA,
    //   Likely want to set this to zero.
    //   As colors that are mostly not-green
    //   will appear very dark in the green channel!
    //   Tune by looking at mostly non-green content,
    //   then start at zero and increase until aliasing is a problem.
    [Range(0.0312f, 0.0833f)]
    public ClampedFloatParameter fxaaQualityEdgeThresholdMin = new ClampedFloatParameter(0.0312f, 0.0312f, 0.0833f);

    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD define.
    // It is here now to allow easier tuning.
    // The minimum amount of local contrast required to apply algorithm.
    //   0.333 - too little (faster)
    //   0.250 - low quality
    //   0.166 - default
    //   0.125 - high quality
    //   0.063 - overkill (slower)
    [Range(0.063f, 0.333f)]
    public ClampedFloatParameter fxaaQualityEdgeThreshold = new ClampedFloatParameter(0.125f, 0.063f, 0.333f);

    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__SUBPIX define.
    // It is here now to allow easier tuning.
    // Choose the amount of sub-pixel aliasing removal.
    // This can effect sharpness.
    //   1.00 - upper limit (softer)
    //   0.75 - default amount of filtering
    //   0.50 - lower limit (sharper, less sub-pixel aliasing removal)
    //   0.25 - almost off
    //   0.00 - completely off
    [Range(0f, 1f)]
    public ClampedFloatParameter fxaaQualitySubpix = new ClampedFloatParameter(0.75f, 0f, 1f);

    #endregion

    public BoolParameter useConsole = new BoolParameter(false);

    // 8.0 is sharper
    // 4.0 is softer
    // 2.0 is really soft (good for vector graphics inputs)
    public ClampedIntParameter fxaaConsoleEdgeSharpness = new ClampedIntParameter(8, 2, 8);

    public bool IsActive() => enabled.value;

    public bool IsTileCompatible() => false;
}
