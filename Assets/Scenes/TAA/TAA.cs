using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Custom/TAA", typeof(UniversalRenderPipeline))]
public class TAA : VolumeComponent, IPostProcessComponent
{
    public BoolParameter enabled = new BoolParameter(false);

    public bool IsActive() => enabled.value;

    public bool IsTileCompatible() => false;
}
