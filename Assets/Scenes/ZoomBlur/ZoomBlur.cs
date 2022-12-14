using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Custom/ZoomBlur", typeof(UniversalRenderPipeline))]
public class ZoomBlur : VolumeComponent, IPostProcessComponent
{
    [Range(0f, 100f), Tooltip("加强效果使模糊效果更强。")]
    public FloatParameter focusPower = new FloatParameter(0f);

    [Range(0f, 10f), Tooltip("值越大越好, 但是负载将增加")]
    public IntParameter focusDetail = new IntParameter(5);

    [Tooltip("模糊中心坐标已经在屏幕的中心(0, 0)")]
    public Vector2Parameter focusScreenPosition = new Vector2Parameter(Vector2.zero);

    [Tooltip("参考宽度分辨率。")]
    public IntParameter referenceResolutionX = new IntParameter(1334);

    public bool IsActive() => focusPower.value > 0f;

    public bool IsTileCompatible() => false;
}
