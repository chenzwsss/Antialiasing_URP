using UnityEngine;
using UnityEngine.Rendering.Universal;

public class TAARendererFeature : ScriptableRendererFeature
{
    public CustomPostProcessData m_CustomPostProcessData;
    public RenderPassEvent m_Event = RenderPassEvent.BeforeRenderingPostProcessing;
    TAAPass taaPass;

    public override void Create()
    {
        if (m_CustomPostProcessData == null)
        {
            Debug.LogError("Post process data missing.");
            return;
        }
        taaPass = new TAAPass(m_Event, m_CustomPostProcessData);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        taaPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(taaPass);
    }

    protected override void Dispose(bool disposing)
    {
        taaPass.Cleanup();
    }
}
