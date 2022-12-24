using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Custom/TAA", typeof(UniversalRenderPipeline))]
public class TAA : VolumeComponent, IPostProcessComponent
{
    public BoolParameter enabled = new BoolParameter(false);

    /// <summary>
    /// Controls the amount of sharpening applied to the color buffer. High values may introduce
    /// dark-border artifacts.
    /// </summary>
    [Tooltip("Controls the amount of sharpening applied to the color buffer. High values may introduce dark-border artifacts.")]
    public ClampedFloatParameter sharpness = new ClampedFloatParameter(0.25f, 0f, 3f);

    public bool IsActive() => enabled.value;

    public bool IsTileCompatible() => false;
}
