using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TAAJitterPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "TAA Jitter Pass";

    TAAData m_TaaData;

    public TAAJitterPass()
    {
        renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }

    public void Setup(TAAData taaData)
    {
        m_TaaData = taaData;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get(k_RenderTag);

        using (new ProfilingScope(cmd, new ProfilingSampler("TAA Camera Setup")))
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            Camera camera = renderingData.cameraData.camera;
            cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, m_TaaData.projJitter);
        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
}
