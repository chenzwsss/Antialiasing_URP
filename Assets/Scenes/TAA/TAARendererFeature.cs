using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class TAARendererFeature : ScriptableRendererFeature
{
    public CustomPostProcessData m_CustomPostProcessData;
    public RenderPassEvent m_Event = RenderPassEvent.BeforeRenderingPostProcessing;

    TAAJitterPass m_TaaJitterPass;
    TAARenderPass m_TaaRenderPass;

    Dictionary<Camera, TAAData> m_TaaDataCaches;

    bool isFirstFrame;

    public override void Create()
    {
        if (m_CustomPostProcessData == null)
        {
            Debug.LogError("Post process data missing.");
            return;
        }

        isFirstFrame = true;

        m_TaaJitterPass = new TAAJitterPass();
        m_TaaRenderPass = new TAARenderPass(m_Event, m_CustomPostProcessData);

        m_TaaDataCaches = new Dictionary<Camera, TAAData>();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.camera.cameraType is not (CameraType.Game)) return;

        if (isFirstFrame)
        {
            isFirstFrame = false;
            return;
        }

        Camera camera = renderingData.cameraData.camera;

        if (!m_TaaDataCaches.TryGetValue(camera, out var taaData))
        {
            taaData = new TAAData();
            m_TaaDataCaches.Add(camera, taaData);
        }
        UpdateTaaData(camera, taaData);

        m_TaaJitterPass.Setup(taaData);
        renderer.EnqueuePass(m_TaaJitterPass);

        m_TaaRenderPass.Setup(renderer.cameraColorTarget, taaData);
        renderer.EnqueuePass(m_TaaRenderPass);
    }

    void UpdateTaaData(Camera camera, TAAData taaData)
    {
        Vector2 jitter = TAAUtils.GenerateRandomOffset();
        taaData.offset = new Vector2(jitter.x / camera.scaledPixelWidth, jitter.y / camera.scaledPixelHeight);
        taaData.projJitter = camera.orthographic
            ? TAAUtils.GetJitteredOrthographicProjectionMatrix(camera, jitter)
            : TAAUtils.GetJitteredPerspectiveProjectionMatrix(camera, jitter);
    }

    protected override void Dispose(bool disposing)
    {
        m_TaaRenderPass.Cleanup();
    }
}
