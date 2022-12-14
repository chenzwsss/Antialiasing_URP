using UnityEngine;
using UnityEngine.Rendering.Universal;

public class FXAARendererFeature : ScriptableRendererFeature
{
    public CustomPostProcessData m_CustomPostProcessData;
    public RenderPassEvent m_Event = RenderPassEvent.BeforeRenderingPostProcessing;
    FXAAPass fxaaPass;

    public override void Create()
    {
        if (m_CustomPostProcessData == null)
        {
            Debug.LogError("Post process data missing.");
            return;
        }
        fxaaPass = new FXAAPass(m_Event, m_CustomPostProcessData);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        fxaaPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(fxaaPass);
    }
}
