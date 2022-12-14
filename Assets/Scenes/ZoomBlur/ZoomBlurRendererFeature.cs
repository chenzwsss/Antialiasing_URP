using UnityEngine;
using UnityEngine.Rendering.Universal;

public class ZoomBlurRendererFeature : ScriptableRendererFeature
{
    public CustomPostProcessData m_CustomPostProcessData;
    public RenderPassEvent m_Event = RenderPassEvent.BeforeRenderingPostProcessing;

    private ZoomBlurPass zoomBlurPass;

    public override void Create()
    {
        if (m_CustomPostProcessData == null)
        {
            Debug.LogError("Post process data missing.");
            return;
        }
        zoomBlurPass = new ZoomBlurPass(m_Event, m_CustomPostProcessData);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_CustomPostProcessData)
        {
            zoomBlurPass.Setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(zoomBlurPass);
        }
    }
}
